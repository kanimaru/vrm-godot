# ADR-0002: Unify Rest-Pose Retargeting Math

**Status:** Proposed
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

The rest-pose-relative quaternion retargeting formula (`W · L⁻¹ · local · W⁻¹`) is implemented
independently in at least two places:

- `VrmaAnimationLibraryBuilder._normalize_rotation` ([vrma_animation_library_builder.gd:329-332](../../addons/vrm/vrma/vrma_animation_library_builder.gd)) —
  applied to baked VRMA tracks at import time, using precomputed `world_rests`/`local_rests`
  dictionaries.
- `VrmIkController._sync_bone_rotation` ([vrm_ik_controller.gd:227-255](../../addons/vrm/vmd/vrm_ik_controller.gd)) —
  the same family of math, applied per-frame to live skeleton bones for VMD foot IK.

`VrmAnimationRetargeter` ([common/vrm_animation_retargeter.gd](../../addons/vrm/common/vrm_animation_retargeter.gd))
and `runtime/vrm_runtime_loader.gd` each contain further, differently-shaped retargeting logic
(bone-name path rewriting, hips-height scaling) solving an adjacent but distinct problem (bone
*identity* resolution rather than rotation math). graphify's semantic extraction independently
flagged the VRMA/IK pair as similar (confidence 0.75); manual review confirmed they share the
exact same formula, reimplemented rather than shared. VRM 1.0's normalized T-pose guarantee (see
the `vrm_format` skill) is what makes this formula legitimately reusable across sources.

## Decision

Extract the core world-rest/local-rest quaternion conversion into a shared utility function, and
have the VRMA import-time bake path and the VMD runtime IK path both call it.

## Options Considered

### Option A: Minimal shared quaternion helper

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Risk | Low-medium — must verify mathematical equivalence before swapping callers |
| Scope | Just the formula; surrounding batch-vs-per-frame logic in each caller stays as-is |

**Pros:** Directly addresses the actual duplication (the math) without forcing unification of
fundamentally different use cases — import-time batch bake vs. runtime per-frame IK.
**Cons:** Doesn't unify the broader retargeting story; `VrmAnimationRetargeter`'s bone-name
resolution remains a separate mechanism (this is intentional — see Consequences).

### Option B: Full shared "Retargeting Engine"

**Pros:** One conceptual system for VRMA/VMD/BVH/runtime post-hoc retargeting.
**Cons:** A much larger, riskier rewrite touching every animation pipeline simultaneously, not
justified by this specific duplication alone. Risks adding indirection/overhead to the
performance-sensitive per-frame IK path. Rejected for now — revisit under the "rule of three" if
a future format needs yet another retargeting variant.

### Option C: Leave separate, document heavily

**Pros:** Zero refactor risk today.
**Cons:** Ongoing drift risk — a bug fixed in one implementation silently persists in the other.
Rejected.

## Trade-off Analysis

Option A is the right scope: fix the actual duplication without over-engineering a unification
that the current use cases don't need.

## Consequences

- Easier: a bug fix to the core formula applies to both VRMA baking and VMD IK at once; future
  import formats get correct math for free.
- Harder: the shared function's signature must serve both the "precomputed dictionaries, batch"
  use case (VRMA) and the "live single bone, per-frame" use case (VMD IK) without forcing
  unnecessary allocations in the hot IK path.
- Revisit: `VrmAnimationRetargeter`'s bone-path-rewrite approach stays separate — it solves bone
  *identity* resolution, not rotation math, and shouldn't be folded into this utility.

## Action Items

1. [ ] Add `world_to_local_rotation(local_rot, world_rest, local_rest) -> Quaternion` (and its
       inverse) to `addons/vrm/common/vrm_util.gd` or a new `common/vrm_rest_pose_math.gd`
2. [ ] Refactor `VrmaAnimationLibraryBuilder._normalize_rotation` to delegate to the shared function
3. [ ] Verify `VrmIkController._sync_bone_rotation`'s math is equivalent, then refactor it to
       delegate to the same shared function
4. [ ] Add a GUT unit test exercising the shared function against known rest poses
5. [ ] Regression-test VMD dance playback IK behavior and VRMA animation import visually
