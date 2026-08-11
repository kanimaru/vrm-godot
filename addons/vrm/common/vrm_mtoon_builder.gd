@tool
extends RefCounted
class_name VrmMtoonBuilder

## Builds ShaderMaterials backed by addons/Godot-MToon-Shader for VRM avatars.
## Selects the correct shader variant (opaque / cutout / transparent × ZWrite × cull)
## and populates all uniforms using the addon's underscore-prefixed naming convention.

# ---------------------------------------------------------------------------
# Shader preloads — all variants from the reference addon.
# ---------------------------------------------------------------------------

const _ADDON_BASE := "res://addons/Godot-MToon-Shader/"

const _SH_OPAQUE := preload("res://addons/Godot-MToon-Shader/mtoon.gdshader")
const _SH_OPAQUE_CULL_OFF := preload("res://addons/Godot-MToon-Shader/mtoon_cull_off.gdshader")
const _SH_CUTOUT := preload("res://addons/Godot-MToon-Shader/mtoon_cutout.gdshader")
const _SH_CUTOUT_CULL_OFF := preload("res://addons/Godot-MToon-Shader/mtoon_cutout_cull_off.gdshader")
const _SH_TRANS := preload("res://addons/Godot-MToon-Shader/mtoon_trans.gdshader")
const _SH_TRANS_CULL_OFF := preload("res://addons/Godot-MToon-Shader/mtoon_trans_cull_off.gdshader")
const _SH_TRANS_ZWRITE := preload("res://addons/Godot-MToon-Shader/mtoon_trans_zwrite.gdshader")
const _SH_TRANS_ZWRITE_CULL_OFF := preload("res://addons/Godot-MToon-Shader/mtoon_trans_zwrite_cull_off.gdshader")
const _SH_OUTLINE := preload("res://addons/Godot-MToon-Shader/mtoon_outline.gdshader")
const _SH_OUTLINE_CUTOUT := preload("res://addons/Godot-MToon-Shader/mtoon_outline_cutout.gdshader")
const _SH_OUTLINE_TRANS := preload("res://addons/Godot-MToon-Shader/mtoon_outline_trans.gdshader")
const _SH_OUTLINE_TRANS_ZWRITE := preload("res://addons/Godot-MToon-Shader/mtoon_outline_trans_zwrite.gdshader")


# ---------------------------------------------------------------------------
# Alpha / Cull mode enums (mirrors what the parsers produce)
# ---------------------------------------------------------------------------

enum AlphaMode { OPAQUE = 0, MASK = 1, BLEND = 2, BLEND_ZWRITE = 3 }
enum OutlineWidthMode { NONE = 0, WORLD = 1, SCREEN = 2 }


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

