extends GutTest

var doc: GLTFDocument
var state: GLTFState
var _extensions_registered: bool = false


func before_each():
	doc = GLTFDocument.new()
	state = GLTFState.new()
	if not _extensions_registered:
		_register_extensions()
		_extensions_registered = true


func _register_extensions():
	# We register to ensure they're available in headless test environment
	var vrm0 = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	var vrm1 = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0)
	GLTFDocument.register_gltf_document_extension(vrm1)

func test_vrm1_expressions_luna():
	var path: String = "res://assets/private/luna/luna.vrm"
	if not FileAccess.file_exists(path):
		pending("Luna VRM is a licensed asset kept in the local assets/private repo - not present here")
		return
		
	var err: Error = doc.append_from_file(path, state)
	assert_eq(err, OK, "Luna VRM should load successfully")
	
	var root: Node = doc.generate_scene(state)
	autofree(root)
	
	var controller = root.get_node_or_null("Vrm1ExpressionController")
	assert_not_null(controller, "Vrm1ExpressionController should be attached to Luna")
	
	if controller:
		var binds: Dictionary = controller._binds
		assert_true(binds.has("happy"), "Happy expression should be present in VRM1")
		assert_gt(binds["happy"].morph_binds.size(), 0, "Happy expression should have at least one morph bind")
		
		# Set expression and force update
		controller.happy = 1.0
		controller._process(0.1)
		
		# Verify happy morph target resolution (from Luna's known data)
		var happy_bind = binds["happy"].morph_binds[0]
		assert_true(str(happy_bind.path).contains("Body"), "Morph target should point to a Body node")
		
		# Now verify it actually MOVED in the mesh
		print("Attempting to resolve path: ", happy_bind.path, " from controller: ", controller.name)
		var body = controller.get_node_or_null(happy_bind.path)
		assert_not_null(body, "Body node should be resolvable via path: " + str(happy_bind.path))
		if body is MeshInstance3D:
			var val = body.get_blend_shape_value(happy_bind.index)
			assert_gt(val, 0.9, "Blend shape value should be updated on the mesh")


func test_vrm1_expression_call_spy():
	var path: String = "res://assets/private/luna/luna.vrm"
	if not FileAccess.file_exists(path):
		pending("Luna VRM is a licensed asset kept in the local assets/private repo - not present here")
		return
	doc.append_from_file(path, state)
	var root: Node = doc.generate_scene(state)
	add_child_autofree(root)
	
	var controller = root.get_node_or_null("Vrm1ExpressionController")
	var binds: Dictionary = controller._binds
	var happy_bind = binds["happy"].morph_binds[0]
	var body = controller.get_node(happy_bind.path)
	
	# Replace Body with Spy
	var spy_script = load("res://unit/mesh_spy.gd")
	var spy = spy_script.new()
	spy.mesh = body.mesh # Use original mesh to avoid blend shape index errors
	var parent = body.get_parent()
	var old_name = body.name
	parent.remove_child(body)
	autofree(body)
	parent.add_child(spy)
	spy.name = old_name
	spy.owner = root # Ensure paths resolve correctly
	spy.owner = root
	
	# Verify call
	controller.set_expression("happy", 1.0)
	controller._process(0.01)
	
	assert_gt(spy.call_count, 0, "set_blend_shape_value should be called on the mesh")


func test_vrm1_missing_base_state_still_writes_morphs() -> void:
	# Serialization split-brain regression, VRM1 flavour: a res://-instanced
	# avatar arrives with compiled _binds but EMPTY base dictionaries (plain
	# RefCounted vars don't survive the scene save). The morph WRITE loop
	# iterates _base_morphs, so expressions were computed and then silently
	# DISCARDED — VMD/VRMA face animation "completely missing" on VRM1 avatars.
	# _ensure_base_state() must rebuild the base from the live meshes.
	var root := Node3D.new()
	add_child_autofree(root)
	var controller := Vrm1ExpressionController.new()
	controller.name = "Vrm1ExpressionController"
	root.add_child(controller)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Face"
	var array_mesh := ArrayMesh.new()
	array_mesh.add_blend_shape("blink")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.UP, Vector3.RIGHT, Vector3.ZERO])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
	mesh_inst.mesh = array_mesh
	root.add_child(mesh_inst)

	var bind := RuntimeMorphBind.new()
	bind.path = NodePath("../Face")
	bind.index = 0
	bind.weight = 1.0
	var expression := RuntimeExpression.new()
	expression.morph_binds.append(bind)
	controller._binds["blink"] = expression
	# _base_morphs deliberately left EMPTY — the post-serialization state.

	controller.set_expression("blink", 1.0)
	controller._process(0.01)
	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 1.0, 0.0001,
		"an empty base must be rebuilt lazily, not silently skip the morph write")

	controller.set_expression("blink", 0.0)
	controller._process(0.01)
	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 0.0, 0.0001,
		"release must restore the lazily captured base")


func test_vrm0_expressions_temptic():
	var vrm0_path: String = "res://assets/private/temptic/model.vrm"
	if not FileAccess.file_exists(vrm0_path):
		pending("Temptic VRM is a licensed asset kept in the local assets/private repo - not present here")
		return
		
	var v0_state = GLTFState.new()
	var err: Error = doc.append_from_file(vrm0_path, v0_state)
	assert_eq(err, OK, "Temptic VRM should load successfully")
	
	var v0_root: Node = doc.generate_scene(v0_state)
	autofree(v0_root)
	
	var v0_controller = v0_root.get_node_or_null("Vrm0ExpressionController")
	assert_not_null(v0_controller, "Vrm0ExpressionController should be attached to Temptic")
	
	if v0_controller:
		var v0_binds: Dictionary = v0_controller._binds
		assert_true(v0_binds.has("neutral"), "Neutral expression should be present in VRM0")
		assert_true(v0_binds.has("joy"), "Joy expression should be present in VRM0")
		
		# Test accumulation and material bind presence
		# (Checking for specific material binds depends on the model's actual data)
		# Just verifying the dictionary contains RuntimeExpression objects now
		assert_is(v0_binds["neutral"], RuntimeExpression, "VRM0 binds should use shared RuntimeExpression")
