class_name BvhLoader
extends RefCounted

const BvhParser = preload("res://addons/vrm/bvh/bvh_parser.gd")
const BvhAnimationLibraryBuilder = preload("res://addons/vrm/bvh/bvh_animation_library_builder.gd")

## Loads a BVH file and builds a retargeted [AnimationLibrary] from it.
##
## [param target_hips_height] — when >= 0.0, overrides [param scale_factor] with a
## value auto-computed from the ratio of [param target_hips_height] to this BVH file's
## own root/hips offset Y, using the single parse this function already performs. Pass
## the target avatar's hips world-rest height here instead of pre-parsing the file
## yourself just to read that ratio.
static func load_animation_library(
		path: String,
		fps: float = 30.0,
		scale_factor: float = 0.01,
		bone_map_preset: String = BvhAnimationLibraryBuilder.PRESET_RAW,
		target_hips_height: float = -1.0,
) -> AnimationLibrary:
	print("BvhLoader: Loading '", path, "' with scale ", scale_factor, " and preset ", bone_map_preset)
	var bvh_data = BvhParser.parse_file(path)
	if bvh_data == null:
		print("BvhLoader: Failed to parse BVH data.")
		return null

	var effective_scale: float = scale_factor
	if target_hips_height >= 0.0 and bvh_data.root != null:
		var bvh_hips_height: float = bvh_data.root.offset.y
		if absf(bvh_hips_height) > 0.001:
			effective_scale = target_hips_height / bvh_hips_height

	var library = BvhAnimationLibraryBuilder.build(bvh_data, fps, effective_scale, bone_map_preset)
	if library and library.get_animation_list().size() > 0:
		print("BvhLoader: Successfully created library with ", library.get_animation_list().size(), " animations.")
	else:
		print("BvhLoader: Created empty library.")
	return library
