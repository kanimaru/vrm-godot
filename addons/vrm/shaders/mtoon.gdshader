shader_type spatial;

/*
 * VRMC_materials_mtoon 1.0 Implementation for Godot 4.x
 * Based on comparison with V-Sekai/Godot-MToon-Shader-main reference.
 * Added: Normal Maps (TBN), Shading Grade Tex, Receive Shadow Tex,
 *        Light Color Attenuation, Directional vs Point light branching,
 *        Emission Multiplier, Indirect Light Equalization (mix_normal).
 */

// skip_vertex_transform lets us manually apply MODELVIEW_MATRIX so that
// we can build the correct TBN matrix for normal maps and do the
// non-uniform-scale-aware normal length correction for the outline pass.
render_mode skip_vertex_transform, blend_mix, depth_draw_always, cull_disabled;

// ---------------------------------------------------------------------------
// Uniforms
// ---------------------------------------------------------------------------

group_uniforms rendering;
// 0: Opaque, 1: Mask (Cutout), 2: Blend (Transparent)
uniform int alpha_mode : hint_range(0, 2) = 0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform bool double_sided = false;

group_uniforms base_color_lit;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_color_texture : source_color, hint_default_white;

group_uniforms shade_color_unlit;
uniform vec3 shade_color : source_color = vec3(0.97, 0.81, 0.86);
uniform sampler2D shade_multiply_texture : source_color, hint_default_white;

group_uniforms shading;
uniform float shading_shift_factor : hint_range(-1.0, 1.0) = 0.0;
uniform sampler2D shading_shift_texture : hint_default_black;
uniform float shading_shift_texture_scale : hint_range(0.0, 10.0) = 1.0;
uniform float shading_toony_factor : hint_range(0.0, 1.0) = 0.9;
// Per-UV shadow mask: darkens the NdotL before the toon ramp.
uniform sampler2D shading_grade_texture : hint_default_white;
uniform float shading_grade_rate : hint_range(0.0, 1.0) = 1.0;
// Per-UV shadow reception: softens or blocks shadow casting on specific regions.
uniform sampler2D receive_shadow_texture : hint_default_white;
uniform float receive_shadow_rate : hint_range(0.0, 1.0) = 1.0;

group_uniforms global_illumination;
// 0 = raw directional ambient, 1 = fully uniform (no directional bias).
// Implemented via mix_normal(worldUp, normal, intensity) — same as V-Sekai reference.
uniform float indirect_light_intensity : hint_range(0.0, 1.0) = 0.1;
// Desaturates light color toward pure-luminance for a more toon-accurate look.
uniform float light_color_attenuation : hint_range(0.0, 1.0) = 0.0;

group_uniforms normal_map;
uniform sampler2D normal_map_texture : hint_normal;
uniform float normal_map_scale : hint_range(-16.0, 16.0) = 1.0;

group_uniforms emission;
uniform vec3 emissive_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emissive_multiplier : hint_range(0.0, 10.0) = 1.0;
uniform sampler2D emissive_texture : source_color, hint_default_white;

group_uniforms rim_lighting;
uniform vec3 rim_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float rim_fresnel_power : hint_range(0.0, 100.0) = 5.0;
uniform float rim_lift : hint_range(0.0, 1.0) = 0.0;
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

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const float EPS_COL = 0.00001;
const float PI_2 = 6.28318530718;

// ---------------------------------------------------------------------------
// Varyings
// ---------------------------------------------------------------------------

// TBN matrix rows passed from vertex() to fragment() for normal mapping.
// Each row is (Tangent.component, Bitangent.component, Normal.component).
varying vec3 tspace0;
varying vec3 tspace1;
varying vec3 tspace2;

// Color terms shared between fragment() and light().
varying vec3 v_base_color;
varying vec3 v_shade_color;

// Normal in view-space after optional normal-map application.
// Used by light() to get a consistent NdotL without re-sampling the texture.
varying vec3 v_view_normal;

// Animated UV computed once per fragment and reused by light().
varying vec2 v_animated_uv;

// Rim computed in fragment(), used in light() for per-light rim contribution.
varying vec3 v_rim;


// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

// Same formula as V-Sekai reference — blend normals toward world-up to
// equalize indirect lighting as indirect_light_intensity approaches 1.
vec3 mix_normal(vec3 base_n, vec3 blend_n, float factor) {
	float new_x = (1.0 - factor + factor * dot(base_n, blend_n));
	return normalize(cross(cross(base_n, blend_n), base_n))
		* sqrt(max(0.0, 1.0 - new_x * new_x)) + new_x * normalize(base_n);
}

