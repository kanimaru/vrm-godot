extends RefCounted

const CP932Decoder = preload("res://addons/vrm/vmd/cp932_decoder.gd")
const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")

static func parse(file: FileAccess) -> Array[VmdFormat.VmdIkDisplayFrame]:
	var frames: Array[VmdFormat.VmdIkDisplayFrame] = []
	if file.get_position() >= file.get_length():
		return frames
		
	var ik_count: int = file.get_32()
	for ik_idx in range(ik_count):
		var frame: VmdFormat.VmdIkDisplayFrame = VmdFormat.VmdIkDisplayFrame.new()
		frame.frame = file.get_32()
		frame.display = file.get_8() == 1
		
		var link_count: int = file.get_32()
		for link_idx in range(link_count):
			var link: VmdFormat.VmdIkLink = VmdFormat.VmdIkLink.new()
			link.name = CP932Decoder.decode(file.get_buffer(20))
			link.enabled = file.get_8() == 1
			frame.ik_links.append(link)
			
		frames.append(frame)
		
	return frames
