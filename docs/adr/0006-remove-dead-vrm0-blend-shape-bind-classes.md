# ADR-0006: Remove Dead VRM0 Blend Shape Bind Classes

**Status:** Implemented
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

`Vrm0RuntimeBlendShapeBind`/`Vrm0RuntimeBlendShapeBinds`
(`addons/vrm/vrm0/nodes/runtime/vrm0_runtime_blend_shape_bind.gd` and `_binds.gd`) are defined but
never referenced anywhere else in the addon (confirmed by grepping the full `addons/` tree).
`Vrm0ExpressionController` explicitly documents that it "uses the shared `RuntimeExpression` class
from VRM1 runtime" instead ([vrm0_expression_controller.gd:6](../../addons/vrm/vrm0/nodes/vrm0_expression_controller.gd)).

This is lower-stakes than the other findings — simple dead-code cleanup rather than a genuine
fork in design direction — but is recorded here for completeness and traceability.

## Decision

Delete both files.

## Options Considered

### Option A: Delete outright

**Pros:** Removes an unused, confusing parallel abstraction. Git history preserves the code if
ever needed again.
**Cons:** None significant — these are private implementation classes inside an addon's
`nodes/runtime/` folder, not part of any public API contract external code could depend on.

### Option B: Keep but mark deprecated

**Pros:** Extra caution in case an unknown downstream fork depends on them.
**Cons:** This addon isn't published as a versioned library with external compatibility
guarantees; the caution isn't warranted. Adds permanent clutter for no benefit.

### Option C: Investigate whether they were the *intended* design

Possible that `Vrm0ExpressionController` has a latent bug and should be using its own VRM0-native
bind classes instead of reaching into VRM1's runtime types (this would also bear on ADR-0007).

**Pros:** Worth a quick sanity check before deleting.
**Cons:** VRM0 and VRM1 morph binds are structurally identical (mesh index + shape index +
weight — no generation-specific fields), so sharing one implementation is the correct design;
the dead classes are the leftover, not the intended path. Covered as a verification step below,
not a separate option to pursue.

## Trade-off Analysis

Option A, after the Option C sanity check confirms these were never wired up as a recent
regression.

## Verification against the VRM spec (Option C, done properly)

Before deleting, checked whether the dead classes might encode a deliberate VRM0-specific design
the currently-active code silently drops. They don't — the opposite is true:

- `RuntimeBlendShapeBind` has exactly three fields: `mesh_path`, `shape_index`, `weight`. No
  concept of material binds at all.
- The VRM 0.0 spec's `vrm.blendshape.group.schema.json` defines a blend shape group as `binds`
  (morph targets) **and** `materialValues` (material color/UV animation via
  `vrm.blendshape.materialbind.schema.json`: `materialName`/`propertyName`/`targetValue`). VRM0
  legitimately uses both.
- The **active** `Vrm0ExpressionController.compile_vrm0_binds` handles both: morph binds via the
  shared `RuntimeMorphBind`, and material binds via `RuntimeMaterialColorBind`/
  `RuntimeTextureTransformBind` (see `_resolve_vrm0_material_property`, which maps VRM0's Unity
  shader property names — `_Color`, `_EmissionColor`, `_ShadeColor`, `_OutlineColor`,
  `_MainTex_ST` — onto Godot MToon property equivalents). The dead classes could never have
  supported this; they have no fields for it.
- Weight units also differ by generation and are already handled correctly in the active path:
  VRM 0.0's `vrm.blendshape.bind.weight` is documented `0–100`
  (`SkinnedMeshRenderer.SetBlendShapeWeight`, Unity's percentage convention), while VRM 1.0's
  `VRMC_vrm.expressions.expression.morphTargetBind.weight` is a plain unitless number (0–1
  convention). `compile_vrm0_binds` does `blend_shape_bind.weight / 100.0` when building the
  shared `RuntimeMorphBind`, correctly normalizing VRM0's percentage into the 0–1 scale the
  shared runtime type (and Godot's blend shapes) expect. The dead classes have no such
  conversion anywhere.
- `git log --follow` on both files shows a single commit each: `b345ee5 feat: implement VRM 1.0
  expression and runtime systems with initial asset support` — i.e. an early VRM0 stub written
  during the initial VRM1 buildout, never touched again. Not a recent regression.

Conclusion: no hidden design to preserve. The dead classes are a strictly less-complete earlier
attempt (morph-only, wrong weight units for standalone use) superseded by the current
shared-class implementation, which correctly covers everything the VRM0 spec requires.

## Consequences

- Easier: one less unused, confusing parallel abstraction near the actively-used runtime bind
  classes.
- Harder: none meaningfully; low risk.

## Action Items

1. [x] Confirm via `git log`/`git blame` these were never wired up (not a recent regression that
       needs fixing forward instead of deleting) — confirmed, single-commit origin, never
       referenced since
2. [x] Delete `vrm0_runtime_blend_shape_bind.gd` and `vrm0_runtime_blend_shape_binds.gd`
       (+ their `.uid` files)
3. [x] Re-run the GUT suite to confirm nothing depended on their mere presence (e.g. `class_name`
       registration side effects) — 173/173 passed, unchanged from before deletion
