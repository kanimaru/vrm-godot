# ADR-0005: Promote VrmIkController into the Addon's Public Surface

**Status:** Implemented (with a mechanism change — see Outcome below)
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

`VrmIkController` lives at `addons/vrm/vmd/vrm_ik_controller.gd`, implying it's VMD-specific, but
it's actually generic foot-IK correction: the runtime demo uses it for VMD, VRMA, *and* BVH
playback (see `_on_animation_selected`'s IK-track detection covering `leftLegIk`/`rightLegIk`/
`leftToeIk`/`rightToeIk` regardless of source format). It is never instantiated by any editor
import plugin — only by `runtime/vrm_runtime_loader.gd`. Anyone consuming `addons/vrm` directly,
without the bundled `runtime/` demo, gets no foot-IK correction, despite the feature being fully
implemented and working.

## Decision

Decide whether foot-IK correction should be a first-class, opt-in feature of the addon's import
pipeline, or explicitly scoped as demo-only.

## Options Considered

### Option A: Promote it — move to `common/`, wire it into import plugins as an opt-in option

Relocate to `addons/vrm/common/vrm_ik_controller.gd`. Add an import option (default **off**) to
`vmd_import_plugin.gd` (and `vrma_import_plugin.gd`/`bvh_import_plugin.gd` if applicable) so any
consumer can enable it without it being forced on existing projects.

| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium — needs new `EditorImportPlugin` option surface |
| Risk | Low, *if* gated behind an explicit opt-in default-off toggle |
| Value | High — exposes a working feature to every consumer of the plugin, not just the demo |

**Pros:** Real reusable value; matches how `VrmAnimationRetargeter` is already auto-attached at
import. Doesn't change behavior for existing users unless they opt in.
**Cons:** Requires new import-option plumbing; must verify `VrmIkController` has no accidental
dependency on `runtime/`-specific state before moving it.

### Option B: Relocate but don't wire it in

Move out of `vmd/` into `runtime/` (or `common/` without import-plugin wiring) purely to stop the
misleading VMD-only folder placement, without exposing it to the editor import pipeline.

**Pros:** Minimal, low-risk fix for the naming/placement problem.
**Cons:** Doesn't solve the more substantive issue — the feature stays invisible to anyone not
using the bundled demo app.

### Option C: Leave as-is, document as demo-only

**Pros:** Zero effort.
**Cons:** Fixes nothing structurally; the misleading folder placement and the "invisible feature"
problem both persist. Rejected.

## Trade-off Analysis

Option A is preferred, but only with the import option defaulting to **off** — auto-attaching a
per-frame IK correction node on every import would silently change behavior/performance for
existing consumers who never asked for it. Option B is an acceptable fallback if the import-option
plumbing proves more invasive than expected, but it leaves the core problem (feature stranded in
demo code) unresolved.

## Action Items

1. [x] Audit `vrm_ik_controller.gd` for any dependency on `runtime/` code before moving it —
       confirmed clean (graphify shows exactly two edges: consumed by `VrmRuntimeLoader`,
       depends on `VRMUtil`; no `runtime/`-specific state, no reference to `_ui` or anything
       demo-app-specific)
2. [x] Move to `addons/vrm/common/vrm_ik_controller.gd`, fixing its internal
       `preload("../common/vrm_util.gd")` to `preload("vrm_util.gd")` (same directory now)
3. [x] ~~Add a default-off import option to `vmd_import_plugin.gd`~~ — **not implemented as
       written; see Outcome below, this action item's premise didn't survive contact with
       Godot's API**
