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

	# packed=true replays what the EDITOR import does to an avatar: serialize
	# the scene (PackedScene.pack) and instantiate the serialized copy. The
	# expression controller's _binds/_base_morphs are plain vars holding
	# RefCounted objects — whatever survives this round trip is what a
	# res://-instanced avatar actually runs with.
	if OS.get_cmdline_user_args().has("packed=true"):
		var ps := PackedScene.new()
		var pack_err: Error = ps.pack(model)
		print("[face] pack err=", pack_err)
		model.free()
		model = ps.instantiate()
		print("[face] instantiated from PackedScene")

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
	print("[face] expressions=", controller.get("expressions"))

	var binds: Dictionary = controller.get("_binds")
	var base_morphs: Dictionary = controller.get("_base_morphs")
	print("[face] _binds=", binds.size(), " _base_morphs=", base_morphs.size())
	for key: NodePath in base_morphs:
		var state_obj: Variant = base_morphs[key]
		print("[face]   base ", key, " -> ",
			"null" if state_obj == null else str(state_obj.get("blend_shapes")))
	if binds.has("blink"):
		var blink_expr: Variant = binds["blink"]
		print("[face]   blink binds=",
			"null" if blink_expr == null else str((blink_expr.get("morph_binds") as Array).size()))

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	print("[face] meshes=", meshes.size())

	for f: int in range(frames):
		var osc: float = 0.5 + 0.5 * sin(f * 0.21)
		# The sink writes absolute values through set_expression every tick.
		# Drive every blink SPELLING the IR/resolver can produce: the VRM0
		# preset property, IR camelCase, VRM0 spec enum casing, and the model's
		# own group names — whichever spelling lands in the unclamped
		# custom_expressions dict AND matches a _binds key is the suspect.
		controller.call("set_expression", "blink", osc)
		controller.call("set_expression", "blinkLeft", osc)
		controller.call("set_expression", "blinkRight", osc)
		controller.call("set_expression", "blink_l", osc)
		controller.call("set_expression", "Blink.Left", osc)
		controller.call("set_expression", "a", 1.0 - osc)
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
