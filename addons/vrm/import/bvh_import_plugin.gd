@tool
class_name BvhImportPlugin
extends EditorImportPlugin

func _get_importer_name() -> String:
	return "vrm.bvh.importer"

func _get_visible_name() -> String:
	return "BVH Animation Library"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["bvh"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "AnimationLibrary"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "scale_factor",
			"default_value": 0.01,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.001,100.0,0.001,or_greater"
		},
		{
			"name": "target_fps",
			"default_value": 30.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,240.0,1.0,or_greater"
		},
		{
			"name": "bone_map_preset",
			"default_value": "Mixamo",
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "Mixamo,CMU,Raw"
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var scale_factor: float = options.get("scale_factor", 0.01)
	var target_fps: float = options.get("target_fps", 30.0)
	var bone_map_preset: String = options.get("bone_map_preset", "Mixamo")
	
	var BvhLoader = load("res://addons/vrm/bvh/bvh_loader.gd")
	var library: AnimationLibrary = BvhLoader.load_animation_library(source_file, target_fps, scale_factor, bone_map_preset)
	
	if library == null:
		return ERR_PARSE_ERROR
		
	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(library, filename)
	return err
