@tool
extends GLTFDocumentExtension
class_name Vrm1Extension

## Handles VRM 1.0 avatars (VRMC_vrm, VRMC_materials_mtoon, VRMC_springBone).

const VrmMtoonBuilder = preload("../common/vrm_mtoon_builder.gd")


func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray([
		"VRMC_vrm",
		"VRMC_materials_mtoon",
		"VRMC_springBone",
		"VRMC_node_constraint",
		"VRMC_vrm_animation",
	])


func _import_preflight(state: GLTFState, extensions: PackedStringArray) -> Error:
	if extensions.has("VRMC_vrm"):
		return OK
	return ERR_SKIP


func _import_post_parse(state: GLTFState) -> Error:
	var json: Dictionary = state.get_json()
	if not json.has("extensions"):
		return OK
		
	var extensions: Dictionary = json["extensions"]
	var vrm_top_level: Vrm1TopLevel = Vrm1TopLevel.new()
	
	if extensions.has("VRMC_vrm"):
		var vrm_dict: Dictionary = extensions["VRMC_vrm"]
		vrm_top_level.spec_version = vrm_dict.get("specVersion", "")
		if vrm_dict.has("meta"):
			vrm_top_level.meta = _parse_meta(vrm_dict["meta"])
		if vrm_dict.has("humanoid"):
			vrm_top_level.humanoid = _parse_humanoid(vrm_dict["humanoid"])
		if vrm_dict.has("firstPerson"):
			vrm_top_level.first_person = _parse_first_person(vrm_dict["firstPerson"])
		if vrm_dict.has("lookAt"):
			vrm_top_level.look_at = _parse_look_at(vrm_dict["lookAt"])
		if vrm_dict.has("expressions"):
			vrm_top_level.expressions = _parse_expressions(vrm_dict["expressions"])
			
	if extensions.has("VRMC_springBone"):
		vrm_top_level.spring_bone = _parse_spring_bone(extensions["VRMC_springBone"])

	state.set_additional_data("vrm1", vrm_top_level)

	# Parse per-material VRMC_materials_mtoon extensions.
	# Produces an Array of Dictionaries (or nulls for non-MToon materials).
	var mtoon_configs: Array = []
	if json.has("materials"):
		var gltf_materials: Array = json["materials"]
		for mat_idx: int in range(gltf_materials.size()):
			var mat_json: Dictionary = gltf_materials[mat_idx]
			if mat_json.has("extensions") and mat_json["extensions"].has("VRMC_materials_mtoon"):
				mtoon_configs.append(_parse_vrm1_mtoon(mat_json, state))
			else:
				mtoon_configs.append(null)
	state.set_additional_data("vrm1_mtoon", mtoon_configs)

	return OK


func _parse_meta(d: Dictionary) -> Vrm1Meta:
	var meta: Vrm1Meta = Vrm1Meta.new()
	meta.name = d.get("name", "")
	meta.version = d.get("version", "")
	# Skipping array details for brevity in basic parser but explicit types rule observed
	meta.copyright_information = d.get("copyrightInformation", "")
	meta.contact_information = d.get("contactInformation", "")
	meta.third_party_licenses = d.get("thirdPartyLicenses", "")
	meta.thumbnail_image = d.get("thumbnailImage", -1)
	meta.license_url = d.get("licenseUrl", "https://vrm.dev/licenses/1.0/")
	meta.avatar_permission = d.get("avatarPermission", "onlyAuthor")
	meta.allow_excessively_violent_usage = d.get("allowExcessivelyViolentUsage", false)
	meta.allow_excessively_sexual_usage = d.get("allowExcessivelySexualUsage", false)
	meta.commercial_usage = d.get("commercialUsage", "personalNonProfit")
	meta.allow_political_or_religious_usage = d.get("allowPoliticalOrReligiousUsage", false)
	meta.allow_antisocial_or_hate_usage = d.get("allowAntisocialOrHateUsage", false)
	meta.credit_notation = d.get("creditNotation", "required")
	meta.allow_redistribution = d.get("allowRedistribution", false)
	meta.modification = d.get("modification", "prohibited")
	return meta


func _parse_humanoid(d: Dictionary) -> Vrm1Humanoid:
	var h: Vrm1Humanoid = Vrm1Humanoid.new()
	if d.has("humanBones"):
		var raw_bones: Dictionary = d["humanBones"]
		for key: String in raw_bones:
			var bd: Dictionary = raw_bones[key]
			var bone: Vrm1HumanoidBone = Vrm1HumanoidBone.new()
			bone.node = bd.get("node", -1)
			h.human_bones[key] = bone
	return h


