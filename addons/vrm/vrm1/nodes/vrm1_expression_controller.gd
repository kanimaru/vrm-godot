@tool
extends Node3D
class_name Vrm1ExpressionController

const RuntimeExpression = preload("../../common/vrm_runtime_expression.gd")
const RuntimeMorphBind = preload("../../common/vrm_runtime_morph_bind.gd")
const RuntimeMaterialColorBind = preload("../../common/vrm_runtime_material_color_bind.gd")
const RuntimeTextureTransformBind = preload("../../common/vrm_runtime_texture_transform_bind.gd")
const RuntimeNodeMorphState = preload("../../common/vrm_runtime_node_morph_state.gd")
const RuntimeMaterialColorState = preload("../../common/vrm_runtime_material_color_state.gd")
const RuntimeMaterialUVState = preload("../../common/vrm_runtime_material_uv_state.gd")
const Vrm1ActiveExpression = preload("../../common/vrm_active_expression.gd")


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
## Compiled at import time and STORED with the scene: the binds need GLTFState to
## compile (glTF node index -> scene node), which an instantiated scene no longer
## has. Without storage every instantiated avatar came up with `expressions == []`.
## export_storage rather than export: serialized, but not a wall of sub-resources
## in the inspector.
@export_storage var _binds: Dictionary[String, RuntimeExpression] = {}
var _base_morphs: Dictionary[NodePath, RuntimeNodeMorphState] = {}
var _base_material_colors: Dictionary[Material, RuntimeMaterialColorState] = {}
var _base_material_uvs: Dictionary[Material, RuntimeMaterialUVState] = {}

var expressions: Array[String]:
	get():
		var typed: Array[String] = []
		typed.assign(_binds.keys())
		return typed

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


func set_expression(expr_name: String, value: float) -> void:
	var standard_prop = expr_name.to_snake_case()
	if standard_prop in ["happy", "angry", "sad", "relaxed", "surprised", "aa", "ih", "ou", "ee", "oh", "blink", "blink_left", "blink_right", "look_up", "look_down", "look_left", "look_right", "neutral"]:
		set(standard_prop, value)
	else:
		set_custom_expression(expr_name, value)


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
		var node_index: int = mb.node
		if node_index != -1 and node_index < gltf_state.get_nodes().size():
			var gnode := gltf_state.get_nodes()[node_index]
			var node_inst: Node = gltf_state.get_scene_node(node_index)
			if not node_inst:
				var node_name: String = gnode.original_name
				if node_name.is_empty():
					node_name = gnode.resource_name
				node_inst = root_node.find_child(node_name, true, false)
				if not node_inst:
					# Fallback for Godot's dot-to-underscore node name sanitization
					node_inst = root_node.find_child(node_name.replace(".", "_"), true, false)

			var is_mesh := node_inst is MeshInstance3D or (node_inst and node_inst.get_class() == "ImporterMeshInstance3D")
			if node_inst and is_mesh:
				# Manual relative path calculation because get_path_to() fails if not in tree
				var path_from_root: String = _get_path_from_root(node_inst, root_node)
				var path: NodePath = NodePath("../" + path_from_root)

				# Record base morph if not recorded
				var base_morph: RuntimeNodeMorphState = _base_morphs.get_or_add(path, RuntimeNodeMorphState.new())
				if not base_morph.blend_shapes.has(mb.index):
					if node_inst.has_method("get_blend_shape_value"):
						base_morph.blend_shapes[mb.index] = node_inst.get_blend_shape_value(mb.index)
					else:
						base_morph.blend_shapes[mb.index] = 0.0

				var rb = RuntimeMorphBind.new()
				rb.path = path
				rb.index = mb.index
				rb.weight = mb.weight
				run_expr.morph_binds.append(rb)

	# Material color binds
	# gltf_state.materials holds the pre-MToon-swap glTF-imported materials, never updated
	# by VrmSceneComposer.apply_mtoon_materials - so the bind's actual material must be
	# re-resolved by name against the live scene tree, or it ends up mutating an orphaned
	# material that isn't part of what's rendered.
	for cb: Vrm1ExpressionMaterialColorBind in expr.material_color_binds:
		var materials: Array = gltf_state.materials
		if cb.material >= 0 and cb.material < materials.size():
			var gltf_mat: Material = materials[cb.material]
			var mat: Material = VrmSceneComposer.find_material_by_name(root_node, gltf_mat.resource_name) if gltf_mat != null else null
			if mat != null:
				var prop_info: Dictionary = _resolve_material_prop_name(cb.type)
				var prop_name: String = _material_prop_for(prop_info, mat)
				var t_val: PackedFloat32Array = cb.target_value
				if not prop_name.is_empty() and t_val.size() == 4:
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
			var gltf_mat: Material = materials[tb.material]
			var mat: Material = VrmSceneComposer.find_material_by_name(root_node, gltf_mat.resource_name) if gltf_mat != null else null
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


