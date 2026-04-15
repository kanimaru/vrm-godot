@tool
extends SceneTree

func _init():
	var state = GLTFState.new()
	print("GLTFState methods:")
	for method in state.get_method_list():
		if "scene_node" in method["name"]:
			print(method["name"])
	quit()
