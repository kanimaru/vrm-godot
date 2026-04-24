


# Technical Documentation: Biovision Hierarchy (BVH) File Format

## 1. Overview
The **Biovision Hierarchy (BVH)** format is a widespread, ASCII-based standard used for storing and exchanging motion capture (mocap) data. Originally developed in the 1990s by Biovision (a motion capture services company), BVH was created to replace the older BVA format. 

BVH provides a lightweight, human-readable structure that encodes both the anatomical hierarchy of a skeleton (joints and bones) and the sequential time-series motion data (translations and rotations). Due to its simplicity, it remains a heavily supported format across 3D software (Blender, Maya, MotionBuilder) and within academic research, biomechanics, and animation pipelines.

---

## 2. File Structure
A BVH file is entirely plain text and is divided strictly into two distinct sections:
1. **`HIERARCHY`**: Defines the skeletal rig, its recursive joint structure, and the initial rest pose (via offsets).
2. **`MOTION`**: Contains the frame-by-frame animation data.

The file formatting relies on specific keywords and recursively nested curly braces `{ }` to define parent-child relationships. 

---

## 3. The `HIERARCHY` Section
The hierarchy section describes the skeleton. It always begins with the keyword `HIERARCHY` on the first line. 

### 3.1 Syntax and Keywords
* **`ROOT <name>`**: Indicates the start of the skeletal tree (typically the hips or pelvis). A file can technically contain multiple roots, but practically, parsers usually expect only one.
* **`{` and `}`**: Used to nest child joints inside parent joints. Formatting convention dictates indenting nested elements using tab characters.
* **`OFFSET <X> <Y> <Z>`**: Defines the translational offset of the segment relative to its parent. 
	* For the root, this is generally `0.0 0.0 0.0`. 
	* For child joints, this offset implicitly dictates the length and direction of the parent bone. There is no rotational offset or explicit bone drawing information in BVH; the basis pose is derived purely from these translation offsets.
* **`CHANNELS <count> <type1> <type2> ...`**: Defines the degrees of freedom for the joint.
	* **Root joints** typically have `6` channels: `Xposition Yposition Zposition Zrotation Xrotation Yrotation`.
	* **Child joints** typically have `3` channels: `Zrotation Xrotation Yrotation`.
	* *Note on Rotation Order:* The BVH format explicitly allows any channel order, but standard BVH files use Z-X-Y rotation channel ordering.
* **`JOINT <name>`**: Declares a child joint. The parsing rules for a joint are identical to the root.
* **`End Site`**: Defines a leaf node or end effector (e.g., the tip of a finger or top of the head). It possesses an `OFFSET` (indicating the length of the preceding bone) but has no children and no `CHANNELS`.

### 3.2 Coordinate System
BVH natively assumes a **right-handed coordinate system** where the **Y-axis is the world up vector**. Skeletal segments are typically aligned along the Y or negative Y-axis, representing a character in a default "T-pose" or standing straight with arms down.

---

## 4. The `MOTION` Section
The motion section records the kinematic animation of the skeletal hierarchy. It begins with the keyword `MOTION` on a dedicated line.

### 4.1 Metadata
Immediately following the `MOTION` keyword are two metadata lines:
* **`Frames: <integer>`**: The total number of motion samples/frames in the file.
* **`Frame Time: <float>`**: The duration of a single frame in seconds. For example, a 30 FPS animation is represented as `Frame Time: 0.033333`.

### 4.2 Data Payload
The remainder of the file is a continuous matrix of floating-point numbers.
* Every line represents exactly **one frame of time** for the entire skeleton.
* Values are separated by spaces.
* The numbers map sequentially to the `CHANNELS` defined in the `HIERARCHY` section, utilizing a depth-first traversal order. A parser must memorize the sequence of channels declared during the hierarchy pass to accurately apply the correct floats to the correct joints during the motion pass.

### 4.3 Example File Structure
```text
HIERARCHY
ROOT Hips
{
	OFFSET 0.00 0.00 0.00
	CHANNELS 6 Xposition Yposition Zposition Zrotation Xrotation Yrotation
	JOINT Chest
	{
		OFFSET 0.00 5.21 0.00
		CHANNELS 3 Zrotation Xrotation Yrotation
		End Site
		{
			OFFSET 0.00 2.00 0.00
		}
	}
}
MOTION
Frames: 2
Frame Time: 0.033333
0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
0.1 0.1 0.1 1.0 2.0 3.0 0.5 0.5 0.5
```

---

## 5. Interpreting & Calculating Transforms
To apply BVH data to a 3D model, a parser must calculate local transformation matrices for every joint, frame by frame, and then calculate global transforms via concatenation.

### 5.1 Local Transformations
1. **Translation**: 
	* For a child joint, the translation is statically defined by the `OFFSET` in the hierarchy.
	* For the root joint, the translation is the sum of its `OFFSET` plus the `X/Y/Zposition` values extracted from the `MOTION` line for that frame.
2. **Rotation**: 
	* The rotation matrix is built from the angular data on the `MOTION` line. 
	* In standard Z-X-Y BVH files, you create three separate rotation matrices (one for each axis) and concatenate them from left to right as **Y * X * Z** ($vR = vYXZ$). 

### 5.2 Global Transformations
After establishing the local matrix ($vM_{local}$) of a joint by combining its translation and rotation, you find its final world position by multiplying it by the transformation matrices of all its ancestors:

$$vM_{global} = vM_{local} * vM_{parent} * vM_{grandparent} \dots $$

*(Note: Matrix multiplication order depends on whether row vectors or column vectors are used in your specific engine/math library)*.

---

## 6. Limitations & Considerations
While highly compatible, developers working with BVH files should be aware of several inherent limitations:

* **No Basis Rotations**: The format only allows for *translational* offsets between joints. If a joint is attached at an angle in its rest pose, this cannot be natively stored as an angular offset—it must be baked into the first frame of animation.
* **No Scale Factor**: BVH does not support scale transformations. Scale mismatches (e.g., centimeters vs. meters) between the BVH file and the target application must be addressed manually or through software-specific importer settings (like Blender's BVH import scale factors).
* **Rotation Order Mismatches**: Game engines like Unity and Unreal often prefer XYZ Euler structures or Quaternions. Standard BVH files use ZXY. Improper conversion during import can lead to gimbal lock or spinning joints.
* **Lack of Mesh Binding**: BVH contains strictly skeletal animation. It does not carry skin weights, mesh data, or complex constraint definitions (unlike modern formats such as FBX or USD).
