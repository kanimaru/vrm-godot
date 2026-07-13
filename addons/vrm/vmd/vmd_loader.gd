class_name VmdLoader
extends RefCounted

## High-level entry point for loading a VMD animation file.
##
## Delegates binary parsing to [VmdParser] and animation-library construction
## to [VmdAnimationLibraryBuilder]. Use [method load_animation_library] as the
## single call needed by the import pipeline or runtime loader.

const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")
const VmdAnimationLibraryBuilder = preload("res://addons/vrm/vmd/vmd_animation_library_builder.gd")

## Parses [param path] and converts the VMD data into a Godot [AnimationLibrary].
##
## [param fps]              — Reserved for future use; VMD is always 30 fps.[br]
## [param camera_y_offset]  — Metres to add to camera target Y (for floor alignment).[br]
## [param a_pose_to_t_pose] — Apply shoulder/arm corrections for A-Pose models.[br]
## [param position_scale]   — Scale applied to VMD bone translation data.[br]
## Returns [code]null[/code] if the file cannot be parsed.
static func load_animation_library(path: String, fps: float = 30.0, camera_y_offset: float = 0.0, a_pose_to_t_pose: bool = true, position_scale: float = 0.08) -> AnimationLibrary:
	print("VmdLoader: Loading '", path, "'")
	var vmd_data: VmdFormat.VmdData = VmdParser.parse_file(path)
	if vmd_data == null:
		printerr("VmdLoader: Failed to parse VMD data.")
		return null
		
	var library: AnimationLibrary = VmdAnimationLibraryBuilder.build(vmd_data, fps, camera_y_offset, a_pose_to_t_pose, position_scale)
	if library and library.get_animation_list().size() > 0:
		print("VmdLoader: Successfully created library from VMD.")
	else:
		print("VmdLoader: Created empty library.")
	return library