func _parse_first_person(d: Dictionary) -> Vrm1FirstPerson:
	var fp: Vrm1FirstPerson = Vrm1FirstPerson.new()
	if d.has("meshAnnotations"):
		var annotations: Array = d["meshAnnotations"]
		for m_dict: Dictionary in annotations:
			var m: Vrm1FirstPersonMeshAnnotation = Vrm1FirstPersonMeshAnnotation.new()
			m.node = m_dict.get("node", -1)
			m.type = m_dict.get("type", "auto")
			fp.mesh_annotations.append(m)
	return fp


func _parse_look_at(d: Dictionary) -> Vrm1LookAt:
	var look_at: Vrm1LookAt = Vrm1LookAt.new()
	if d.has("offsetFromHeadBone"):
		look_at.offset_from_head_bone = Vector3(d["offsetFromHeadBone"][0], d["offsetFromHeadBone"][1], d["offsetFromHeadBone"][2])
	look_at.type = d.get("type", "bone")
	return look_at


func _parse_expressions(d: Dictionary) -> Vrm1Expressions:
	var exp_node: Vrm1Expressions = Vrm1Expressions.new()
	if d.has("preset"):
		for key: String in d["preset"].keys():
			var expr_dict: Dictionary = d["preset"][key]
			var expr_data: Vrm1ExpressionData = _parse_expression_data(expr_dict)
			exp_node.preset[key] = expr_data
			
	if d.has("custom"):
		for key: String in d["custom"].keys():
			var expr_dict: Dictionary = d["custom"][key]
			var expr_data: Vrm1ExpressionData = _parse_expression_data(expr_dict)
			exp_node.custom[key] = expr_data
			
	return exp_node


func _parse_expression_data(d: Dictionary) -> Vrm1ExpressionData:
	var ed: Vrm1ExpressionData = Vrm1ExpressionData.new()
	ed.is_binary = d.get("isBinary", false)
	ed.override_blink = d.get("overrideBlink", "none")
	ed.override_look_at = d.get("overrideLookAt", "none")
	ed.override_mouth = d.get("overrideMouth", "none")
	
	if d.has("morphTargetBinds"):
		for mb_d: Dictionary in d["morphTargetBinds"]:
			var mb: Vrm1ExpressionMorphBind = Vrm1ExpressionMorphBind.new()
			mb.node = mb_d.get("node", -1)
			mb.index = mb_d.get("index", -1)
			mb.weight = mb_d.get("weight", 0.0)
			ed.morph_binds.append(mb)
			
	if d.has("materialColorBinds"):
		for cb_d: Dictionary in d["materialColorBinds"]:
			var cb: Vrm1ExpressionMaterialColorBind = Vrm1ExpressionMaterialColorBind.new()
			cb.material = cb_d.get("material", -1)
			cb.type = cb_d.get("type", "")
			if cb_d.has("targetValue"):
				var tv: Array = cb_d["targetValue"]
				var p_tv: PackedFloat32Array = PackedFloat32Array()
				for v: float in tv:
					p_tv.append(v)
				cb.target_value = p_tv
			ed.material_color_binds.append(cb)
			
	if d.has("textureTransformBinds"):
		for tb_d: Dictionary in d["textureTransformBinds"]:
			var tb: Vrm1ExpressionTextureTransformBind = Vrm1ExpressionTextureTransformBind.new()
			tb.material = tb_d.get("material", -1)
			if tb_d.has("scale"):
				tb.scale = Vector2(tb_d["scale"][0], tb_d["scale"][1])
			else:
				tb.scale = Vector2(1, 1)
			if tb_d.has("offset"):
				tb.offset = Vector2(tb_d["offset"][0], tb_d["offset"][1])
			else:
				tb.offset = Vector2(0, 0)
			ed.texture_transform_binds.append(tb)
			
	return ed



func _parse_spring_bone(d: Dictionary) -> Vrm1SpringBone:
	var sb: Vrm1SpringBone = Vrm1SpringBone.new()

	if d.has("colliders"):
		for c: Dictionary in d["colliders"]:
			sb.colliders.append(_parse_spring_bone_collider(c))

	if d.has("colliderGroups"):
		for cg: Dictionary in d["colliderGroups"]:
			var group: Vrm1SpringBoneColliderGroup = Vrm1SpringBoneColliderGroup.new()
			group.name = cg.get("name", "")

			if cg.has("colliders"):
				var indices: PackedInt32Array = PackedInt32Array()
				for raw_idx in cg["colliders"]:
					indices.push_back(int(raw_idx))
				group.colliders = indices

			sb.collider_groups.append(group)

	if d.has("springs"):
		for s: Dictionary in d["springs"]:
			sb.springs.append(_parse_spring_bone_spring(s))

	return sb


