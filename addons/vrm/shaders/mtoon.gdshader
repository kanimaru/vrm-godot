shader_type spatial;

/*
 * VRMC_materials_mtoon 1.0 Implementation for Godot 4.x
 * Step 10: Fixing Ambient / GI, MatCap UVs, Rim Lighting Mix
 */

render_mode blend_mix, depth_draw_always, cull_disabled;

// --- Uniforms ---

group_uniforms rendering;
uniform int alpha_mode : hint_range(0, 2) = 2;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform bool double_sided = false;

group_uniforms base_color_lit;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_color_texture : source_color, hint_default_white;

group_uniforms shade_color_unlit;
uniform vec3 shade_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D shade_multiply_texture : source_color, hint_default_white;

group_uniforms shading;
uniform float shading_shift_factor : hint_range(-1.0, 1.0) = 0.0;
uniform sampler2D shading_shift_texture : hint_default_black;
uniform float shading_toony_factor : hint_range(0.0, 1.0) = 0.9;

group_uniforms global_illumination;
// giEqualizationFactor: 0 = raw GI, 1 = fully uniform (flat ambient)
uniform float gi_equalization_factor : hint_range(0.0, 1.0) = 0.9;

group_uniforms emission;
uniform vec3 emissive_color : source_color = vec3(0.0, 0.0, 0.0);
uniform sampler2D emissive_texture : source_color, hint_default_white;

group_uniforms rim_lighting;
uniform vec3 rim_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float rim_fresnel_power : hint_range(0.0, 100.0) = 5.0;
uniform float rim_lift : hint_range(-1.0, 1.0) = 0.0;
uniform sampler2D rim_multiply_texture : source_color, hint_default_white;
uniform float rim_lighting_mix : hint_range(0.0, 1.0) = 1.0;

group_uniforms matcap;
uniform vec3 matcap_factor : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D matcap_texture : source_color, hint_default_black;

group_uniforms uv_animation;
uniform sampler2D uv_animation_mask_texture : hint_default_white;
uniform float uv_animation_scroll_x_speed : hint_range(-10.0, 10.0) = 0.0;
uniform float uv_animation_scroll_y_speed : hint_range(-10.0, 10.0) = 0.0;
uniform float uv_animation_rotation_speed : hint_range(-10.0, 10.0) = 0.0;

group_uniforms;

// --- Varyings ---
varying vec3 v_base_color;
varying vec3 v_shade_color;
varying vec2 v_animated_uv;

