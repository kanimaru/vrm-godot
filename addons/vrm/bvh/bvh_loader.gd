class_name BvhLoader
extends RefCounted

const BvhParser = preload("res://addons/vrm/bvh/bvh_parser.gd")
const BvhAnimationLibraryBuilder = preload("res://addons/vrm/bvh/bvh_animation_library_builder.gd")

static func load_animation_library(path: String, fps: float = 30.0, scale_factor: float = 0.01, bone_map_preset: String = BvhAnimationLibraryBuilder.PRESET_RAW) -> AnimationLibrary:
	print("BvhLoader: Loading '", path, "' with scale ", scale_factor, " and preset ", bone_map_preset)
	var bvh_data = BvhParser.parse_file(path)
	if bvh_data == null:
		print("BvhLoader: Failed to parse BVH data.")
		return null
		
	var library = BvhAnimationLibraryBuilder.build(bvh_data, fps, scale_factor, bone_map_preset)
	if library and library.get_animation_list().size() > 0:
		print("BvhLoader: Successfully created library with ", library.get_animation_list().size(), " animations.")
	else:
		print("BvhLoader: Created empty library.")
	return library
