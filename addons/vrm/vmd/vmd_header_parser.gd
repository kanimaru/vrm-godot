extends RefCounted

const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")
const CP932Decoder = preload("res://addons/vrm/vmd/cp932_decoder.gd")

static func parse(file: FileAccess, data: VmdFormat.VmdData) -> bool:
	var signature: String = file.get_buffer(30).get_string_from_ascii()
	if not signature.begins_with("Vocaloid Motion Data"):
		printerr("VmdHeaderParser: Invalid VMD signature: ", signature)
		return false
	
	data.model_name = CP932Decoder.decode(file.get_buffer(20))
	return true