void fragment() {
	// --- Double Sided Logic ---
	if (!FRONT_FACING && !double_sided) {
		discard;
	}
	if (!FRONT_FACING && double_sided) {
		NORMAL = -NORMAL;
	}

	// --- UV Animation ---
	float anim_mask = texture(uv_animation_mask_texture, UV).b;
	float rotation = uv_animation_rotation_speed * TIME * anim_mask;
	float cos_rot = cos(rotation);
	float sin_rot = sin(rotation);
	vec2 animated_uv = mat2(vec2(cos_rot, sin_rot), vec2(-sin_rot, cos_rot)) * (UV - 0.5) + 0.5;
	animated_uv += vec2(uv_animation_scroll_x_speed, uv_animation_scroll_y_speed) * TIME * anim_mask;
	v_animated_uv = animated_uv;

	// --- Sampling ---
	vec4 tex_color = texture(base_color_texture, animated_uv);
	float raw_alpha = tex_color.a * base_color.a;

	// --- Alpha Mode ---
	if (alpha_mode == 0) {
		ALPHA = 1.0;
	} else if (alpha_mode == 1) {
		if (raw_alpha < alpha_cutoff) {
			discard;
		}
		ALPHA = 1.0;
	} else {
		ALPHA = raw_alpha;
	}

	// --- Color Terms ---
	v_base_color = tex_color.rgb * base_color.rgb;
	v_shade_color = shade_color.rgb * texture(shade_multiply_texture, animated_uv).rgb;

	// KEY FIX: ALBEDO is the shade color (our unlit baseline).
	// Godot uses ALBEDO * ambient for the ambient light pass,
	// so the ambient light will correctly tint the shadow side.
	// The light() function adds the transition toward base_color on lit surfaces.
	ALBEDO = v_shade_color;

	// Emission
	EMISSION = emissive_color * texture(emissive_texture, animated_uv).rgb;

	// --- Spec-Compliant MatCap UVs (fixed from NORMAL.xy shortcut) ---
	// Spec §Rim Lighting pseudocode:
	//   worldViewX = normalize(V.z, 0, -V.x)
	//   worldViewY = cross(V, worldViewX)
	//   matcapUv = vec2(dot(worldViewX, N), dot(worldViewY, N)) * 0.495 + 0.5
	vec3 world_view_x = normalize(vec3(VIEW.z, 0.0, -VIEW.x));
	vec3 world_view_y = cross(VIEW, world_view_x);
	vec2 matcap_uv = vec2(dot(world_view_x, NORMAL), dot(world_view_y, NORMAL)) * 0.495 + 0.5;
	vec3 matcap_term = matcap_factor * texture(matcap_texture, matcap_uv).rgb;

	// --- Rim (Emission-like/Unlit portion) ---
	// Spec: rim = (matcap + parametricRim) * rimMultiply * lerp(1, lighting, rimLightingMix)
	// For the fragment pass we only handle the "unlit" fraction (when rimLightingMix = 0).
	float rim_dot = clamp(1.0 - dot(NORMAL, VIEW) + rim_lift, 0.0, 1.0);
	float parametric_rim = pow(rim_dot, max(rim_fresnel_power, 0.0001));
	vec3 rim_base = (rim_color * parametric_rim + matcap_term) * texture(rim_multiply_texture, animated_uv).rgb;
	EMISSION += rim_base * (1.0 - rim_lighting_mix);
}

void light() {
	// 1. Toon Shading Ramp (spec §Implementation pseudocode)
	float NdotL = dot(NORMAL, LIGHT);
	float shift_tex = texture(shading_shift_texture, v_animated_uv).r;
	float shading = NdotL + shading_shift_factor + shift_tex;

	float a = -1.0 + shading_toony_factor;
	float b = 1.0 - shading_toony_factor;
	float shading_factor = clamp((shading - a) / max(b - a, 0.0001), 0.0, 1.0);

	// 2. Combine with shadow maps
	float final_shading = shading_factor * ATTENUATION;

	// 3. Diffuse: lerp(shade, base, shading) * lightColor
	// Since ALBEDO = shade, we add only the delta to reach base color.
	vec3 diffuse_term = LIGHT_COLOR * (v_base_color - v_shade_color) * final_shading;

	// 4. Lit Rim (light-modulated portion)
	// Spec: rim *= lerp(1, lighting, rimLightingMixFactor)
	float rim_dot = clamp(1.0 - dot(NORMAL, VIEW) + rim_lift, 0.0, 1.0);
	float parametric_rim = pow(rim_dot, max(rim_fresnel_power, 0.0001));

	vec3 world_view_x = normalize(vec3(VIEW.z, 0.0, -VIEW.x));
	vec3 world_view_y = cross(VIEW, world_view_x);
	vec2 matcap_uv = vec2(dot(world_view_x, NORMAL), dot(world_view_y, NORMAL)) * 0.495 + 0.5;
	vec3 matcap_term = matcap_factor * texture(matcap_texture, matcap_uv).rgb;

	vec3 rim_base = (rim_color * parametric_rim + matcap_term) * texture(rim_multiply_texture, v_animated_uv).rgb;
	// Multiply lit rim by the light color and final_shading (the "lighting" in the spec)
	vec3 dynamic_rim = rim_base * rim_lighting_mix * LIGHT_COLOR * final_shading;

	// 5. Accumulate
	DIFFUSE_LIGHT += diffuse_term + dynamic_rim;
}
