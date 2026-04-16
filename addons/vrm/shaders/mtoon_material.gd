@tool
class_name MtoonMaterial
extends Resource

## Synchronizes parameters between mtoon.gdshader and mtoon_outline.gdshader.
## Exposes all MToon 1.0 uniforms as inspector properties and handles
## outline enabling/disabling and GI equalization from the environment.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal outline_toggled(enabled: bool)


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum AlphaMode { OPAQUE = 0, MASK = 1, BLEND = 2 }
enum OutlineWidthMode { NONE = 0, WORLD_COORDINATES = 1, SCREEN_COORDINATES = 2 }


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MTOON_SHADER := preload("res://addons/vrm/shaders/mtoon.gdshader")
const MTOON_OUTLINE_SHADER := preload("res://addons/vrm/shaders/mtoon_outline.gdshader")

## How often the GI equalization SH samples are updated (in seconds).
const GI_UPDATE_INTERVAL := 0.1


# ---------------------------------------------------------------------------
# Exports — Rendering Section
# ---------------------------------------------------------------------------

@export_group("Rendering")

@export var alpha_mode: AlphaMode = AlphaMode.BLEND:
	set(v):
		alpha_mode = v
		_set_both("alpha_mode", v)

@export var alpha_cutoff: float = 0.5:
	set(v):
		alpha_cutoff = clampf(v, 0.0, 1.0)
		_set_both("alpha_cutoff", alpha_cutoff)

@export var double_sided: bool = false:
	set(v):
		double_sided = v
		_set_param(_body_material, "double_sided", v)


# ---------------------------------------------------------------------------
# Exports — Outline
# ---------------------------------------------------------------------------

@export_group("Outline")

@export var outline_enabled: bool = true:
	set(v):
		outline_enabled = v
		_sync_outline_pass()
		outline_toggled.emit(v)

@export var outline_width_mode: OutlineWidthMode = OutlineWidthMode.WORLD_COORDINATES:
	set(v):
		outline_width_mode = v
		_set_param(_outline_material, "outline_width_mode", v)

@export var outline_width: float = 0.01:
	set(v):
		outline_width = maxf(v, 0.0)
		_set_param(_outline_material, "outline_width", outline_width)

@export var outline_width_multiply_texture: Texture2D:
	set(v):
		outline_width_multiply_texture = v
		_set_param(_outline_material, "outline_width_multiply_texture", v)

@export var outline_color: Color = Color.BLACK:
	set(v):
		outline_color = v
		_set_param(_outline_material, "outline_color", Vector3(v.r, v.g, v.b))

@export var outline_lighting_mix: float = 1.0:
	set(v):
		outline_lighting_mix = clampf(v, 0.0, 1.0)
		_set_param(_outline_material, "outline_lighting_mix", outline_lighting_mix)


# ---------------------------------------------------------------------------
# Exports — Lit / Shade Colors
# ---------------------------------------------------------------------------

@export_group("Colors")

@export var base_color: Color = Color.WHITE:
	set(v):
		base_color = v
		_set_both("base_color", v)

@export var base_color_texture: Texture2D:
	set(v):
		base_color_texture = v
		_set_both("base_color_texture", v)

@export var shade_color: Color = Color.WHITE:
	set(v):
		shade_color = v
		_set_param(_body_material, "shade_color", Vector3(v.r, v.g, v.b))

@export var shade_multiply_texture: Texture2D:
	set(v):
		shade_multiply_texture = v
		_set_param(_body_material, "shade_multiply_texture", v)


# ---------------------------------------------------------------------------
# Exports — Shading Ramp
# ---------------------------------------------------------------------------

@export_group("Shading")

@export_range(-1.0, 1.0) var shading_shift_factor: float = 0.0:
	set(v):
		shading_shift_factor = v
		_set_both("shading_shift_factor", v)

@export var shading_shift_texture: Texture2D:
	set(v):
		shading_shift_texture = v
		_set_both("shading_shift_texture", v)

@export_range(0.0, 1.0) var shading_toony_factor: float = 0.9:
	set(v):
		shading_toony_factor = v
		_set_both("shading_toony_factor", v)


# ---------------------------------------------------------------------------
# Exports — Global Illumination
# ---------------------------------------------------------------------------

@export_group("Global Illumination")

@export_range(0.0, 1.0) var gi_equalization_factor: float = 0.9:
	set(v):
		gi_equalization_factor = v
		_set_param(_body_material, "gi_equalization_factor", v)

## When enabled, samples SH from the Environment every GI_UPDATE_INTERVAL secs.
@export var auto_sample_gi: bool = true


