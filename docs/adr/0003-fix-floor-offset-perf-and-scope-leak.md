# ADR-0003: Fix Floor-Offset Correction Performance and Scope Leak

**Status:** Proposed
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

`VrmAnimationRetargeter._retarget_animation` calls `_apply_vmd_floor_offset(anim)`
([common/vrm_animation_retargeter.gd:125-127](../../addons/vrm/common/vrm_animation_retargeter.gd))
**inside** the per-track loop. `_apply_vmd_floor_offset` itself scans every track, so for an
animation with *n* bone tracks it runs the full scan *n* times — O(n²) instead of O(n).

Separately, despite its VMD-specific name, the fix is gated only by a generically-named
`ProjectSettings` key (`vrm_fix_vmd_floor_offset`, default `true`) and applies to **every**
`AnimationLibrary` the generic retargeter touches — including plain VRMA clips that never
involved VMD at all. This is a scope leak: a format-specific correction living in
generation/format-agnostic shared code.

## Decision

1. Move the `_apply_vmd_floor_offset(anim)` call outside the per-track loop so it runs once per
   animation.
2. Scope the correction explicitly to VMD-originated animations instead of relying on a global,
   indiscriminately-applied setting.

## Options Considered

### Option A: Tag animations at build time, check the tag

`VmdAnimationLibraryBuilder` sets `anim.set_meta("source_format", "vmd")`; the retargeter checks
that meta before applying the floor offset.

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Risk | Low |

**Pros:** Minimal change, keeps the correction in the shared retargeter but scopes it correctly.
**Cons:** The generic retargeter still has to know VMD-specific concepts exist, even if gated.

### Option B: Move the fix into `VmdAnimationLibraryBuilder.build()`

Apply the floor offset directly at VMD bake time, before the library ever reaches the generic
retargeter, which then never needs to know about VMD at all.

**Pros:** Architecturally cleanest — fully removes the VMD-specific concern from the
generation-agnostic retargeter, consistent with the direction of ADR-0001/ADR-0002.
**Cons:** Must verify ordering — the floor-offset filter matches tracks by *resolved* bone name
(`leftFoot`, `rightFoot`, etc.), and bone-name resolution currently happens in the retargeter,
after baking. If VMD tracks aren't yet in resolved-name form at bake time, this option needs the
bone-name resolution step moved earlier too, which is a larger change.

### Option C: Keep the global setting, just rename/document it

**Pros:** No behavior change beyond the O(n²) fix.
**Cons:** Doesn't fix the scope leak — VRMA/BVH content can still be silently floor-snapped.
Only acceptable if testing shows this never actually affects non-VMD content in practice, which
is unlikely to hold as a long-term guarantee. Rejected as the primary fix, but worth doing as a
stopgap if B proves infeasible.

## Trade-off Analysis

Prefer Option B if the bone-name-resolution ordering allows it (see Action Items — this must be
verified before committing to B over A). Either way, the O(n²) loop fix is required regardless of
which scoping option is chosen.

## Consequences

- Easier: VRMA and BVH animations no longer risk an unintended floor-snap; the retargeter shrinks
  back to being genuinely format-agnostic.
- Harder: must verify no currently-passing behavior secretly depends on floor-offset being
  applied to all animations — check with existing tests plus a manual visual check of a
  VRMA-only avatar before and after.

## Action Items

1. [ ] Move `_apply_vmd_floor_offset(anim)` outside the per-track loop in `_retarget_animation`
       (required regardless of scoping option)
2. [ ] Determine whether floor-offset's bone-name filter can run against VMD's pre-resolution
       track names; if yes, implement Option B, else implement Option A
3. [ ] Add a GUT test asserting floor-offset is NOT applied to a VRMA-sourced animation
4. [ ] Manually verify VMD dance playback still lands feet at Y=0 after the change
