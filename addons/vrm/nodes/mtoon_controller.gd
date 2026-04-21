@tool
extends Node3D


## Manages all MToon materials for a VRM model.
## Holds the MtoonMaterial resources so they stay accessible in the inspector
## and calls their GI update loop every frame.

@export var mtoon_materials: Array[MtoonMaterial] = []


func _process(delta: float) -> void:
	var world_env: WorldEnvironment = _find_world_environment()
	for mtoon: MtoonMaterial in mtoon_materials:
		if mtoon:
			mtoon.process(delta, world_env)


func _find_world_environment() -> WorldEnvironment:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	var root: Node = vp.get_tree().root if vp.get_tree() else null
	if root == null:
		return null
	return _search_node(root)


func _search_node(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for child: Node in node.get_children():
		var result: WorldEnvironment = _search_node(child)
		if result:
			return result
	return null
