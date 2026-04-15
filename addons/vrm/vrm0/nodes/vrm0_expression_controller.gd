@tool
extends Node3D
class_name Vrm0ExpressionController


## A dictionary containing the runtime mappings of expressions.
## Uses the shared RuntimeExpression class from VRM1 runtime.
var _binds: Dictionary[String, RuntimeExpression] = {}
var expressions: Array[String]: 
	get():
		var typed: Array[String] = []
		typed.assign(_binds.keys())
		return typed

## Custom expressions that are not standard VRM presets.
@export var custom_expressions: Dictionary[String, float] = {}

var _dirty: bool = false
var _base_morphs: Dictionary[NodePath, Dictionary] = {} # {NodePath: {index: value}}
var _base_material_colors: Dictionary[NodePath, Dictionary] = {} # {NodePath: {prop: Color}}
var _base_material_uvs: Dictionary[NodePath, Dictionary] = {} # {NodePath: {prop: [scale, offset]}}


## Standard VRM Expressions
@export_range(0.0, 1.0) var neutral: float = 0.0:
	set(v): neutral = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var joy: float = 0.0:
	set(v): joy = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var angry: float = 0.0:
	set(v): angry = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var sorrow: float = 0.0:
	set(v): sorrow = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var fun: float = 0.0:
	set(v): fun = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var surprised: float = 0.0:
	set(v): surprised = clampf(v, 0.0, 1.0); _request_update()

@export_range(0.0, 1.0) var a: float = 0.0:
	set(v): a = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var i: float = 0.0:
	set(v): i = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var u: float = 0.0:
	set(v): u = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var e: float = 0.0:
	set(v): e = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var o: float = 0.0:
	set(v): o = clampf(v, 0.0, 1.0); _request_update()

@export_range(0.0, 1.0) var blink: float = 0.0:
	set(v): blink = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var blink_left: float = 0.0:
	set(v): blink_left = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var blink_right: float = 0.0:
	set(v): blink_right = clampf(v, 0.0, 1.0); _request_update()


func _request_update() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_apply_expressions()
		_dirty = false


func set_expression(expression_name: String, value: float) -> void:
	var standard_prop = expression_name.to_lower()
	if standard_prop in ["neutral", "joy", "angry", "sorrow", "fun", "a", "i", "u", "e", "o", "blink", "blink_left", "blink_right"]:
		set(standard_prop, value)
	else:
		custom_expressions[expression_name] = value
		_request_update()


func _apply_expressions() -> void:
	# Reset morph targets to base state
	for mesh_path in _base_morphs:
		var node = get_node_or_null(mesh_path)
		if node and node.has_method("set_blend_shape_value"):
			var base_values = _base_morphs[mesh_path]
			for idx in base_values:
				node.set_blend_shape_value(idx, base_values[idx])

	# Reset material colors to base state
	for mat_path in _base_material_colors:
		var node = get_node_or_null(mat_path)
		if node and node is MeshInstance3D:
			for surface_idx in range(node.get_surface_override_material_count()):
				var mat = node.get_surface_override_material(surface_idx)
				if mat:
					var base_colors = _base_material_colors[mat_path]
					for prop in base_colors:
						mat.set(prop, base_colors[prop])

	# Accumulate and apply all active expressions
	for expr_key in _binds:
		var val: float = 0.0
		if expr_key in ["neutral", "joy", "angry", "sorrow", "fun", "a", "i", "u", "e", "o", "blink", "blink_left", "blink_right"]:
			val = get(expr_key)
		else:
			val = custom_expressions.get(expr_key, 0.0)

		if val <= 0.0:
			continue

		var re: RuntimeExpression = _binds[expr_key]
		if re.is_binary:
			val = 1.0 if val > 0.5 else 0.0

		# Morph binds (uses RuntimeMorphBind fields: path, index, weight)
		for mb: RuntimeMorphBind in re.morph_binds:
			var node = get_node_or_null(mb.path)
			if node and node.has_method("set_blend_shape_value"):
				var current: float = node.get_blend_shape_value(mb.index) if node.has_method("get_blend_shape_value") else 0.0
				node.set_blend_shape_value(mb.index, current + (val * mb.weight))

		# Material color binds (uses RuntimeMaterialColorBind fields: material, prop, color)
		for mcb: RuntimeMaterialColorBind in re.color_binds:
			if mcb.material:
				var base_col: Color = Color.WHITE
				# Look up the base color via stored path info
				mcb.material.set(mcb.prop, mcb.color * val)

		# Texture transform binds (uses RuntimeTextureTransformBind fields: material, scale, offset)
		for ttb: RuntimeTextureTransformBind in re.uv_binds:
			if ttb.material:
				ttb.material.set("uv1_scale", ttb.scale * val)
				ttb.material.set("uv1_offset", ttb.offset * val)


