extends GutTest

## Unit tests for VrmMtoonBuilder.
## Verifies shader variant selection and material parameter application.
## No VRM file assets are required.


# ---------------------------------------------------------------------------
# build_body — shader variant selection (8 combos)
# ---------------------------------------------------------------------------

func test_build_body_opaque_single_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.OPAQUE,
		"double_sided": false,
	})

	assert_not_null(mat)
	assert_not_null(mat.shader)
	assert_true(mat.shader.resource_path.contains("mtoon.gdshader"),
			"Opaque single-sided should use mtoon.gdshader")


func test_build_body_opaque_double_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.OPAQUE,
		"double_sided": true,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_cull_off.gdshader"),
			"Opaque double-sided should use mtoon_cull_off")


func test_build_body_mask_single_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.MASK,
		"double_sided": false,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_cutout.gdshader"))
	assert_false(mat.shader.resource_path.contains("cull_off"),
			"Single-sided must not use cull_off variant")


func test_build_body_mask_double_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.MASK,
		"double_sided": true,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_cutout_cull_off.gdshader"))


func test_build_body_blend_single_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.BLEND,
		"double_sided": false,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_trans.gdshader"))
	assert_false(mat.shader.resource_path.contains("cull_off"))
	assert_false(mat.shader.resource_path.contains("zwrite"))


func test_build_body_blend_double_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.BLEND,
		"double_sided": true,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_trans_cull_off.gdshader"))


func test_build_body_blend_zwrite_single_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE,
		"double_sided": false,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_trans_zwrite.gdshader"))
	assert_false(mat.shader.resource_path.contains("cull_off"))


func test_build_body_blend_zwrite_double_sided() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_mode": VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE,
		"double_sided": true,
	})

	assert_true(mat.shader.resource_path.contains("mtoon_trans_zwrite_cull_off.gdshader"))


# ---------------------------------------------------------------------------
# build_outline — None returns null, non-None returns material
# ---------------------------------------------------------------------------

func test_build_outline_returns_null_when_mode_is_none() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({
		"outline_width_mode": VrmMtoonBuilder.OutlineWidthMode.NONE,
	})

	assert_null(mat)


func test_build_outline_returns_null_when_key_absent() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({})

	assert_null(mat)


func test_build_outline_world_opaque() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({
		"outline_width_mode": VrmMtoonBuilder.OutlineWidthMode.WORLD,
		"alpha_mode": VrmMtoonBuilder.AlphaMode.OPAQUE,
	})

	assert_not_null(mat)
	assert_true(mat.shader.resource_path.contains("mtoon_outline.gdshader"))


func test_build_outline_mask() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({
		"outline_width_mode": VrmMtoonBuilder.OutlineWidthMode.SCREEN,
		"alpha_mode": VrmMtoonBuilder.AlphaMode.MASK,
	})

	assert_not_null(mat)
	assert_true(mat.shader.resource_path.contains("mtoon_outline_cutout.gdshader"))


func test_build_outline_blend() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({
		"outline_width_mode": VrmMtoonBuilder.OutlineWidthMode.WORLD,
		"alpha_mode": VrmMtoonBuilder.AlphaMode.BLEND,
	})

	assert_not_null(mat)
	assert_true(mat.shader.resource_path.contains("mtoon_outline_trans.gdshader"))


func test_build_outline_blend_zwrite() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({
		"outline_width_mode": VrmMtoonBuilder.OutlineWidthMode.WORLD,
		"alpha_mode": VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE,
	})

	assert_not_null(mat)
	assert_true(mat.shader.resource_path.contains("mtoon_outline_trans_zwrite.gdshader"))


# ---------------------------------------------------------------------------
# Shader parameter application
# ---------------------------------------------------------------------------

