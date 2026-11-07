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


# ---------------------------------------------------------------------------
# get_expression (the read half)
# This controller was write-only for a long time while the VRM1 one had a
# getter, so anything polling weights generically read every VRM0 weight as 0
# and logged "Nonexistent function 'get_expression'" once per expression per
# poll. The round trip matters more than the getter merely existing:
# set_expression picks the store (exported property vs custom_expressions) and
# get_expression must pick the same one, or a written weight reads back as 0
# in silence.
# ---------------------------------------------------------------------------

func test_get_expression_reads_back_a_standard_preset() -> void:
	_controller.set_expression("joy", 0.6)

	assert_almost_eq(_controller.get_expression("joy"), 0.6, 0.0001)


func test_get_expression_reads_back_a_custom_expression() -> void:
	# Perfect-sync ARKit morphs arrive as custom expressions, not presets - the
	# store set_expression routes them to must be the one get_expression checks.
	_controller.set_expression("mouthSmileLeft", 0.4)

	assert_almost_eq(_controller.get_expression("mouthSmileLeft"), 0.4, 0.0001)
	assert_true(_controller.custom_expressions.has("mouthsmileleft"),
		"a non-preset name belongs in custom_expressions, under its normalized key")


func test_get_expression_round_trips_every_standard_name() -> void:
	for expr_name: String in Vrm0ExpressionController.STANDARD_EXPRESSIONS:
		_controller.set_expression(expr_name, 0.25)
		assert_almost_eq(_controller.get_expression(expr_name), 0.25, 0.0001,
			"%s must round trip through its exported property" % expr_name)


func test_get_expression_normalizes_case_like_set_expression() -> void:
	_controller.set_expression("Blink", 1.0)

	assert_almost_eq(_controller.get_expression("BLINK"), 1.0, 0.0001)
	assert_almost_eq(_controller.blink, 1.0, 0.0001, "both spellings must reach the exported property")


func test_get_expression_is_zero_for_an_unknown_name() -> void:
	assert_almost_eq(_controller.get_expression("not_an_expression"), 0.0, 0.0001)


func test_controller_advertises_get_expression() -> void:
	# The contract generic callers probe with has_method() before reading;
	# without it they report every weight as 0, which is indistinguishable from
	# a genuinely released expression.
	assert_true(_controller.has_method("get_expression"))


# ---------------------------------------------------------------------------
# Weight clamping
# The exported presets clamp in their own setters, so only the custom path and
# the accumulate loop were ever unbounded. Both matter: a weight above 1 is not
# just cosmetic, it drives a morph past its authored shape and the mesh visibly
# tears. VRM1 already caps both (set_custom_expression, and clampf on the summed
# morph value); these pin VRM0 to the same contract.
# ---------------------------------------------------------------------------

func test_set_expression_clamps_a_custom_expression_above_one() -> void:
	_controller.set_expression("mouthSmileLeft", 5.0)

	assert_almost_eq(_controller.get_expression("mouthSmileLeft"), 1.0, 0.0001,
		"a custom expression must clamp like a preset does")


func test_set_expression_clamps_a_custom_expression_below_zero() -> void:
	_controller.set_expression("mouthSmileLeft", -2.0)

	assert_almost_eq(_controller.get_expression("mouthSmileLeft"), 0.0, 0.0001)


func test_standard_presets_still_clamp() -> void:
	# The half that already worked. Here so a refactor of set_expression cannot
	# quietly move the clamp off the preset path while fixing the custom one.
	_controller.set_expression("joy", 5.0)
	_controller.set_expression("blink", -1.0)

	assert_almost_eq(_controller.joy, 1.0, 0.0001)
	assert_almost_eq(_controller.blink, 0.0, 0.0001)


## Two expressions bound to the SAME morph index, each at full weight. The
## accumulate loop adds into whatever is already on the mesh, so without a cap
## the second bind carries the morph to 2.0.
func _install_two_binds_on_one_morph() -> void:
	for expr_name: String in ["blink", "joy"]:
		var bind := RuntimeMorphBind.new()
		bind.path = NodePath("../Face")
		bind.index = 0
		bind.weight = 1.0
		var expression := RuntimeExpression.new()
		expression.morph_binds.append(bind)
		_controller._binds[expr_name] = expression


func test_two_binds_on_one_morph_cannot_exceed_full_weight() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var mesh_inst := _build_blink_face(root)
	_install_two_binds_on_one_morph()

	_controller.set_expression("blink", 1.0)
	_controller.set_expression("joy", 1.0)
	_controller._apply_expressions()

	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 1.0, 0.0001,
		"two full-weight binds on one morph must cap at 1.0, not sum to 2.0")