func _parse_spring_bone_collider(d: Dictionary) -> Vrm1SpringBoneCollider:
	var col: Vrm1SpringBoneCollider = Vrm1SpringBoneCollider.new()
	col.node = d.get("node", -1)

	var shape: Vrm1SpringBoneShape = Vrm1SpringBoneShape.new()

	# Check for VRMC_springBone_extended_collider shape first (takes priority).
	var ext_shape: Dictionary = {}
	if (
		d.has("extensions")
		and d["extensions"].has("VRMC_springBone_extended_collider")
	):
		var ext: Dictionary = d["extensions"]["VRMC_springBone_extended_collider"]
		if ext.has("shape"):
			ext_shape = ext["shape"]

	if not ext_shape.is_empty():
		# Extended collider — may be sphere, capsule, or plane.
		if ext_shape.has("sphere"):
			var s: Dictionary = ext_shape["sphere"]
			shape.type = "sphere"
			shape.inside = s.get("inside", false)
			shape.radius = s.get("radius", 0.0)
			var off: Array = s.get("offset", [0.0, 0.0, 0.0])
			shape.offset = Vector3(off[0], off[1], off[2])

		elif ext_shape.has("capsule"):
			var c: Dictionary = ext_shape["capsule"]
			shape.type = "capsule"
			shape.inside = c.get("inside", false)
			shape.radius = c.get("radius", 0.0)
			var off: Array = c.get("offset", [0.0, 0.0, 0.0])
			shape.offset = Vector3(off[0], off[1], off[2])
			var tail: Array = c.get("tail", [0.0, 0.0, 0.0])
			shape.tail = Vector3(tail[0], tail[1], tail[2])

		elif ext_shape.has("plane"):
			var p: Dictionary = ext_shape["plane"]
			shape.type = "plane"
			var off: Array = p.get("offset", [0.0, 0.0, 0.0])
			shape.offset = Vector3(off[0], off[1], off[2])
			var n: Array = p.get("normal", [0.0, 0.0, 1.0])
			shape.normal = Vector3(n[0], n[1], n[2])

	elif d.has("shape"):
		# Standard VRMC_springBone collider shape.
		var raw: Dictionary = d["shape"]

		if raw.has("sphere"):
			var s: Dictionary = raw["sphere"]
			shape.type = "sphere"
			shape.radius = s.get("radius", 0.0)
			var off: Array = s.get("offset", [0.0, 0.0, 0.0])
			shape.offset = Vector3(off[0], off[1], off[2])

		elif raw.has("capsule"):
			var c: Dictionary = raw["capsule"]
			shape.type = "capsule"
			shape.radius = c.get("radius", 0.0)
			var off: Array = c.get("offset", [0.0, 0.0, 0.0])
			shape.offset = Vector3(off[0], off[1], off[2])
			var tail: Array = c.get("tail", [0.0, 0.0, 0.0])
			shape.tail = Vector3(tail[0], tail[1], tail[2])

	col.shape = shape
	return col


func _parse_spring_bone_spring(d: Dictionary) -> Vrm1SpringBoneSpring:
	var spring: Vrm1SpringBoneSpring = Vrm1SpringBoneSpring.new()
	spring.name = d.get("name", "")
	spring.center = d.get("center", -1)

	if d.has("colliderGroups"):
		var indices: PackedInt32Array = PackedInt32Array()
		for raw_idx in d["colliderGroups"]:
			indices.push_back(int(raw_idx))
		spring.collider_groups = indices

	if d.has("joints"):
		for jt: Dictionary in d["joints"]:
			spring.joints.append(_parse_spring_bone_joint(jt))

	return spring


func _parse_spring_bone_joint(d: Dictionary) -> Vrm1SpringBoneJoint:
	var jt: Vrm1SpringBoneJoint = Vrm1SpringBoneJoint.new()
	jt.node = d.get("node", -1)
	jt.hit_radius = d.get("hitRadius", 0.0)
	jt.stiffness = d.get("stiffness", 1.0)
	jt.gravity_power = d.get("gravityPower", 0.0)
	jt.drag_force = d.get("dragForce", 0.5)

	# gravityDir is a [x, y, z] JSON array per spec, not a dict.
	if d.has("gravityDir"):
		var gd: Array = d["gravityDir"]
		jt.gravity_dir = Vector3(gd[0], gd[1], gd[2])

	return jt



