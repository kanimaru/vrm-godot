---
name: VMC Tracking Specification
description: Technical assumptions for GLTF, VRM, VMC Protocol, and Godot 4's Skeleton retargeting. Used for implementing VMC tracking correctly.
---

# VRM & VMC Tracking Specifications

This document outlines the core technical assumptions and format specifications for GLTF, VRM (0.0 and 1.0), the VMC Protocol, and Godot 4's skeleton retargeting system. This knowledge is essential for building a geometrically correct tracker pipeline without suffering from "spaghetti" deformities.

## 1. glTF 2.0 Core Assumptions
VRM is an extension of the Khronos glTF 2.0 specification.
- **Coordinate System:** Right-handed system. **Y is up**, and **-Z is forward** (into the screen).
- **Units:** Distance and positions are strictly measured in **Meters**. Angles are in **Radians**.

## 2. VRM 0.0 vs VRM 1.0
VRM builds upon glTF but enforces humanoid standards. 

### VRM 0.0
- **Coordinate System:** Adopts the glTF standard (Right-Handed, Y-Up), but historically data inside the file could sometimes be ambiguous about true 'forward' due to Unity (Left-Handed) authoring.
- **T-Pose:** Required, but thumb vectors and parallel limbs were slightly loose.

### VRM 1.0
- **Coordinate System:** Strictly enforces a **Right-Handed, Y-Up, +Z Forward** orientation.
- **T-Pose Constraints:** Extremely strict. Arms mapped perfectly parallel to X.

## 3. VMC (Virtual Motion Capture) Protocol
The VMC protocol handles transporting motion capture data in real time using Open Sound Control (OSC).
- **Coordinate System:** **Left-Handed, Y-up, +Z forward** (Unity's native coordinate system).
- **Rotations:** Transported as Quaternions (`x, y, z, w`).
- **Positions:** Transported as Vector3 (`x, y, z`), measured in meters.
- **OSC Address Example:**
  - `/VMC/Ext/Bone/Pos` -> string:bone_name, float:pos_x, pos_y, pos_z, rot_x, rot_y, rot_z, rot_w

## 4. Godot 4's Armature & Retargeting System
- **Coordinate System:** **Right-handed, Y-up, -Z forward**.
- **BoneMap & SkeletonProfile:** Uses `SkeletonProfileHumanoid` to map varying names (`hips`, `b_hips`) to standard (`Hips`).
- When setting tracking data, you MUST NOT move the raw `Node3D` transforms of the bones. Apply rotations using `Skeleton3D.set_bone_pose_rotation()`.

## 5. Tracking Math (VMC -> Godot)
Because VMC originates in Left-Handed space and Godot uses Right-Handed space, you must convert the Quaternions to prevent mesh distortion.
- **Rotations (Quaternions):** A Unity Quaternion `(X, Y, Z, W)` must be converted. The typical conversion to Godot's Right-Handed space is: `Quaternion(-x, y, -z, w)` or `Quaternion(x, -y, z, w)` or similar depending on base rest pose mappings. Based on Godot standard, left-to-right convert can be: `Quaternion(-quat.x, quat.y, quat.z, -quat.w)`. Verify math locally based on axis flip.
- **Translation:** Apply the root translation only to the bone equivalent of `Hips`.
