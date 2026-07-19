# ADR-0007: Consolidate Cross-Generation Runtime Types and Expression Name Mapping

**Status:** Implemented (name-mapping mechanism corrected — see Outcome below)
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

Two related layering smells:

1. VRM0's expression controller depends directly on VRM1's `RuntimeExpression`/`RuntimeMorphBind`
   classes (`addons/vrm/vrm1/nodes/runtime/`), even though these types are generation-agnostic —
   see [ADR-0006](0006-remove-dead-vrm0-blend-shape-bind-classes.md) for why sharing them is
   correct. The "legacy" format depending on the "current" format's internals is backwards;
   both should depend on a shared, generation-neutral location instead.
2. Two independent expression-name-mapping tables exist for the same problem: `EXPRESSION_NAME_MAP`
   in `VrmaAnimationLibraryBuilder` and `VRM1_TO_VRM0_EXPRESSIONS` in
   `runtime/vrm_runtime_loader.gd:19`. `common/vrm_constants.gd` — the designated home for shared
   constants per the `vrm_format` skill — has neither.

## Decision

Relocate the shared runtime expression-bind classes to `common/`, and consolidate both
name-mapping tables into a single constant in `vrm_constants.gd`.

## Options Considered

### Runtime classes — Option A: Move to `common/`

Move `RuntimeExpression`, `RuntimeMorphBind`, `RuntimeMaterialColorBind`, etc. from
`vrm1/nodes/runtime/` to `addons/vrm/common/`; update both `Vrm0ExpressionController` and
`Vrm1ExpressionController` to reference the common location.

**Pros:** Removes the backwards VRM0→VRM1 dependency; folder structure accurately reflects that
these types aren't VRM1-specific. Consistent with the direction of ADR-0001/ADR-0002 (pull shared
logic out of generation-specific folders).
**Cons:** Mechanical risk — every `preload()`/`class_name` reference needs updating.

### Runtime classes — Option B: Rename in place, leave in `vrm1/`

**Pros:** Cheaper — no path updates.
**Cons:** Leaves the misleading folder location; doesn't fix the dependency direction, only
documents it. Rejected as insufficient.

### Runtime classes — Option C: Give VRM0 its own copy

**Pros:** Restores "generation independence."
**Cons:** Directly reverses ADR-0006's reasoning — these binds are structurally identical across
generations, so forking them back apart reintroduces the exact duplication being removed
elsewhere in this review. Rejected.

### Name mapping — Option A: Single table in `vrm_constants.gd`

Both `VrmaAnimationLibraryBuilder` and `vrm_runtime_loader.gd` reference one
`EXPRESSION_NAME_MAP: Dictionary[String, String]` (or bidirectional helper) defined in
`vrm_constants.gd`.

**Pros:** Matches `vrm_constants.gd`'s stated purpose; one obvious place for future contributors
to add new expression preset mappings.
**Cons:** Requires reconciling any discrepancies between the two existing tables first (see
Action Items).

### Name mapping — Option B: One table delegates to the other

E.g. `vrm_runtime_loader.gd` references `VrmaAnimationLibraryBuilder.EXPRESSION_NAME_MAP`
directly instead of duplicating it.

**Pros:** Avoids touching `vrm_constants.gd`.
**Cons:** Leaves "ownership" of a naming constant in an animation builder class, which is an odd
place for unrelated runtime code to depend on. Rejected in favor of the constants file.

## Trade-off Analysis

Option A for both: move the runtime classes to `common/`, and consolidate the expression map into
`vrm_constants.gd`. Both changes are mechanical rather than risky, and both align with the
direction already set by ADR-0001/ADR-0002/ADR-0006.

## Action Items

1. [x] Diff `EXPRESSION_NAME_MAP` (vrma builder) against `VRM1_TO_VRM0_EXPRESSIONS` (runtime
       loader) for discrepancies before merging — **done, and they turned out not to be
       duplicates of the same problem at all; see Outcome below**
2. [x] Move the runtime bind/state classes from `vrm1/nodes/runtime/` to `common/`; update
       references in `vrm0_expression_controller.gd`, `vrm1_expression_controller.gd`,
       `vrm1_active_expression.gd`, and any other referencing files — also renamed the 8 files
       to drop the `vrm1_` prefix (e.g. `vrm1_runtime_expression.gd` → `vrm_runtime_expression.gd`),
       matching every other file already in `common/`. Consumers (`vrm0_expression_controller.gd`,
       `vrm1_expression_controller.gd`) now reference them via explicit
       `const X = preload("uid://...")  # res://addons/vrm/common/...gd"` declarations instead of
       bare global `class_name` resolution — after the stale-class-cache surprise in ADR-0005,
       `uid://` references are immune to that failure mode since Godot tracks them by UID, not path.
3. [x] Add the reconciled mapping table to `vrm_constants.gd`; update both call sites to
       reference it — see Outcome; only one of the two tables actually belonged here