func _get_path_from_root(node: Node, root: Node) -> String:
	var path_segments: Array[String] = []
	var curr: Node = node
	while curr != null and curr != root:
		path_segments.push_front(curr.name)
		curr = curr.get_parent()
	return "/".join(path_segments)


## Resolves a VRM1 material color bind's type to both the BaseMaterial3D-native property
## (used when a material fell back to a plain glTF PBR material with no MToon extension) and
## the real MToon shader uniform name (used for the ShaderMaterial VrmMtoonBuilder normally
## produces). shade/rim/matcap/outline have no BaseMaterial3D equivalent, so std_property is
## left empty for those - _material_prop_for() treats that as "unsupported for this material".
func _resolve_material_prop_name(vrm_color_type: String) -> Dictionary:
	match vrm_color_type:
		"color": return {"std_property": "albedo_color", "shader_property": "_Color"}
		"emissionColor": return {"std_property": "emission", "shader_property": "_EmissionColor"}
		"shadeColor": return {"std_property": "", "shader_property": "_ShadeColor"}
		"matcapColor": return {"std_property": "", "shader_property": "_MatcapColor"}
		"rimColor": return {"std_property": "", "shader_property": "_RimColor"}
		"outlineColor": return {"std_property": "", "shader_property": "_OutlineColor"}
	return {"std_property": "albedo_color", "shader_property": "_Color"}


## Picks the correct single property name for prop_info against mat's concrete type.
## Returns "" if mat's type has no equivalent for this VRM property.
func _material_prop_for(prop_info: Dictionary, mat: Material) -> String:
	if mat is ShaderMaterial:
		return prop_info.get("shader_property", "")
	if mat is BaseMaterial3D:
		return prop_info.get("std_property", "")
	return ""


func _get_material_color(mat: Material, prop_name: String) -> Color:
	if mat is BaseMaterial3D:
		if prop_name in mat:
			return mat.get(prop_name)
	elif mat is ShaderMaterial:
		var param = mat.get_shader_parameter(prop_name)
		if typeof(param) == TYPE_COLOR:
			return param

	return Color.WHITE


## The MToon shader packs UV scale+offset into one _MainTex_ST vec4 uniform, unlike
## BaseMaterial3D's separate uv1_scale/uv1_offset Vector3 properties.
func _get_material_uv_scale(mat: Material) -> Vector2:
	if mat is BaseMaterial3D:
		return Vector2(mat.uv1_scale.x, mat.uv1_scale.y)
	elif mat is ShaderMaterial:
		var param = mat.get_shader_parameter("_MainTex_ST")
		if typeof(param) == TYPE_VECTOR4:
			return Vector2(param.x, param.y)
	return Vector2.ONE


func _get_material_uv_offset(mat: Material) -> Vector2:
	if mat is StandardMaterial3D or mat is BaseMaterial3D:
		return Vector2(mat.uv1_offset.x, mat.uv1_offset.y)
	elif mat is ShaderMaterial:
		var param = mat.get_shader_parameter("_MainTex_ST")
		if typeof(param) == TYPE_VECTOR4:
			return Vector2(param.z, param.w)
	return Vector2.ZERO


func _process(_delta: float) -> void:
	if not _is_dirty:
		return
	_is_dirty = false
	_apply_expressions()


