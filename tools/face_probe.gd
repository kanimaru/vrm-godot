extends SceneTree
## Headless blendshape-accumulation probe: loads a VRM, drives its expression
## controller with oscillating absolute weights exactly the way VBeami's sink
## does (set_expression with 0..1 values every frame), and watches the ACTUAL
## mesh blend-shape values. With a correct reset-then-accumulate cycle the max
## value stays <= ~1; a growing max means weights are stacking up somewhere.
##
## Usage:
##   godot --headless --path . -s res://tools/face_probe.gd \
##       ++ model=res://assets/temptic/model.vrm frames=600


func _initialize() -> void:
	_run()


func _run() -> void:
	var model_path: String = "res://assets/temptic/model.vrm"
	var frames: int = 600
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("model="):
			model_path = arg.trim_prefix("model=")
		elif arg.begins_with("frames="):
			frames = int(arg.trim_prefix("frames="))

	var vrm0_ext: GLTFDocumentExtension = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	var vrm1_ext: GLTFDocumentExtension = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0_ext, true)
	GLTFDocument.register_gltf_document_extension(vrm1_ext, true)

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	if gltf.append_from_file(model_path, state) != OK:
		print("[face] FAILED to load ", model_path)
		quit(1)
		return
	var model: Node = gltf.generate_scene(state)
	root.add_child(model)
	await process_frame

	var util: GDScript = load("res://addons/vrm/common/vrm_util.gd")
	var controller: Node = util.find_expression_controller(model)
	print("[face] model=", model_path)
	if controller == null:
		print("[face] no expression controller found")
		quit(1)
		return
	print("[face] controller=", controller.get_script().get_global_name())

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	print("[face] meshes=", meshes.size())

	for f: int in range(frames):
		var osc: float = 0.5 + 0.5 * sin(f * 0.21)
		# The sink writes absolute values through set_expression every tick:
		# auto-blink, viseme, gaze — plus ARKit names that land in
		# custom_expressions (unbound on VRM0, should be inert).
		controller.call("set_expression", "blink", osc)
		controller.call("set_expression", "a", 1.0 - osc)
		controller.call("set_expression", "look_up", osc * 0.35)
		controller.call("set_expression", "joy", 0.5)
		controller.call("set_expression", "eyeBlinkLeft", osc)
		await process_frame

		if f % 100 == 99 or f == frames - 1:
			var worst: float = 0.0
			var worst_desc: String = ""
			for mesh: MeshInstance3D in meshes:
				if mesh.mesh == null:
					continue
				for i: int in range(mesh.mesh.get_blend_shape_count() if mesh.mesh is ArrayMesh else mesh.get_blend_shape_count()):
					var v: float = mesh.get_blend_shape_value(i)
					if absf(v) > absf(worst):
						worst = v
						worst_desc = "%s[%d]" % [mesh.name, i]
			print("[face] frame=%d maxBlend=%.3f at %s" % [f + 1, worst, worst_desc])

	print("[face] done")
	quit(0)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child: Node in node.get_children():
		_collect_meshes(child, out)
