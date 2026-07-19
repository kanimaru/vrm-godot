# Architecture Decision Records

Findings from the `addons/vrm/` architecture review on 2026-07-13, backed by the graphify
knowledge graph and direct source verification.

| ADR | Title | Theme | Status |
|---|---|---|---|
| [0001](0001-extract-shared-vrm-scene-composition.md) | Extract Shared VRM Scene Composition Logic | VRM0/VRM1 extension duplication | Implemented |
| [0002](0002-unify-rest-pose-retargeting-math.md) | Unify Rest-Pose Retargeting Math | Duplicate quaternion retargeting formula | **Superseded** — hand-verification showed the two formulas aren't actually equivalent; no code changed |
| [0003](0003-fix-floor-offset-perf-and-scope-leak.md) | Fix Floor-Offset Correction Performance and Scope Leak | Bug: O(n²) loop + VMD fix leaking into VRMA/BVH | **Superseded** — the function turned out to be dead code (never matched any track from any source); deleted instead of relocated |
| [0004](0004-eliminate-redundant-bvh-parsing.md) | Eliminate Redundant BVH Parsing in Runtime Loader | Bug: double file parse per BVH selection | Implemented |
| [0005](0005-promote-vrm-ik-controller.md) | Promote VrmIkController into the Addon's Public Surface | Feature stranded in demo-only code | **Implemented, mechanism changed** — relocated to `common/`; the proposed import-plugin auto-attach option was architecturally impossible (import plugins never have a skeleton/scene to attach to), so it's opt-in via direct instantiation instead |
| [0006](0006-remove-dead-vrm0-blend-shape-bind-classes.md) | Remove Dead VRM0 Blend Shape Bind Classes | Dead code cleanup | Implemented |
| [0007](0007-consolidate-cross-generation-runtime-types.md) | Consolidate Cross-Generation Runtime Types and Expression Name Mapping | Layering + duplicate constant tables | **Implemented, mechanism corrected** — the two "duplicate" tables were solving different problems; one was redundant with `to_snake_case()` and got deleted, the other (genuine cross-gen rename) moved to `vrm_constants.gd`. Also surfaced confirmed VRM0 spec-coverage gaps (rim/matcap material binds, gaze expressions) as follow-up candidates |

All seven ADRs are closed. See each file's Outcome/Action Items section for what actually
shipped versus what was originally proposed — 0002, 0003, 0005, and 0007 all diverged from
their initial plan after implementation-time verification.