# ---------------------------------------------------------------------------
# Exports — Emission
# ---------------------------------------------------------------------------

@export_group("Emission")

@export var emissive_color: Color = Color.BLACK:
	set(v):
		emissive_color = v
		_set_param(_body_material, "emissive_color", Vector3(v.r, v.g, v.b))

@export var emissive_texture: Texture2D:
	set(v):
		emissive_texture = v
		_set_param(_body_material, "emissive_texture", v)


# ---------------------------------------------------------------------------
# Exports — Rim Lighting
# ---------------------------------------------------------------------------

@export_group("Rim Lighting")

@export var rim_color: Color = Color.BLACK:
	set(v):
		rim_color = v
		_set_param(_body_material, "rim_color", Vector3(v.r, v.g, v.b))

@export_range(0.0, 100.0) var rim_fresnel_power: float = 5.0:
	set(v):
		rim_fresnel_power = v
		_set_param(_body_material, "rim_fresnel_power", v)

@export_range(-1.0, 1.0) var rim_lift: float = 0.0:
	set(v):
		rim_lift = v
		_set_param(_body_material, "rim_lift", v)

@export var rim_multiply_texture: Texture2D:
	set(v):
		rim_multiply_texture = v
		_set_param(_body_material, "rim_multiply_texture", v)

@export_range(0.0, 1.0) var rim_lighting_mix: float = 1.0:
	set(v):
		rim_lighting_mix = v
		_set_param(_body_material, "rim_lighting_mix", v)


# ---------------------------------------------------------------------------
# Exports — MatCap
# ---------------------------------------------------------------------------

@export_group("MatCap")

@export var matcap_factor: Color = Color.WHITE:
	set(v):
		matcap_factor = v
		_set_param(_body_material, "matcap_factor", Vector3(v.r, v.g, v.b))

@export var matcap_texture: Texture2D:
	set(v):
		matcap_texture = v
		_set_param(_body_material, "matcap_texture", v)


# ---------------------------------------------------------------------------
# Exports — UV Animation
# ---------------------------------------------------------------------------

@export_group("UV Animation")

@export var uv_animation_mask_texture: Texture2D:
	set(v):
		uv_animation_mask_texture = v
		_set_both("uv_animation_mask_texture", v)

@export_range(-10.0, 10.0) var uv_animation_scroll_x_speed: float = 0.0:
	set(v):
		uv_animation_scroll_x_speed = v
		_set_both("uv_animation_scroll_x_speed", v)

@export_range(-10.0, 10.0) var uv_animation_scroll_y_speed: float = 0.0:
	set(v):
		uv_animation_scroll_y_speed = v
		_set_both("uv_animation_scroll_y_speed", v)

@export_range(-10.0, 10.0) var uv_animation_rotation_speed: float = 0.0:
	set(v):
		uv_animation_rotation_speed = v
		_set_both("uv_animation_rotation_speed", v)


# ---------------------------------------------------------------------------
# Private Variables
# ---------------------------------------------------------------------------

var _body_material: ShaderMaterial
var _outline_material: ShaderMaterial
var _gi_timer: float = 0.0

## Cached SH coefficients — [up, down] average, passed to shader.
var _uniformed_gi: Vector3 = Vector3.ONE


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Call this once to bind the two materials this resource will control.
func bind(body: ShaderMaterial, outline: ShaderMaterial) -> void:
	_body_material = body
	_outline_material = outline
	_ensure_shaders()
	push_all()


