@tool
extends Node3D
class_name Vrm0ExpressionController


## A dictionary containing the runtime mappings of expressions to MeshInstance3D blend shapes.
var expression_binds: Dictionary[String, RuntimeBlendShapeBinds] = {}


## Standard VRM Expressions
@export_range(0.0, 1.0) var neutral: float = 0.0:
	set(value):
		neutral = clampf(value, 0.0, 1.0)
		set_expression("neutral", neutral)

@export_range(0.0, 1.0) var joy: float = 0.0:
	set(value):
		joy = clampf(value, 0.0, 1.0)
		set_expression("joy", joy)

@export_range(0.0, 1.0) var angry: float = 0.0:
	set(value):
		angry = clampf(value, 0.0, 1.0)
		set_expression("angry", angry)

@export_range(0.0, 1.0) var sorrow: float = 0.0:
	set(value):
		sorrow = clampf(value, 0.0, 1.0)
		set_expression("sorrow", sorrow)

@export_range(0.0, 1.0) var fun: float = 0.0:
	set(value):
		fun = clampf(value, 0.0, 1.0)
		set_expression("fun", fun)

@export_range(0.0, 1.0) var surprised: float = 0.0:
	set(value):
		surprised = clampf(value, 0.0, 1.0)
		set_expression("surprised", surprised)


## Vowels
@export_range(0.0, 1.0) var a: float = 0.0:
	set(value):
		a = clampf(value, 0.0, 1.0)
		set_expression("a", a)

@export_range(0.0, 1.0) var i: float = 0.0:
	set(value):
		i = clampf(value, 0.0, 1.0)
		set_expression("i", i)

@export_range(0.0, 1.0) var u: float = 0.0:
	set(value):
		u = clampf(value, 0.0, 1.0)
		set_expression("u", u)

@export_range(0.0, 1.0) var e: float = 0.0:
	set(value):
		e = clampf(value, 0.0, 1.0)
		set_expression("e", e)

@export_range(0.0, 1.0) var o: float = 0.0:
	set(value):
		o = clampf(value, 0.0, 1.0)
		set_expression("o", o)


## Blinking
@export_range(0.0, 1.0) var blink: float = 0.0:
	set(value):
		blink = clampf(value, 0.0, 1.0)
		set_expression("blink", blink)

@export_range(0.0, 1.0) var blink_left: float = 0.0:
	set(value):
		blink_left = clampf(value, 0.0, 1.0)
		set_expression("blink_left", blink_left)

@export_range(0.0, 1.0) var blink_right: float = 0.0:
	set(value):
		blink_right = clampf(value, 0.0, 1.0)
		set_expression("blink_right", blink_right)


## Applies the blend shape modifiers for a given expression name.
func set_expression(expression_name: String, value: float) -> void:
	if expression_binds.has(expression_name):
		var runtime_binds := expression_binds[expression_name] as RuntimeBlendShapeBinds
		if runtime_binds:
			for bind: RuntimeBlendShapeBind in runtime_binds.binds:
				var mesh_instance: MeshInstance3D = get_node_or_null(bind.mesh_path) as MeshInstance3D
				if mesh_instance != null:
					# Godot 4 MeshInstance3D blend shapes are manipulated between 0.0 and 1.0. 
					# The VRM weight factor provides scaling natively.
					mesh_instance.set_blend_shape_value(bind.shape_index, value * bind.weight)


## Utility method meant to be called by the GLTFDocumentExtension during the `_generate_scene_node` hook.
## Populates the `expression_binds` dictionary so it works seamlessly at runtime.
func compile_vrm0_binds(blend_shape_master: Vrm0BlendShape, gltf_state: GLTFState, root_node: Node) -> void:
	for group_ref in blend_shape_master.blend_shape_groups:
		var group := group_ref as Vrm0BlendShapeGroup
		var binds_for_group: Array[RuntimeBlendShapeBind] = []
		var expression_key: String = group.preset_name.to_lower()
		if expression_key == "" or expression_key == "unknown":
			expression_key = group.name.to_lower()
			
		for b_ref in group.binds:
			var b := b_ref as Vrm0BlendShapeBind
			var node_index: int = _find_node_with_mesh(gltf_state, b.mesh)
			
			if node_index != -1:
				var node_name: String = gltf_state.get_node_name(node_index)
				var mesh_instance_node: Node = root_node.find_child(node_name, true, false)
				if mesh_instance_node:
					var target_path: NodePath = get_path_to(mesh_instance_node)
					var weight: float = b.weight / 100.0 # VRM 0.0 weights are 0-100, normalize to 0-1
					var rb := RuntimeBlendShapeBind.new()
					rb.mesh_path = target_path
					rb.shape_index = b.index
					rb.weight = weight
					binds_for_group.append(rb)
					
		var runtime_binds := RuntimeBlendShapeBinds.new()
		runtime_binds.binds = binds_for_group
		expression_binds[expression_key] = runtime_binds


## Helper function to resolve which GLTF node contains a specific mesh index
func _find_node_with_mesh(gltf_state: GLTFState, mesh_index: int) -> int:
	var nodes: Array[GLTFNode] = gltf_state.get_nodes()
	for i: int in range(nodes.size()):
		var n: GLTFNode = nodes[i]
		if n.mesh == mesh_index:
			return i
	return -1
