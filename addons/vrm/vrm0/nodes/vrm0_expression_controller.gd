@tool
extends Node3D
class_name Vrm0ExpressionController

## Uses the shared runtime expression/bind classes from common/ — these are
## generation-agnostic, not VRM1-specific, despite the historical "Vrm1" naming
## on some of the older call sites.
const RuntimeExpression = preload("../../common/vrm_runtime_expression.gd")
const RuntimeMorphBind = preload("../../common/vrm_runtime_morph_bind.gd")
const RuntimeMaterialColorBind = preload("../../common/vrm_runtime_material_color_bind.gd")
const RuntimeTextureTransformBind = preload("../../common/vrm_runtime_texture_transform_bind.gd")
const RuntimeNodeMorphState = preload("../../common/vrm_runtime_node_morph_state.gd")
const RuntimeMaterialColorState = preload("../../common/vrm_runtime_material_color_state.gd")
const RuntimeMaterialUVState = preload("../../common/vrm_runtime_material_uv_state.gd")

## VRM0's presetName enum spells gaze presets without a separator; map them to the
## underscored property names used everywhere else in this controller.
const VRM0_GAZE_PRESET_ALIASES: Dictionary[String, String] = {
	"lookup": "look_up",
	"lookdown": "look_down",
	"lookleft": "look_left",
	"lookright": "look_right",
}

## The expression names this controller keeps in an exported property rather than
## in custom_expressions. Single source of truth for set_expression,
## get_expression and _apply_expressions: all three must agree on where a weight
## lives, or a value written to one store is read back from the other as 0.
##
## "surprised" is deliberately absent even though an exported property of that
## name exists on this node. VRM0's BlendShapePreset enum has no surprised, so
## such a group has always arrived as a custom expression and its weight has
## always lived in custom_expressions; the exported property is a stray from the
## VRM1 shape and moving the name here would strand it.
const STANDARD_EXPRESSIONS: Array[String] = [
	"neutral", "joy", "angry", "sorrow", "fun",
	"a", "i", "u", "e", "o",
	"blink", "blink_left", "blink_right",
	"look_up", "look_down", "look_left", "look_right",
]

## Compiled at import time and STORED with the scene: the binds need GLTFState to
## compile (glTF node index -> scene node), which an instantiated scene no longer
## has. Without storage every instantiated avatar came up with `expressions == []`.
## export_storage rather than export: serialized, but not a wall of sub-resources
## in the inspector.
@export_storage var _binds: Dictionary[String, RuntimeExpression] = {}
var expressions: Array[String]: 
	get():
		var typed: Array[String] = []
		typed.assign(_binds.keys())
		return typed

## Custom expressions that are not standard VRM presets.
@export var custom_expressions: Dictionary[String, float] = {}

var _dirty: bool = false
var _base_morphs: Dictionary[NodePath, RuntimeNodeMorphState] = {}
var _base_material_colors: Dictionary[NodePath, RuntimeMaterialColorState] = {}
var _base_material_uvs: Dictionary[NodePath, RuntimeMaterialUVState] = {}


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

@export_range(0.0, 1.0) var look_up: float = 0.0:
	set(v): look_up = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var look_down: float = 0.0:
	set(v): look_down = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var look_left: float = 0.0:
	set(v): look_left = clampf(v, 0.0, 1.0); _request_update()
@export_range(0.0, 1.0) var look_right: float = 0.0:
	set(v): look_right = clampf(v, 0.0, 1.0); _request_update()


func _request_update() -> void:
	_dirty = true


## The one spelling a custom (non-preset) expression is stored and looked up
## under. compile_vrm0_binds, set_expression, get_expression and
## _apply_expressions all route custom names through here, so the dictionary
## key never depends on which spelling a caller happened to use.
##
## This exists because it once did: compile stored binds under
## group.name.to_lower() ("jawopen") while set_expression stored weights under
## the caller's spelling ("jawOpen", the ARKit canonical form VBeami's solver
## emits). GDScript dictionaries are case-sensitive, so _apply_expressions read
## every perfect-sync weight back as 0.0 and the mouth never moved on a VRM0
## avatar. Lower-case is the stored form because that is what already-imported
## scenes carry in their serialized _binds.
static func _custom_key(expression_name: String) -> String:
	return expression_name.to_lower()


func _process(_delta: float) -> void:
	if _dirty:
		_apply_expressions()
		_dirty = false


