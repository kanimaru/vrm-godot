extends RefCounted

const CP932Decoder = preload("res://addons/vrm/vmd/cp932_decoder.gd")
const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")

static func parse(file: FileAccess) -> Array[VmdFormat.VmdMorphFrame]:
	var frames: Array[VmdFormat.VmdMorphFrame] = []
	if file.get_position() >= file.get_length():
		return frames
		
	var morph_count: int = file.get_32()
	for morph_idx in range(morph_count):
		var frame: VmdFormat.VmdMorphFrame = VmdFormat.VmdMorphFrame.new()
		frame.name = CP932Decoder.decode(file.get_buffer(15))
		frame.frame = file.get_32()
		frame.weight = file.get_float()
		frames.append(frame)
		
	return frames
