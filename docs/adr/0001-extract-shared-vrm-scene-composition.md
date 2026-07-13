# ADR-0001: Extract Shared VRM Scene Composition Logic

**Status:** Implemented
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

`Vrm0Extension._import_post` ([addons/vrm/vrm0/vrm0_extension.gd:198-314](../../addons/vrm/vrm0/vrm0_extension.gd))
and `Vrm1Extension._import_post` ([addons/vrm/vrm1/vrm1_extension.gd:334-458](../../addons/vrm/vrm1/vrm1_extension.gd))
each independently: attach a `VrmAnimationRetargeter`, rename the skeleton to `GeneralSkeleton`,
build a `node_index → name` map by walking `GLTFNode.original_name`/`resource_name`, build MToon
materials and walk the whole scene tree to swap them in (`_apply_materials_to_scene_tree`,
duplicated near-verbatim at [vrm0:444](../../addons/vrm/vrm0/vrm0_extension.gd) and
[vrm1:619](../../addons/vrm/vrm1/vrm1_extension.gd)), and spawn `MtoonController`.

None of this is generation-specific — only the *parsing* that feeds it differs between VRM 0.x
and VRM 1.0. Roughly 150-200 lines are duplicated between the two files, including an entire
material-application pipeline copied variable-name-for-variable-name. This also explains why the
knowledge graph scored the "VRM 0.x Extension" and "Import Plugins & Bone Retargeting" communities
as weakly cohesive (0.10-0.14) — a lot of loosely related composition logic is bolted onto two
files instead of factored out.

## Decision

Extract the generation-agnostic scene-composition steps into a shared helper, and have both
extensions call it with their already-parsed data.

## Options Considered

### Option A: Static utility class (`common/vrm_scene_composer.gd`)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Risk | Low — no change to how extensions register with `GLTFDocument` |
| Team familiarity | High — matches existing `VRMUtil`/`VrmMtoonBuilder` static-helper pattern |

**Pros:** Surgical; both extensions keep extending `GLTFDocumentExtension` directly, which
`register_gltf_document_extension` requires anyway. Easy to unit test in isolation.
**Cons:** Still two call sites to keep in sync when invoking the composer, though the logic
itself is unified.

### Option B: Shared base class (`VrmExtensionBase extends GLTFDocumentExtension`)

**Pros:** Composition logic becomes structurally impossible to skip in a subclass.
**Cons:** Adds an inheritance layer purely to share code that a static utility already shares
just as well; couples the composition logic tightly to the extension lifecycle when it may be
useful to call from elsewhere (e.g. a future "reapply materials" editor tool). Rejected.

### Option C: Leave as-is

**Pros:** Zero effort.
**Cons:** Every future fix (e.g. material application edge cases, retargeter wiring changes)
must be applied twice and re-verified twice. Rejected.

## Trade-off Analysis

Option A is preferred: it removes the duplication without adding structural coupling beyond
what's needed, and keeps each extension's `_import_post` focused on generation-specific
concerns (spring bone class, expression-controller `compile_*` method, VRM1's extra look-at
step) while delegating the shared 80% to one place.

## Consequences

- Easier: bug fixes to material application, retargeter wiring, or node-name resolution apply
  once. A hypothetical future VRM generation reuses the composer for free.
- Harder: the initial refactor must preserve exact current behavior — needs before/after
  comparison via the existing parsing/mtoon GUT tests plus a manual visual import check.
- Revisit: whether spring-bone wiring and expression-controller instantiation (genuinely
  generation-specific: different simulator classes, different `compile_vrm0/1_binds` methods)
  should also be parameterized via a small interface, or stay inline in each extension. Current
  recommendation is to keep those inline — they're not duplicated, only the composer's
  generic steps are.

## Action Items

1. [x] Create `addons/vrm/common/vrm_scene_composer.gd` with static functions:
       `resolve_node_name(gnode)`, `resolve_all_node_names(state)`, `attach_retargeter(root)`,
       `rename_skeleton_to_general(skeleton)`, `apply_mtoon_materials(root, mtoon_configs, state)`
       (implementation note: `spawn_mtoon_controller` was folded into `apply_mtoon_materials`
       rather than kept separate, since every current caller wants both together and
       `_apply_materials_to_scene_tree` became a private helper of the composer instead of a
       public one — no caller outside the composer needs it)
2. [x] Update `vrm0_extension.gd` `_import_post` to call the composer instead of inlined code
3. [x] Update `vrm1_extension.gd` `_import_post` likewise
4. [x] Delete the now-duplicate `_apply_materials_to_scene_tree` from both files
5. [x] Run `unit/test_vrm0_parsing.gd`, `test_vrm1_parsing.gd`, `test_vrm0_mtoon_parsing.gd`,
       `test_vrm1_mtoon_parsing.gd` to confirm parity — 108/108 passed. Full suite also run
       (170/170 passed), which incidentally exercises the refactored `_import_post` path
       end-to-end via `test_vrm_expressions.gd`'s real VRM0/VRM1 imports (`doc.append_from_file`
       + `doc.generate_scene`). That run also surfaced and fixed an unrelated stale path
       (`res://test/unit/mesh_spy.gd` → `res://unit/mesh_spy.gd`) left over from the earlier
       `test/` → `unit/` migration — not part of this ADR's scope, fixed in passing.
6. [ ] Manually import a VRM0 and a VRM1 sample model in the editor to visually confirm
       materials, spring bones, and expressions still work — **not done**; requires the Godot
       editor GUI, unavailable in this session. GUT coverage (item 5) exercises the same code
       path programmatically but doesn't substitute for a visual check.

`addons/vrm/vrm0/vrm0_extension.gd` shrank 469 → 368 lines, `addons/vrm/vrm1/vrm1_extension.gd`
shrank 644 → 541 lines; the new composer is 146 lines, replacing what had been ~190 duplicated
lines split across both files.