## Read one expression weight back. The mirror of set_expression: presets and
## custom names both normalize through the same path, so a weight written under
## any spelling reads back under any other.
##
## Added late: this controller was write-only for a long time while the VRM1 one
## had a getter, so anything polling weights generically (VBeami's Live Monitor
## and facedebug dump, for two) raised "Nonexistent function 'get_expression'"
## once per expression per poll against every VRM0 avatar and read every weight
## as 0. Callers that must cope with a controller lacking this should probe with
## has_method() rather than call blind.
func get_expression(expression_name: String) -> float:
	var standard_prop := expression_name.to_lower()
	if standard_prop in STANDARD_EXPRESSIONS:
		return get(standard_prop)
	return custom_expressions.get(_custom_key(expression_name), 0.0)


func set_expression(expression_name: String, value: float) -> void:
	var standard_prop := expression_name.to_lower()
	if standard_prop in STANDARD_EXPRESSIONS:
		set(standard_prop, value)
	else:
		# The presets get their clamp from their own exported setters; a custom
		# expression has no setter to inherit one from, so it clamps here. Mirrors
		# Vrm1ExpressionController.set_custom_expression.
		custom_expressions[_custom_key(expression_name)] = clampf(value, 0.0, 1.0)
		_request_update()


func _apply_expressions() -> void:
	_ensure_base_state()

	# Reset morph targets to base state
	for mesh_path: NodePath in _base_morphs:
		var node: Node = get_node_or_null(mesh_path)
		if node and node.has_method("set_blend_shape_value"):
			var base_state: RuntimeNodeMorphState = _base_morphs[mesh_path]
			for idx: int in base_state.blend_shapes:
				node.set_blend_shape_value(idx, base_state.blend_shapes[idx])

	# Reset material colors to base state
	for mat_path: NodePath in _base_material_colors:
		var node: Node = get_node_or_null(mat_path)
		if node and node is MeshInstance3D:
			for surface_idx: int in range(node.get_surface_override_material_count()):
				var mat: Material = node.get_surface_override_material(surface_idx)
				if mat:
					var base_state: RuntimeMaterialColorState = _base_material_colors[mat_path]
					for prop in base_state.properties:
						_set_material_color(mat, prop, base_state.properties[prop])

	# Reset material UVs to base state
	for mat_path: NodePath in _base_material_uvs:
		var node: Node = get_node_or_null(mat_path)
		if node and node is MeshInstance3D:
			for surface_idx: int in range(node.get_surface_override_material_count()):
				var mat: Material = node.get_surface_override_material(surface_idx)
				if mat:
					var base_state: RuntimeMaterialUVState = _base_material_uvs[mat_path]
					_set_material_uv(mat, base_state.scale, base_state.offset)

	# Accumulate and apply all active expressions
	for expr_key in _binds:
		var val: float = 0.0
		if expr_key in STANDARD_EXPRESSIONS:
			val = get(expr_key)
		else:
			# expr_key came out of compile_vrm0_binds already in _custom_key form.
			val = custom_expressions.get(expr_key, 0.0)

		if val <= 0.0:
			continue

		var expression: RuntimeExpression = _binds[expr_key]
		if expression.is_binary:
			val = 1.0 if val > 0.5 else 0.0

		# Morph binds (uses RuntimeMorphBind fields: path, index, weight)
		for morph_bind: RuntimeMorphBind in expression.morph_binds:
			var node: Node = get_node_or_null(morph_bind.path)
			if node and node.has_method("set_blend_shape_value"):
				var current: float = node.get_blend_shape_value(morph_bind.index) if node.has_method("get_blend_shape_value") else 0.0
				# Capped, not just summed. Several expressions can bind the same morph
				# index (VRM's combined `blink` shares targets with blink_L/blink_R), and
				# unbounded addition drives the morph past its authored shape - the mesh
				# visibly tears rather than merely looking wrong. This also catches a weight
				# written straight into custom_expressions, which is @export and so bypasses
				# set_expression's clamp entirely. VRM0 bind weights are non-negative, so
				# capping per contribution reaches the same place as capping the sum.
				node.set_blend_shape_value(morph_bind.index, clampf(current + (val * morph_bind.weight), 0.0, 1.0))

		# Material color binds (uses RuntimeMaterialColorBind fields: material, prop, color)
		for material_color_bind: RuntimeMaterialColorBind in expression.color_binds:
			if material_color_bind.material:
				_set_material_color(material_color_bind.material, material_color_bind.prop, material_color_bind.color * val)

		# Texture transform binds (uses RuntimeTextureTransformBind fields: material, scale, offset)
		for texture_transform_bind: RuntimeTextureTransformBind in expression.uv_binds:
			if texture_transform_bind.material:
				_set_material_uv(texture_transform_bind.material, texture_transform_bind.scale * val, texture_transform_bind.offset * val)


