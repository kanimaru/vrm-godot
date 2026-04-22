class_name VrmaLoader
extends RefCounted

## Runtime helper for loading .vrma files as AnimationLibrary resources.
## The VrmaExtension is temporarily registered so that VRMC_vrm_animation data
## is parsed into GLTFState even outside the editor import pipeline.
##
## Usage:
##   var library = VrmaLoader.load_animation_library("user://my_anim.vrma")
##   $AnimationPlayer.add_animation_library("my_anim", library)

const VrmaAnimationLibraryBuilder = preload(
	"res://addons/vrm/vrma/vrma_animation_library_builder.gd"
)


static func load_animation_library(path: String) -> AnimationLibrary:
	# Register VrmaExtension so _import_post_parse fires and populates state.
	var extension: VrmaExtension = VrmaExtension.new()
	GLTFDocument.register_gltf_document_extension(extension)

	var library: AnimationLibrary = _load_internal(path)

	GLTFDocument.unregister_gltf_document_extension(extension)
	return library


static func _load_internal(path: String) -> AnimationLibrary:
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()

	var err: Error = gltf.append_from_file(path, state, 0)
	if err != OK:
		printerr("VrmaLoader: Failed to parse '", path, "' (", err, ")")
		return null

	var scene: Node = gltf.generate_scene(state, 30.0, true, false)
	if scene == null:
		printerr("VrmaLoader: Failed to generate scene from '", path, "'")
		return null

	var library: AnimationLibrary = VrmaAnimationLibraryBuilder.build(state, scene)
	scene.free()

	return library
