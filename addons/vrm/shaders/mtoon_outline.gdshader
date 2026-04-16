shader_type spatial;

/*
 * VRMC_materials_mtoon 1.0 Outline Implementation for Godot 4.x
 * Step 8: Correcting Shadow Sync
 */

render_mode blend_mix, depth_draw_always, cull_front;

// --- Uniforms ---

group_uniforms outline;
uniform int outline_width_mode : hint_range(0, 2) = 1;
uniform float outline_width : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D outline_width_multiply_texture : hint_default_white;
uniform vec3 outline_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float outline_lighting_mix : hint_range(0.0, 1.0) = 1.0;

group_uniforms shading;
uniform float shading_shift_factor : hint_range(-1.0, 1.0) = 0.0;
uniform sampler2D shading_shift_texture : hint_default_black;
uniform float shading_toony_factor : hint_range(0.0, 1.0) = 0.9;

group_uniforms uv_animation;
uniform sampler2D uv_animation_mask_texture : hint_default_white;
uniform float uv_animation_scroll_x_speed : hint_range(-10.0, 10.0) = 0.0;
uniform float uv_animation_scroll_y_speed : hint_range(-10.0, 10.0) = 0.0;
uniform float uv_animation_rotation_speed : hint_range(-10.0, 10.0) = 0.0;

group_uniforms;

// --- Varyings ---
varying vec2 v_animated_uv;

void vertex() {
	// --- UV Animation Logic (Vertex Stage) ---
	float anim_mask = textureLod(uv_animation_mask_texture, UV, 0.0).b;
	float rotation = uv_animation_rotation_speed * TIME * anim_mask;
	float cos_rot = cos(rotation);
	float sin_rot = sin(rotation);
	vec2 animated_uv = mat2(vec2(cos_rot, sin_rot), vec2(-sin_rot, cos_rot)) * (UV - 0.5) + 0.5;
	animated_uv += vec2(uv_animation_scroll_x_speed, uv_animation_scroll_y_speed) * TIME * anim_mask;

	v_animated_uv = animated_uv;

	// Sample the G channel of the multiply texture
	float width_mask = textureLod(outline_width_multiply_texture, animated_uv, 0.0).g;
	float final_width = outline_width * width_mask;
	
	if (outline_width_mode == 0) {
		VERTEX = vec3(0.0);
	}
	else if (outline_width_mode == 1) {
		VERTEX += NORMAL * final_width;
	} 
	else if (outline_width_mode == 2) {
		vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec3 clip_normal = mat3(PROJECTION_MATRIX * MODELVIEW_MATRIX) * NORMAL;
		float aspect = PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0];
		vec2 offset = normalize(clip_normal.xy);
		offset.x *= aspect; 
		clip_pos.xy += offset * final_width * clip_pos.w * 0.01;
		POSITION = clip_pos;
	}
	
	NORMAL = -NORMAL;
}

void fragment() {
	ALBEDO = outline_color;
}

void light() {
	// 1. Calculate NdotL
	float NdotL = dot(NORMAL, LIGHT);
	
	// 2. Toon Threshold (Sync with base pass)
	float shift_tex = texture(shading_shift_texture, v_animated_uv).r;
	float shading = NdotL + shading_shift_factor + shift_tex;
	
	float a = -1.0 + shading_toony_factor;
	float b = 1.0 - shading_toony_factor;
	float shading_factor = clamp((shading - a) / max(b - a, 0.0001), 0.0, 1.0);
	
	// 3. Self-Shadowing (ATTENUATION)
	float final_shading = shading_factor * ATTENUATION;
	
	// 4. Apply Outline Lighting Mix
	// We mix between "always 1.0" and "follows shading factor"
	float light_multiplier = mix(1.0, final_shading, outline_lighting_mix);
	
	// 5. Final Accumulation
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ALBEDO * light_multiplier;
}