4. [x] Update `.claude/skills/vrm_format` references — `gltf-structure.md` had a stale
       `vrm1/nodes/runtime/` path plus no mention of the `surprised`/gaze-preset gaps; fixed and
       expanded
5. [x] Re-run the GUT suite — 173/173, unchanged. Manual runtime-demo slider test not done
       (no editor GUI in this session, same caveat as ADR-0004/ADR-0001's manual-check items)

## Outcome: the two "duplicate" tables were solving different problems

Action item 1 (diff before merging) is the one that mattered here. `EXPRESSION_NAME_MAP` and
`VRM1_TO_VRM0_EXPRESSIONS` looked like the same duplicated table from the outside — both are
`Dictionary[String, String]` keyed by VRM1 preset names — but diffing their actual keys/values
and call sites shows they solve two unrelated problems:

**`EXPRESSION_NAME_MAP` (in `VrmaAnimationLibraryBuilder`) was never a cross-generation table.**
Every entry (`"happy": "happy"`, `"blinkLeft": "blink_left"`, ...) is a VRM1-internal camelCase
JSON-key → snake_case `Vrm1ExpressionController` property name conversion. `Vrm1ExpressionController.
get_expression()`/`set_expression()` already does exactly this generically via
`expr_name.to_snake_case()` — and every single entry in the hardcoded table produces the
identical output `to_snake_case()` would. It wasn't a duplicate of the other table; it was a
duplicate of a one-line built-in string method. **Deleted**, call site now does
`expr_name.to_snake_case()` directly with a comment explaining why no table is needed.

**`VRM1_TO_VRM0_EXPRESSIONS` (in `vrm_runtime_loader.gd`) is the genuine cross-generation table**
— joy/sorrow/fun vs. happy/sad/relaxed, a/i/u/e/o vs. aa/ih/ou/ee/oh — used when retargeting a
VRM1-authored VRMA animation onto a VRM0 avatar, whose `Vrm0ExpressionController` still uses the
old naming. This can't be derived generically; it's genuinely hand-maintained data. **This is the
one that actually belonged in `vrm_constants.gd`**, renamed `EXPRESSION_VRM1_TO_VRM0` there.

While diffing them (per your request to check the spec for what VRM0 does and doesn't support),
found real, confirmed generation asymmetries, now documented in a comment on the constant and in
the `vrm_format` skill:

- VRM 1.0 added `surprised` as a new preset in 1.0 (`docs/VRMC_vrm-1.0/expressions.md`,
  "Emotions" table says so explicitly). VRM 0.x's spec preset enum has no equivalent. The
  identity-fallback in the mapping happens to work only because `Vrm0ExpressionController`
  exposes a non-spec `surprised` property anyway — not because VRM0 supports it.
- VRM 0.x's spec preset enum *does* define `lookup`/`lookdown`/`lookleft`/`lookright`, but
  `Vrm0ExpressionController` doesn't expose properties for any of them (unlike
  `Vrm1ExpressionController`, which has `look_up`/`look_down`/`look_left`/`look_right`). A VRM1
  VRMA's gaze-expression tracks silently no-op when retargeted onto a VRM0 avatar — not a crash,
  just nothing happens.
- Separately (material binds, not expression names): VRM 1.0's `materialColorBind.type` has 6
  values (`color`, `emissionColor`, `shadeColor`, `matcapColor`, `rimColor`, `outlineColor`,
  all handled by `Vrm1ExpressionController._resolve_material_prop_name`). VRM 0.x's
  `Vrm0ExpressionController._resolve_vrm0_material_property` only translates 4 Unity property
  names (`_Color`, `_EmissionColor`, `_ShadeColor`, `_OutlineColor`) — no `_RimColor`/matcap
  equivalent, even though VRM0's `materialbind.propertyName` is a free-form string that could
  legally carry one. A VRM0 file with rim or matcap material animation would have those binds
  silently dropped (`_resolve_vrm0_material_property` returns `{}` for unrecognized names, and
  the caller does `if prop_info.is_empty(): continue`).

None of these three gaps were fixed here — they're feature-completeness gaps in VRM0 support, not
naming/layering duplication, which is what this ADR was scoped to address. Flagging them as
follow-up candidates rather than fixing silently or ignoring.

## Consequences (revised)

- Easier: "where do I add a new cross-generation expression name mapping" has one obvious
  answer (`vrm_constants.gd`); `vrm0/`/`vrm1/` folders contain only generation-specific code;
  `vrma_animation_library_builder.gd` has one less hardcoded table to keep in sync with
  `Vrm1ExpressionController`'s actual property names.
- Harder: none beyond the mechanical reference updates, all completed and test-verified.
- Follow-up candidates (not part of this ADR): VRM0 material-bind support for rim/matcap colors,
  and VRM0 gaze-expression (`look_up`/etc.) properties on `Vrm0ExpressionController` — both are
  real spec-coverage gaps, not addressed here.