## Rebuilds the base-state snapshots from the LIVE meshes/materials when they
## are missing. The base dictionaries hold plain RefCounted values that do NOT
## survive scene serialization, while the compiled _binds sometimes do — a
## res://-instanced avatar then arrives split-brained: binds present, base
## EMPTY. Because the morph WRITE loop below iterates _base_morphs, an empty
## base meant expressions were computed and then silently discarded — VMD and
## VRMA face animation "completely missing" on VRM1 avatars. Values read before
## the first expression write ARE the base; idempotent, runs on every apply
## since no flag can be trusted across the same serialization boundary.
func _ensure_base_state() -> void:
	for expr_key: String in _binds:
		var expression: RuntimeExpression = _binds[expr_key]

		for morph_bind: RuntimeMorphBind in expression.morph_binds:
			var node: Node = get_node_or_null(morph_bind.path)
			if node == null or not node.has_method("get_blend_shape_value"):
				continue
			var morph_state: RuntimeNodeMorphState = _base_morphs.get_or_add(
				morph_bind.path, RuntimeNodeMorphState.new())
			if not morph_state.blend_shapes.has(morph_bind.index):
				morph_state.blend_shapes[morph_bind.index] = node.get_blend_shape_value(morph_bind.index)

		for color_bind: RuntimeMaterialColorBind in expression.color_binds:
			if color_bind.material == null:
				continue
			var color_state: RuntimeMaterialColorState = _base_material_colors.get_or_add(
				color_bind.material, RuntimeMaterialColorState.new())
			if not color_state.properties.has(color_bind.prop):
				color_state.properties[color_bind.prop] = _get_material_color(
					color_bind.material, color_bind.prop)

		for uv_bind: RuntimeTextureTransformBind in expression.uv_binds:
			if uv_bind.material == null:
				continue
			if not _base_material_uvs.has(uv_bind.material):
				var base_uv := RuntimeMaterialUVState.new()
				base_uv.scale = _get_material_uv_scale(uv_bind.material)
				base_uv.offset = _get_material_uv_offset(uv_bind.material)
				_base_material_uvs[uv_bind.material] = base_uv


