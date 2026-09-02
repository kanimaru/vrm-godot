extends GutTest

## Unit tests for Vrm0ExpressionController's material property resolution and
## VRM0 preset-name normalization. All inputs are synthetic — no proprietary
## assets required.

var _controller: Vrm0ExpressionController


func before_each() -> void:
	_controller = Vrm0ExpressionController.new()
	autofree(_controller)


func after_each() -> void:
	_controller = null


# ---------------------------------------------------------------------------
# Material property resolution (_resolve_vrm0_material_property)
# std_property is the BaseMaterial3D-native name (used for the rare plain-PBR-fallback
# material); shader_property is the real MToon shader uniform (used for the ShaderMaterial
# VrmMtoonBuilder normally produces). See _material_prop_for() for how these get picked.
# ---------------------------------------------------------------------------

func test_resolves_rim_color() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_RimColor")

	assert_eq(info, { "type": "color", "std_property": "", "shader_property": "_RimColor" })


func test_resolves_matcap_color() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_MatcapColor")

	assert_eq(info, { "type": "color", "std_property": "", "shader_property": "_MatcapColor" })


func test_resolves_base_color() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_Color")

	assert_eq(info, { "type": "color", "std_property": "albedo_color", "shader_property": "_Color" })


func test_unknown_property_returns_empty_dict() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_NotARealProperty")

	assert_true(info.is_empty())


# ---------------------------------------------------------------------------
# Per-material-type property name dispatch (_material_prop_for)
# ---------------------------------------------------------------------------

func test_material_prop_for_shader_material_uses_shader_property() -> void:
	var prop_info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_RimColor")
	var shader_mat := ShaderMaterial.new()

	var resolved: String = _controller.call("_material_prop_for", prop_info, shader_mat)

	assert_eq(resolved, "_RimColor")


func test_material_prop_for_base_material_uses_std_property() -> void:
	var prop_info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_Color")
	var std_mat := StandardMaterial3D.new()

	var resolved: String = _controller.call("_material_prop_for", prop_info, std_mat)

	assert_eq(resolved, "albedo_color")


func test_material_prop_for_base_material_with_no_equivalent_returns_empty() -> void:
	var prop_info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_RimColor")
	var std_mat := StandardMaterial3D.new()

	var resolved: String = _controller.call("_material_prop_for", prop_info, std_mat)

	assert_true(resolved.is_empty(), "rim color has no BaseMaterial3D equivalent")


# ---------------------------------------------------------------------------
# Gaze preset-name normalization (compile_vrm0_binds)
# VRM0's presetName enum spells these without a separator ("lookup", "lookleft", ...);
# the controller must normalize them to the underscored keys its exported
# look_up/look_down/look_left/look_right properties are matched against.
# ---------------------------------------------------------------------------

func _make_group(preset_name: String) -> Vrm0BlendShapeGroup:
	var group := Vrm0BlendShapeGroup.new()
	group.preset_name = preset_name
	return group


func test_lookup_preset_normalizes_to_look_up_bind_key() -> void:
	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_make_group("lookup"))
	_controller.compile_vrm0_binds(master, GLTFState.new(), autofree(Node.new()))

	assert_true(_controller.expressions.has("look_up"))
	assert_false(_controller.expressions.has("lookup"), "raw unnormalized preset name should not leak through")


func test_lookdown_lookleft_lookright_presets_normalize() -> void:
	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_make_group("lookdown"))
	master.blend_shape_groups.append(_make_group("lookleft"))
	master.blend_shape_groups.append(_make_group("lookright"))
	_controller.compile_vrm0_binds(master, GLTFState.new(), autofree(Node.new()))

	assert_true(_controller.expressions.has("look_down"))
	assert_true(_controller.expressions.has("look_left"))
	assert_true(_controller.expressions.has("look_right"))


func test_look_up_expression_drives_exported_property_via_set_expression() -> void:
	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_make_group("lookup"))
	_controller.compile_vrm0_binds(master, GLTFState.new(), autofree(Node.new()))

	_controller.set_expression("look_up", 0.75)

	assert_almost_eq(_controller.look_up, 0.75, 0.0001)


func test_non_gaze_preset_name_is_left_unchanged() -> void:
	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_make_group("joy"))
	_controller.compile_vrm0_binds(master, GLTFState.new(), autofree(Node.new()))

	assert_true(_controller.expressions.has("joy"))


# ---------------------------------------------------------------------------
# Serialization split-brain regression: a res://-instanced avatar arrives with
# compiled _binds but EMPTY base-state dictionaries (plain RefCounted vars do
# not survive the scene save). The reset loop then iterated nothing while the
# accumulate loop kept adding — blink morphs marched 4 → 9 → 17 within a
# minute of auto-blink pulses. _ensure_base_state() must rebuild the base from
# the live meshes so repeated applies TRACK the expression instead of summing.
# ---------------------------------------------------------------------------

