# ADR-0007: Consolidate Cross-Generation Runtime Types and Expression Name Mapping

**Status:** Proposed
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

## Consequences

- Easier: "where do I add a new expression preset mapping" has one obvious answer; `vrm0/`/`vrm1/`
  folders more accurately contain only generation-specific code.
- Harder: moving classes referenced via `preload()`/`class_name` requires updating all reference
  paths — mechanical but must be thorough (search-and-replace across the addon).
- Revisit: the two existing name-mapping tables may have accumulated small differences that
  should be reconciled explicitly rather than silently picking one as authoritative.

## Action Items

1. [ ] Diff `EXPRESSION_NAME_MAP` (vrma builder) against `VRM1_TO_VRM0_EXPRESSIONS` (runtime
       loader) for discrepancies before merging
2. [ ] Move the runtime bind/state classes from `vrm1/nodes/runtime/` to `common/`; update
       references in `vrm0_expression_controller.gd`, `vrm1_expression_controller.gd`,
       `vrm1_active_expression.gd`, and any other referencing files
3. [ ] Add the reconciled mapping table to `vrm_constants.gd`; update both call sites to
       reference it
4. [ ] Update `.claude/skills/vrm_format` references if they mention the old
       `vrm1/nodes/runtime/` location
5. [ ] Re-run the GUT suite and manually test the expression sliders in the runtime demo
