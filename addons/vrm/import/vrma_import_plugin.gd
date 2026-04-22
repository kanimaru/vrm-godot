@tool
class_name VrmaImportPlugin
extends EditorImportPlugin

## Imports .vrma files as AnimationLibrary resources.
## Tracks are retargeted to %GeneralSkeleton, %Vrm1ExpressionController, and
## %Vrm1LookAtController so the library can be used on any VRM 1.0 avatar.

const VrmaAnimationLibraryBuilder = preload(
	"res://addons/vrm/vrma/vrma_animation_library_builder.gd"
)


func _get_importer_name() -> String:
	return "vrm.animation"


func _get_visible_name() -> String:
	return "VRM Animation"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["vrma"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "AnimationLibrary"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "Default"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(
	path: String, option_name: StringName, options: Dictionary
) -> bool:
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
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()

	var err: Error = gltf.append_from_file(source_file, state, 0)
	if err != OK:
		printerr("VrmaImportPlugin: Failed to parse '", source_file, "' (", err, ")")
		return err

	var scene: Node = gltf.generate_scene(state, 30.0, true, false)
	if scene == null:
		printerr("VrmaImportPlugin: Failed to generate scene from '", source_file, "'")
		return FAILED

	var library: AnimationLibrary = VrmaAnimationLibraryBuilder.build(state, scene)
	scene.free()

	if library == null:
		return FAILED

	var save_err: Error = ResourceSaver.save(library, save_path + "." + _get_save_extension())
	return save_err
