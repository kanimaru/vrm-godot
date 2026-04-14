@tool
extends Node3D
class_name Vrm1ExpressionController

@export_range(0.0, 1.0) var happy: float = 0.0:
	set(v):
		happy = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var angry: float = 0.0:
	set(v):
		angry = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var sad: float = 0.0:
	set(v):
		sad = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var relaxed: float = 0.0:
	set(v):
		relaxed = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var surprised: float = 0.0:
	set(v):
		surprised = clampf(v, 0.0, 1.0)
		_request_update()

@export_range(0.0, 1.0) var aa: float = 0.0:
	set(v):
		aa = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var ih: float = 0.0:
	set(v):
		ih = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var ou: float = 0.0:
	set(v):
		ou = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var ee: float = 0.0:
	set(v):
		ee = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var oh: float = 0.0:
	set(v):
		oh = clampf(v, 0.0, 1.0)
		_request_update()

@export_range(0.0, 1.0) var blink: float = 0.0:
	set(v):
		blink = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var blink_left: float = 0.0:
	set(v):
		blink_left = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var blink_right: float = 0.0:
	set(v):
		blink_right = clampf(v, 0.0, 1.0)
		_request_update()

@export_range(0.0, 1.0) var look_up: float = 0.0:
	set(v):
		look_up = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var look_down: float = 0.0:
	set(v):
		look_down = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var look_left: float = 0.0:
	set(v):
		look_left = clampf(v, 0.0, 1.0)
		_request_update()
@export_range(0.0, 1.0) var look_right: float = 0.0:
	set(v):
		look_right = clampf(v, 0.0, 1.0)
		_request_update()

@export_range(0.0, 1.0) var neutral: float = 0.0:
	set(v):
		neutral = clampf(v, 0.0, 1.0)
		_request_update()

var custom_expressions: Dictionary[String, float] = {}
var _is_dirty: bool = false
var _binds: Dictionary[String, RuntimeExpression] = {}
var _base_morphs: Dictionary[NodePath, RuntimeNodeMorphState] = {}
var _base_material_colors: Dictionary[Material, RuntimeMaterialColorState] = {}
var _base_material_uvs: Dictionary[Material, RuntimeMaterialUVState] = {}

func _request_update() -> void:
	_is_dirty = true

func set_custom_expression(expr_name: String, value: float) -> void:
	custom_expressions[expr_name] = clampf(value, 0.0, 1.0)
	_request_update()

func get_expression(expr_name: String) -> float:
	var standard_prop = expr_name.to_snake_case()
	if standard_prop in ["happy", "angry", "sad", "relaxed", "surprised", "aa", "ih", "ou", "ee", "oh", "blink", "blink_left", "blink_right", "look_up", "look_down", "look_left", "look_right", "neutral"]:
		return get(standard_prop)
	return custom_expressions.get(expr_name, 0.0)

func compile_vrm1_binds(expressions_ref: Vrm1Expressions, gltf_state: GLTFState, root_node: Node) -> void:
	_binds.clear()
	_base_morphs.clear()
	_base_material_colors.clear()
	_base_material_uvs.clear()
	
	if expressions_ref == null:
		return
		
	# Gather presets
	for preset_name: String in expressions_ref.preset:
		var expr: Vrm1ExpressionData = expressions_ref.preset[preset_name]
		_register_expression(preset_name, expr, gltf_state, root_node)
		
	# Gather custom
	for custom_name: String in expressions_ref.custom:
		var expr: Vrm1ExpressionData = expressions_ref.custom[custom_name]
		_register_expression(custom_name, expr, gltf_state, root_node)

