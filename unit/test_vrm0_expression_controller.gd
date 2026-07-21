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
# ---------------------------------------------------------------------------

func test_resolves_rim_color() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_RimColor")

	assert_eq(info, { "type": "color", "property": "rim_color" })


func test_resolves_matcap_color() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_MatcapColor")

	assert_eq(info, { "type": "color", "property": "matcap_color" })


func test_resolves_base_color() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_Color")

	assert_eq(info, { "type": "color", "property": "albedo_color" })


func test_unknown_property_returns_empty_dict() -> void:
	var info: Dictionary = _controller.call("_resolve_vrm0_material_property", "_NotARealProperty")

	assert_true(info.is_empty())


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
