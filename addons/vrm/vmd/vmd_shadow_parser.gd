extends RefCounted

const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")

static func parse(file: FileAccess) -> Array[VmdFormat.VmdShadowFrame]:
	var frames: Array[VmdFormat.VmdShadowFrame] = []
	if file.get_position() >= file.get_length():
		return frames
		
	var shadow_count: int = file.get_32()
	for shadow_idx in range(shadow_count):
		var frame: VmdFormat.VmdShadowFrame = VmdFormat.VmdShadowFrame.new()
		frame.frame = file.get_32()
		frame.mode = file.get_8()
		frame.distance = file.get_float()
		frames.append(frame)
		
	return frames