func _register_expression(expr_name: String, expr: Vrm1ExpressionData, gltf_state: GLTFState, root_node: Node) -> void:
	var run_expr = RuntimeExpression.new()
	run_expr.is_binary = expr.is_binary
	run_expr.override_blink = expr.override_blink
	run_expr.override_look_at = expr.override_look_at
	run_expr.override_mouth = expr.override_mouth
	
	# Morph binds
	for mb: Vrm1ExpressionMorphBind in expr.morph_binds:
		var node_index: int = _find_node_with_mesh(gltf_state, mb.node)
		if node_index != -1:
			var node_name: String = gltf_state.get_node_name(node_index)
			var node_inst: Node = root_node.find_child(node_name, true, false)
			if node_inst and node_inst is MeshInstance3D:
				var path: NodePath = get_path_to(node_inst)
				
				# Record base morph if not recorded
				if not _base_morphs.has(path):
					_base_morphs[path] = RuntimeNodeMorphState.new()
				var base_morph := _base_morphs[path] as RuntimeNodeMorphState
				if not base_morph.blend_shapes.has(mb.index):
					base_morph.blend_shapes[mb.index] = node_inst.get_blend_shape_value(mb.index)
				
				var rb = RuntimeMorphBind.new()
				rb.path = path
				rb.index = mb.index
				rb.weight = mb.weight
				run_expr.morph_binds.append(rb)
				
	# Material color binds
	for cb: Vrm1ExpressionMaterialColorBind in expr.material_color_binds:
		var materials: Array = gltf_state.materials
		if cb.material >= 0 and cb.material < materials.size():
			var mat: Material = materials[cb.material]
			if mat != null:
				var prop_name: String = _resolve_material_prop_name(cb.type)
				var t_val: PackedFloat32Array = cb.target_value
				if t_val.size() == 4:
					var target_color: Color = Color(t_val[0], t_val[1], t_val[2], t_val[3])
					
					# Record base color
					if not _base_material_colors.has(mat):
						_base_material_colors[mat] = RuntimeMaterialColorState.new()
					var base_color_state := _base_material_colors[mat] as RuntimeMaterialColorState
					if not base_color_state.properties.has(prop_name):
						base_color_state.properties[prop_name] = _get_material_color(mat, prop_name)
						
					var rb = RuntimeMaterialColorBind.new()
					rb.material = mat
					rb.prop = prop_name
					rb.color = target_color
					run_expr.color_binds.append(rb)
					
	# Texture transform binds
	for tb: Vrm1ExpressionTextureTransformBind in expr.texture_transform_binds:
		var materials: Array = gltf_state.materials
		if tb.material >= 0 and tb.material < materials.size():
			var mat: Material = materials[tb.material]
			if mat != null:
				# Record base UV
				if not _base_material_uvs.has(mat):
					var base_uv := RuntimeMaterialUVState.new()
					base_uv.scale = _get_material_uv_scale(mat)
					base_uv.offset = _get_material_uv_offset(mat)
					_base_material_uvs[mat] = base_uv
					
				var rb = RuntimeTextureTransformBind.new()
				rb.material = mat
				rb.scale = tb.scale
				rb.offset = tb.offset
				run_expr.uv_binds.append(rb)

	_binds[expr_name] = run_expr

func _find_node_with_mesh(gltf_state: GLTFState, mesh_index: int) -> int:
	var nodes: Array[GLTFNode] = gltf_state.get_nodes()
	for i: int in range(nodes.size()):
		var n: GLTFNode = nodes[i]
		if n.mesh == mesh_index:
			return i
	return -1
	
func _resolve_material_prop_name(vrm_color_type: String) -> String:
	# Generic map which works for standard BaseMaterial and Godot VRM MToon logic
	match vrm_color_type:
		"color": return "albedo_color"
		"emissionColor": return "emission"
		"shadeColor": return "shade_color"
		"matcapColor": return "matcap_color"
		"rimColor": return "rim_color"
		"outlineColor": return "outline_color"
	return "albedo_color"

func _get_material_color(mat: Material, prop_name: String) -> Color:
	if mat is StandardMaterial3D or mat is BaseMaterial3D:
		if prop_name in mat:
			return mat.get(prop_name)
	elif mat is ShaderMaterial:
		var param = mat.get_shader_parameter(prop_name)
		if typeof(param) == TYPE_COLOR:
			return param
			
	return Color.WHITE

