@tool
extends GLTFDocumentExtension
class_name Vrm0Extension

## Handles legacy VRM 0.0 avatars.


const m_bind_script = preload("structures/vrm0_material_bind.gd")
const VrmMtoonBuilder = preload("../common/vrm_mtoon_builder.gd")


func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["VRM"])


func _import_preflight(state: GLTFState, extensions: PackedStringArray) -> Error:
	if extensions.has("VRM"):
		return OK
	return ERR_SKIP


func _import_post_parse(state: GLTFState) -> Error:
	var json: Dictionary = state.get_json()
	if not json.has("extensions"):
		return OK
		
	var extensions: Dictionary = json["extensions"]
	if not extensions.has("VRM"):
		return OK
		
	var vrm_dict: Dictionary = extensions["VRM"]
	var vrm_top_level: Vrm0TopLevel = Vrm0TopLevel.new()
	
	vrm_top_level.exporter_version = vrm_dict.get("exporterVersion", "")
	vrm_top_level.spec_version = vrm_dict.get("specVersion", "")
	
	if vrm_dict.has("meta"):
		vrm_top_level.meta = _parse_meta(vrm_dict["meta"])
	
	if vrm_dict.has("humanoid"):
		vrm_top_level.humanoid = _parse_humanoid(vrm_dict["humanoid"])
		
	if vrm_dict.has("firstPerson"):
		vrm_top_level.first_person = _parse_first_person(vrm_dict["firstPerson"])
		
	if vrm_dict.has("blendShapeMaster"):
		vrm_top_level.blend_shape_master = _parse_blend_shape(vrm_dict["blendShapeMaster"])
		
	if vrm_dict.has("secondaryAnimation"):
		vrm_top_level.secondary_animation = _parse_secondary_animation(vrm_dict["secondaryAnimation"])

	state.set_additional_data("vrm0", vrm_top_level)

	# Parse per-material MToon properties from legacy VRM extension.
	# Produces an Array of Dictionaries (or nulls for non-MToon materials).
	var mtoon_configs: Array = []
	if vrm_dict.has("materialProperties"):
		var props_list: Array = vrm_dict["materialProperties"]
		for mat_idx: int in range(props_list.size()):
			var props: Dictionary = props_list[mat_idx]
			if props.get("shader", "") == "VRM/MToon":
				mtoon_configs.append(_parse_vrm0_mtoon(props, state))
			else:
				mtoon_configs.append(null)
	state.set_additional_data("vrm0_mtoon", mtoon_configs)

	return OK


func _parse_meta(d: Dictionary) -> Vrm0Meta:
	var meta: Vrm0Meta = Vrm0Meta.new()
	meta.title = d.get("title", "")
	meta.version = d.get("version", "")
	meta.author = d.get("author", "")
	meta.contact_information = d.get("contactInformation", "")
	meta.reference = d.get("reference", "")
	meta.texture = d.get("texture", -1)
	meta.allowed_user_name = d.get("allowedUserName", "")
	meta.violent_ussage_name = d.get("violentUssageName", "")
	meta.sexual_ussage_name = d.get("sexualUssageName", "")
	meta.commercial_ussage_name = d.get("commercialUssageName", "")
	meta.other_permission_url = d.get("otherPermissionUrl", "")
	meta.license_name = d.get("licenseName", "")
	meta.other_license_url = d.get("otherLicenseUrl", "")
	return meta


func _parse_humanoid(d: Dictionary) -> Vrm0Humanoid:
	var h: Vrm0Humanoid = Vrm0Humanoid.new()
	h.arm_stretch = d.get("armStretch", 0.05)
	h.leg_stretch = d.get("legStretch", 0.05)
	h.upper_arm_twist = d.get("upperArmTwist", 0.5)
	h.lower_arm_twist = d.get("lowerArmTwist", 0.5)
	h.upper_leg_twist = d.get("upperLegTwist", 0.5)
	h.lower_leg_twist = d.get("lowerLegTwist", 0.5)
	h.feet_spacing = d.get("feetSpacing", 0.0)
	h.has_translation_dof = d.get("hasTranslationDoF", false)
	
	if d.has("humanBones"):
		for bd: Dictionary in d["humanBones"]:
			var bone: Vrm0Humanoid.Bone = Vrm0Humanoid.Bone.new()
			bone.bone = bd.get("bone", "")
			bone.node = bd.get("node", -1)
			bone.use_default_values = bd.get("useDefaultValues", true)
			if bd.has("axisLength"):
				bone.axis_length = bd["axisLength"]
			h.human_bones.append(bone)
	return h


