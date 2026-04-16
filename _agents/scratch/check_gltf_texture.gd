extends SceneTree

func _init():
	var state = GLTFState.new()
	print("GLTFState methods related to images/textures:")
	for m in state.get_method_list():
		if "image" in m.name.to_lower() or "texture" in m.name.to_lower() or "material" in m.name.to_lower():
			var args_info: String = ""
			for a in m.args:
				args_info += a.name + ", "
			print("  %s(%s)" % [m.name, args_info])
	print("")
	
	var gltf_tex = GLTFTexture.new()
	print("GLTFTexture properties:")
	for prop in gltf_tex.get_property_list():
		if prop.usage & PROPERTY_USAGE_EDITOR or prop.usage & PROPERTY_USAGE_STORAGE:
			print("  - %s" % prop.name)
	quit()
