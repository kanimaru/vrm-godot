extends GutTest

## Unit tests for the VRM 0.0 MToon material parser (_parse_vrm0_mtoon).
## All inputs are synthetic dictionaries — no proprietary assets required.
## _parse_vrm0_mtoon does not call _resolve_vrm0_texture when no texture keys
## are present, so passing null for GLTFState is safe for these pure-dict tests.

var _ext: Vrm0Extension


func before_each() -> void:
	_ext = Vrm0Extension.new()


func after_each() -> void:
	_ext = null


func _parse(props: Dictionary) -> Dictionary:
	# GLTFState is only accessed when texture keys are present.
	# These tests contain no texture keys, so passing null is safe.
	return _ext.call("_parse_vrm0_mtoon", props, null)


# ---------------------------------------------------------------------------
# Alpha mode mapping  (_BlendMode)
# ---------------------------------------------------------------------------

func test_alpha_mode_opaque_by_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.OPAQUE)


func test_alpha_mode_mask_when_blend_mode_1() -> void:
	var p: Dictionary = _parse({ "floatProperties": { "_BlendMode": 1.0 } })

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.MASK)


func test_alpha_mode_blend_when_blend_mode_2() -> void:
	var p: Dictionary = _parse({ "floatProperties": { "_BlendMode": 2.0 } })

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.BLEND)


func test_alpha_mode_blend_zwrite_when_blend_mode_3() -> void:
	var p: Dictionary = _parse({ "floatProperties": { "_BlendMode": 3.0 } })

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE)


func test_alpha_cutoff_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["alpha_cutoff"], 0.5)


func test_alpha_cutoff_explicit() -> void:
	var p: Dictionary = _parse({ "floatProperties": { "_Cutoff": 0.3 } })

	assert_eq(p["alpha_cutoff"], 0.3)


# ---------------------------------------------------------------------------
# Double-sided  (_CullMode)
# ---------------------------------------------------------------------------

func test_double_sided_false_when_cull_mode_2() -> void:
	var p: Dictionary = _parse({ "floatProperties": { "_CullMode": 2.0 } })

	assert_false(p["double_sided"])


func test_double_sided_true_when_cull_mode_0() -> void:
	var p: Dictionary = _parse({ "floatProperties": { "_CullMode": 0.0 } })

	assert_true(p["double_sided"])


func test_double_sided_false_by_default() -> void:
	# Default _CullMode is 2 (back-face culling).
	var p: Dictionary = _parse({})

	assert_false(p["double_sided"])


# ---------------------------------------------------------------------------
# Base color  (_Color)
# ---------------------------------------------------------------------------

func test_base_color_parsed_from_vector_properties() -> void:
	var p: Dictionary = _parse({
		"vectorProperties": { "_Color": [0.5, 0.25, 0.1, 1.0] },
	})

	assert_true(p.has("base_color"))
	var c: Color = p["base_color"]
	assert_almost_eq(c.r, 0.5, 0.001)
	assert_almost_eq(c.g, 0.25, 0.001)
	assert_almost_eq(c.b, 0.1, 0.001)
	assert_almost_eq(c.a, 1.0, 0.001)


func test_base_color_absent_when_key_missing() -> void:
	var p: Dictionary = _parse({})

	assert_false(p.has("base_color"))


# ---------------------------------------------------------------------------
# Shade color  (_ShadeColor)
# ---------------------------------------------------------------------------

func test_shade_color_parsed() -> void:
	var p: Dictionary = _parse({
		"vectorProperties": { "_ShadeColor": [0.9, 0.8, 0.85, 1.0] },
	})

	assert_true(p.has("shade_color"))
	var c: Color = p["shade_color"]
	assert_almost_eq(c.r, 0.9, 0.001)


func test_shade_color_absent_when_key_missing() -> void:
	var p: Dictionary = _parse({})

	assert_false(p.has("shade_color"))


# ---------------------------------------------------------------------------
# Shading ramp
# ---------------------------------------------------------------------------

func test_shading_shift_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["shading_shift_factor"], 0.0)


func test_shading_toony_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["shading_toony_factor"], 0.9)


func test_shading_values_explicit() -> void:
	var p: Dictionary = _parse({
		"floatProperties": { "_ShadeShift": -0.3, "_ShadeToony": 0.75 },
	})

	assert_eq(p["shading_shift_factor"], -0.3)
	assert_eq(p["shading_toony_factor"], 0.75)


# ---------------------------------------------------------------------------
# Rim  (_RimColor, _RimFresnelPower, _RimLift, _RimLightingMix)
# ---------------------------------------------------------------------------

func test_rim_color_parsed() -> void:
	var p: Dictionary = _parse({
		"vectorProperties": { "_RimColor": [0.0, 0.5, 1.0, 1.0] },
	})

	assert_true(p.has("rim_color"))
	assert_eq(p["rim_color"].b, 1.0)


func test_rim_fresnel_power_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["rim_fresnel_power"], 5.0)


func test_rim_lift_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["rim_lift"], 0.0)


func test_rim_lighting_mix_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["rim_lighting_mix"], 1.0)


# ---------------------------------------------------------------------------
# Outline  (_OutlineWidthMode, _OutlineWidth, _OutlineColor, etc.)
# ---------------------------------------------------------------------------

func test_outline_width_mode_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["outline_width_mode"], 0)


func test_outline_width_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["outline_width"], 0.0)


func test_outline_color_parsed() -> void:
	var p: Dictionary = _parse({
		"vectorProperties": { "_OutlineColor": [0.1, 0.2, 0.3, 1.0] },
	})

	assert_true(p.has("outline_color"))
	assert_almost_eq(p["outline_color"].r, 0.1, 0.001)


# ---------------------------------------------------------------------------
# UV animation
# ---------------------------------------------------------------------------

func test_uv_animation_defaults() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["uv_anim_scroll_x"], 0.0)
	assert_eq(p["uv_anim_scroll_y"], 0.0)
	assert_eq(p["uv_anim_rotation"], 0.0)


func test_uv_animation_explicit() -> void:
	var p: Dictionary = _parse({
		"floatProperties": {
			"_UvAnimScrollX": 0.5,
			"_UvAnimScrollY": -0.25,
			"_UvAnimRotation": 1.0,
		},
	})

	assert_eq(p["uv_anim_scroll_x"], 0.5)
	assert_eq(p["uv_anim_scroll_y"], -0.25)
	assert_eq(p["uv_anim_rotation"], 1.0)


# ---------------------------------------------------------------------------
# GI / Indirect light
# ---------------------------------------------------------------------------

func test_indirect_light_intensity_default() -> void:
	var p: Dictionary = _parse({})

	assert_eq(p["indirect_light_intensity"], 0.1)


func test_indirect_light_intensity_explicit() -> void:
	var p: Dictionary = _parse({
		"floatProperties": { "_IndirectLightIntensity": 0.4 },
	})

	assert_eq(p["indirect_light_intensity"], 0.4)


# ---------------------------------------------------------------------------
# Empty input — no crash
# ---------------------------------------------------------------------------

func test_empty_float_vector_texture_dicts_no_crash() -> void:
	var p: Dictionary = _parse({
		"floatProperties": {},
		"vectorProperties": {},
		"textureProperties": {},
	})

	# Should at least produce the alpha mode and other mandatory keys.
	assert_true(p.has("alpha_mode"))
	assert_true(p.has("double_sided"))