func _import_post(state: GLTFState, root: Node) -> Error:
	var vrm_top_level: Vrm1TopLevel = state.get_additional_data("vrm1") as Vrm1TopLevel
	if vrm_top_level == null:
		return OK
	
	# Store the parsed VRM data as node metadata so the EditorInspectorPlugin can access it.
	root.set_meta("vrm1_data", vrm_top_level)

	var skeleton: Skeleton3D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			skeleton = n
			break
		stack.append_array(n.get_children(true))

	if skeleton != null and vrm_top_level.spring_bone != null:
		var gltf_nodes: Array[GLTFNode] = state.get_nodes()
		var node_names: Dictionary[int, String] = {}
		for i: int in range(gltf_nodes.size()):
			var gnode: GLTFNode = gltf_nodes[i]
			if gnode != null:
				var node_name: String = gnode.original_name
				if node_name.is_empty():
					node_name = gnode.resource_name
				node_names[i] = node_name

		var spring_sim: Vrm1SpringBoneSimulator = Vrm1SpringBoneSimulator.new()
		spring_sim.name = "Vrm1SpringBoneSimulator"
		spring_sim.spring_bone_data = vrm_top_level.spring_bone
		spring_sim.gltf_node_names = node_names

		skeleton.add_child(spring_sim, true)
		spring_sim.owner = root

	if vrm_top_level.expressions != null:
		var expr_controller: Vrm1ExpressionController = Vrm1ExpressionController.new()
		expr_controller.name = "Vrm1ExpressionController"
		root.add_child(expr_controller, true)
		expr_controller.owner = root
		expr_controller.compile_vrm1_binds(vrm_top_level.expressions, state, root)

	# --- MToon Material Replacement ---
	var mtoon_configs: Variant = state.get_additional_data("vrm1_mtoon")
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
# MToon Parsing — VRM 1.0 (VRMC_materials_mtoon)
# ---------------------------------------------------------------------------

