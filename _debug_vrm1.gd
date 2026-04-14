extends SceneTree

func _init() -> void:
	print("Starting debug...")
	
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	
	# Register extensions
	var vrm0 = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	var vrm1 = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0)
	GLTFDocument.register_gltf_document_extension(vrm1)
	
	var target_file = "res://assets/luna/luna.vrm"
	var err = doc.append_from_file(target_file, state)
	print("Load error: ", err)
	var node = doc.generate_scene(state)
	if node:
		var ctrl = node.get_node_or_null("Vrm1ExpressionController")
		if ctrl:
			print("Vrm1ExpressionController found!")
			print("Binds count: ", ctrl._binds.size())
			var happy_expr = ctrl._binds.get("happy")
			if happy_expr:
				print("Happy morph binds count: ", happy_expr.morph_binds.size())
				for bind in happy_expr.morph_binds:
					print("Morph bind: ", bind.path, " ", bind.index, " ", bind.weight)
			else:
				print("No happy bind in dictionary")
		else:
			print("No controller found!")
			
	quit()
