extends GutTest

## Coverage for Vrm1ExpressionController's procedural override handling (overrideBlink/
## overrideLookAt/overrideMouth), per expressions.md's "Procedural override" section:
## `block` forces the target category's weight to 0 outright; `blend` instead attenuates
## the target's own weight by `1 - saturate(sum of all active overriding weights)`; and a
## target expression with isBinary must snap fully to 0 the instant it receives ANY
## attenuation, never a fractional value.
##
## Uses material color binds (not morph binds) as the observable side effect, following
## the pattern in test_vrm1_expression_controller.gd: a real MToon ShaderMaterial with two
## independent color uniforms (_Color for the overriding expression, _RimColor for the
## target) avoids needing synthetic blend-shape mesh data.

const VrmMtoonBuilder = preload("res://addons/vrm/common/vrm_mtoon_builder.gd")

var _root: Node3D
var _controller: Vrm1ExpressionController
var _shader_mat: ShaderMaterial
var _state: GLTFState
var _base_rim: Color
var _base_color: Color


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_controller = Vrm1ExpressionController.new()
	_root.add_child(_controller)

	var mesh_inst := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_inst.mesh = array_mesh
	_root.add_child(mesh_inst)

	_shader_mat = VrmMtoonBuilder.build_body({})
	_shader_mat.resource_name = "TestMat"
	mesh_inst.set_surface_override_material(0, _shader_mat)
	_base_rim = _shader_mat.get_shader_parameter("_RimColor")
	_base_color = _shader_mat.get_shader_parameter("_Color")

	var placeholder := StandardMaterial3D.new()
	placeholder.resource_name = "TestMat"
	_state = GLTFState.new()
	var materials: Array[Material] = [placeholder]
	_state.materials = materials


func after_each() -> void:
	_root = null
	_controller = null
	_shader_mat = null
	_state = null


## Builds a Vrm1ExpressionData with a single material color bind targeting _RimColor
## (via type "rimColor") set to pure white, so the applied color linearly interpolates
## from _base_rim toward Color(1,1,1,1) as the effective weight goes from 0 to 1.
func _make_rim_target_data(is_binary: bool = false) -> Vrm1ExpressionData:
	var cb := Vrm1ExpressionMaterialColorBind.new()
	cb.material = 0
	cb.type = "rimColor"
	cb.target_value = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var data := Vrm1ExpressionData.new()
	data.material_color_binds.append(cb)
	data.is_binary = is_binary
	return data


## Builds a Vrm1ExpressionData for an overriding expression (e.g. "happy") with a bind on
## _Color, independent of _RimColor, so its own weight is observable without interference.
## Targets black rather than white: MToon's default base _Color is white, so a white
## target would make (target - base) zero and the bind's output identical at every weight.
func _make_overriding_data(override_blink: String) -> Vrm1ExpressionData:
	var cb := Vrm1ExpressionMaterialColorBind.new()
	cb.material = 0
	cb.type = "color"
	cb.target_value = PackedFloat32Array([0.0, 0.0, 0.0, 1.0])
	var data := Vrm1ExpressionData.new()
	data.material_color_binds.append(cb)
	data.override_blink = override_blink
	return data


func _compile(preset: Dictionary) -> void:
	var expressions := Vrm1Expressions.new()
	for key: String in preset:
		expressions.preset[key] = preset[key]
	_controller.compile_vrm1_binds(expressions, _state, _root)


func _rim() -> Color:
	return _shader_mat.get_shader_parameter("_RimColor")


func test_block_override_zeroes_target_regardless_of_weight() -> void:
	_compile({
		"happy": _make_overriding_data("block"),
		"blink": _make_rim_target_data(),
	})
	_controller.set_expression("happy", 1.0)
	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()

	assert_eq(_rim(), _base_rim, "blink should be fully suppressed to base color, not blended toward its target at all")


func test_blend_override_attenuates_target_by_formula() -> void:
	_compile({
		"happy": _make_overriding_data("blend"),
		"blink": _make_rim_target_data(),
	})
	_controller.set_expression("happy", 0.5)
	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()

	# factor = 1 - saturate(0.5) = 0.5; effective blink weight = 1.0 * 0.5 = 0.5
	var expected: Color = _base_rim.lerp(Color(1, 1, 1, 1), 0.5)
	assert_eq(_rim(), expected)


func test_blend_sums_across_multiple_overriding_expressions() -> void:
	_compile({
		"happy": _make_overriding_data("blend"),
		"angry": _make_overriding_data("blend"),
		"blink": _make_rim_target_data(),
	})
	_controller.set_expression("happy", 0.3)
	_controller.set_expression("angry", 0.4)
	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()

	# factor = 1 - saturate(0.3 + 0.4) = 0.3; effective blink weight = 1.0 * 0.3 = 0.3
	var expected: Color = _base_rim.lerp(Color(1, 1, 1, 1), 0.3)
	assert_eq(_rim(), expected)


func test_blend_factor_saturates_at_full_suppression() -> void:
	_compile({
		"happy": _make_overriding_data("blend"),
		"angry": _make_overriding_data("blend"),
		"blink": _make_rim_target_data(),
	})
	_controller.set_expression("happy", 0.8)
	_controller.set_expression("angry", 0.5)
	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()

	# sum = 1.3, saturated to 1.0 -> factor = 0.0 -> fully suppressed, same observable
	# result as block even though this path went through blend's multiplication, not skip.
	assert_eq(_rim(), _base_rim)


func test_binary_target_snaps_to_zero_under_any_blend_attenuation() -> void:
	_compile({
		"happy": _make_overriding_data("blend"),
		"blink": _make_rim_target_data(true),
	})
	_controller.set_expression("happy", 0.1)  # factor = 0.9, i.e. only mild attenuation
	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()

	# isBinary must snap to 0 the instant ANY attenuation applies, not 1.0 * 0.9 = 0.9's
	# worth of color - fractional output is exactly what isBinary forbids.
	assert_eq(_rim(), _base_rim)


func test_overriding_expression_itself_is_unaffected_by_its_own_override() -> void:
	_compile({
		"happy": _make_overriding_data("blend"),
	})
	_controller.set_expression("happy", 0.7)
	_controller._apply_expressions()

	var applied: Color = _shader_mat.get_shader_parameter("_Color")
	var expected: Color = _base_color.lerp(Color(0, 0, 0, 1), 0.7)
	assert_eq(applied, expected, "happy targets _Color, not a procedural category - its own weight must not be attenuated by its own override")


func test_block_takes_precedence_over_blend_for_the_same_category() -> void:
	_compile({
		"happy": _make_overriding_data("block"),
		"angry": _make_overriding_data("blend"),
		"blink": _make_rim_target_data(),
	})
	_controller.set_expression("happy", 1.0)
	_controller.set_expression("angry", 0.1)
	_controller.set_expression("blink", 1.0)
	_controller._apply_expressions()

	assert_eq(_rim(), _base_rim, "a block override on the category must win outright even if another active expression only blends it")


func test_no_active_override_leaves_target_weight_unchanged() -> void:
	_compile({
		"blink": _make_rim_target_data(),
	})
	_controller.set_expression("blink", 0.4)
	_controller._apply_expressions()

	var expected: Color = _base_rim.lerp(Color(1, 1, 1, 1), 0.4)
	assert_eq(_rim(), expected)