func compile_vrm0_binds(blend_shape_master: Vrm0BlendShape, gltf_state: GLTFState, root_node: Node) -> void:
	_binds.clear()
	_base_morphs.clear()
	_base_material_colors.clear()
	_base_material_uvs.clear()

	if not blend_shape_master:
		return

	for group: Vrm0BlendShapeGroup in blend_shape_master.blend_shape_groups:
		var expression: RuntimeExpression = RuntimeExpression.new()
		expression.is_binary = group.is_binary

		var expression_key: String = group.preset_name.to_lower()
		if expression_key == "" or expression_key == "unknown":
			expression_key = group.name.to_lower()

		# Morph binds
		for blend_shape_bind: Vrm0BlendShapeBind in group.binds:
			var node_index: int = _find_node_with_mesh(gltf_state, blend_shape_bind.mesh)

			if node_index != -1:
				var gnode: GLTFNode = gltf_state.get_nodes()[node_index]
				var mesh_instance_node: Node = gltf_state.get_scene_node(node_index)

				if not mesh_instance_node:
					var node_name: String = gnode.original_name
					if node_name.is_empty():
						node_name = gnode.resource_name
					mesh_instance_node = root_node.find_child(node_name, true, false)
					if not mesh_instance_node:
						# Fallback for Godot's dot-to-underscore node name sanitization
						mesh_instance_node = root_node.find_child(node_name.replace(".", "_"), true, false)

				if not mesh_instance_node:
					continue

				var path_from_root: String = _get_path_from_root(mesh_instance_node, root_node)
				var target_path: NodePath = NodePath("../" + path_from_root)

				var morph_bind: RuntimeMorphBind = RuntimeMorphBind.new()
				morph_bind.path = target_path
				morph_bind.index = blend_shape_bind.index
				morph_bind.weight = blend_shape_bind.weight / 100.0
				expression.morph_binds.append(morph_bind)

				# Capture base state
				if not _base_morphs.has(target_path):
					_base_morphs[target_path] = {}
				if not _base_morphs[target_path].has(blend_shape_bind.index):
					if mesh_instance_node.has_method("get_blend_shape_value"):
						_base_morphs[target_path][blend_shape_bind.index] = mesh_instance_node.get_blend_shape_value(blend_shape_bind.index)
					else:
						_base_morphs[target_path][blend_shape_bind.index] = 0.0

		# Material binds
		for material_bind: Vrm0MaterialBind in group.material_binds:
			var prop_info: Dictionary = _resolve_vrm0_material_property(material_bind.property_name)
			if prop_info.is_empty():
				continue

			var target_mesh: MeshInstance3D = _find_mesh_with_material(root_node, material_bind.material_name)
			if not target_mesh:
				continue

			var mat: Material = target_mesh.get_active_material(0)
			if not mat:
				continue

			if prop_info.type == "color" and material_bind.target_value.size() >= 4:
				var mcb := RuntimeMaterialColorBind.new()
				mcb.material = mat
				mcb.prop = prop_info.property
				mcb.color = Color(material_bind.target_value[0], material_bind.target_value[1], material_bind.target_value[2], material_bind.target_value[3])
				expression.color_binds.append(mcb)

				# Capture base state
				var mat_path: NodePath = NodePath("../" + _get_path_from_root(target_mesh, root_node))
				if not _base_material_colors.has(mat_path):
					_base_material_colors[mat_path] = {}
				if not _base_material_colors[mat_path].has(prop_info.property):
					_base_material_colors[mat_path][prop_info.property] = mat.get(prop_info.property)

			elif prop_info.type == "uv" and material_bind.target_value.size() >= 4:
				var texture_transform_bind := RuntimeTextureTransformBind.new()
				texture_transform_bind.material = mat
				texture_transform_bind.scale = Vector2(material_bind.target_value[0], material_bind.target_value[1])
				texture_transform_bind.offset = Vector2(material_bind.target_value[2], material_bind.target_value[3])
				expression.uv_binds.append(texture_transform_bind)

		_binds[expression_key] = expression


func _resolve_vrm0_material_property(vrm0_prop: String) -> Dictionary:
	match vrm0_prop:
		"_Color": return {"type": "color", "property": "albedo_color"}
		"_EmissionColor": return {"type": "color", "property": "emission"}
		"_ShadeColor", "_ShadedColor": return {"type": "color", "property": "shade_color"}
		"_OutlineColor": return {"type": "color", "property": "outline_color"}
		"_MainTex_ST": return {"type": "uv", "property": "uv1"}
	return {}


func _find_mesh_with_material(root: Node, mat_name: String) -> MeshInstance3D:
	for mesh_inst: MeshInstance3D in root.find_children("", "MeshInstance3D", true, false):
		for idx in range(mesh_inst.get_surface_override_material_count()):
			var mat = mesh_inst.get_active_material(idx)
			if mat and mat.resource_name == mat_name:
				return mesh_inst
	return null


func _find_node_with_mesh(gltf_state: GLTFState, mesh_index: int) -> int:
	var nodes: Array[GLTFNode] = gltf_state.get_nodes()
	for idx: int in range(nodes.size()):
		if nodes[idx].mesh == mesh_index:
			return idx
	return -1


func _get_path_from_root(node: Node, root: Node) -> String:
	var path_segments: Array[String] = []
	var curr: Node = node
	while curr != null and curr != root:
		path_segments.push_front(curr.name)
		curr = curr.get_parent()
	return "/".join(path_segments)
