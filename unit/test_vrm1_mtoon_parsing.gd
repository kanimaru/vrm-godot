extends GutTest

## Unit tests for the VRM 1.0 MToon material parser (_parse_vrm1_mtoon).
## All inputs are synthetic dictionaries — no proprietary assets required.
## _parse_vrm1_mtoon only accesses GLTFState for texture resolution.
## Tests that omit texture keys pass null for state safely.

var _ext: Vrm1Extension


func before_each() -> void:
	_ext = Vrm1Extension.new()


func after_each() -> void:
	_ext = null


## Builds a minimal VRM1 material JSON dict with the VRMC_materials_mtoon ext applied.
func _make_mat(ext_fields: Dictionary = {}, top_fields: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {
		"extensions": {
			"VRMC_materials_mtoon": ext_fields,
		},
	}
	for k: String in top_fields:
		d[k] = top_fields[k]
	return d


func _parse(mat_json: Dictionary) -> Dictionary:
	return _ext.call("_parse_vrm1_mtoon", mat_json, null)


# ---------------------------------------------------------------------------
# Alpha mode mapping
# ---------------------------------------------------------------------------

func test_alpha_mode_opaque_by_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.OPAQUE)


func test_alpha_mode_mask() -> void:
	var p: Dictionary = _parse(_make_mat({}, { "alphaMode": "MASK" }))

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.MASK)


func test_alpha_mode_blend() -> void:
	var p: Dictionary = _parse(_make_mat({}, { "alphaMode": "BLEND" }))

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.BLEND)


func test_alpha_mode_blend_zwrite_when_transparent_with_zwrite_true() -> void:
	var p: Dictionary = _parse(_make_mat(
		{ "transparentWithZWrite": true },
		{ "alphaMode": "BLEND" },
	))

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE)


func test_alpha_mode_blend_stays_blend_when_transparent_zwrite_false() -> void:
	var p: Dictionary = _parse(_make_mat(
		{ "transparentWithZWrite": false },
		{ "alphaMode": "BLEND" },
	))

	assert_eq(p["alpha_mode"], VrmMtoonBuilder.AlphaMode.BLEND)


func test_alpha_cutoff_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["alpha_cutoff"], 0.5)


func test_alpha_cutoff_explicit() -> void:
	var p: Dictionary = _parse(_make_mat({}, { "alphaCutoff": 0.25 }))

	assert_eq(p["alpha_cutoff"], 0.25)


# ---------------------------------------------------------------------------
# renderQueueOffsetNumber
# ---------------------------------------------------------------------------

func test_render_queue_offset_default_is_zero() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["render_queue_offset"], 0)


func test_render_queue_offset_explicit() -> void:
	var p: Dictionary = _parse(_make_mat({ "renderQueueOffsetNumber": -5 }))

	assert_eq(p["render_queue_offset"], -5)


# ---------------------------------------------------------------------------
# Double-sided
# ---------------------------------------------------------------------------

func test_double_sided_false_by_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_false(p["double_sided"])


func test_double_sided_true_when_set() -> void:
	var p: Dictionary = _parse(_make_mat({}, { "doubleSided": true }))

	assert_true(p["double_sided"])


# ---------------------------------------------------------------------------
# Base color (pbrMetallicRoughness.baseColorFactor)
# ---------------------------------------------------------------------------

func test_base_color_parsed_from_pbr() -> void:
	var p: Dictionary = _parse(_make_mat({}, {
		"pbrMetallicRoughness": {
			"baseColorFactor": [0.8, 0.6, 0.4, 1.0],
		},
	}))

	assert_true(p.has("base_color"))
	var c: Color = p["base_color"]
	assert_almost_eq(c.r, 0.8, 0.001)
	assert_almost_eq(c.g, 0.6, 0.001)
	assert_almost_eq(c.b, 0.4, 0.001)
	assert_almost_eq(c.a, 1.0, 0.001)


func test_base_color_absent_when_pbr_missing() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_false(p.has("base_color"))


# ---------------------------------------------------------------------------
# KHR_texture_transform
# ---------------------------------------------------------------------------

