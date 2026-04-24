class_name BvhLoader
extends RefCounted

const BvhParser = preload("res://addons/vrm/bvh/bvh_parser.gd")
const BvhAnimationLibraryBuilder = preload("res://addons/vrm/bvh/bvh_animation_library_builder.gd")

static func load_animation_library(path: String, fps: float = 30.0, scale_factor: float = 0.01, bone_map_preset: String = BvhAnimationLibraryBuilder.PRESET_MIXAMO) -> AnimationLibrary:
	var bvh_data = BvhParser.parse_file(path)
	if bvh_data == null:
		return null
		
	return BvhAnimationLibraryBuilder.build(bvh_data, fps, scale_factor, bone_map_preset)