## Parses a VRM 1.0 material JSON object (with VRMC_materials_mtoon extension)
## into a plain Dictionary of parameters that VrmMtoonBuilder understands.
func _parse_vrm1_mtoon(mat_json: Dictionary, state: GLTFState) -> Dictionary:
	var p: Dictionary = {}
	var ext: Dictionary = mat_json["extensions"]["VRMC_materials_mtoon"]

	# --- Standard glTF PBR fields ---
	if mat_json.has("pbrMetallicRoughness"):
		var pbr: Dictionary = mat_json["pbrMetallicRoughness"]
		if pbr.has("baseColorFactor"):
			var f: Array = pbr["baseColorFactor"]
			p["base_color"] = Color(f[0], f[1], f[2], f[3])
		if pbr.has("baseColorTexture"):
			p["base_color_texture"] = _resolve_gltf_texture(pbr["baseColorTexture"], state)
			# KHR_texture_transform carries UV tiling/offset for this texture.
			p["uv_st"] = _resolve_khr_texture_transform(pbr["baseColorTexture"])

	if mat_json.has("emissiveFactor"):
		var e: Array = mat_json["emissiveFactor"]
		p["emissive_color"] = Color(e[0], e[1], e[2])
	if mat_json.has("emissiveTexture"):
		p["emissive_texture"] = _resolve_gltf_texture(mat_json["emissiveTexture"], state)

	# --- Alpha ---
	# transparentWithZWrite is a VRM-spec boolean inside the MToon extension that
	# upgrades a BLEND material to also write to the depth buffer.
	var alpha_str: String = mat_json.get("alphaMode", "OPAQUE")
	var transparent_zwrite: bool = ext.get("transparentWithZWrite", false)
	match alpha_str:
		"MASK":
			p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.MASK
		"BLEND":
			if transparent_zwrite:
				p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.BLEND_ZWRITE
			else:
				p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.BLEND
		_:
			p["alpha_mode"] = VrmMtoonBuilder.AlphaMode.OPAQUE
	p["alpha_cutoff"] = mat_json.get("alphaCutoff", 0.5)
	p["double_sided"] = mat_json.get("doubleSided", false)

	# --- VRMC_materials_mtoon extension fields ---
	# Shade
	if ext.has("shadeColorFactor"):
		var s: Array = ext["shadeColorFactor"]
		p["shade_color"] = Color(s[0], s[1], s[2], 1.0)
	if ext.has("shadeMultiplyTexture"):
		p["shade_texture"] = _resolve_gltf_texture(ext["shadeMultiplyTexture"], state)

	# Shading ramp
	p["shading_shift_factor"] = ext.get("shadingShiftFactor", 0.0)
	p["shading_toony_factor"] = ext.get("shadingToonyFactor", 0.9)
	if ext.has("shadingShiftTexture"):
		p["shading_shift_texture"] = _resolve_gltf_texture(ext["shadingShiftTexture"], state)

	# Normal map (from top-level glTF)
	if mat_json.has("normalTexture"):
		p["normal_map_texture"] = _resolve_gltf_texture(mat_json["normalTexture"], state)
		p["normal_map_scale"] = mat_json["normalTexture"].get("scale", 1.0)

	# GI
	p["indirect_light_intensity"] = ext.get("giEqualizationFactor", 0.9)

	# MatCap
	if ext.has("matcapFactor"):
		var m: Array = ext["matcapFactor"]
		p["matcap_color"] = Color(m[0], m[1], m[2])
	if ext.has("matcapTexture"):
		p["matcap_texture"] = _resolve_gltf_texture(ext["matcapTexture"], state)

	# Rim
	if ext.has("parametricRimColorFactor"):
		var r: Array = ext["parametricRimColorFactor"]
		p["rim_color"] = Color(r[0], r[1], r[2])
	p["rim_fresnel_power"] = ext.get("parametricRimFresnelPowerFactor", 5.0)
	p["rim_lift"] = ext.get("parametricRimLiftFactor", 0.0)
	p["rim_lighting_mix"] = ext.get("rimLightingMixFactor", 1.0)
	if ext.has("rimMultiplyTexture"):
		p["rim_texture"] = _resolve_gltf_texture(ext["rimMultiplyTexture"], state)

	# Outline
	var outline_mode_str: String = ext.get("outlineWidthMode", "none")
	match outline_mode_str:
		"worldCoordinates":
			p["outline_width_mode"] = VrmMtoonBuilder.OutlineWidthMode.WORLD
		"screenCoordinates":
			p["outline_width_mode"] = VrmMtoonBuilder.OutlineWidthMode.SCREEN
		_:
			p["outline_width_mode"] = VrmMtoonBuilder.OutlineWidthMode.NONE
	p["outline_width"] = ext.get("outlineWidthFactor", 0.0)
	if ext.has("outlineWidthMultiplyTexture"):
		p["outline_width_texture"] = _resolve_gltf_texture(ext["outlineWidthMultiplyTexture"], state)
	if ext.has("outlineColorFactor"):
		var o: Array = ext["outlineColorFactor"]
		p["outline_color"] = Color(o[0], o[1], o[2])
	p["outline_lighting_mix"] = ext.get("outlineLightingMixFactor", 1.0)

	# UV Animation
	p["uv_anim_scroll_x"] = ext.get("uvAnimationScrollXSpeedFactor", 0.0)
	p["uv_anim_scroll_y"] = ext.get("uvAnimationScrollYSpeedFactor", 0.0)
	p["uv_anim_rotation"] = ext.get("uvAnimationRotationSpeedFactor", 0.0)
	if ext.has("uvAnimationMaskTexture"):
		p["uv_anim_mask_texture"] = _resolve_gltf_texture(ext["uvAnimationMaskTexture"], state)

	return p


## Extracts UV scale+offset from a KHR_texture_transform extension on a textureInfo dict.
## Returns a Vector4(scale.x, scale.y, offset.x, offset.y) matching the _MainTex_ST convention.
func _resolve_khr_texture_transform(texture_info: Dictionary) -> Vector4:
	var ext_dict: Dictionary = texture_info.get("extensions", {})
	if not ext_dict.has("KHR_texture_transform"):
		return Vector4(1.0, 1.0, 0.0, 0.0)
	var khr: Dictionary = ext_dict["KHR_texture_transform"]
	var scale: Array = khr.get("scale", [1.0, 1.0])
	var offset: Array = khr.get("offset", [0.0, 0.0])
	return Vector4(scale[0], scale[1], offset[0], offset[1])


# ---------------------------------------------------------------------------
# Texture Helpers
# ---------------------------------------------------------------------------

## Resolves a glTF textureInfo object (e.g. {"index": 3}) to a Godot Texture2D.
func _resolve_gltf_texture(texture_info: Dictionary, state: GLTFState) -> Texture2D:
	var tex_index: int = texture_info.get("index", -1)
	if tex_index < 0:
		return null

	var gltf_textures: Array[GLTFTexture] = state.get_textures()
	if tex_index >= gltf_textures.size():
		return null

	var gltf_tex: GLTFTexture = gltf_textures[tex_index]
	var img_index: int = gltf_tex.src_image
	if img_index < 0:
		return null

	var images: Array[Texture2D] = state.get_images()
	if img_index >= images.size():
		return null

	return images[img_index]


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