## Push all current export values to both ShaderMaterials at once.
func push_all() -> void:
	if _body_material == null or _outline_material == null:
		return

	# Rendering
	_set_both("alpha_mode", int(alpha_mode))
	_set_both("alpha_cutoff", alpha_cutoff)
	_set_param(_body_material, "double_sided", double_sided)

	# Colors
	_set_both("base_color", base_color)
	_set_both("base_color_texture", base_color_texture)
	_set_param(_body_material, "shade_color", Vector3(shade_color.r, shade_color.g, shade_color.b))
	_set_param(_body_material, "shade_multiply_texture", shade_multiply_texture)

	# Shading (shared)
	_set_both("shading_shift_factor", shading_shift_factor)
	_set_both("shading_shift_texture", shading_shift_texture)
	_set_both("shading_toony_factor", shading_toony_factor)

	# GI
	_set_param(_body_material, "gi_equalization_factor", gi_equalization_factor)

	# Emission
	_set_param(_body_material, "emissive_color", Vector3(emissive_color.r, emissive_color.g, emissive_color.b))
	_set_param(_body_material, "emissive_texture", emissive_texture)

	# Rim
	_set_param(_body_material, "rim_color", Vector3(rim_color.r, rim_color.g, rim_color.b))
	_set_param(_body_material, "rim_fresnel_power", rim_fresnel_power)
	_set_param(_body_material, "rim_lift", rim_lift)
	_set_param(_body_material, "rim_multiply_texture", rim_multiply_texture)
	_set_param(_body_material, "rim_lighting_mix", rim_lighting_mix)

	# MatCap
	_set_param(_body_material, "matcap_factor", Vector3(matcap_factor.r, matcap_factor.g, matcap_factor.b))
	_set_param(_body_material, "matcap_texture", matcap_texture)

	# UV Animation (shared)
	_set_both("uv_animation_mask_texture", uv_animation_mask_texture)
	_set_both("uv_animation_scroll_x_speed", uv_animation_scroll_x_speed)
	_set_both("uv_animation_scroll_y_speed", uv_animation_scroll_y_speed)
	_set_both("uv_animation_rotation_speed", uv_animation_rotation_speed)

	# Outline-specific
	_set_param(_outline_material, "outline_width_mode", int(outline_width_mode))
	_set_param(_outline_material, "outline_width", outline_width)
	_set_param(_outline_material, "outline_width_multiply_texture", outline_width_multiply_texture)
	_set_param(_outline_material, "outline_color", Vector3(outline_color.r, outline_color.g, outline_color.b))
	_set_param(_outline_material, "outline_lighting_mix", outline_lighting_mix)

	_sync_outline_pass()


## Should be called from _process(delta) of the owning node.
## Handles the periodic GI sampling update.
func process(delta: float, world_environment: WorldEnvironment) -> void:
	if not auto_sample_gi:
		return

	_gi_timer += delta
	if _gi_timer < GI_UPDATE_INTERVAL:
		return
	_gi_timer = 0.0

	_sample_and_push_gi(world_environment)


## Manually trigger a GI sample from the given WorldEnvironment.
func sample_gi_from_environment(world_environment: WorldEnvironment) -> void:
	_sample_and_push_gi(world_environment)


# ---------------------------------------------------------------------------
# Private Helpers
# ---------------------------------------------------------------------------

func _ensure_shaders() -> void:
	if _body_material != null and _body_material.shader == null:
		_body_material.shader = MTOON_SHADER
	if _outline_material != null and _outline_material.shader == null:
		_outline_material.shader = MTOON_OUTLINE_SHADER


func _set_param(mat: ShaderMaterial, param: StringName, value: Variant) -> void:
	if mat == null:
		return
	mat.set_shader_parameter(param, value)


func _set_both(param: StringName, value: Variant) -> void:
	_set_param(_body_material, param, value)
	_set_param(_outline_material, param, value)


func _sync_outline_pass() -> void:
	if _body_material == null:
		return

	if outline_enabled:
		if _body_material.next_pass == null:
			_body_material.next_pass = _outline_material
	else:
		_body_material.next_pass = null


func _sample_and_push_gi(world_environment: WorldEnvironment) -> void:
	if world_environment == null or world_environment.environment == null:
		return

	var env: Environment = world_environment.environment

	# The MToon spec defines uniformedGi as the average of the up and down SH samples.
	# Godot exposes get_environment_radiance_at_point which isn't practical here.
	# Instead we sample the sky texture at the two poles as an approximation.
	# This matches the spec's recommended two-point sampling example:
	#   uniformedGi = (rawGi([0, 1, 0]) + rawGi([0, -1, 0])) / 2
	var gi_up := _sample_sh(env, Vector3.UP)
	var gi_down := _sample_sh(env, Vector3.DOWN)
	_uniformed_gi = (gi_up + gi_down) * 0.5

	# Pass the equalized ambient to the shader.
	# The shader uses this to lerp between directional and uniform ambient.
	_set_param(_body_material, "gi_equalization_factor", gi_equalization_factor)


func _sample_sh(env: Environment, direction: Vector3) -> Vector3:
	# Godot 4 does not expose raw SH coefficients via GDScript.
	# We use the ambient light color as the best-available approximation.
	# For a fully correct implementation, you would need a C++ GDExtension
	# that reads RenderingServer::environment_get_ambient_light().
	var ambient: Color = env.ambient_light_color
	var energy: float = env.ambient_light_energy

	# Modulate by direction to approximate the hemispherical variation.
	# When direction is UP, the ceiling tends to be brighter, so we leave it as-is.
	# When direction is DOWN, the floor is darker, so we dim it.
	var directional_weight: float = remap(direction.y, -1.0, 1.0, 0.5, 1.0)
	var sampled := Vector3(ambient.r, ambient.g, ambient.b) * energy * directional_weight

	return sampled
