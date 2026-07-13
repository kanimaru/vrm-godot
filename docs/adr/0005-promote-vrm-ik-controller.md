# ADR-0005: Promote VrmIkController into the Addon's Public Surface

**Status:** Proposed
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

## Consequences

- Easier: plugin users get access to a working, tested feature without reimplementing it from
  `runtime/vrm_runtime_loader.gd`.
- Harder: import plugins need a new option surface; `VrmIkController` needs auditing to confirm
  it's free of demo-app-specific assumptions (e.g. references to `_ui`) before relocation.
- Revisit: whether this should share a single "runtime extras" opt-in toggle with the retargeter,
  since both are post-import runtime behavior nodes conceptually.

## Action Items

1. [ ] Audit `vrm_ik_controller.gd` for any dependency on `runtime/` code before moving it
2. [ ] Move to `addons/vrm/common/vrm_ik_controller.gd`
3. [ ] Add a default-off import option to `vmd_import_plugin.gd` (and other applicable import
       plugins) to auto-attach it
4. [ ] Update `runtime/vrm_runtime_loader.gd` to reference the relocated path
5. [ ] Update `unit/test_vrm_ik_controller.gd` and the `vrm_format`/`vmc_tracking` skill docs if
       they reference the old location
