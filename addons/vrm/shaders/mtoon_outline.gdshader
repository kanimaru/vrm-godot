shader_type spatial;

/*
 * VRMC_materials_mtoon 1.0 Outline Implementation for Godot 4.x
 * Step 9: Rendering Sync (Alpha Mode & Cutout)
 */

render_mode blend_mix, depth_draw_always, cull_front;

// --- Uniforms ---

group_uniforms rendering;
// 0: Opaque, 1: Mask (Cutout), 2: Blend (Transparent)
uniform int alpha_mode : hint_range(0, 2) = 2;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

group_uniforms base_color_lit;
// Needed to sync alpha cutout with the body
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_color_texture : source_color, hint_default_white;

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
	// --- UV Animation ---
	float anim_mask = textureLod(uv_animation_mask_texture, UV, 0.0).b;
	float rotation = uv_animation_rotation_speed * TIME * anim_mask;
	float cos_rot = cos(rotation);
	float sin_rot = sin(rotation);
	vec2 animated_uv = mat2(vec2(cos_rot, sin_rot), vec2(-sin_rot, cos_rot)) * (UV - 0.5) + 0.5;
	animated_uv += vec2(uv_animation_scroll_x_speed, uv_animation_scroll_y_speed) * TIME * anim_mask;

	v_animated_uv = animated_uv;

	// Outline Width
	float width_mask = textureLod(outline_width_multiply_texture, animated_uv, 0.0).g;
	float final_width = outline_width * width_mask;
	
	if (outline_width_mode == 1) {
		// World-space: expand along normals in object space. Unit = metres.
		VERTEX += NORMAL * final_width;
	} else if (outline_width_mode == 2) {
		// Screen-space: expand in clip space so width is constant on screen.
		// Unit = ratio of screen height (e.g. 0.01 = 1% of screen height).
		vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec3 clip_normal = mat3(PROJECTION_MATRIX * MODELVIEW_MATRIX) * NORMAL;
		// aspect = width/height; we DIVIDE x to compensate so the outline
		// stays equally thick in pixels regardless of screen aspect ratio.
		float aspect = PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0];
		vec2 offset = normalize(clip_normal.xy);
		offset.x /= aspect;
		// Multiply by 2.0 because NDC range is [-1, 1] (total = 2 units).
		clip_pos.xy += offset * final_width * 2.0 * clip_pos.w;
		POSITION = clip_pos;
	}
	
	NORMAL = -NORMAL;
}

void fragment() {
	// NONE mode: discard every pixel. This is more reliable than collapsing
	// vertices to vec3(0) in vertex(), which is undefined behaviour on some GPUs.
	if (outline_width_mode == 0) {
		discard;
	}

	// --- Alpha Clipping Sync ---
	vec4 body_tex = texture(base_color_texture, v_animated_uv);
	float alpha = body_tex.a * base_color.a;

	if (alpha_mode == 1) { // Mask
		if (alpha < alpha_cutoff) {
			discard;
		}
	} else if (alpha_mode == 2) { // Transparent
		// Outlines are usually opaque shells, but we can modulate their alpha too
		ALPHA = alpha;
	}

	ALBEDO = outline_color;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float shift_tex = texture(shading_shift_texture, v_animated_uv).r;
	float shading = NdotL + shading_shift_factor + shift_tex;
	
	float a = -1.0 + shading_toony_factor;
	float b = 1.0 - shading_toony_factor;
	float shading_factor = clamp((shading - a) / max(b - a, 0.0001), 0.0, 1.0);
	float final_shading = shading_factor * ATTENUATION;
	float light_multiplier = mix(1.0, final_shading, outline_lighting_mix);
	
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ALBEDO * light_multiplier;
}
