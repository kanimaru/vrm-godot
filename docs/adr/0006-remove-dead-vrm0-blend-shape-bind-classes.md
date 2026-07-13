# ADR-0006: Remove Dead VRM0 Blend Shape Bind Classes

**Status:** Proposed
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

## Consequences

- Easier: one less unused, confusing parallel abstraction near the actively-used runtime bind
  classes.
- Harder: none meaningfully; low risk.

## Action Items

1. [ ] Confirm via `git log`/`git blame` these were never wired up (not a recent regression that
       needs fixing forward instead of deleting)
2. [ ] Delete `vrm0_runtime_blend_shape_bind.gd` and `vrm0_runtime_blend_shape_binds.gd`
       (+ their `.uid` files)
3. [ ] Re-run the GUT suite to confirm nothing depended on their mere presence (e.g. `class_name`
       registration side effects)