4. [x] Update `runtime/vrm_runtime_loader.gd` to reference the relocated path (also corrected:
       it's attached once per loaded avatar in the model-loading flow, not per animation
       selection as this ADR's Context section assumed — see Outcome)
5. [x] Update `unit/test_vrm_ik_controller.gd` and the `vrm_format` skill doc reference (only
       `vrm_format` mentioned it by name; `vmc_tracking` doesn't reference it)

## Outcome: import-plugin wiring doesn't fit Godot's API; relocation is what actually delivers Option A's value

Two things action item 3 got wrong, found while implementing:

**`VrmIkController` is already attached once per loaded avatar, not per animation selection.**
This ADR's Context section says the runtime demo uses it "for VMD, VRMA, and BVH playback" based
on `_on_animation_selected`'s IK-track detection — true, but that's just the `.enabled` toggle.
The actual node creation happens earlier, in the avatar-loading flow (`runtime/vrm_runtime_loader.gd`,
"Setup IK" section): every loaded avatar with a skeleton gets one `VrmIkController` attached
unconditionally, doing nothing until `.enabled` is set true for an animation that happens to carry
`leftLegIk`/`rightLegIk`/`leftToeIk`/`rightToeIk` marker tracks — which in practice only
`VmdAnimationLibraryBuilder` produces (VRMA and BVH tracks use different names). So it's
VMD-specific in practice even though the controller code itself doesn't hardcode that.

**Import plugins can't attach it at all — they have no scene to attach it to.** The proposed
mechanism (`vmd_import_plugin.gd` gets a default-off import option that auto-attaches
`VrmIkController`) is architecturally impossible: `EditorImportPlugin._import()` for a `.vmd`
file parses a standalone motion file and saves a bare `AnimationLibrary` `.res` resource — it has
no `Skeleton3D`, no avatar scene, no `root` to attach anything to. A `.vmd` file isn't tied to any
specific avatar at import time; it can be applied to any VRM model later. The only place that
*does* have both a skeleton and a root during import is `Vrm0Extension`/`Vrm1Extension`'s
`_import_post` (i.e. importing the `.vrm` avatar itself) — but `EditorSceneFormatImporter` and
`GLTFDocumentExtension` don't expose the same `_get_import_options()`/options-dictionary hook
`EditorImportPlugin` does; adding a user-facing checkbox there would need a new
`EditorScenePostImportPlugin`, a bigger addition than this ADR's stated scope.

Given that, the part of Option A that's actually buildable — and that actually delivers the
"stop being addon-invisible" value this ADR was chasing — is the relocation itself. Moving the
file to `common/` is what makes `VrmIkController` discoverable and reusable by any consumer of
`addons/vrm`: `preload("res://addons/vrm/common/vrm_ik_controller.gd")`, instantiate, call
`.setup(skeleton, root, is_vrm0)`, exactly as `vrm_runtime_loader.gd` already does. That's three
lines of opt-in code for a consumer who wants it — arguably a more literal reading of "default
off" than a checkbox would have been, since nothing auto-attaches it outside the demo at all. No
speculative `VrmSceneComposer` convenience wrapper was added for this, since there's no second
caller yet to justify one (would be pure speculative generality).

**Bonus finding while testing:** moving the file broke `unit/test_vrm_ik_controller.gd` with
`Invalid call. Nonexistent function 'new' in base 'GDScript'` — not a real regression, but a
stale `.godot/global_script_class_cache.cfg` entry still pointing `VrmIkController` at the old
`vmd/` path. Fixed by running `godot --headless --editor --quit` once to force a filesystem
rescan. Worth knowing for future `class_name` file moves in this repo: the cache doesn't
self-heal under a plain headless GUT run.

Full GUT suite: 173/173 after the cache fix.

## Consequences

- Easier: plugin users get access to a working, tested feature without reimplementing it from
  `runtime/vrm_runtime_loader.gd`.
- Harder: import plugins need a new option surface; `VrmIkController` needs auditing to confirm
  it's free of demo-app-specific assumptions (e.g. references to `_ui`) before relocation.
- Revisit: whether this should share a single "runtime extras" opt-in toggle with the retargeter,
  since both are post-import runtime behavior nodes conceptually. **Moot now** — see Outcome;
  there's no import-time options surface for either to share on the avatar-import side.