## Builds a body ShaderMaterial from a raw parameter dictionary.
## @param p  Parsed parameter dict — see _ParamBag below.
## @returns  Configured ShaderMaterial with the correct shader variant and all uniforms set.
static func build_body(p: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _pick_body_shader(p.get("alpha_mode", AlphaMode.OPAQUE), p.get("double_sided", false))
	_apply_all(mat, p)
	return mat


## Builds a matching outline ShaderMaterial (returns null when outline is disabled).
## It copies the shared parameters from the body and adds outline-specific ones.
static func build_outline(p: Dictionary) -> ShaderMaterial:
	var mode: int = p.get("outline_width_mode", OutlineWidthMode.NONE)
	if mode == OutlineWidthMode.NONE:
		return null

	var mat := ShaderMaterial.new()
	mat.shader = _pick_outline_shader(p.get("alpha_mode", AlphaMode.OPAQUE))
	_apply_all(mat, p)
	return mat


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _pick_body_shader(alpha_mode: int, double_sided: bool) -> Shader:
	match alpha_mode:
		AlphaMode.MASK:
			return _SH_CUTOUT_CULL_OFF if double_sided else _SH_CUTOUT
		AlphaMode.BLEND:
			return _SH_TRANS_CULL_OFF if double_sided else _SH_TRANS
		AlphaMode.BLEND_ZWRITE:
			return _SH_TRANS_ZWRITE_CULL_OFF if double_sided else _SH_TRANS_ZWRITE
		_:  # OPAQUE
			return _SH_OPAQUE_CULL_OFF if double_sided else _SH_OPAQUE


static func _pick_outline_shader(alpha_mode: int) -> Shader:
	match alpha_mode:
		AlphaMode.MASK:
			return _SH_OUTLINE_CUTOUT
		AlphaMode.BLEND, AlphaMode.BLEND_ZWRITE:
			return _SH_OUTLINE_TRANS_ZWRITE if alpha_mode == AlphaMode.BLEND_ZWRITE else _SH_OUTLINE_TRANS
		_:
			return _SH_OUTLINE


## Writes all parameters from the bag to a ShaderMaterial using the
## reference addon's uniform naming convention (_Color, _ShadeColor, …).
static func _apply_all(mat: ShaderMaterial, p: Dictionary) -> void:
	# --- Alpha ---
	var alpha_mode: int = p.get("alpha_mode", AlphaMode.OPAQUE)
	# _AlphaCutoutEnable: 0=opaque/blend, 1=cutout
	var cutout_enable: float = 1.0 if alpha_mode == AlphaMode.MASK else 0.0
	mat.set_shader_parameter("_AlphaCutoutEnable", cutout_enable)
	mat.set_shader_parameter("_Cutoff", float(p.get("alpha_cutoff", 0.5)))

	# render_priority (not a shader uniform - a base Material property): offsets draw
	# order for transparent materials, only meaningful when alpha_mode is BLEND per spec.
	# Godot clamps to [-128, 127], well within the spec's authored [-9, +9] range.
	mat.render_priority = int(p.get("render_queue_offset", 0))

	# --- Base color / Lit ---
	var base_color: Color = p.get("base_color", Color.WHITE)
	mat.set_shader_parameter("_Color", base_color)
	if p.has("base_color_texture") and p["base_color_texture"] != null:
		mat.set_shader_parameter("_MainTex", p["base_color_texture"])

	# UV scale/offset (default = no transform)
	mat.set_shader_parameter("_MainTex_ST", p.get("uv_st", Vector4(1, 1, 0, 0)))

	# --- Shade color ---
	var shade_color: Color = p.get("shade_color", Color(0.97, 0.81, 0.86, 1.0))
	mat.set_shader_parameter("_ShadeColor", shade_color)
	if p.has("shade_texture") and p["shade_texture"] != null:
		mat.set_shader_parameter("_ShadeTexture", p["shade_texture"])

	# --- Shading ramp ---
	mat.set_shader_parameter("_ShadeShift", float(p.get("shading_shift_factor", 0.0)))
	mat.set_shader_parameter("_ShadeToony", float(p.get("shading_toony_factor", 0.9)))
	if p.has("shading_shift_texture") and p["shading_shift_texture"] != null:
		mat.set_shader_parameter("_ShadingGradeTexture", p["shading_shift_texture"])
		# shadingShiftTextureInfo.scale: how much this texture contributes to the shading
		# boundary shift (spec default 1.0, matching _ShadingGradeRate's own shader default).
		mat.set_shader_parameter("_ShadingGradeRate", float(p.get("shading_shift_texture_scale", 1.0)))
	if p.has("receive_shadow_texture") and p["receive_shadow_texture"] != null:
		mat.set_shader_parameter("_ReceiveShadowTexture", p["receive_shadow_texture"])
		mat.set_shader_parameter("_ReceiveShadowRate", 1.0)

	# --- Normal map ---
	if p.has("normal_map_texture") and p["normal_map_texture"] != null:
		mat.set_shader_parameter("_BumpMap", p["normal_map_texture"])
		mat.set_shader_parameter("_BumpScale", float(p.get("normal_map_scale", 1.0)))

	# --- GI / Indirect ---
	mat.set_shader_parameter("_IndirectLightIntensity", float(p.get("indirect_light_intensity", 0.1)))

	# --- Emission ---
	var emissive: Color = p.get("emissive_color", Color.BLACK)
	mat.set_shader_parameter("_EmissionColor", emissive)
	mat.set_shader_parameter("_EmissionMultiplier", float(p.get("emissive_multiplier", 1.0)))
	if p.has("emissive_texture") and p["emissive_texture"] != null:
		mat.set_shader_parameter("_EmissionMap", p["emissive_texture"])

	# --- MatCap ---
	var matcap_color: Color = p.get("matcap_color", Color.BLACK)
	mat.set_shader_parameter("_MatcapColor", matcap_color)
	if p.has("matcap_texture") and p["matcap_texture"] != null:
		mat.set_shader_parameter("_SphereAdd", p["matcap_texture"])

	# --- Rim ---
	var rim_color: Color = p.get("rim_color", Color.BLACK)
	mat.set_shader_parameter("_RimColor", rim_color)
	mat.set_shader_parameter("_RimFresnelPower", float(p.get("rim_fresnel_power", 5.0)))
	mat.set_shader_parameter("_RimLift", float(p.get("rim_lift", 0.0)))
	mat.set_shader_parameter("_RimLightingMix", float(p.get("rim_lighting_mix", 1.0)))
	if p.has("rim_texture") and p["rim_texture"] != null:
		mat.set_shader_parameter("_RimTexture", p["rim_texture"])

	# --- Outline ---
	var outline_mode: int = p.get("outline_width_mode", OutlineWidthMode.NONE)
	mat.set_shader_parameter("_OutlineWidthMode", float(outline_mode))
	mat.set_shader_parameter("_OutlineWidth", float(p.get("outline_width", 0.0)))
	var outline_color: Color = p.get("outline_color", Color.BLACK)
	mat.set_shader_parameter("_OutlineColor", outline_color)
	mat.set_shader_parameter("_OutlineLightingMix", float(p.get("outline_lighting_mix", 1.0)))
	mat.set_shader_parameter("_OutlineScaledMaxDistance", float(p.get("outline_scaled_max_distance", 1.0)))
	# _OutlineColorMode: 0=FixedColor, 1=MixedLighting
	mat.set_shader_parameter("_OutlineColorMode", float(p.get("outline_color_mode", 0)))
	if p.has("outline_width_texture") and p["outline_width_texture"] != null:
		mat.set_shader_parameter("_OutlineWidthTexture", p["outline_width_texture"])

	# --- UV Animation ---
	mat.set_shader_parameter("_UvAnimScrollX", float(p.get("uv_anim_scroll_x", 0.0)))
	mat.set_shader_parameter("_UvAnimScrollY", float(p.get("uv_anim_scroll_y", 0.0)))
	mat.set_shader_parameter("_UvAnimRotation", float(p.get("uv_anim_rotation", 0.0)))
	if p.has("uv_anim_mask_texture") and p["uv_anim_mask_texture"] != null:
		mat.set_shader_parameter("_UvAnimMaskTexture", p["uv_anim_mask_texture"])
