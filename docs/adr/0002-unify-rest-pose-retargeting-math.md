# ADR-0002: Unify Rest-Pose Retargeting Math

**Status:** Superseded — investigation disproved the premise, see Outcome below
**Date:** 2026-07-13 (superseded 2026-07-13)
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

## Action Items (superseded — not executed as written)

1. [x] ~~Add `world_to_local_rotation(local_rot, world_rest, local_rest) -> Quaternion`~~ —
       not added; see Outcome below
2. [x] ~~Refactor `VrmaAnimationLibraryBuilder._normalize_rotation` to delegate~~ — not done
3. [x] Verify `VrmIkController._sync_bone_rotation`'s math is equivalent — **done, and it is
       not equivalent.** This item was the load-bearing check for the whole ADR; it failed.
4. [ ] ~~Add a GUT unit test exercising the shared function~~ — moot, no shared function
5. [ ] ~~Regression-test VMD dance playback / VRMA import visually~~ — moot, no code changed

## Outcome: the two formulas are not the same, this ADR does not proceed

Action item 3 required verifying mathematical equivalence before merging. Re-deriving both
formulas by hand (not just trusting graphify's 0.75 semantic-similarity score, which turned out
to be surface-level pattern matching — both use quaternions named `world_rest`/`local_rest` and
both invert something) shows they solve different problems:

**`VrmaAnimationLibraryBuilder._normalize_rotation`:**
```
result = W · L⁻¹ · local_rot · W⁻¹
```
A **conjugation (similarity transform)** using two *static* rest quaternions from the *same* bone
on the *source* VRMA rig, both precomputed once from the glTF bind pose. It re-expresses a
keyframe's local-to-parent rotation, authored in the source rig's own rest-relative frame, as an
equivalent value usable against a target skeleton whose rest is presumed near-identity (per VRM
1.0's normalized T-pose guarantee). All four operands are fixed for the whole bake.

**`VrmIkController._sync_bone_rotation`:**
```
pose_quat = P⁻¹ · R · T
```
A **hierarchical world-to-local extraction** — R is this bone's static rest orientation
(skeleton-local), but P (the parent's *current, possibly IK-perturbed* pose) and T (the *live*
IK target orientation, converted into skeleton-local space via the skeleton's *current* global
transform) are both dynamic, recomputed every frame. There is no conjugation/sandwich structure
here at all.

Different arity (4-term conjugation vs. 3-term product), different mix of static vs. dynamic
operands, different operation (similarity transform vs. local-from-world extraction). Substituting
either formula for the other would silently produce wrong rotations. There is no shared function
that serves both correctly without becoming either incorrect or a trivial `Quaternion` multiply
wrapper that adds indirection without adding shared logic.

**One narrower candidate considered and also rejected:** `VrmaAnimationLibraryBuilder._compute_world_rest_rotations`
(accumulates `GLTFNode.rotation` up the parent chain, from import-time glTF node data) and
`VrmIkController._bone_rest_skel_quat` (accumulates `Skeleton3D.get_bone_rest()` up the parent
chain, from the post-import runtime skeleton) *are* the same algorithm — "walk to the root
multiplying local rests" — applied to two different APIs. But each is ~8 lines, used in exactly
one call site apiece, and unifying them would require a `Callable`-based generic walker (to
abstract over `Array[GLTFNode]` vs `Skeleton3D` bone indices) that costs more complexity than the
duplication it removes. Per the project's own "don't add abstractions beyond what the task
requires" guidance, and the rule-of-three heuristic already invoked in this ADR's Option B
rejection: not worth it at two call sites. Revisit only if a third accumulate-rest-up-the-chain
implementation appears.

No code was changed for this ADR. [ADR-0001](0001-extract-shared-vrm-scene-composition.md)'s
composer extraction is unaffected — it never touched this math.
