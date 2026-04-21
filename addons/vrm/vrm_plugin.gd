@tool
extends EditorPlugin


var vrm0_extension: GLTFDocumentExtension
var vrm1_extension: GLTFDocumentExtension
var vrm_importer: VrmSceneFormatImporter
var vrm0_inspector: EditorInspectorPlugin
var vrm1_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	vrm0_extension = preload("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	vrm1_extension = preload("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	vrm_importer = preload("res://addons/vrm/import/vrm_scene_format_importer.gd").new()
	vrm0_inspector = preload("res://addons/vrm/vrm0/vrm0_inspector_plugin.gd").new()
	vrm1_inspector = preload("res://addons/vrm/vrm1/vrm1_inspector_plugin.gd").new()
	
	GLTFDocument.register_gltf_document_extension(vrm0_extension)
	GLTFDocument.register_gltf_document_extension(vrm1_extension)
	add_scene_format_importer_plugin(vrm_importer)
	add_inspector_plugin(vrm0_inspector)
	add_inspector_plugin(vrm1_inspector)


func _exit_tree() -> void:
	if vrm0_inspector:
		remove_inspector_plugin(vrm0_inspector)
		vrm0_inspector = null
	if vrm1_inspector:
		remove_inspector_plugin(vrm1_inspector)
		vrm1_inspector = null
	if vrm_importer:
		remove_scene_format_importer_plugin(vrm_importer)
		vrm_importer = null
	if vrm0_extension:
		GLTFDocument.unregister_gltf_document_extension(vrm0_extension)
		vrm0_extension = null
	if vrm1_extension:
		GLTFDocument.unregister_gltf_document_extension(vrm1_extension)
		vrm1_extension = null
