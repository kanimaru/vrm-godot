@tool
class_name VrmSceneFormatImporter
extends EditorSceneFormatImporter


func _get_extensions() -> PackedStringArray:
	return PackedStringArray(["vrm"])


func _get_import_flags() -> int:
	return EditorSceneFormatImporter.IMPORT_SCENE


func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	
	var err: Error = gltf.append_from_file(path, state, flags)
	if err != OK:
		printerr("VrmSceneFormatImporter: Failed to load VRM file at path: ", path)
		return null
		
	var generated_scene: Node = gltf.generate_scene(state, 30.0, true, false)
	return generated_scene
