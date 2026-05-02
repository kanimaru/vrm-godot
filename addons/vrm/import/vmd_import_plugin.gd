@tool
class_name VmdImportPlugin
extends EditorImportPlugin

## Imports .vmd files as AnimationLibrary resources.
## Tracks are retargeted to %GeneralSkeleton, %Vrm1ExpressionController, 
## and %VmdCamera for universal use on VRM avatars.

const VmdLoader = preload("res://addons/vrm/vmd/vmd_loader.gd")

func _get_importer_name() -> String:
	return "vrm.vmd"

func _get_visible_name() -> String:
	return "MMD Vocaloid Motion Data"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["vmd"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "AnimationLibrary"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "fps",
			"default_value": 30.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,120,1"
		},
		{
			"name": "camera_y_offset",
			"default_value": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-50,50,0.1,or_greater,or_less"
		},
		{
			"name": "a_pose_to_t_pose",
			"default_value": true
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	platform_variants: Array[String],
	gen_files: Array[String],
) -> Error:
	var fps: float = options.get("fps", 30.0)
	var y_offset: float = options.get("camera_y_offset", 0.0)
	var a_pose: bool = options.get("a_pose_to_t_pose", true)
	
	var library: AnimationLibrary = VmdLoader.load_animation_library(source_file, fps, y_offset, a_pose)
	
	if library == null:
		printerr("VmdImportPlugin: Failed to import '", source_file, "'")
		return FAILED

	var save_err: Error = ResourceSaver.save(library, save_path + "." + _get_save_extension())
	return save_err
