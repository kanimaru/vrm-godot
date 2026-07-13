extends RefCounted

const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")

static func parse(file: FileAccess) -> Array[VmdFormat.VmdCameraFrame]:
	var frames: Array[VmdFormat.VmdCameraFrame] = []
	if file.get_position() >= file.get_length():
		return frames
		
	var camera_count: int = file.get_32()
	for camera_idx in range(camera_count):
		var frame: VmdFormat.VmdCameraFrame = VmdFormat.VmdCameraFrame.new()
		frame.frame = file.get_32()
		frame.distance = file.get_float()
		
		# Convert camera target position from MMD (LH, Z+) to Godot (RH, Z-).
		var target_x: float = file.get_float()
		var target_y: float = file.get_float()
		var target_z: float = file.get_float()
		frame.target_position = Vector3(target_x, target_y, -target_z)
		
		frame.rotation = Vector3(file.get_float(), file.get_float(), file.get_float())
		frame.interpolation = file.get_buffer(24)
		frame.fov = file.get_32()
		frame.perspective = file.get_8() == 0
		frames.append(frame)
		
	return frames