func test_build_body_color_parameter_set() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"base_color": Color(0.5, 0.25, 0.1, 1.0),
	})

	var color: Color = mat.get_shader_parameter("_Color")
	assert_almost_eq(color.r, 0.5, 0.001)
	assert_almost_eq(color.g, 0.25, 0.001)
	assert_almost_eq(color.b, 0.1, 0.001)


func test_build_body_shade_color_parameter_set() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"shade_color": Color(0.9, 0.7, 0.8, 1.0),
	})

	var color: Color = mat.get_shader_parameter("_ShadeColor")
	assert_almost_eq(color.r, 0.9, 0.001)


func test_build_body_uv_st_default_when_absent() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({})

	var st: Vector4 = mat.get_shader_parameter("_MainTex_ST")
	assert_eq(st, Vector4(1.0, 1.0, 0.0, 0.0))


func test_build_body_uv_st_explicit() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"uv_st": Vector4(2.0, 3.0, 0.5, 0.25),
	})

	var st: Vector4 = mat.get_shader_parameter("_MainTex_ST")
	assert_eq(st, Vector4(2.0, 3.0, 0.5, 0.25))


func test_build_body_alpha_cutoff_parameter() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"alpha_cutoff": 0.35,
	})

	var cutoff: float = mat.get_shader_parameter("_Cutoff")
	assert_eq(cutoff, 0.35)


func test_build_body_rim_fresnel_power() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"rim_fresnel_power": 3.0,
	})

	var power: float = mat.get_shader_parameter("_RimFresnelPower")
	assert_eq(power, 3.0)


func test_build_body_uv_animation_scroll() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"uv_anim_scroll_x": 0.5,
		"uv_anim_scroll_y": -0.25,
		"uv_anim_rotation": 1.0,
	})

	assert_eq(mat.get_shader_parameter("_UvAnimScrollX"), 0.5)
	assert_eq(mat.get_shader_parameter("_UvAnimScrollY"), -0.25)
	assert_eq(mat.get_shader_parameter("_UvAnimRotation"), 1.0)


# ---------------------------------------------------------------------------
# render_queue_offset -> Material.render_priority
# ---------------------------------------------------------------------------

func test_build_body_render_priority_default_is_zero() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({})

	assert_eq(mat.render_priority, 0)


func test_build_body_render_priority_positive_offset() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"render_queue_offset": 9,
	})

	assert_eq(mat.render_priority, 9)


func test_build_body_render_priority_negative_offset() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"render_queue_offset": -9,
	})

	assert_eq(mat.render_priority, -9)


func test_build_outline_also_receives_render_priority() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_outline({
		"outline_width_mode": VrmMtoonBuilder.OutlineWidthMode.WORLD,
		"render_queue_offset": 3,
	})

	assert_eq(mat.render_priority, 3)


# ---------------------------------------------------------------------------
# shading_shift_texture_scale -> _ShadingGradeRate
# ---------------------------------------------------------------------------

func test_shading_grade_rate_defaults_to_one_when_scale_absent() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"shading_shift_texture": PlaceholderTexture2D.new(),
	})

	assert_eq(mat.get_shader_parameter("_ShadingGradeRate"), 1.0)


func test_shading_grade_rate_uses_parsed_scale() -> void:
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"shading_shift_texture": PlaceholderTexture2D.new(),
		"shading_shift_texture_scale": 0.35,
	})

	assert_eq(mat.get_shader_parameter("_ShadingGradeRate"), 0.35)


func test_shading_grade_rate_untouched_when_no_shading_shift_texture() -> void:
	# No shading_shift_texture key means the whole branch is skipped, so the material
	# never gets an explicit _ShadingGradeRate override - it falls through to the shader's
	# own declared default (1.0), which get_shader_parameter reports as null (it only
	# returns instance overrides, not shader-declared defaults).
	var mat: ShaderMaterial = VrmMtoonBuilder.build_body({
		"shading_shift_texture_scale": 0.35,
	})

	assert_null(mat.get_shader_parameter("_ShadingGradeRate"))