## Rebuilds the base-state snapshots from the LIVE meshes/materials when they
## are missing. The base dictionaries hold plain RefCounted values that do NOT
## survive scene serialization, while the compiled _binds sometimes do — a
## res://-instanced avatar then arrives split-brained: binds present, base
## EMPTY. The reset loop iterated nothing, every apply ADDED into the mesh, and
## blink morphs marched 4 → 9 → 17 within a minute of auto-blink pulses ("VRM0
## avatars keep distorting"). Values read before the first expression write ARE
## the base, so capturing lazily here is exact. Idempotent — existing entries
## (from a same-session compile) are never overwritten — and runs on every
## apply, because no flag can be trusted across the same serialization boundary
## that loses the dictionaries.
func _ensure_base_state() -> void:
	for expr_key: String in _binds:
		var expression: RuntimeExpression = _binds[expr_key]

		for morph_bind: RuntimeMorphBind in expression.morph_binds:
			var node: Node = get_node_or_null(morph_bind.path)
			if node == null or not node.has_method("get_blend_shape_value"):
				continue
			if not _base_morphs.has(morph_bind.path):
				_base_morphs[morph_bind.path] = RuntimeNodeMorphState.new()
			var morph_state: RuntimeNodeMorphState = _base_morphs[morph_bind.path]
			if not morph_state.blend_shapes.has(morph_bind.index):
				morph_state.blend_shapes[morph_bind.index] = node.get_blend_shape_value(morph_bind.index)

		for color_bind: RuntimeMaterialColorBind in expression.color_binds:
			if color_bind.material == null:
				continue
			var color_mesh_path: NodePath = _mesh_path_for_material(color_bind.material)
			if color_mesh_path.is_empty():
				continue
			if not _base_material_colors.has(color_mesh_path):
				_base_material_colors[color_mesh_path] = RuntimeMaterialColorState.new()
			var color_state: RuntimeMaterialColorState = _base_material_colors[color_mesh_path]
			if not color_state.properties.has(color_bind.prop):
				color_state.properties[color_bind.prop] = _get_material_color(color_bind.material, color_bind.prop)

		for uv_bind: RuntimeTextureTransformBind in expression.uv_binds:
			if uv_bind.material == null:
				continue
			var uv_mesh_path: NodePath = _mesh_path_for_material(uv_bind.material)
			if uv_mesh_path.is_empty():
				continue
			if not _base_material_uvs.has(uv_mesh_path):
				_base_material_uvs[uv_mesh_path] = _get_material_uv(uv_bind.material)


## The reset loops address materials through their mesh's NodePath; a lazily
## rebuilt base has only the Material reference, so walk the avatar for the
## mesh whose active surface material is [param mat].
func _mesh_path_for_material(mat: Material) -> NodePath:
	var root: Node = get_parent()
	if root == null:
		return NodePath()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			for surface_idx: int in range(mesh_instance.get_surface_override_material_count()):
				if mesh_instance.get_active_material(surface_idx) == mat:
					return NodePath("../" + _get_path_from_root(mesh_instance, root))
		stack.append_array(node.get_children())
	return NodePath()


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
			expression_key = _custom_key(group.name)
		# VRM0's presetName enum spells these without a separator ("lookup", "lookleft", ...);
		# normalize to the underscored property names so they hit the exported gaze properties
		# above instead of silently falling through to custom_expressions.
		expression_key = VRM0_GAZE_PRESET_ALIASES.get(expression_key, expression_key)

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
					_base_morphs[target_path] = RuntimeNodeMorphState.new()
				var base_state := _base_morphs[target_path]
				if not base_state.blend_shapes.has(blend_shape_bind.index):
					if mesh_instance_node.has_method("get_blend_shape_value"):
						base_state.blend_shapes[blend_shape_bind.index] = mesh_instance_node.get_blend_shape_value(blend_shape_bind.index)
					else:
						base_state.blend_shapes[blend_shape_bind.index] = 0.0

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
				var resolved_prop: String = _material_prop_for(prop_info, mat)
				if resolved_prop.is_empty():
					continue

				var mcb := RuntimeMaterialColorBind.new()
				mcb.material = mat
				mcb.prop = resolved_prop
				mcb.color = Color(material_bind.target_value[0], material_bind.target_value[1], material_bind.target_value[2], material_bind.target_value[3])
				expression.color_binds.append(mcb)

				# Capture base state
				var mat_path: NodePath = NodePath("../" + _get_path_from_root(target_mesh, root_node))
				if not _base_material_colors.has(mat_path):
					_base_material_colors[mat_path] = RuntimeMaterialColorState.new()
				var base_state := _base_material_colors[mat_path]
				if not base_state.properties.has(resolved_prop):
					base_state.properties[resolved_prop] = _get_material_color(mat, resolved_prop)

			elif prop_info.type == "uv" and material_bind.target_value.size() >= 4:
				var texture_transform_bind := RuntimeTextureTransformBind.new()
				texture_transform_bind.material = mat
				texture_transform_bind.scale = Vector2(material_bind.target_value[0], material_bind.target_value[1])
				texture_transform_bind.offset = Vector2(material_bind.target_value[2], material_bind.target_value[3])
				expression.uv_binds.append(texture_transform_bind)

				# Capture base state
				var mat_path: NodePath = NodePath("../" + _get_path_from_root(target_mesh, root_node))
				if not _base_material_uvs.has(mat_path):
					_base_material_uvs[mat_path] = _get_material_uv(mat)

		_binds[expression_key] = expression