func test_a_weight_written_straight_into_the_dictionary_cannot_overdrive_a_morph() -> void:
	# custom_expressions is @export, so the inspector and any direct write bypass
	# set_expression entirely. Clamping only on the way in would leave this path
	# open, which is why the accumulate loop has to cap as well.
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var mesh_inst := _build_blink_face(root)

	var bind := RuntimeMorphBind.new()
	bind.path = NodePath("../Face")
	bind.index = 0
	bind.weight = 1.0
	var expression := RuntimeExpression.new()
	expression.morph_binds.append(bind)
	_controller._binds["mouthSmileLeft"] = expression

	_controller.custom_expressions["mouthSmileLeft"] = 5.0
	_controller._apply_expressions()

	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 1.0, 0.0001,
		"an unclamped dictionary write must still land inside 0..1 on the mesh")


# ---------------------------------------------------------------------------
# Custom-expression key normalization (the frozen-mouth bug)
# compile_vrm0_binds keyed custom groups by group.name.to_lower() ("jawopen")
# while set_expression stored the weight under the caller's spelling
# ("jawOpen" - the ARKit canonical form VBeami's solver emits). Dictionary
# lookups are case-sensitive, so _apply_expressions read every perfect-sync
# weight as 0.0 and a VRM0 avatar's mouth never moved. All four call sites now
# share _custom_key(); these pin that they agree.
# ---------------------------------------------------------------------------

func _make_custom_group(clip_name: String) -> Vrm0BlendShapeGroup:
	var group := Vrm0BlendShapeGroup.new()
	group.preset_name = "unknown"
	group.name = clip_name
	return group


func test_compiled_custom_bind_key_matches_set_expression_key() -> void:
	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_make_custom_group("jawOpen"))
	_controller.compile_vrm0_binds(master, GLTFState.new(), autofree(Node.new()))
	assert_eq(_controller.expressions.size(), 1)
	var bind_key: String = _controller.expressions[0]

	_controller.set_expression("jawOpen", 0.8)

	assert_almost_eq(_controller.custom_expressions.get(bind_key, 0.0), 0.8, 0.0001,
		"the weight must be stored under the exact key the bind was compiled to (%s)" % bind_key)


func test_camel_case_perfect_sync_weight_reaches_the_mesh() -> void:
	# The end-to-end symptom. The bind is installed under the key compile
	# produces; the weight arrives under the spelling the solver uses.
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var mesh_inst := _build_blink_face(root)

	var bind := RuntimeMorphBind.new()
	bind.path = NodePath("../Face")
	bind.index = 0
	bind.weight = 1.0
	var expression := RuntimeExpression.new()
	expression.morph_binds.append(bind)
	_controller._binds["jawopen"] = expression

	_controller.set_expression("jawOpen", 1.0)
	_controller._apply_expressions()

	assert_almost_eq(mesh_inst.get_blend_shape_value(0), 1.0, 0.0001,
		"a camelCase weight must drive the lower-cased bind; 0.0 here is the frozen-mouth bug")


func test_custom_expression_reads_back_under_any_spelling() -> void:
	_controller.set_expression("JawOpen", 0.4)

	assert_almost_eq(_controller.get_expression("jawopen"), 0.4, 0.0001)
	assert_almost_eq(_controller.get_expression("JAWOPEN"), 0.4, 0.0001)
	assert_almost_eq(_controller.get_expression("jawOpen"), 0.4, 0.0001)


func test_custom_expression_spellings_share_one_slot() -> void:
	# Two spellings must not become two entries that the apply loop then sums.
	_controller.set_expression("jawOpen", 1.0)
	_controller.set_expression("JAWOPEN", 0.2)

	assert_eq(_controller.custom_expressions.size(), 1, "one expression, one key")
	assert_almost_eq(_controller.get_expression("jawOpen"), 0.2, 0.0001, "the later write wins")


# ---------------------------------------------------------------------------
# Material binds at editor import, and against meshes with several materials.
# compile_vrm0_binds runs in _import_post, while meshes are still
# ImporterMeshInstance3D; the old MeshInstance3D walk found none, so every VRM0
# material colour/UV bind of an editor-imported avatar was dropped in silence.
# It also bound the mesh's surface 0 whatever surface matched, and kept the base
# per mesh, so releasing one material's bind wrote its base into the others.
# ---------------------------------------------------------------------------

func _rim_material(mat_name: String, rim: Color) -> ShaderMaterial:
	# Deliberately not the MToon builder, so this runs without the MToon addon.
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nuniform vec4 _RimColor;\nuniform vec4 _MainTex_ST;"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.resource_name = mat_name
	mat.set_shader_parameter("_RimColor", rim)
	mat.set_shader_parameter("_MainTex_ST", Vector4(1.0, 1.0, 0.0, 0.0))
	return mat


func _rim_group(preset: String, mat_name: String, target: Color) -> Vrm0BlendShapeGroup:
	var group := _make_group(preset)
	var mbind := Vrm0MaterialBind.new()
	mbind.material_name = mat_name
	mbind.property_name = "_RimColor"
	mbind.target_value = PackedFloat32Array([target.r, target.g, target.b, target.a])
	group.material_binds.append(mbind)
	return group


func _triangle_arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	return arrays