func _apply_expressions() -> void:
	_ensure_base_state()

	var accumulated_morphs: Dictionary[NodePath, RefCounted] = {}
	var accumulated_colors: Dictionary[Material, RefCounted] = {}
	var accumulated_uv_scales: Dictionary[Material, Vector2] = {}
	var accumulated_uv_offsets: Dictionary[Material, Vector2] = {}

	# Determine block/blend state per procedural category from all active overriding
	# expressions. Per expressions.md's "Procedural override" section: `block` forces the
	# target category's weight to 0 outright; `blend` instead accumulates an attenuation
	# factor (1 - saturate(sum of overriding weights)) that scales the target's own weight.
	var blocked_blink: bool = false
	var blocked_look_at: bool = false
	var blocked_mouth: bool = false
	var blend_sum_blink: float = 0.0
	var blend_sum_look_at: float = 0.0
	var blend_sum_mouth: float = 0.0

	# We collect active expressions and process overrides beforehand
	var active_expressions: Array[Vrm1ActiveExpression] = []
	for expr_name: String in _binds.keys():
		var w: float = get_expression(expr_name)
		if w > 0.0:
			var data: RuntimeExpression = _binds[expr_name]
			if data.is_binary:
				w = 1.0 if w > 0.5 else 0.0

			if w > 0.0:
				var active_expr: Vrm1ActiveExpression = Vrm1ActiveExpression.new()
				active_expr.name = expr_name
				active_expr.weight = w
				active_expr.data = data
				active_expressions.append(active_expr)

				if data.override_blink == "block": blocked_blink = true
				elif data.override_blink == "blend": blend_sum_blink += w
				if data.override_look_at == "block": blocked_look_at = true
				elif data.override_look_at == "blend": blend_sum_look_at += w
				if data.override_mouth == "block": blocked_mouth = true
				elif data.override_mouth == "blend": blend_sum_mouth += w

	var blend_factor_blink: float = 1.0 - clampf(blend_sum_blink, 0.0, 1.0)
	var blend_factor_look_at: float = 1.0 - clampf(blend_sum_look_at, 0.0, 1.0)
	var blend_factor_mouth: float = 1.0 - clampf(blend_sum_mouth, 0.0, 1.0)

	const BLINK_NAMES: Array[String] = ["blink", "blinkLeft", "blinkRight", "blink_left", "blink_right"]
	const LOOK_AT_NAMES: Array[String] = ["lookUp", "lookDown", "lookLeft", "lookRight", "look_up", "look_down", "look_left", "look_right"]
	const MOUTH_NAMES: Array[String] = ["aa", "ih", "ou", "ee", "oh"]

	for active_expr: Vrm1ActiveExpression in active_expressions:
		var w: float = active_expr.weight
		var expr_name: String = active_expr.name
		var data: RuntimeExpression = active_expr.data

		# Skip if blocked (rough mapping of categories based on preset names)
		if blocked_blink and (expr_name in BLINK_NAMES):
			continue
		if blocked_look_at and (expr_name in LOOK_AT_NAMES):
			continue
		if blocked_mouth and (expr_name in MOUTH_NAMES):
			continue

		# Attenuate procedural targets under an active "blend" override. Per the spec's
		# isBinary interaction rules, a binary target must snap fully to 0 the instant it
		# receives ANY attenuation - fractional output is not permitted for isBinary
		# expressions, only their block/pass-through extremes.
		if expr_name in BLINK_NAMES and blend_factor_blink < 1.0:
			w = 0.0 if data.is_binary else w * blend_factor_blink
		elif expr_name in LOOK_AT_NAMES and blend_factor_look_at < 1.0:
			w = 0.0 if data.is_binary else w * blend_factor_look_at
		elif expr_name in MOUTH_NAMES and blend_factor_mouth < 1.0:
			w = 0.0 if data.is_binary else w * blend_factor_mouth

		if w <= 0.0:
			continue

		for bind: RuntimeMorphBind in data.morph_binds:
			var path: NodePath = bind.path
			var idx: int = bind.index
			var morph_state: RuntimeNodeMorphState = accumulated_morphs.get_or_add(path, RuntimeNodeMorphState.new())
			var cur: float = morph_state.blend_shapes.get(idx, 0.0)
			morph_state.blend_shapes[idx] = cur + (bind.weight * w)

		for bind: RuntimeMaterialColorBind in data.color_binds:
			var mat: Material = bind.material
			var prop: String = bind.prop
			var target_color: Color = bind.color
			var base_color: Color = (_base_material_colors[mat] as RuntimeMaterialColorState).properties[prop]
			var accum_color_state: RuntimeMaterialColorState = accumulated_colors.get_or_add(mat, RuntimeMaterialColorState.new())
			var cur_color: Color = accum_color_state.properties.get(prop, base_color)
			# Mix based on delta
			var delta: Color = target_color - base_color
			cur_color += delta * w
			accum_color_state.properties[prop] = cur_color

		for bind: RuntimeTextureTransformBind in data.uv_binds:
			var mat: Material = bind.material
			var target_s: Vector2 = bind.scale
			var target_o: Vector2 = bind.offset
			var base_uv_state: RuntimeMaterialUVState = _base_material_uvs[mat]
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
		var node: Node = get_node_or_null(path)
		if node and node.has_method("set_blend_shape_value"):
			var base_morph_state: RuntimeNodeMorphState = _base_morphs[path]
			for idx: int in base_morph_state.blend_shapes.keys():
				var base_val: float = base_morph_state.blend_shapes[idx]
				var accumulated: float = 0.0
				if accumulated_morphs.has(path):
					var accum_morph_state: RuntimeNodeMorphState = accumulated_morphs[path]
					if accum_morph_state.blend_shapes.has(idx):
						accumulated = accum_morph_state.blend_shapes[idx]

				var final_value: float = clampf(base_val + accumulated, 0.0, 1.0)
				node.set_blend_shape_value(idx, final_value)
		else:
			printerr("[Vrm1ExpressionController] Failed to resolve node at path: ", path)

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
		var base_uv_state: RuntimeMaterialUVState = _base_material_uvs[mat]
		var base_s: Vector2 = base_uv_state.scale
		var base_o: Vector2 = base_uv_state.offset

		if accumulated_uv_scales.has(mat):
			base_s = accumulated_uv_scales[mat]
			base_o = accumulated_uv_offsets[mat]

		if mat is StandardMaterial3D or mat is BaseMaterial3D:
			mat.uv1_scale = Vector3(base_s.x, base_s.y, 1.0)
			mat.uv1_offset = Vector3(base_o.x, base_o.y, 0.0)
		elif mat is ShaderMaterial:
			mat.set_shader_parameter("_MainTex_ST", Vector4(base_s.x, base_s.y, base_o.x, base_o.y))
