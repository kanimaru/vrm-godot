shader_type spatial;

/*
 * VRMC_materials_mtoon 1.0 Implementation for Godot 4.x
 * Step 1: Core Structure & Color Uniforms
 */

// Custom lit toon shader base
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Uniforms ---

// Base Color (Lit)
group_uniforms base_color_lit;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_color_texture : source_color, hint_default_white;

// Shade Color (Unlit)
group_uniforms shade_color_unlit;
uniform vec3 shade_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D shade_multiply_texture : source_color, hint_default_white;

// Restore standard grouping
group_uniforms;

void fragment() {
	// Sample the Base Color texture
	vec4 tex_color = texture(base_color_texture, UV);
	
	// Apply the color multiplier (pbrMetallicRoughness.baseColorFactor)
	vec4 composite_base = tex_color * base_color;
	
	// Assign to ALBEDO (Step 1 requirement)
	ALBEDO = composite_base.rgb;
	
	// Handle alpha for transparency (MASK/BLEND modes will be refined later)
	ALPHA = composite_base.a;
}