func _get_material_uv_scale(mat: Material) -> Vector2:
	if mat is StandardMaterial3D or mat is BaseMaterial3D:
		return mat.uv1_scale.xy
	elif mat is ShaderMaterial:
		var param = mat.get_shader_parameter("uv1_scale")
		if typeof(param) == TYPE_VECTOR3 or typeof(param) == TYPE_VECTOR2:
			return Vector2(param.x, param.y)
	return Vector2.ONE
	
func _get_material_uv_offset(mat: Material) -> Vector2:
	if mat is StandardMaterial3D or mat is BaseMaterial3D:
		return mat.uv1_offset.xy
	elif mat is ShaderMaterial:
		var param = mat.get_shader_parameter("uv1_offset")
		if typeof(param) == TYPE_VECTOR3 or typeof(param) == TYPE_VECTOR2:
			return Vector2(param.x, param.y)
	return Vector2.ZERO


func _process(_delta: float) -> void:
	if not _is_dirty:
		return
	_is_dirty = false
	_apply_expressions()

func _apply_expressions() -> void:
	var accumulated_morphs: Dictionary[NodePath, RefCounted] = {}
	var accumulated_colors: Dictionary[Material, RefCounted] = {}
	var accumulated_uv_scales: Dictionary[Material, Vector2] = {}
	var accumulated_uv_offsets: Dictionary[Material, Vector2] = {}
	
	# Determine blocked categories via overrides
	var blocked_blink: bool = false
	var blocked_look_at: bool = false
	var blocked_mouth: bool = false
	
	# We collect active expressions and process overrides beforehand
	var active_expressions: Array[RefCounted] = []
	for expr_name: String in _binds.keys():
		var w: float = get_expression(expr_name)
		if w > 0.0:
			var data := _binds[expr_name] as RuntimeExpression
			if data.is_binary:
				w = 1.0 if w > 0.5 else 0.0
				
			if w > 0.0:
				var active_expr := Vrm1ActiveExpression.new()
				active_expr.name = expr_name
				active_expr.weight = w
				active_expr.data = data
				active_expressions.append(active_expr)
				# Process block overrides natively
				if data.override_blink == "block": blocked_blink = true
				if data.override_look_at == "block": blocked_look_at = true
				if data.override_mouth == "block": blocked_mouth = true

	for active_expr: Vrm1ActiveExpression in active_expressions:
		var w: float = active_expr.weight
		var expr_name: String = active_expr.name
		var data: RuntimeExpression = active_expr.data
		
		# Skip if blocked (rough mapping of categories based on preset names)
		if blocked_blink and (expr_name in ["blink", "blinkLeft", "blinkRight", "blink_left", "blink_right"]):
			continue
		if blocked_look_at and (expr_name in ["lookUp", "lookDown", "lookLeft", "lookRight", "look_up", "look_down", "look_left", "look_right"]):
			continue
		if blocked_mouth and (expr_name in ["aa", "ih", "ou", "ee", "oh"]):
			continue
			
		for bind: RuntimeMorphBind in data.morph_binds:
			var path: NodePath = bind.path
			var idx: int = bind.index
			if not accumulated_morphs.has(path):
				accumulated_morphs[path] = RuntimeNodeMorphState.new()
			var cur: float = accumulated_morphs[path].blend_shapes.get(idx, 0.0)
			accumulated_morphs[path].blend_shapes[idx] = cur + (bind.weight * w)
			
		for bind: RuntimeMaterialColorBind in data.color_binds:
			var mat: Material = bind.material
			var prop: String = bind.prop
			var target_color: Color = bind.color
			var base_color: Color = (_base_material_colors[mat] as RuntimeMaterialColorState).properties[prop]
			
			if not accumulated_colors.has(mat):
				accumulated_colors[mat] = RuntimeMaterialColorState.new()
			var accum_color_state := accumulated_colors[mat] as RuntimeMaterialColorState
			var cur_color: Color = accum_color_state.properties.get(prop, base_color)
			# Mix based on delta
			var delta: Color = target_color - base_color
			cur_color += delta * w
			accum_color_state.properties[prop] = cur_color
			
		for bind: RuntimeTextureTransformBind in data.uv_binds:
			var mat: Material = bind.material
			var target_s: Vector2 = bind.scale
			var target_o: Vector2 = bind.offset
			var base_uv_state := _base_material_uvs[mat] as RuntimeMaterialUVState
			var base_s: Vector2 = base_uv_state.scale
			var base_o: Vector2 = base_uv_state.offset
			
			if not accumulated_uv_scales.has(mat): 
				accumulated_uv_scales[mat] = base_s
				accumulated_uv_offsets[mat] = base_o
				
			var cur_s: Vector2 = accumulated_uv_scales[mat]
			var cur_o: Vector2 = accumulated_uv_offsets[mat]
			
			var ds = target_s - base_s
			var do = target_o - base_o
			
			accumulated_uv_scales[mat] = cur_s + (ds * w)
			accumulated_uv_offsets[mat] = cur_o + (do * w)

	# Apply Morphs
	for path: NodePath in _base_morphs.keys():
		var node: Node = get_node(path)
		if node is MeshInstance3D:
			var base_morph_state := _base_morphs[path] as RuntimeNodeMorphState
			for idx: int in base_morph_state.blend_shapes.keys():
				var base_val: float = base_morph_state.blend_shapes[idx]
				var accumulated: float = 0.0
				if accumulated_morphs.has(path):
					var accum_morph_state := accumulated_morphs[path] as RuntimeNodeMorphState
					if accum_morph_state.blend_shapes.has(idx):
						accumulated = accum_morph_state.blend_shapes[idx]
				
				# VRM 1.0 weights are clamped up to exactly 1.0 logic natively,
				node.set_blend_shape_value(idx, clampf(base_val + accumulated, 0.0, 1.0))
				
	# Apply Material Colors
	for mat in _base_material_colors.keys():
		var base_state := _base_material_colors[mat] as RuntimeMaterialColorState
		for prop: String in base_state.properties.keys():
			var base_c: Color = base_state.properties[prop]
			var t_color: Color = base_c
			if accumulated_colors.has(mat):
				var accum_color_state := accumulated_colors[mat] as RuntimeMaterialColorState
				if accum_color_state.properties.has(prop):
					t_color = accum_color_state.properties[prop]
				
			# Clamped output
			t_color.r = clampf(t_color.r, 0.0, 1.0)
			t_color.g = clampf(t_color.g, 0.0, 1.0)
			t_color.b = clampf(t_color.b, 0.0, 1.0)
			t_color.a = clampf(t_color.a, 0.0, 1.0)
			
			if mat is StandardMaterial3D or mat is BaseMaterial3D:
				mat.set(prop, t_color)
			elif mat is ShaderMaterial:
				mat.set_shader_parameter(prop, t_color)

	# Apply Material UVs
	for mat in _base_material_uvs.keys():
		var base_uv_state := _base_material_uvs[mat] as RuntimeMaterialUVState
		var base_s: Vector2 = base_uv_state.scale
		var base_o: Vector2 = base_uv_state.offset
		var s: Vector2 = base_s
		var o: Vector2 = base_o
		
		if accumulated_uv_scales.has(mat):
			s = accumulated_uv_scales[mat]
			o = accumulated_uv_offsets[mat]
			
		if mat is StandardMaterial3D or mat is BaseMaterial3D:
			mat.uv1_scale = Vector3(s.x, s.y, 1.0)
			mat.uv1_offset = Vector3(o.x, o.y, 0.0)
		elif mat is ShaderMaterial:
			mat.set_shader_parameter("uv1_scale", Vector3(s.x, s.y, 1.0))
			mat.set_shader_parameter("uv1_offset", Vector3(o.x, o.y, 0.0))
