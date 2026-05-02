# **VMD Format Specification: Godot Engine Integration & Pitfalls**

This document supplements the standard VMD specification with specific instructions for implementing a VMD importer or player within the Godot Engine (4.x).

## **1\. The Coordinate System Conflict**

The single most common pitfall is the difference in handedness.

* MMD: Left-Handed (DirectX style), Z+ is forward.  
* Godot: Right-Handed (OpenGL/Vulkan style), Z+ is backward.

### **Implementation Detail: The Z-Axis Flip**

When importing VMD data into Godot, you must invert the Z-axis for both position and rotation to maintain visual parity:

* Position: (x, y, \-z)  
* Quaternion: (\-x, \-y, z, w)  (This negates the Z-axis of rotation and flips the rotation angle to maintain mathematical parity)
* Rotation: If using Euler angles (Camera), the Z-rotation often requires a sign flip.

## **2\. Rest Pose (Bind Pose) Management in Godot**

In Godot's Skeleton3D, a bone's "Transform" is relative to its "Rest" pose.

* Pitfall: If you apply the VMD quaternion directly to Skeleton3D.set\_bone\_pose\_rotation, it replaces the pose.  
* Correct Approach: VMD rotations are intended to be applied on top of the model's rest state. In Godot, AnimationPlayer handles this by applying tracks relative to the Skeleton's Rest.  
* Warning: Ensure your model importer (PMX to Godot) has correctly set the Rest poses. If the Godot bone rest is identity but the MMD bone was naturally tilted, the motion will look broken.

## **3\. Bone Naming and Encoding**

* Pitfall: Godot uses UTF-8 strings. VMD uses Shift-JIS.  
* Implementation: You must use a Shift-JIS to UTF-8 conversion layer before matching bone names.  
* Japanese Names: Many MMD models use Japanese names for internal logic (e.g., "全ての親" for Mother bone). If your Godot model uses English bone names (e.g., "Root"), you must implement a translation dictionary or the motion will not find its targets.

## **4\. Interpolation and AnimationPlayer**

Godot's Animation resource uses tracks (Position, Rotation, Scale).

* VMD Nuance: VMD defines interpolation per-keyframe. Godot's Animation.INTERPOLATION\_CUBIC is a global track setting and does not match the VMD Bezier curve exactly.  
* Solution for Accuracy: To get a 1:1 match with MMD, you cannot use Godot's default interpolation. You must:  
  1. Bake the keyframes at a high framerate (e.g., 30fps or 60fps).  
  2. Or, write a custom playback script that manually samples the VMD Bezier curves and sets the bone poses every frame.

## **5\. The IK Switch (Inverse Kinematics)**

Godot 4 uses SkeletonModifier3D or SkeletonIK3D.

* Pitfall: VMD has a section that turns IK On or Off at specific timestamps.  
* Implementation: You should map these to the active property of your Godot IK modifiers. If the VMD says "IK Off" for the legs, the AnimationPlayer should control the leg bones; if "IK On," the IK solver should take over.

## **6\. Global Scale (Unit Conversion)**

* MMD Scale: 1 unit is roughly 0.1 meters (8-10cm).  
* Godot Scale: 1 unit is exactly 1.0 meter.  
* Implementation: When importing VMD position data, you must decide on a scale factor. A common choice is to multiply all VMD positions by 0.1 to prevent the model from appearing 10 times too large in the Godot world.

## **7\. Camera FOV**

* MMD: FOV is usually stored as a vertical or horizontal degree depending on the version.  
* Godot: Camera3D uses Vertical FOV by default.  
* Conversion: Ensure you verify the MMD FOV type. If the aspect ratios differ, you may need to calculate the FOV conversion to ensure the framing remains the same as in MikuMikuDance.

## **8\. Summary Checklist for Godot Parsers**

1. Decode Shift-JIS names to UTF-8.  
2. Invert Z-axis for all positions and rotations.  
3. Multiply positions by a scale factor (e.g., 0.1).  
4. Map VMD bone names to Godot bone names using a translation table.  
5. Sort keyframes by time.  
6. For rotations, use Quaternion.normalized() to prevent precision errors over long animations.