func _parse_first_person(d: Dictionary) -> Vrm0FirstPerson:
	var fp: Vrm0FirstPerson = Vrm0FirstPerson.new()
	fp.first_person_bone = d.get("firstPersonBone", -1)
	fp.look_at_type_name = d.get("lookAtTypeName", "Bone")
	if d.has("meshAnnotations"):
		for md: Dictionary in d["meshAnnotations"]:
			var m: Vrm0FirstPerson.MeshAnnotation = Vrm0FirstPerson.MeshAnnotation.new()
			m.mesh = md.get("mesh", -1)
			m.first_person_flag = md.get("firstPersonFlag", "Auto")
			fp.mesh_annotations.append(m)
	return fp


func _parse_blend_shape(d: Dictionary) -> Vrm0BlendShape:
	var bs := Vrm0BlendShape.new()
	if d.has("blendShapeGroups"):
		for g: Dictionary in d["blendShapeGroups"]:
			var group: Vrm0BlendShapeGroup = Vrm0BlendShapeGroup.new()
			group.name = g.get("name", "")
			group.preset_name = g.get("presetName", "")
			group.is_binary = g.get("isBinary", false)
			
			if g.has("binds"):
				for b: Dictionary in g["binds"]:
					var bind: Vrm0BlendShapeBind = Vrm0BlendShapeBind.new()
					bind.mesh = b.get("mesh", -1)
					bind.index = b.get("index", -1)
					bind.weight = b.get("weight", 0.0)
					group.binds.append(bind)
			
			if g.has("materialValues"):
				for m: Dictionary in g["materialValues"]:
					var m_bind : Resource = m_bind_script.new()
					m_bind.material_name = m.get("materialName", "")
					m_bind.property_name = m.get("propertyName", "")
					m_bind.target_value = PackedFloat32Array(m.get("targetValue", []))
					group.material_binds.append(m_bind)
			
			bs.blend_shape_groups.append(group)
	return bs


func _parse_secondary_animation(d: Dictionary) -> Vrm0SecondaryAnimation:
	var sec := Vrm0SecondaryAnimation.new()
	if d.has("boneGroups"):
		for s: Dictionary in d["boneGroups"]:
			var spring: Vrm0Spring = Vrm0Spring.new()
			spring.comment = s.get("comment", "")
			spring.stiffness = s.get("stiffiness", 1.0) # Handling typo in schema
			spring.gravity_power = s.get("gravityPower", 0.0)
			if s.has("gravityDir"):
				spring.gravity_dir = Vector3(s["gravityDir"].get("x", 0), s["gravityDir"].get("y", -1), s["gravityDir"].get("z", 0))
			spring.drag_force = s.get("dragForce", 0.4)
			spring.center = s.get("center", -1)
			spring.hit_radius = s.get("hitRadius", 0.02)
			
			if s.has("bones"):
				var arr: PackedInt32Array = PackedInt32Array()
				for raw_b in s["bones"]:
					arr.push_back(int(raw_b))
				spring.bones = arr

			if s.has("colliderGroups"):
				var arr: PackedInt32Array = PackedInt32Array()
				for raw_cg in s["colliderGroups"]:
					arr.push_back(int(raw_cg))
				spring.collider_groups = arr
				
			sec.bone_groups.append(spring)
			
	if d.has("colliderGroups"):
		for cg: Dictionary in d["colliderGroups"]:
			var group: Vrm0ColliderGroup = Vrm0ColliderGroup.new()
			group.node = cg.get("node", -1)
			if cg.has("colliders"):
				for c: Dictionary in cg["colliders"]:
					var col: Vrm0Collider = Vrm0Collider.new()
					col.radius = c.get("radius", 0.0)
					if c.has("offset"):
						col.offset = Vector3(c["offset"].get("x", 0), c["offset"].get("y", 0), c["offset"].get("z", 0))
					group.colliders.append(col)
			sec.collider_groups.append(group)
			
	return sec


