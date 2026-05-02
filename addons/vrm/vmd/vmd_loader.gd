class_name VmdLoader
extends RefCounted

const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
const VmdAnimationLibraryBuilder = preload("res://addons/vrm/vmd/vmd_animation_library_builder.gd")

## Loads a VMD file and converts it into a retargeted AnimationLibrary.
static func load_animation_library(path: String, fps: float = 30.0, camera_y_offset: float = 0.0, a_pose_to_t_pose: bool = true, position_scale: float = 0.08) -> AnimationLibrary:
	print("VmdLoader: Loading '", path, "'")
	var vmd_data: VmdParser.VmdData = VmdParser.parse_file(path)
	if vmd_data == null:
		printerr("VmdLoader: Failed to parse VMD data.")
		return null
		
	var library: AnimationLibrary = VmdAnimationLibraryBuilder.build(vmd_data, fps, camera_y_offset, a_pose_to_t_pose, position_scale)
	if library and library.get_animation_list().size() > 0:
		print("VmdLoader: Successfully created library from VMD.")
	else:
		print("VmdLoader: Created empty library.")
	return library
