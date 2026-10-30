# Third-party notices

The VRM addon (`addons/vrm/`) and the project around it are MIT licensed, see [LICENSE](LICENSE).
This file lists material from other projects that ships in this repository or in its release
packages.

## VRM specification (`docs/VRM_0.0/`, `docs/VRMC_*`)

The spec documents, JSON schemas and figures under `docs/` are copied from the VRM Consortium's
[vrm-c/vrm-specification](https://github.com/vrm-c/vrm-specification) (also published at
<https://vrm.dev/en/vrm/vrm_features/>). They're kept as the ground truth the parsers are written
against. Copyright © VRM Consortium.

> **Unverified:** that repository has no top-level `LICENSE` file (checked 2026-10-30), so the
> terms these copies are redistributed under haven't been confirmed. Check with the VRM
> Consortium, or link to the documents instead of bundling them.

## MToon shader (`addons/Godot-MToon-Shader/`, release packages only)

It isn't committed here. `dotquay install` fetches it from
[kanimaru/godot-mtoon-shader](https://github.com/kanimaru/godot-mtoon-shader), and the release
zip bundles it. It's based on the `Godot-MToon-Shader` addon of
[V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm/tree/master/addons/Godot-MToon-Shader),
which ports Masataka SUMI's [MToon](https://github.com/Santarh/MToon). MIT License:

- Copyright © 2020-2022 V-Sekai Contributors
- Copyright © 2018 Masataka SUMI

Its full license text ships as `addons/Godot-MToon-Shader/LICENSE`.

## GUT (`addons/gut/`)

The test framework, [bitwes/Gut](https://github.com/bitwes/Gut), MIT License. Its license
ships as `addons/gut/LICENSE.md`, and its bundled fonts are under the SIL Open Font License
(`addons/gut/fonts/OFL.txt`). GUT isn't part of the release packages.

## Test avatars (`assets/tester/`)

`tester-vrm0.0.vrm` and `tester-vrm1.0.vrm` are the project's own minimal test rigs and are
covered by this repository's license.