## Resolves a VRM0 material bind's propertyName to both the BaseMaterial3D-native property
## (used when a material fell back to a plain glTF PBR material with no MToon extension) and
## the real MToon shader uniform name (used for the ShaderMaterial VrmMtoonBuilder normally
## produces). shade/rim/matcap/outline have no BaseMaterial3D equivalent, so std_property is
## left empty for those - _material_prop_for() treats that as "unsupported for this material".
func _resolve_vrm0_material_property(vrm0_prop: String) -> Dictionary:
	match vrm0_prop:
		"_Color": return {"type": "color", "std_property": "albedo_color", "shader_property": "_Color"}
		"_EmissionColor": return {"type": "color", "std_property": "emission", "shader_property": "_EmissionColor"}
		"_ShadeColor", "_ShadedColor": return {"type": "color", "std_property": "", "shader_property": "_ShadeColor"}
		"_OutlineColor": return {"type": "color", "std_property": "", "shader_property": "_OutlineColor"}
		"_RimColor": return {"type": "color", "std_property": "", "shader_property": "_RimColor"}
		"_MatcapColor": return {"type": "color", "std_property": "", "shader_property": "_MatcapColor"}
		"_MainTex_ST": return {"type": "uv"}
	return {}


## Picks the correct single property name for prop_info against mat's concrete type.
## Returns "" if mat's type has no equivalent for this VRM property.
func _material_prop_for(prop_info: Dictionary, mat: Material) -> String:
	if mat is ShaderMaterial:
		return prop_info.get("shader_property", "")
	if mat is BaseMaterial3D:
		return prop_info.get("std_property", "")
	return ""


func _get_material_color(mat: Material, prop: String) -> Color:
	if mat is ShaderMaterial:
		var param: Variant = mat.get_shader_parameter(prop)
		if typeof(param) == TYPE_COLOR:
			return param
	elif mat is BaseMaterial3D:
		if prop in mat:
			return mat.get(prop)
	return Color.WHITE


func _set_material_color(mat: Material, prop: String, value: Color) -> void:
	if mat is ShaderMaterial:
		mat.set_shader_parameter(prop, value)
	elif mat is BaseMaterial3D:
		mat.set(prop, value)


## The MToon shader packs UV scale+offset into one _MainTex_ST vec4 uniform, unlike
## BaseMaterial3D's separate uv1_scale/uv1_offset Vector3 properties.
func _get_material_uv(mat: Material) -> RuntimeMaterialUVState:
	var state := RuntimeMaterialUVState.new()
	if mat is ShaderMaterial:
		var param: Variant = mat.get_shader_parameter("_MainTex_ST")
		if typeof(param) == TYPE_VECTOR4:
			state.scale = Vector2(param.x, param.y)
			state.offset = Vector2(param.z, param.w)
	elif mat is BaseMaterial3D:
		state.scale = Vector2(mat.uv1_scale.x, mat.uv1_scale.y)
		state.offset = Vector2(mat.uv1_offset.x, mat.uv1_offset.y)
	return state


func _set_material_uv(mat: Material, scale: Vector2, offset: Vector2) -> void:
	if mat is ShaderMaterial:
		mat.set_shader_parameter("_MainTex_ST", Vector4(scale.x, scale.y, offset.x, offset.y))
	elif mat is BaseMaterial3D:
		mat.uv1_scale = Vector3(scale.x, scale.y, 1.0)
		mat.uv1_offset = Vector3(offset.x, offset.y, 0.0)


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
