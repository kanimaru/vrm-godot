shader_type spatial;

/*
 * VRMC_materials_mtoon 1.0 Implementation for Godot 4.x
 * Step 8: Correcting Shadow & Ambient Logic
 */

render_mode blend_mix, depth_draw_always, cull_back;

// --- Uniforms ---

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
varying vec2 v_animated_uv;

void vertex() {
	// Pre-calculate animated UV in vertex stage for efficiency 
	// (Note: This lacks per-pixel masking from texture, so we'll stick to fragment for masking).
}

void fragment() {
	// --- UV Animation Calculation ---
	float anim_mask = texture(uv_animation_mask_texture, UV).b;
	float rotation = uv_animation_rotation_speed * TIME * anim_mask;
	float cos_rot = cos(rotation);
	float sin_rot = sin(rotation);
	vec2 animated_uv = mat2(vec2(cos_rot, sin_rot), vec2(-sin_rot, cos_rot)) * (UV - 0.5) + 0.5;
	animated_uv += vec2(uv_animation_scroll_x_speed, uv_animation_scroll_y_speed) * TIME * anim_mask;
	
	v_animated_uv = animated_uv;
	
	// --- Base Color Calculation ---
	vec4 tex_color = texture(base_color_texture, animated_uv);
	v_base_color = tex_color.rgb * base_color.rgb;
	
	// --- Shade Color Calculation ---
	vec3 shade_tex = texture(shade_multiply_texture, animated_uv).rgb;
	vec3 shade_color_term = shade_color.rgb * shade_tex;
	
	// CRITICAL: Set ALBEDO to Shade Color.
	// This ensures unlit areas (shadows) use the correct dark color.
	ALBEDO = shade_color_term;
	ALPHA = tex_color.a * base_color.a;
	
	// Emission
	vec3 emission_term = emissive_color * texture(emissive_texture, animated_uv).rgb;
	EMISSION = emission_term;
	
	// Rim Lighting (Constant Portion)
	float rim_dot = clamp(1.0 - dot(NORMAL, VIEW) + rim_lift, 0.0, 1.0);
	float parametric_rim = pow(rim_dot, max(rim_fresnel_power, 0.0001));
	vec3 parametric_term = rim_color * texture(rim_multiply_texture, animated_uv).rgb * parametric_rim;
	
	vec2 matcap_uv = NORMAL.xy * 0.495 + 0.5;
	vec3 matcap_term = matcap_factor * texture(matcap_texture, matcap_uv).rgb;
	
	vec3 total_rim = parametric_term + matcap_term;
	EMISSION += total_rim * (1.0 - rim_lighting_mix);
}

void light() {
	// 1. Toon Shading Threshold
	float NdotL = dot(NORMAL, LIGHT);
	float shift_tex = texture(shading_shift_texture, v_animated_uv).r;
	float shading = NdotL + shading_shift_factor + shift_tex;
	
	float a = -1.0 + shading_toony_factor;
	float b = 1.0 - shading_toony_factor;
	float shading_factor = clamp((shading - a) / max(b - a, 0.0001), 0.0, 1.0);
	
	// 2. Self-Shadowing (ATTENUATION)
	// Treat shadow mapping as an additional multiplier to the toon factor
	float final_shading = shading_factor * ATTENUATION;
	
	// 3. Additive Shading
	// We transition from ALBEDO (Shade) to v_base_color (Lit)
	vec3 diffuse_delta = (v_base_color - ALBEDO);
	vec3 diffuse_term = diffuse_delta * final_shading;
	
	// 4. Rim Lighting (Dynamic Portion)
	float rim_dot = clamp(1.0 - dot(NORMAL, VIEW) + rim_lift, 0.0, 1.0);
	float parametric_rim = pow(rim_dot, max(rim_fresnel_power, 0.0001));
	vec3 parametric_term = rim_color * texture(rim_multiply_texture, v_animated_uv).rgb * parametric_rim;
	
	vec2 matcap_uv = NORMAL.xy * 0.495 + 0.5;
	vec3 matcap_term = matcap_factor * texture(matcap_texture, matcap_uv).rgb;
	
	vec3 total_rim = parametric_term + matcap_term;
	vec3 dynamic_rim = total_rim * rim_lighting_mix * final_shading;
	
	// 5. Final Accumulation
	// Multiply by light color only once at the end
	DIFFUSE_LIGHT += LIGHT_COLOR * (diffuse_term + dynamic_rim);
}