// Unpack a tangent-space normal map texel with a per-channel scale.
vec3 unpack_scale_normal(vec4 packed, float scale) {
	packed.xy = scale * (packed.xy * 2.0 - 1.0);
	packed.z = sqrt(max(0.0, 1.0 - dot(packed.xy, packed.xy)));
	return packed.xyz;
}


// ---------------------------------------------------------------------------
// vertex()
// ---------------------------------------------------------------------------

void vertex() {
	// Apply the model-view transform manually (required by skip_vertex_transform).
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Build the TBN matrix in view-space for normal mapping.
	// Each tspace row encodes one component of (Tangent, Bitangent, Normal).
	vec3 view_normal = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec3 view_tangent = mat3(MODELVIEW_MATRIX) * TANGENT;
	vec3 view_bitangent = mat3(MODELVIEW_MATRIX) * BINORMAL;

	tspace0 = vec3(view_tangent.x, view_bitangent.x, view_normal.x);
	tspace1 = vec3(view_tangent.y, view_bitangent.y, view_normal.y);
	tspace2 = vec3(view_tangent.z, view_bitangent.z, view_normal.z);
}


// ---------------------------------------------------------------------------
// fragment()
// ---------------------------------------------------------------------------

void fragment() {
	// --- Double Sided Logic ---
	if (!FRONT_FACING && !double_sided) {
		discard;
	}

	// --- UV Animation ---
	// Spec §UV Animation: mask is the Blue channel of the mask texture.
	float anim_mask = texture(uv_animation_mask_texture, UV).b;
	float uv_time = TIME * anim_mask;
	float rotation = uv_animation_rotation_speed * uv_time;
	float cos_rot = cos(rotation);
	float sin_rot = sin(rotation);
	vec2 animated_uv = mat2(
		vec2(cos_rot,  sin_rot),
		vec2(-sin_rot, cos_rot)
	) * (UV - 0.5) + 0.5;
	animated_uv += vec2(uv_animation_scroll_x_speed, uv_animation_scroll_y_speed) * uv_time;
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

	// --- Normal Mapping ---
	// Detect normal map presence by checking texture size above 8px.
	bool has_normal_map = textureSize(normal_map_texture, 0).x > 8;
	vec3 tangent_normal = vec3(0.0, 0.0, 1.0);
	if (has_normal_map) {
		tangent_normal = unpack_scale_normal(texture(normal_map_texture, animated_uv), normal_map_scale);
	}

	// Reconstruct view-space normal from the TBN varyings.
	vec3 view_n;
	if (has_normal_map) {
		view_n = vec3(
			dot(tspace0, tangent_normal),
			dot(tspace1, tangent_normal),
			dot(tspace2, tangent_normal)
		);
	} else {
		// Geometric normal stored in the Z-column of the TBN matrix.
		view_n = vec3(tspace0.z, tspace1.z, tspace2.z);
	}

	// Flip if the projection matrix is flipped (e.g. VR / mirrored cameras).
	view_n *= step(0.0, dot(VIEW, view_n)) * 2.0 - 1.0;

	// Double-sided: invert for back-faces.
	if (!FRONT_FACING) {
		view_n = -view_n;
	}

	view_n = normalize(view_n);
	v_view_normal = view_n;

	// --- Indirect Light Equalization ---
	// Blend the normal toward world-up (in view-space) by indirect_light_intensity.
	// At 1.0, ambient is perfectly uniform regardless of face direction.
	vec3 up_normal = mat3(VIEW_MATRIX) * vec3(0.0, 1.0, 0.0);
	vec3 equalized_normal = normalize(mix_normal(up_normal, view_n, indirect_light_intensity));
	NORMAL = equalized_normal;

	// The LIGHT_COME_FROM_UP_RATIO brightens the ambient base slightly.
	// sin() approximates a mild S-curve as intensity goes from 0→1.
	float light_come_from_up = mix(0.8, 1.0, sin(indirect_light_intensity));

	// --- ALBEDO = lit color * equalization ratio ---
	// The ambient pass in Godot is ALBEDO * ambient_light.
	// Using the lit base color (not shade) here so ambient surfaces look
	// correctly coloured without any direct light.
	// The light() function then adds the toon transition on top.
	ALBEDO = v_base_color * light_come_from_up;

	// Provide shade to light() via v_shade_color (already set above).

	// --- Emission ---
	EMISSION = emissive_color * emissive_multiplier * texture(emissive_texture, animated_uv).rgb;

	// --- MatCap UV (spec-compliant world-view-tangent construction) ---
	vec3 view_camera_up = vec3(0.0, 1.0, 0.0);
	vec3 view_view_up = normalize(view_camera_up - VIEW * dot(VIEW, view_camera_up));
	vec3 view_view_right = normalize(cross(VIEW, view_view_up));
	vec2 matcap_uv = vec2(
		dot(view_view_right, view_n),
		dot(view_view_up, view_n)
	) * 0.5 + 0.5;
	vec3 matcap_term = matcap_factor * texture(matcap_texture, matcap_uv).rgb;

	// --- Rim ---
	float rim_dot = clamp(1.0 - dot(view_n, VIEW) + rim_lift, 0.0, 1.0);
	float parametric_rim = pow(rim_dot, max(rim_fresnel_power, 0.001));
	v_rim = (rim_color * parametric_rim + matcap_term) * texture(rim_multiply_texture, animated_uv).rgb;

	// The unlit portion of rim goes directly to emission.
	EMISSION += v_rim * (1.0 - rim_lighting_mix);

	// --- Roughness / Metallic (toon = fully diffuse) ---
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}