func _import_post(state: GLTFState, root: Node) -> Error:
	var vrm_top_level: Vrm0TopLevel = state.get_additional_data("vrm0") as Vrm0TopLevel
	if vrm_top_level == null:
		return OK

	# NOTE: Do NOT rotate the root here. Godot's GLTFDocument already converts
	# the coordinate space from glTF (+Z forward) to Godot (-Z forward) for both
	# VRM 0.0 models and .vrma files. A manual flip would misalign bone rests
	# (which are baked at import time and don't change with parent node rotation)
	# against the NLR rotations, inverting shoulders and elbows.
	
	# Store the parsed VRM data as node metadata so the EditorInspectorPlugin can access it.
	root.set_meta("vrm0_data", vrm_top_level)

	var skeleton: Skeleton3D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			skeleton = n
			skeleton.name = "GeneralSkeleton"
			skeleton.unique_name_in_owner = true
			break
		stack.append_array(n.get_children(true))

	# Store a vrm_role -> actual_bone_name lookup on the root so VrmaAnimationLibraryBuilder
	# can retarget animations to this avatar's real bone names at import/runtime.
	if vrm_top_level.humanoid != null:
		var gltf_nodes: Array[GLTFNode] = state.get_nodes()
		var humanoid_bone_map: Dictionary[String, String] = {}
		for bone_data: Vrm0Humanoid.Bone in vrm_top_level.humanoid.human_bones:
			if bone_data.node < 0 or bone_data.node >= gltf_nodes.size():
				continue
			var gnode: GLTFNode = gltf_nodes[bone_data.node]
			var bone_name: String = gnode.original_name
			if bone_name.is_empty():
				bone_name = gnode.resource_name
			humanoid_bone_map[bone_data.bone.to_lower()] = bone_name
		root.set_meta("vrm_humanoid_bones", humanoid_bone_map)

	if skeleton != null and vrm_top_level.secondary_animation != null:
		var gltf_nodes: Array[GLTFNode] = state.get_nodes()
		var node_names: Dictionary[int, String] = {}
		for i: int in range(gltf_nodes.size()):
			var gnode: GLTFNode = gltf_nodes[i]
			if gnode != null:
				var node_name: String = gnode.original_name
				if node_name.is_empty():
					node_name = gnode.resource_name
				node_names[i] = node_name

		var spring_sim: Vrm0SpringBoneSimulator = Vrm0SpringBoneSimulator.new()
		spring_sim.name = "Vrm0SpringBoneSimulator"
		spring_sim.secondary_animation = vrm_top_level.secondary_animation
		spring_sim.gltf_node_names = node_names

		skeleton.add_child(spring_sim, true)
		spring_sim.owner = root

	if vrm_top_level.blend_shape_master != null:
		var expr_controller: Vrm0ExpressionController = Vrm0ExpressionController.new()
		expr_controller.name = "Vrm0ExpressionController"
		root.add_child(expr_controller, true)
		expr_controller.owner = root
		expr_controller.compile_vrm0_binds(vrm_top_level.blend_shape_master, state, root)

	# --- MToon Material Replacement ---
	var mtoon_configs: Variant = state.get_additional_data("vrm0_mtoon")
	if mtoon_configs is Array:
		var gltf_materials: Array = state.get_materials()

		# Build a name -> ShaderMaterial map for scene-tree lookup.
		# The surface material resource_name on baked ArrayMesh surfaces matches
		# the resource_name of the corresponding glTF material.
		var name_to_shader: Dictionary[String, ShaderMaterial] = {}
		var active_mtoons: Array[Material] = []
		for mat_idx: int in range(mtoon_configs.size()):
			var params: Variant = mtoon_configs[mat_idx]
			if not (params is Dictionary):
				continue

			var body_mat: ShaderMaterial = VrmMtoonBuilder.build_body(params)
			var outline_mat: ShaderMaterial = VrmMtoonBuilder.build_outline(params)
			if outline_mat != null:
				body_mat.next_pass = outline_mat

			# Map by glTF material name so the scene-tree walker can look it up.
			var gltf_mat: Material = gltf_materials[mat_idx] as Material if mat_idx < gltf_materials.size() else null
			if gltf_mat != null and not gltf_mat.resource_name.is_empty():
				name_to_shader[gltf_mat.resource_name] = body_mat
			
			active_mtoons.append(body_mat)
			if outline_mat != null:
				active_mtoons.append(outline_mat)

		if not name_to_shader.is_empty():
			_apply_materials_to_scene_tree(root, name_to_shader)

			var mtoon_controller_script := load("res://addons/Godot-MToon-Shader/mtoon_controller.gd")
			if mtoon_controller_script != null:
				var controller: Node = mtoon_controller_script.new()
				controller.name = "MtoonController"
				controller.set("mtoon_materials", active_mtoons)
				root.add_child(controller, true)
				controller.owner = root

	return OK


