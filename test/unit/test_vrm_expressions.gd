extends GutTest

var doc: GLTFDocument
var state: GLTFState

func before_each():
	doc = GLTFDocument.new()
	state = GLTFState.new()
	_register_extensions()

func _register_extensions():
	# We register to ensure they're available in headless test environment
	var vrm0 = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	var vrm1 = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0)
	GLTFDocument.register_gltf_document_extension(vrm1)

func test_vrm1_expressions_luna():
	var path: String = "res://assets/luna/luna.vrm"
	if not FileAccess.file_exists(path):
		assert_true(false, "Luna VRM file missing at: " + path)
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
		
		# Verify happy morph target resolution (from Luna's known data)
		var happy_bind = binds["happy"].morph_binds[0]
		assert_true(str(happy_bind.path).contains("Body"), "Morph target should point to a Body node")

func test_vrm0_expressions_temptic():
	var path: String = "res://assets/temptic/model.vrm"
	if not FileAccess.file_exists(path):
		assert_true(false, "Temptic VRM file missing at: " + path)
		return
		
	var err: Error = doc.append_from_file(path, state)
	assert_eq(err, OK, "Temptic VRM should load successfully")
	
	var root: Node = doc.generate_scene(state)
	autofree(root)
	
	var controller = root.get_node_or_null("Vrm0ExpressionController")
	assert_not_null(controller, "Vrm0ExpressionController should be attached to Temptic")
	
	if controller:
		var binds: Dictionary = controller.expression_binds
		assert_true(binds.has("neutral"), "Neutral expression should be present in VRM0")
		assert_true(binds.has("joy"), "Joy expression should be present in VRM0")