// ---------------------------------------------------------------------------
// light()
// ---------------------------------------------------------------------------

void light() {
	// NdotL using the equalized view-space normal from fragment().
	float NdotL = dot(normalize(v_view_normal), LIGHT);

	// --- Receive Shadow Attenuation ---
	// Allow artists to suppress shadows on specific UV regions (e.g. skin under hair).
	float shadow_tex = texture(receive_shadow_texture, v_animated_uv).r;
	float light_attenuation = mix(
		1.0,
		length(ATTENUATION) / sqrt(3.0),   // normalised [0,1]
		receive_shadow_rate * shadow_tex
	);

	// --- Shading Grade ---
	// Per-UV multiplier that darkens the NdotL before the toon ramp.
	// At _ShadingGradeRate=1 and tex=0, the surface is always in full shadow.
	float shading_grade = 1.0 - shading_grade_rate * (1.0 - texture(shading_grade_texture, v_animated_uv).r);

	// --- Toon Ramp (MToon 1.0 spec linearstep) ---
	// Map NdotL through shading grade → half-space → shadow shift → linearstep.
	float shading = NdotL * 0.5 + 0.5;            // [-1,1] → [0,1]
	shading *= light_attenuation;                  // attenuate by shadow
	shading *= shading_grade;                      // per-UV darkness mask
	shading = shading * 2.0 - 1.0;                // [0,1] → [-1,1]

	// Apply the shading shift and texture offset.
	float shift_tex = texture(shading_shift_texture, v_animated_uv).r * shading_shift_texture_scale;
	shading += shading_shift_factor + shift_tex;

	float a = -1.0 + shading_toony_factor;
	float b = 1.0 - shading_toony_factor;
	float shading_factor = clamp((shading - a) / max(b - a, EPS_COL), 0.0, 1.0);

	// Hard-cut shading to zero when fully in shadow (Godot clustering fix).
	float final_shading = shading_factor * step(EPS_COL, length(ATTENUATION));

	// --- Light Color Attenuation ---
	// Desaturate the light colour toward its max luminance channel.
	// At 1.0, toon shading ignores the light's hue entirely.
	vec3 light_col = LIGHT_COLOR;
	float lum = max(light_col.r, max(light_col.g, light_col.b));
	light_col = mix(light_col, vec3(max(EPS_COL, lum)), light_color_attenuation);
	light_col /= 3.14159; // Lambertian normalisation (matches reference)

	// Point/Spot lights use a reduced-power attenuation to avoid clustering
	// artifacts — same trick used in the V-Sekai reference.
	if (!LIGHT_IS_DIRECTIONAL) {
		float att_len = length(ATTENUATION) / sqrt(3.0);
		light_col *= pow(att_len, 0.1) * 0.5;
	}

	// --- Diffuse: lerp(shade, base, shading) * lightColor ---
	// ALBEDO = v_base_color*ratio (set in fragment). We write DIFFUSE_LIGHT
	// directly so we bypass Godot's built-in Lambertian multiply.
	vec3 toon_col = mix(v_shade_color, v_base_color, final_shading);
	DIFFUSE_LIGHT += toon_col * light_col;

	// --- Lit Rim ---
	// Spec: rim *= lerp(1, lighting, rimLightingMix)
	SPECULAR_LIGHT += v_rim * rim_lighting_mix * light_col * final_shading;
}
