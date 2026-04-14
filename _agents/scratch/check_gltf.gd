extends SceneTree

func _init():
	var gnode = GLTFNode.new()
	print("GLTFNode properties:")
	for prop in gnode.get_property_list():
		if prop.usage & PROPERTY_USAGE_EDITOR or prop.usage & PROPERTY_USAGE_STORAGE:
			print(" - ", prop.name)
	quit()