func test_material_bind_resolves_on_an_import_time_mesh() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var face := _rim_material("Face", Color(0.2, 0.2, 0.2, 1.0))
	var importer_mesh := ImporterMesh.new()
	importer_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, _triangle_arrays(), [], {}, face)
	var importer_inst := ImporterMeshInstance3D.new()
	importer_inst.mesh = importer_mesh
	root.add_child(importer_inst)

	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_rim_group("joy", "Face", Color.RED))
	_controller.compile_vrm0_binds(master, GLTFState.new(), root)

	var expression: RuntimeExpression = _controller._binds["joy"]
	assert_eq(expression.color_binds.size(), 1, "the bind must survive an import-time scene")
	if expression.color_binds.size() == 1:
		assert_eq(expression.color_binds[0].material, face)


func _two_material_body(root: Node3D, first: Material, second: Material) -> MeshInstance3D:
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _triangle_arrays())
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _triangle_arrays())
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Body"
	mesh_inst.mesh = array_mesh
	root.add_child(mesh_inst)
	mesh_inst.set_surface_override_material(0, first)
	mesh_inst.set_surface_override_material(1, second)
	return mesh_inst


func test_a_bind_on_the_second_surface_targets_that_material() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var skin := _rim_material("Skin", Color(0.2, 0.2, 0.2, 1.0))
	var cheek := _rim_material("Cheek", Color(0.2, 0.2, 0.2, 1.0))
	_two_material_body(root, skin, cheek)

	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_rim_group("joy", "Cheek", Color.RED))
	_controller.compile_vrm0_binds(master, GLTFState.new(), root)
	_controller.set_expression("joy", 1.0)
	_controller._apply_expressions()

	assert_almost_eq(Color(cheek.get_shader_parameter("_RimColor")).r, 1.0, 0.001,
		"the bind names Cheek, on surface 1")
	assert_almost_eq(Color(skin.get_shader_parameter("_RimColor")).r, 0.2, 0.001,
		"surface 0's material must not receive Cheek's bind")


func test_releasing_a_bind_leaves_the_other_materials_of_the_mesh_alone() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var skin := _rim_material("Skin", Color(0.7, 0.7, 0.7, 1.0))
	var cheek := _rim_material("Cheek", Color(0.2, 0.2, 0.2, 1.0))
	_two_material_body(root, skin, cheek)

	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_rim_group("joy", "Cheek", Color.RED))
	_controller.compile_vrm0_binds(master, GLTFState.new(), root)
	_controller.set_expression("joy", 1.0)
	_controller._apply_expressions()
	_controller.set_expression("joy", 0.0)
	_controller._apply_expressions()

	assert_almost_eq(Color(skin.get_shader_parameter("_RimColor")).r, 0.7, 0.001,
		"Skin must keep its own colour, not take Cheek's base")
	assert_almost_eq(Color(cheek.get_shader_parameter("_RimColor")).r, 0.2, 0.001)


## UniVRM moves a material value from its base toward the target by the weight.
## Writing target * weight darkened a half-weight colour instead.
func test_half_weight_colour_lies_halfway_between_base_and_target() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	root.add_child(_controller)
	var skin := _rim_material("Skin", Color(0.2, 0.2, 0.2, 1.0))
	var cheek := _rim_material("Cheek", Color(0.2, 0.2, 0.2, 1.0))
	_two_material_body(root, skin, cheek)

	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(_rim_group("joy", "Cheek", Color(1.0, 0.2, 0.2, 1.0)))
	_controller.compile_vrm0_binds(master, GLTFState.new(), root)
	_controller.set_expression("joy", 0.5)
	_controller._apply_expressions()

	var rim := Color(cheek.get_shader_parameter("_RimColor"))
	assert_almost_eq(rim.r, 0.6, 0.001, "halfway from 0.2 to 1.0")
	assert_almost_eq(rim.g, 0.2, 0.001, "a channel the bind does not change stays at its base")


## Temptic's angry bind targets _Color with [1, 0, 0]: RGB, no alpha. Requiring
## four values dropped it.
func test_a_colour_target_without_alpha_still_binds() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var skin := _rim_material("Skin", Color(0.2, 0.2, 0.2, 1.0))
	var cheek := _rim_material("Cheek", Color(0.2, 0.2, 0.2, 1.0))
	_two_material_body(root, skin, cheek)
	var group := _make_group("angry")
	var mbind := Vrm0MaterialBind.new()
	mbind.material_name = "Cheek"
	mbind.property_name = "_RimColor"
	mbind.target_value = PackedFloat32Array([1.0, 0.0, 0.0])
	group.material_binds.append(mbind)
	var master := Vrm0BlendShape.new()
	master.blend_shape_groups.append(group)

	_controller.compile_vrm0_binds(master, GLTFState.new(), root)

	var expression: RuntimeExpression = _controller._binds["angry"]
	assert_eq(expression.color_binds.size(), 1)
	if expression.color_binds.size() == 1:
		assert_eq(expression.color_binds[0].color, Color(1.0, 0.0, 0.0, 1.0))
