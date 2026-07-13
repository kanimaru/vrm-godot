extends RefCounted

const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")

static func parse(file: FileAccess) -> Array[VmdFormat.VmdLightFrame]:
	var frames: Array[VmdFormat.VmdLightFrame] = []
	if file.get_position() >= file.get_length():
		return frames
		
	var light_count: int = file.get_32()
	for light_idx in range(light_count):
		var frame: VmdFormat.VmdLightFrame = VmdFormat.VmdLightFrame.new()
		frame.frame = file.get_32()
		frame.color = Color(file.get_float(), file.get_float(), file.get_float(), 1.0)
		frame.position = Vector3(file.get_float(), file.get_float(), file.get_float())
		frames.append(frame)
		
	return frames
