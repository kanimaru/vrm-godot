# ADR-0004: Eliminate Redundant BVH Parsing in Runtime Loader

**Status:** Implemented
**Date:** 2026-07-13
**Deciders:** kanimaru

## Context

`_on_animation_selected` in `runtime/vrm_runtime_loader.gd`
([runtime/vrm_runtime_loader.gd:591-596](../../runtime/vrm_runtime_loader.gd)) calls
`BvhParser.parse_file(path)` directly to read the hips offset for auto-scale computation, then
immediately calls `BvhLoader.load_animation_library(path, ...)`, which parses the same file again
internally. Every BVH animation selection reads and fully parses the file from disk twice.

This also bypasses `BvhLoader`'s intended role as a façade — the caller reaches around it to get
data (`BvhData.root.offset.y`) the façade doesn't expose, which is the same root cause the
knowledge graph flagged as a "surprising connection" (`VrmRuntimeLoader → BvhParser`), unlike the
VMD path, which stays entirely behind `VmdLoader`.

## Decision

Extend `BvhLoader`'s API so the scale computation happens inside the single parse it already
performs, removing the caller's need to parse independently.

## Options Considered

### Option A: Return parsed `BvhData` alongside the library

`BvhLoader.load_animation_library` returns both the `AnimationLibrary` and the parsed `BvhData`
(e.g. via a small result struct), letting the caller compute scale from that.

**Pros:** Removes the double-parse.
**Cons:** Leaks `BvhData` back to the caller, which invites future code to keep reaching around
the façade instead of asking it to do the computation.

### Option B: Cheap header-only "peek" helper

`BvhLoader.peek_hips_height(path) -> float` parses only the hierarchy/header, skipping motion
frame data.

**Pros:** Cheaper than a full second parse.
**Cons:** Still two file reads and two parse passes; only worth it if Option C is infeasible.

### Option C: Move auto-scale computation inside `BvhLoader`/`BvhAnimationLibraryBuilder`

Add a `target_hips_height: float = -1.0` parameter to `load_animation_library`. When provided
(>= 0), the builder computes `scale_factor` internally from the `BvhData` it already parsed,
instead of accepting a pre-computed `scale_factor` from the caller.

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low |
| Risk | Low — additive, default-valued parameter |
| Team familiarity | High — matches existing parameterized-scale calling convention |

**Pros:** Fully eliminates the double-parse (one parse total, inside `BvhLoader`), removes the
caller's need to know about `BvhParser`/`BvhData` at all, and restores the façade.
**Cons:** None significant; requires threading one new parameter through
`BvhAnimationLibraryBuilder.build()`.

## Trade-off Analysis

Option C is the cleanest fix — it's the only option that removes the double-parse *and* the
façade violation simultaneously, at equivalent or lower implementation cost to A or B.

## Consequences

- Easier: one parse per BVH selection instead of two — halves I/O and CPU cost for every
  animation switch; `BvhLoader` becomes the single entry point again.
- Harder: need to confirm no other caller of `load_animation_library` is broken by the new
  parameter — mitigate with a default value that preserves current behavior.

## Action Items

1. [x] Add `target_hips_height: float = -1.0` parameter to `BvhLoader.load_animation_library`;
       when >= 0, compute `scale_factor` internally from `BvhData.root.offset.y`
       (implementation note: resolved to an `effective_scale` local inside `BvhLoader` itself,
       using the single `BvhData` it already parses, rather than threading the new parameter
       through `BvhAnimationLibraryBuilder.build()` — `build()`'s signature is unchanged, it
       still just takes a `scale_factor`; `BvhLoader` decides what that value is before calling
       it. Keeps the override logic in one place and `build()`'s contract simple)
2. [x] Update `vrm_runtime_loader.gd`'s `_on_animation_selected` to pass `target_hips_height`
       instead of calling `BvhParser.parse_file` directly
3. [x] Remove the now-unused direct `BvhParser` reference from `vrm_runtime_loader.gd` — it was
       the only reference in the file, so nothing else needed it
4. [x] Test a sample `.bvh` file before/after to confirm playback scale is unchanged — added
       `unit/test_bvh_loader.gd` (3 tests: explicit scale used when no override, auto-scale
       computed correctly from a known root OFFSET + target height, negative override value
       preserves explicit-scale behavior). Full GUT suite re-run clean (173/173, up from 170 —
       the 3 new tests). No sample asset file was available to eyeball in the editor GUI
       (unavailable in this session); the synthetic fixture's asserted values are exact algebra
       (`10.0 * 1.8 / 90.0 = 0.2`), not a visual approximation, so this is considered sufficient
       coverage without that manual step.

`BvhLoader.load_animation_library` gained one additional default-valued trailing parameter;
`BvhImportPlugin._import`'s existing 4-positional-arg call site is unaffected.
