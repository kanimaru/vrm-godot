To implement a high-fidelity MMD player in Godot 4, use the following technical specification to reconcile coordinate systems, skeletal hierarchies, and kinematic behaviors.

### 1. Coordinate System and Scale Conversion
MMD uses a left-handed, Y-up coordinate system (DirectX-style), whereas Godot uses a right-handed, Y-up system (OpenGL-style).
*   **Vertex/Bone Positions**: Transform MMD positions to Godot space using the formula $P_{godot} = [x, y, -z]$.[1]
*   **Rotation Matrices**: Convert rotation matrices ($M_{mmd}$) by applying a "sandwich" product with an inversion matrix ($M_i$): $M_{godot} = M_i \times M_{mmd} \times M_i$, where $M_i = diag(1, 1, -1)$.[2]
*   **Unit Scaling**: Apply a global scale factor of $0.08$ to all PMX and VMD data to ensure 1 MMD unit $\approx 12.5cm$, which aligns model dimensions with Godot’s physics and light attenuation defaults.[3]

### 2. Skeletal Logic and Rest Poses
The primary cause of model distortion in Godot is the mismatch between MMD’s absolute bone storage and Godot’s relative hierarchy.
*   **Relative Rests**: PMX files store absolute world positions for bone rests.[4] You must calculate Godot’s relative `rest` pose by multiplying the child’s absolute transform by the inverse of the parent’s absolute transform: $T_{relative\_rest} = T_{absolute\_child} \times T_{absolute\_parent}^{-1}$.
*   **Bone Constraints**: Always check the PMX "Rotation Only" flags during VMD playback; applying translations to bones not flagged for it will cause skeletal "explosions" or limb detaching.

### 3. Hierarchical Root Motion
To prevent foot sliding ("skating"), you must extract root motion from the model's absolute origin bone.
*   **The Mother-Center Stack**: The hierarchy must be strictly structured as: `Mother (全ての親) -> Center (センター) -> Groove (グルーブ) -> Hips (腰)`.
*   **Extraction**: In the `AnimationTree`, assign the "Root Motion Track" to the Mother bone.
*   **Movement Application**: Every frame, retrieve the positional delta via `get_root_motion_position()` from the `AnimationMixer` and apply it to the `CharacterBody3D.velocity` or global position.

### 4. Foot Grounding and IK Logic
MMD relies on a runtime Cyclic Coordinate Descent (CCDIK) algorithm for foot placement.
*   **CCDIK implementation**: Place `CCDIK3D` nodes inside a `SkeletonModifier3D` to ensure they run after the animation pose is calculated but before the mesh is skinned.
*   **Raycast Targeting**: Cast rays downward from the animated foot positions to find the floor.[5] Set the `CCDIK3D` target to the ray's hit point.
*   **Pelvis Compensation (Pelvis Dip)**: If the floor is too low for the foot to reach, lower the `Center` bone (the "Pelvis Dip") until the leg can reach the ground, then lerp this value to avoid jitter.[5]
*   **Pole Alignment**: Parent knee "Pole" targets (Marker3D nodes) to the `Hips` bone so that they automatically rotate with the character, preventing knees from flipping backward during turns.[6]

### 5. Deployment Workflow
*   **Import**: Use a UTF-16LE decoder for Japanese bone names and read PMX Globals to set dynamic index sizes.[7, 8]
*   **Skinning**: Renormalize vertex weights if they do not sum to 1.0 to prevent GPU skinning artifacts.[4]
*   **Materials**: Recreate MMD's Sphere Maps (MatCaps) in a custom shader that samples textures using view-space normals.
