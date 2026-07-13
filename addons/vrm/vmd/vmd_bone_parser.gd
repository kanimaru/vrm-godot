extends RefCounted

const CP932Decoder = preload("res://addons/vrm/vmd/cp932_decoder.gd")
const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")

static func parse(file: FileAccess) -> Array[VmdFormat.VmdBoneFrame]:
	var frames: Array[VmdFormat.VmdBoneFrame] = []
	if file.get_position() >= file.get_length():
		return frames
		
	var bone_count: int = file.get_32()
	for bone_idx in range(bone_count):
		var frame: VmdFormat.VmdBoneFrame = VmdFormat.VmdBoneFrame.new()
		frame.name = CP932Decoder.decode(file.get_buffer(15))
		frame.frame = file.get_32()
		
		# Convert from MMD Left-Handed (Z+) to Godot Right-Handed (Z-).
		# Position mapping: (X, Y, -Z).
		var pos_x: float = file.get_float()
		var pos_y: float = file.get_float()
		var pos_z: float = file.get_float()
		frame.position = Vector3(pos_x, pos_y, -pos_z)
		
		# MMD Quaternions are stored as (X, Y, Z, W) in a Left-Handed (Z+) system.
		# To convert LH->RH: reflect axis across Z=0 (negate Z), then negate
		# the angle (handedness flip). Result: (-X, -Y, Z, W).
		# Matches Godot-MMD reference: ReadQuaternionXYInv.
		var quat_x: float = file.get_float()
		var quat_y: float = file.get_float()
		var quat_z: float = file.get_float()
		var quat_w: float = file.get_float()
		frame.rotation = Quaternion(-quat_x, -quat_y, quat_z, quat_w)
		frame.interpolation = file.get_buffer(64)
		
		frames.append(frame)
		
	return frames