# ---------------------------------------------------------------------------
# MToon Parsing — VRM 0.0 (materialProperties)
# ---------------------------------------------------------------------------

## Parses VRM 0.0 materialProperties into a plain Dictionary of parameters
## that VrmMtoonBuilder understands (using its neutral key names).
func _parse_vrm0_mtoon(props: Dictionary, state: GLTFState) -> Dictionary:
	var p: Dictionary = {}
	var floats: Dictionary = props.get("floatProperties", {})
	var vectors: Dictionary = props.get("vectorProperties", {})
	var textures: Dictionary = props.get("textureProperties", {})

	# --- Rendering / Alpha ---
	var blend_mode: int = int(floats.get("_BlendMode", 0))
	match blend_mode:
		1:
			p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.MASK
		2:
			p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.BLEND
		3:
			p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE
		_:
			p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.OPAQUE
	p["alpha_cutoff"] = floats.get("_Cutoff", 0.5)
	# _CullMode: 0=None (double-sided), 2=Back (single-sided)
	p["double_sided"] = int(floats.get("_CullMode", 2)) == 0

	# --- Base color ---
	if vectors.has("_Color"):
		var c: Array = vectors["_Color"]
		p["base_color"] = Color(c[0], c[1], c[2], c[3])
	if textures.has("_MainTex"):
		p["base_color_texture"] = _resolve_vrm0_texture(textures["_MainTex"], state)

	# --- Shade color ---
	if vectors.has("_ShadeColor"):
		var s: Array = vectors["_ShadeColor"]
		p["shade_color"] = Color(s[0], s[1], s[2], 1.0)
	if textures.has("_ShadeTexture"):
		p["shade_texture"] = _resolve_vrm0_texture(textures["_ShadeTexture"], state)

	# --- Shading ramp ---
	p["shading_shift_factor"] = floats.get("_ShadeShift", 0.0)
	p["shading_toony_factor"] = floats.get("_ShadeToony", 0.9)
	if textures.has("_ShadingGradeTexture"):
		p["shading_shift_texture"] = _resolve_vrm0_texture(textures["_ShadingGradeTexture"], state)
	if textures.has("_ReceiveShadowTexture"):
		p["receive_shadow_texture"] = _resolve_vrm0_texture(textures["_ReceiveShadowTexture"], state)

	# --- Normal map ---
	if textures.has("_BumpMap"):
		p["normal_map_texture"] = _resolve_vrm0_texture(textures["_BumpMap"], state)
		p["normal_map_scale"] = floats.get("_BumpScale", 1.0)

	# --- GI / Indirect ---
	p["indirect_light_intensity"] = floats.get("_IndirectLightIntensity", 0.1)

	# --- Emission ---
	if vectors.has("_EmissionColor"):
		var e: Array = vectors["_EmissionColor"]
		p["emissive_color"] = Color(e[0], e[1], e[2])
	if textures.has("_EmissionMap"):
		p["emissive_texture"] = _resolve_vrm0_texture(textures["_EmissionMap"], state)

	# --- MatCap ---
	if vectors.has("_MatcapColor"):
		var mc: Array = vectors["_MatcapColor"]
		p["matcap_color"] = Color(mc[0], mc[1], mc[2])
	if textures.has("_SphereAdd"):
		p["matcap_texture"] = _resolve_vrm0_texture(textures["_SphereAdd"], state)

	# --- Rim ---
	if vectors.has("_RimColor"):
		var r: Array = vectors["_RimColor"]
		p["rim_color"] = Color(r[0], r[1], r[2])
	p["rim_fresnel_power"] = floats.get("_RimFresnelPower", 5.0)
	p["rim_lift"] = floats.get("_RimLift", 0.0)
	p["rim_lighting_mix"] = floats.get("_RimLightingMix", 1.0)
	if textures.has("_RimTexture"):
		p["rim_texture"] = _resolve_vrm0_texture(textures["_RimTexture"], state)

	# --- Outline ---
	p["outline_width_mode"] = int(floats.get("_OutlineWidthMode", 0))
	p["outline_width"] = floats.get("_OutlineWidth", 0.0)
	if vectors.has("_OutlineColor"):
		var o: Array = vectors["_OutlineColor"]
		p["outline_color"] = Color(o[0], o[1], o[2])
	p["outline_lighting_mix"] = floats.get("_OutlineLightingMix", 1.0)
	p["outline_color_mode"] = int(floats.get("_OutlineColorMode", 0))
	if textures.has("_OutlineWidthTexture"):
		p["outline_width_texture"] = _resolve_vrm0_texture(textures["_OutlineWidthTexture"], state)

	# --- UV Animation ---
	p["uv_anim_scroll_x"] = floats.get("_UvAnimScrollX", 0.0)
	p["uv_anim_scroll_y"] = floats.get("_UvAnimScrollY", 0.0)
	p["uv_anim_rotation"] = floats.get("_UvAnimRotation", 0.0)
	if textures.has("_UvAnimMaskTexture"):
		p["uv_anim_mask_texture"] = _resolve_vrm0_texture(textures["_UvAnimMaskTexture"], state)

	return p


