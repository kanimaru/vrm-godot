extends RefCounted

## Parses a binary VMD (Vocaloid Motion Data) file into typed data structures.
##
## VMD files use a Left-Handed coordinate system (Z-forward) and CP932
## (Shift-JIS) text encoding. This parser converts positions and quaternions
## to Godot's Right-Handed (Z-backward) coordinate system during parsing.

const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")
const VmdHeaderParser = preload("res://addons/vrm/vmd/vmd_header_parser.gd")
const VmdBoneParser = preload("res://addons/vrm/vmd/vmd_bone_parser.gd")
const VmdMorphParser = preload("res://addons/vrm/vmd/vmd_morph_parser.gd")
const VmdCameraParser = preload("res://addons/vrm/vmd/vmd_camera_parser.gd")
const VmdLightParser = preload("res://addons/vrm/vmd/vmd_light_parser.gd")
const VmdShadowParser = preload("res://addons/vrm/vmd/vmd_shadow_parser.gd")
const VmdIkParser = preload("res://addons/vrm/vmd/vmd_ik_parser.gd")


## Opens [param path] and parses the binary VMD format into a [VmdData] object.
## Returns [code]null[/code] if the file cannot be opened or has an invalid header.
static func parse_file(path: String) -> VmdFormat.VmdData:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("VmdParser: Failed to open file: ", path)
		return null

	var data: VmdFormat.VmdData = VmdFormat.VmdData.new()

	if not VmdHeaderParser.parse(file, data):
		return null

	data.bone_frames = VmdBoneParser.parse(file)
	data.morph_frames = VmdMorphParser.parse(file)
	data.camera_frames = VmdCameraParser.parse(file)
	data.light_frames = VmdLightParser.parse(file)
	data.shadow_frames = VmdShadowParser.parse(file)
	data.ik_display_frames = VmdIkParser.parse(file)

	return data