func test_khr_texture_transform_returns_correct_vector4() -> void:
	var texture_info: Dictionary = {
		"index": 0,
		"extensions": {
			"KHR_texture_transform": {
				"scale": [2.0, 3.0],
				"offset": [0.5, 0.25],
			},
		},
	}

	var result: Vector4 = _ext.call("_resolve_khr_texture_transform", texture_info)

	assert_eq(result, Vector4(2.0, 3.0, 0.5, 0.25))


func test_khr_texture_transform_returns_identity_when_absent() -> void:
	var texture_info: Dictionary = { "index": 0 }

	var result: Vector4 = _ext.call("_resolve_khr_texture_transform", texture_info)

	assert_eq(result, Vector4(1.0, 1.0, 0.0, 0.0))


# ---------------------------------------------------------------------------
# Shade color (shadeColorFactor)
# ---------------------------------------------------------------------------

func test_shade_color_parsed() -> void:
	var p: Dictionary = _parse(_make_mat({
		"shadeColorFactor": [0.9, 0.7, 0.7],
	}))

	assert_true(p.has("shade_color"))
	assert_almost_eq(p["shade_color"].r, 0.9, 0.001)


func test_shade_color_absent_when_key_missing() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_false(p.has("shade_color"))


# ---------------------------------------------------------------------------
# Shading shift / toony
# ---------------------------------------------------------------------------

func test_shading_shift_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["shading_shift_factor"], 0.0)


func test_shading_toony_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["shading_toony_factor"], 0.9)


func test_shading_values_explicit() -> void:
	var p: Dictionary = _parse(_make_mat({
		"shadingShiftFactor": -0.2,
		"shadingToonyFactor": 0.8,
	}))

	assert_eq(p["shading_shift_factor"], -0.2)
	assert_eq(p["shading_toony_factor"], 0.8)


func test_shading_shift_texture_scale_default_when_texture_absent() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_false(p.has("shading_shift_texture_scale"), "scale is a sub-property of the texture info - it should only appear when the texture itself is present")


func test_shading_shift_texture_scale_defaults_to_one_when_texture_present_without_scale() -> void:
	var p: Dictionary = _parse(_make_mat({
		"shadingShiftTexture": {},
	}))

	assert_eq(p["shading_shift_texture_scale"], 1.0)


func test_shading_shift_texture_scale_explicit() -> void:
	var p: Dictionary = _parse(_make_mat({
		"shadingShiftTexture": { "scale": 0.35 },
	}))

	assert_eq(p["shading_shift_texture_scale"], 0.35)


# ---------------------------------------------------------------------------
# GI equalization factor
# ---------------------------------------------------------------------------
# giEqualizationFactor has no compatible receptacle in the bundled shader (its
# _IndirectLightIntensity uniform is an unrelated "GI Intensity" knob with its own
# default/range - see vrm1_extension.gd). It must NOT flow into indirect_light_intensity;
# these tests guard against reintroducing that mis-mapping.

func test_gi_equalization_does_not_override_indirect_light_intensity() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_false(p.has("indirect_light_intensity"))


func test_gi_equalization_explicit_still_not_mapped() -> void:
	var p: Dictionary = _parse(_make_mat({ "giEqualizationFactor": 0.5 }))

	assert_false(p.has("indirect_light_intensity"))


# ---------------------------------------------------------------------------
# Emissive (top-level glTF fields)
# ---------------------------------------------------------------------------

func test_emissive_color_parsed() -> void:
	var p: Dictionary = _parse(_make_mat({}, {
		"emissiveFactor": [0.0, 0.5, 1.0],
	}))

	assert_true(p.has("emissive_color"))
	assert_eq(p["emissive_color"].b, 1.0)


func test_emissive_color_absent_when_key_missing() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_false(p.has("emissive_color"))


# ---------------------------------------------------------------------------
# Emissive multiplier
# (VRMC_materials_hdr_emissiveMultiplier / KHR_materials_emissive_strength — both are
# siblings of VRMC_materials_mtoon under material.extensions, not nested inside it)
# ---------------------------------------------------------------------------

