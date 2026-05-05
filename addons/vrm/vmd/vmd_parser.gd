class_name VmdParser
extends RefCounted

const CP932Decoder = preload("res://addons/vrm/vmd/cp932_decoder.gd")

class VmdBoneFrame:
	var name: String = ""
	var frame: int = 0
	var position: Vector3 = Vector3.ZERO
	var rotation: Quaternion = Quaternion.IDENTITY
	var interpolation: PackedByteArray = PackedByteArray() # 64 bytes

class VmdMorphFrame:
	var name: String = ""
	var frame: int = 0
	var weight: float = 0.0

class VmdCameraFrame:
	var frame: int = 0
	var distance: float = 0.0
	var target_position: Vector3 = Vector3.ZERO
	var rotation: Vector3 = Vector3.ZERO # Euler Radians
	var interpolation: PackedByteArray = PackedByteArray() # 24 bytes
	var fov: int = 0
	var perspective: bool = true

class VmdLightFrame:
	var frame: int = 0
	var color: Color = Color.WHITE
	var position: Vector3 = Vector3.ZERO

class VmdShadowFrame:
	var frame: int = 0
	var mode: int = 0
	var distance: float = 0.0

class VmdIkLink:
	var name: String = ""
	var enabled: bool = true

class VmdIkDisplayFrame:
	var frame: int = 0
	var display: bool = true
	var ik_links: Array[VmdIkLink] = []

class VmdData:
	var model_name: String = ""
	var bone_frames: Array[VmdBoneFrame] = []
	var morph_frames: Array[VmdMorphFrame] = []
	var camera_frames: Array[VmdCameraFrame] = []
	var light_frames: Array[VmdLightFrame] = []
	var shadow_frames: Array[VmdShadowFrame] = []
	var ik_display_frames: Array[VmdIkDisplayFrame] = []


static func parse_file(path: String) -> VmdData:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("VmdParser: Failed to open file: ", path)
		return null
	
	var data: VmdData = VmdData.new()
	
	# 1. Header
	var signature: String = file.get_buffer(30).get_string_from_ascii()
	if not signature.begins_with("Vocaloid Motion Data"):
		printerr("VmdParser: Invalid VMD signature: ", signature)
		return null
	
	data.model_name = CP932Decoder.decode(file.get_buffer(20))
	
	# 2. Bone Frames
	if file.get_position() < file.get_length():
		var bone_count: int = file.get_32()
		for i: int in range(bone_count):
			var frame: VmdBoneFrame = VmdBoneFrame.new()
			frame.name = CP932Decoder.decode(file.get_buffer(15))
			frame.frame = file.get_32()
			# Convert from MMD Left-Handed (Z+) to Godot Right-Handed (Z-)
			# Position: (X, Y, -Z)
			var px: float = file.get_float()
			var py: float = file.get_float()
			var pz: float = file.get_float()
			frame.position = Vector3(px, py, -pz)
			
			# MMD Quaternions are stored as (X, Y, Z, W) in a Left-Handed (Z+) system.
			# To convert LH→RH: reflect axis across Z=0 (negate Z), then negate
			# the angle (handedness flip). Result: (-X, -Y, Z, W).
			# Matches Godot-MMD reference: ReadQuaternionXYInv.
			var qx: float = file.get_float()
			var qy: float = file.get_float()
			var qz: float = file.get_float()
			var qw: float = file.get_float()
			frame.rotation = Quaternion(-qx, -qy, qz, qw)
			frame.interpolation = file.get_buffer(64)
			data.bone_frames.append(frame)
			
	# 3. Morph Frames
	if file.get_position() < file.get_length():
		var morph_count: int = file.get_32()
		for i: int in range(morph_count):
			var frame: VmdMorphFrame = VmdMorphFrame.new()
			frame.name = CP932Decoder.decode(file.get_buffer(15))
			frame.frame = file.get_32()
			frame.weight = file.get_float()
			data.morph_frames.append(frame)
			
	# 4. Camera Frames
	if file.get_position() < file.get_length():
		var camera_count: int = file.get_32()
		for i: int in range(camera_count):
			var frame: VmdCameraFrame = VmdCameraFrame.new()
			frame.frame = file.get_32()
			frame.distance = file.get_float()
			# Convert camera target position: (X, Y, -Z)
			var tx: float = file.get_float()
			var ty: float = file.get_float()
			var tz: float = file.get_float()
			frame.target_position = Vector3(tx, ty, -tz)
			frame.rotation = Vector3(file.get_float(), file.get_float(), file.get_float())
			frame.interpolation = file.get_buffer(24)
			frame.fov = file.get_32()
			frame.perspective = file.get_8() == 0
			data.camera_frames.append(frame)
			
	# 5. Light Frames
	if file.get_position() < file.get_length():
		var light_count: int = file.get_32()
		for i: int in range(light_count):
			var frame: VmdLightFrame = VmdLightFrame.new()
			frame.frame = file.get_32()
			frame.color = Color(file.get_float(), file.get_float(), file.get_float(), 1.0)
			frame.position = Vector3(file.get_float(), file.get_float(), file.get_float())
			data.light_frames.append(frame)
			
	# 6. Shadow Frames
	if file.get_position() < file.get_length():
		var shadow_count: int = file.get_32()
		for i: int in range(shadow_count):
			var frame: VmdShadowFrame = VmdShadowFrame.new()
			frame.frame = file.get_32()
			frame.mode = file.get_8()
			frame.distance = file.get_float()
			data.shadow_frames.append(frame)
			
	# 7. IK/Display Frames
	if file.get_position() < file.get_length():
		var ik_count: int = file.get_32()
		for i: int in range(ik_count):
			var frame: VmdIkDisplayFrame = VmdIkDisplayFrame.new()
			frame.frame = file.get_32()
			frame.display = file.get_8() == 1
			var link_count: int = file.get_32()
			for j: int in range(link_count):
				var link: VmdIkLink = VmdIkLink.new()
				link.name = CP932Decoder.decode(file.get_buffer(20))
				link.enabled = file.get_8() == 1
				frame.ik_links.append(link)
			data.ik_display_frames.append(frame)
			
	return data
