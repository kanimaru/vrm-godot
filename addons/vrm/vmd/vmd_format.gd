extends RefCounted

## One keyframe of bone animation data from a VMD file.
class VmdBoneFrame:
	## MMD bone name encoded in CP932.
	var name: String = ""
	## VMD frame index (30 fps timeline).
	var frame: int = 0
	## Bone position delta in Godot (RH) space, NOT yet scaled.
	var position: Vector3 = Vector3.ZERO
	## Bone rotation in Godot (RH) space.
	var rotation: Quaternion = Quaternion.IDENTITY
	## Raw Bezier curve control points — 64 bytes, 4 curves of 16 bytes each.
	var interpolation: PackedByteArray = PackedByteArray()


## One keyframe of facial morph (blend shape) data.
class VmdMorphFrame:
	## MMD morph name encoded in CP932.
	var name: String = ""
	## VMD frame index (30 fps timeline).
	var frame: int = 0
	## Blend weight in the range [0.0, 1.0].
	var weight: float = 0.0


## One keyframe of camera animation data.
class VmdCameraFrame:
	## VMD frame index (30 fps timeline).
	var frame: int = 0
	## Distance from the camera to the look-at target (negative = behind).
	var distance: float = 0.0
	## World-space look-at target in Godot (RH) space.
	var target_position: Vector3 = Vector3.ZERO
	## Euler rotation in radians (Pitch X, Yaw Y, Roll Z) in Godot space.
	var rotation: Vector3 = Vector3.ZERO
	## Raw Bezier curve control points — 24 bytes, 6 curves of 4 bytes each.
	var interpolation: PackedByteArray = PackedByteArray()
	## Vertical field of view in degrees.
	var fov: int = 0
	## True = perspective projection; false = orthographic.
	var perspective: bool = true


## One keyframe of directional light data.
class VmdLightFrame:
	## VMD frame index (30 fps timeline).
	var frame: int = 0
	## Linear RGB light colour.
	var color: Color = Color.WHITE
	## Light direction vector (stored as position in VMD).
	var position: Vector3 = Vector3.ZERO


## One keyframe of shadow-map settings.
class VmdShadowFrame:
	## VMD frame index (30 fps timeline).
	var frame: int = 0
	## Shadow mode flag (0 = off, 1 = mode 1, 2 = mode 2).
	var mode: int = 0
	## Shadow map range distance.
	var distance: float = 0.0


## One IK link entry within a [VmdIkDisplayFrame].
class VmdIkLink:
	## Name of the IK bone.
	var name: String = ""
	## Whether the IK chain is enabled for this frame.
	var enabled: bool = true


## One keyframe that toggles IK chain visibility/enable state.
class VmdIkDisplayFrame:
	## VMD frame index (30 fps timeline).
	var frame: int = 0
	## Global display toggle for the IK chains.
	var display: bool = true
	## Per-IK-bone enable states for this frame.
	var ik_links: Array[VmdIkLink] = []


## Container for all data read from a single VMD file.
class VmdData:
	## Name of the MMD model this motion was recorded for.
	var model_name: String = ""
	var bone_frames: Array[VmdBoneFrame] = []
	var morph_frames: Array[VmdMorphFrame] = []
	var camera_frames: Array[VmdCameraFrame] = []
	var light_frames: Array[VmdLightFrame] = []
	var shadow_frames: Array[VmdShadowFrame] = []
	var ik_display_frames: Array[VmdIkDisplayFrame] = []