func test_emissive_multiplier_defaults_to_one_when_no_extension_present() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["emissive_multiplier"], 1.0)


func test_emissive_multiplier_parsed_from_vrmc_hdr_extension() -> void:
	var mat_json: Dictionary = _make_mat()
	mat_json["extensions"]["VRMC_materials_hdr_emissiveMultiplier"] = { "emissiveMultiplier": 3.5 }
	var p: Dictionary = _parse(mat_json)

	assert_eq(p["emissive_multiplier"], 3.5)


func test_emissive_multiplier_parsed_from_khr_emissive_strength_fallback() -> void:
	var mat_json: Dictionary = _make_mat()
	mat_json["extensions"]["KHR_materials_emissive_strength"] = { "emissiveStrength": 2.0 }
	var p: Dictionary = _parse(mat_json)

	assert_eq(p["emissive_multiplier"], 2.0)


func test_emissive_multiplier_prefers_vrmc_hdr_over_khr_when_both_present() -> void:
	var mat_json: Dictionary = _make_mat()
	mat_json["extensions"]["VRMC_materials_hdr_emissiveMultiplier"] = { "emissiveMultiplier": 3.5 }
	mat_json["extensions"]["KHR_materials_emissive_strength"] = { "emissiveStrength": 2.0 }
	var p: Dictionary = _parse(mat_json)

	assert_eq(p["emissive_multiplier"], 3.5)


# ---------------------------------------------------------------------------
# Rim
# ---------------------------------------------------------------------------

func test_rim_color_parsed() -> void:
	var p: Dictionary = _parse(_make_mat({
		"parametricRimColorFactor": [1.0, 0.0, 0.5],
	}))

	assert_true(p.has("rim_color"))
	assert_eq(p["rim_color"].r, 1.0)


func test_rim_fresnel_power_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["rim_fresnel_power"], 5.0)


func test_rim_lift_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["rim_lift"], 0.0)


func test_rim_lighting_mix_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["rim_lighting_mix"], 1.0)


# ---------------------------------------------------------------------------
# Outline width mode string mapping
# ---------------------------------------------------------------------------

func test_outline_mode_none_by_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["outline_width_mode"], VrmMtoonBuilder.OutlineWidthMode.NONE)


func test_outline_mode_world_coordinates() -> void:
	var p: Dictionary = _parse(_make_mat({ "outlineWidthMode": "worldCoordinates" }))

	assert_eq(p["outline_width_mode"], VrmMtoonBuilder.OutlineWidthMode.WORLD)


func test_outline_mode_screen_coordinates() -> void:
	var p: Dictionary = _parse(_make_mat({ "outlineWidthMode": "screenCoordinates" }))

	assert_eq(p["outline_width_mode"], VrmMtoonBuilder.OutlineWidthMode.SCREEN)


func test_outline_mode_none_explicit() -> void:
	var p: Dictionary = _parse(_make_mat({ "outlineWidthMode": "none" }))

	assert_eq(p["outline_width_mode"], VrmMtoonBuilder.OutlineWidthMode.NONE)


func test_outline_width_default() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["outline_width"], 0.0)


# ---------------------------------------------------------------------------
# UV animation
# ---------------------------------------------------------------------------

func test_uv_animation_defaults() -> void:
	var p: Dictionary = _parse(_make_mat())

	assert_eq(p["uv_anim_scroll_x"], 0.0)
	assert_eq(p["uv_anim_scroll_y"], 0.0)
	assert_eq(p["uv_anim_rotation"], 0.0)


func test_uv_animation_explicit() -> void:
	var p: Dictionary = _parse(_make_mat({
		"uvAnimationScrollXSpeedFactor": 0.3,
		"uvAnimationScrollYSpeedFactor": -0.1,
		"uvAnimationRotationSpeedFactor": 2.0,
	}))

	assert_eq(p["uv_anim_scroll_x"], 0.3)
	assert_eq(p["uv_anim_scroll_y"], -0.1)
	assert_eq(p["uv_anim_rotation"], 2.0)
