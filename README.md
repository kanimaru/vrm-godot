# VRM Importer for Godot

A Godot 4.7 editor plugin that imports [VRM](https://vrm.dev/) humanoid avatars — both VRM 0.x
and VRM 1.0 — as native Godot scenes, and retargets three common motion sources onto them:
VRMA, MMD `.vmd`, and `.bvh`.

## Features

### Import

| File type | What you get |
|---|---|
| `.vrm` (0.x or 1.0) | A scene with a `Skeleton3D`, MToon materials, expressions, spring bone physics, and (VRM 1.0) node constraints, first-person visibility layers, and material variants — all wired up automatically. |
| `.vrma` | A VRM 1.0 animation clip, importable as an `AnimationLibrary` and retargetable onto any VRM 1.0 avatar's actual bone names at runtime. |
| `.vmd` | An MMD motion file, retargeted onto the humanoid skeleton (including IK-driven leg/foot correction). |
| `.bvh` | A motion-capture file, retargeted the same way. |

Both VRM generations are detected automatically from the file's own extension keys — you
don't need to tell the importer which one you're loading.

### Humanoid & materials

- Full VRM 0.x / VRM 1.0 humanoid bone mapping, resolved through each spec's own role names
  (not hardcoded bone name guesses), feeding a `vrm_role -> actual_bone_name` lookup any
  runtime code can query via `VRMUtil`.
- MToon 1.0 materials, built as native `ShaderMaterial`s (shading ramp, rim lighting, matcap,
  outlines, UV animation, render priority, emissive multiplier via
  `VRMC_materials_hdr_emissiveMultiplier` / `KHR_materials_emissive_strength`).
- [`KHR_materials_variants`](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_variants)
  support (common in VRoid/Booth outfit-swap avatars) — a `VrmMaterialVariantController` is
  attached automatically when a file declares variants, exposing `set_variant()` /
  `set_variant_by_name()` for game code.
- Spring bone physics (VRM 0.x `secondaryAnimation` and VRM 1.0 `VRMC_springBone`, including
  the extended sphere/capsule/plane collider shapes), with real collision against authored
  collider groups — not just sway.
- VRM 1.0 `VRMC_node_constraint` (roll/aim/rotation bone constraints — twist bones, cloth-aim
  helpers, sub-arm rotation copying).
- Expression control (VRM 0.x blend shape presets, VRM 1.0 expressions including the
  `block`/`blend` procedural-override modes), material color/UV binds, and per-eye look-at
  with proper convergence (VRM 1.0).
- VRM 1.0 `firstPerson` mesh visibility — `thirdPersonOnly`/`firstPersonOnly` meshes move onto
  dedicated render layers your own first-person/third-person cameras can filter with their
  `cull_mask`. See `VrmConstants.FIRST_PERSON_ONLY_LAYER` / `THIRD_PERSON_ONLY_LAYER`.

### Diagnostics

Missing required humanoid bones and (VRM 1.0) non-T-pose humanoid bone scales are reported
via `push_warning` at import time — the avatar still imports, but you'll see a clear reason
in the console instead of a silently broken rig.

## Requirements

Godot 4.7. The plugin relies on native `SpringBoneSimulator3D`/`SpringBoneCollision3D`
nodes, which are a relatively recent addition to Godot's `Skeleton3D` modifier pipeline and
are not available on older 4.x releases.

## Installation

1. Download `vrm-addons-<version>.zip` from the
   [releases page](https://github.com/kanimaru/vrm-godot/releases) and unzip it into your
   project's root. It holds `addons/vrm/` and the `addons/Godot-MToon-Shader/` it needs.
2. Enable **VRM Importer** under **Project → Project Settings → Plugins**.
3. Drop a `.vrm`, `.vrma`, `.vmd`, or `.bvh` file into your project — Godot will import it
   automatically.

With [dotquay](https://github.com/kanimaru/dotquay), add both addons to your project's
`dotquay.toml` instead and run `dotquay install`:

```toml
[addons.vrm]
git = "https://github.com/kanimaru/vrm-godot.git"
branch = "main"
path = "addons/vrm"

[addons.mtoon-shader]
git = "https://github.com/kanimaru/godot-mtoon-shader.git"
branch = "main"
path = "."
install_as = "Godot-MToon-Shader"
```

### Working on this repository

The MToon shader isn't committed here. After cloning, fetch it with dotquay:

```bash
dotquay install
```

[GUT](addons/gut/) (the test framework) is committed under `addons/gut/`.

## Usage

### Reading VRM metadata at runtime

```gdscript
var vrm_data: Vrm1TopLevel = VRMUtil.get_vrm1_data(avatar_root)  # or get_vrm0_data()
print(vrm_data.meta.name, " by ", vrm_data.meta.authors)

var actual_bone_name: String = VRMUtil.get_humanoid_bone(avatar_root, "leftUpperArm")
```

### Driving expressions

```gdscript
var expr := avatar_root.get_node("%Vrm1ExpressionController")  # or Vrm0ExpressionController
expr.set_expression("happy", 1.0)
```

### Switching material variants

```gdscript
var variants := avatar_root.get_node_or_null("%VrmMaterialVariantController")
if variants:
    variants.set_variant_by_name("Winter")
```

### Retargeting animation

Import a `.vrma`, `.vmd`, or `.bvh` file the normal way, then instance its `AnimationLibrary`
onto any VRM avatar's `AnimationPlayer` — the plugin's `VrmAnimationRetargeter` (attached
automatically to every imported avatar) rewrites track paths to that specific avatar's real
bone names at runtime, so the same animation clip works across avatars with completely
different underlying rigs.

See `runtime/` for a working demo scene that loads an avatar and plays back all three motion
sources side by side.

## Known limitations

- **Import only.** There is no VRM export path — you can't author or edit an avatar in Godot
  and save it back out as `.vrm`.
- **VRM 1.0 `firstPerson`'s `auto` mesh classification isn't implemented.** The spec's `auto`
  mode splits a mesh into head/non-head triangle groups by skin weight; this plugin only
  honors explicit `thirdPersonOnly`/`firstPersonOnly`/`both` annotations and treats `auto`
  (and unannotated meshes) as always-visible. A whole-mesh heuristic was deliberately not
  attempted — real content commonly has a single body mesh spanning both head and torso
  vertices, which a naive per-mesh classifier would misclassify.
- **The bundled MToon shader's lighting formula predates the VRM 1.0 spec's own pseudocode.**
  It's a port of Unity's original MToon shader (a multiplicative "shading grade" model)
  rather than the spec's additive `shading = dot(N,L) + shadingShiftFactor + texture(...)`
  formula. All of the spec's shading-boundary parameters are wired up and functional, but the
  exact curve may not pixel-match a fully spec-compliant renderer.
- **Required-bone and T-pose checks are warnings, not hard failures.** A VRM file missing a
  required humanoid bone, or (VRM 1.0) with non-uniform/non-positive rest scale on a humanoid
  bone, still imports — you'll see a `push_warning` in the console explaining what's wrong.
- **`KHR_texture_transform` is only applied to the base color texture.** Other MToon texture
  slots (shade, shading-shift, matcap, rim, outline-width, UV-animation-mask) share the same
  UV transform as the base texture rather than having independent ones.

## Testing

Unit tests live under `unit/` and use [GUT](https://github.com/bitwes/Gut). Run them with:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=unit -gexit
```

### Private test assets

Some tests and probes run against licensed avatars and third-party animations that can't be
redistributed. They live in a separate git repository checked out at `assets/private/`
(gitignored here), with the layout `assets/private/{luna,temptic,dove,VRMA,vmd}/`. Without
it those tests report as pending, and everything else runs against the bundled
`assets/tester/` avatars.

## Project structure

```
addons/vrm/
  vrm0/, vrm1/     VRM-generation-specific GLTFDocumentExtensions, parsed structures, and nodes
  vrma/, vmd/, bvh/  Animation import + retargeting for each motion source
  common/          Generation-agnostic shared logic (VrmSceneComposer, VrmUtil, runtime controllers)
  import/          EditorImportPlugin / SceneFormatImporter registrations
docs/              Bundled VRM/glTF/VMD/BVH spec references (used as the ground truth for parsing)
docs/adr/          Architecture decision records for internal refactors
unit/              GUT test suite
runtime/           Standalone demo/preview app built on top of the plugin (not part of the import pipeline itself)
```

## License

MIT — see [LICENSE](LICENSE). Third-party material and its licenses are listed in
[NOTICE.md](NOTICE.md).