func _build_blink_face(root: Node) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Face"
	var array_mesh := ArrayMesh.new()
	array_mesh.add_blend_shape("Blink.Left")
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.UP, Vector3.RIGHT, Vector3.ZERO])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
	mesh_inst.mesh = array_mesh
	root.add_child(mesh_inst)
	return mesh_inst


## _binds as they arrive after serialization: compiled morph binds, NO base.
func _install_split_brain_blink_bind() -> void:
	var bind := RuntimeMorphBind.new()
	bind.path = NodePath("../Face")
	bind.index = 0
	bind.weight = 1.0
	var expression := RuntimeExpression.new()
	expression.morph_binds.append(bind)
	_controller._binds["blink"] = expression


func test_missing_base_state_does_not_accumulate_morphs() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var mesh_inst := _build_blink_face(root)
	_install_split_brain_blink_bind()

	for i: int in range(5):
		_controller.set_expression("blink", 1.0)
		_controller._apply_expressions()
	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 1.0, 0.0001,
		"five full-weight applies must land on 1.0, not sum to 5.0")

	_controller.set_expression("blink", 0.25)
	_controller._apply_expressions()
	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 0.25, 0.0001,
		"the morph must track the expression weight")

	_controller.set_expression("blink", 0.0)
	_controller._apply_expressions()
	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 0.0, 0.0001,
		"releasing the expression must restore the captured base")


func test_lazy_base_capture_preserves_authored_rest_weight() -> void:
	# The base is whatever the mesh held BEFORE the first expression write —
	# including a nonzero authored rest weight, which release must restore.
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var mesh_inst := _build_blink_face(root)
	mesh_inst.set_blend_shape_value(0, 0.3)
	_install_split_brain_blink_bind()

	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()
	_controller.set_expression("blink", 0.0)
	_controller._apply_expressions()

	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 0.3, 0.0001,
		"release must restore the pre-expression value, not zero")


func test_missing_base_state_does_not_accumulate_material_colors() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Body"
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_inst.mesh = array_mesh
	root.add_child(mesh_inst)

	# A minimal shader with the uniform under test — deliberately NOT the MToon
	# builder, so this test runs in checkouts without the MToon shader addon.
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nuniform vec4 _RimColor;"
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("_RimColor", Color(0.1, 0.2, 0.3, 1.0))
	mesh_inst.set_surface_override_material(0, shader_mat)
	var base_rim: Variant = shader_mat.get_shader_parameter("_RimColor")

	var color_bind := RuntimeMaterialColorBind.new()
	color_bind.material = shader_mat
	color_bind.prop = "_RimColor"
	color_bind.color = Color(1.0, 0.0, 0.0, 1.0)
	var expression := RuntimeExpression.new()
	expression.color_binds.append(color_bind)
	_controller._binds["joy"] = expression

	for i: int in range(3):
		_controller.set_expression("joy", 1.0)
		_controller._apply_expressions()
	_controller.set_expression("joy", 0.0)
	_controller._apply_expressions()

	var released: Variant = shader_mat.get_shader_parameter("_RimColor")
	assert_eq(typeof(released), TYPE_COLOR)
	assert_almost_eq(released.r, Color(base_rim).r, 0.01,
		"releasing must restore the lazily captured base rim color")


# ---------------------------------------------------------------------------
# End-to-end material color bind against a real MToon ShaderMaterial.
# Regression coverage for the MToon-swap ordering bug: a material bind must land on
# whatever material is ACTUALLY rendering (the real MToon shader, addressed by its real
# uniform name), not a stale pre-swap material or a Godot-native property name that
# doesn't exist on the shader.
# ---------------------------------------------------------------------------

func test_rim_color_bind_applies_to_real_mtoon_shader_uniform() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)

	var mesh_inst := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_inst.mesh = array_mesh
	root.add_child(mesh_inst)

	var VrmMtoonBuilder = load("res://addons/vrm/common/vrm_mtoon_builder.gd")
	var shader_mat: ShaderMaterial = VrmMtoonBuilder.build_body({})
	shader_mat.resource_name = "TestMat"
	mesh_inst.set_surface_override_material(0, shader_mat)

	var master := Vrm0BlendShape.new()
	var group := Vrm0BlendShapeGroup.new()
	group.preset_name = "joy"
	var mbind := Vrm0MaterialBind.new()
	mbind.material_name = "TestMat"
	mbind.property_name = "_RimColor"
	mbind.target_value = PackedFloat32Array([1.0, 0.0, 0.0, 1.0])
	group.material_binds.append(mbind)
	master.blend_shape_groups.append(group)

	_controller.compile_vrm0_binds(master, GLTFState.new(), root)
	_controller.set_expression("joy", 1.0)
	_controller._apply_expressions()

	var applied: Variant = shader_mat.get_shader_parameter("_RimColor")
	assert_eq(typeof(applied), TYPE_COLOR, "the bind should have written a Color to the real _RimColor shader uniform")
	assert_almost_eq(applied.r, 1.0, 0.01)