# ---------------------------------------------------------------------------
# Texture Helpers
# ---------------------------------------------------------------------------

## Resolves a VRM 0.0 texture index (property value) to a Godot Texture2D.
func _resolve_vrm0_texture(tex_index_val: Variant, state: GLTFState) -> Texture2D:
	var tex_index: int = int(tex_index_val)
	if tex_index < 0:
		return null

	var images: Array[Texture2D] = state.get_images()
	if tex_index >= images.size():
		return null

	return images[tex_index]


# ---------------------------------------------------------------------------
# Scene Tree Material Replacement
# ---------------------------------------------------------------------------

## Recursively walks the scene tree from root.
## During _import_post, nodes are ImporterMeshInstance3D with an ImporterMesh.
## ImporterMesh uses get_surface_material() / set_surface_material(), which
## bakes the replacement directly into the final ArrayMesh.
func _apply_materials_to_scene_tree(
		node: Node,
		name_to_shader: Dictionary[String, ShaderMaterial],
) -> void:
	if node is ImporterMeshInstance3D:
		var importer_inst: ImporterMeshInstance3D = node as ImporterMeshInstance3D
		var importer_mesh: ImporterMesh = importer_inst.mesh
		if importer_mesh != null:
			for i: int in range(importer_mesh.get_surface_count()):
				var surf_mat: Material = importer_mesh.get_surface_material(i)
				if surf_mat == null or surf_mat.resource_name.is_empty():
					continue
				if name_to_shader.has(surf_mat.resource_name):
					importer_mesh.set_surface_material(i, name_to_shader[surf_mat.resource_name])
	elif node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		if mesh_inst.mesh != null:
			for i: int in range(mesh_inst.mesh.get_surface_count()):
				var surf_mat: Material = mesh_inst.mesh.surface_get_material(i)
				if surf_mat == null or surf_mat.resource_name.is_empty():
					continue
				if name_to_shader.has(surf_mat.resource_name):
					mesh_inst.set_surface_override_material(i, name_to_shader[surf_mat.resource_name])

	for child: Node in node.get_children():
		_apply_materials_to_scene_tree(child, name_to_shader)
