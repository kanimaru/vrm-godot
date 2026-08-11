@tool
extends GLTFDocumentExtension
class_name Vrm1Extension

## Handles VRM 1.0 avatars (VRMC_vrm, VRMC_materials_mtoon, VRMC_springBone).

const VrmMtoonBuilder = preload("../common/vrm_mtoon_builder.gd")
const VRMUtil = preload("../common/vrm_util.gd")
const VrmSceneComposer = preload("../common/vrm_scene_composer.gd")


func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray([
		"VRMC_vrm",
		"VRMC_materials_mtoon",
		"VRMC_springBone",
		"VRMC_node_constraint",
		"VRMC_vrm_animation",
		"VRMC_materials_hdr_emissiveMultiplier",
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

	# Parse per-node VRMC_node_constraint extensions.
	# Produces a sparse node_index -> Vrm1NodeConstraint map (only nodes that carry the
	# extension are present as keys — unlike mtoon_configs above, there is no downstream
	# consumer that needs array-index alignment with the full node list).
	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {}
	if json.has("nodes"):
		var gltf_node_json: Array = json["nodes"]
		for node_idx: int in range(gltf_node_json.size()):
			var node_json: Dictionary = gltf_node_json[node_idx]
			if node_json.has("extensions") and node_json["extensions"].has("VRMC_node_constraint"):
				var nc: Vrm1NodeConstraint = _parse_node_constraint(node_idx, node_json["extensions"]["VRMC_node_constraint"])
				if nc != null:
					node_constraints[node_idx] = nc
	state.set_additional_data("vrm1_node_constraints", node_constraints)

	return OK


func _parse_meta(d: Dictionary) -> Vrm1Meta:
	var meta: Vrm1Meta = Vrm1Meta.new()
	meta.name = d.get("name", "")
	meta.version = d.get("version", "")
	meta.authors = PackedStringArray(d.get("authors", []))
	meta.copyright_information = d.get("copyrightInformation", "")
	meta.contact_information = d.get("contactInformation", "")
	meta.references = PackedStringArray(d.get("references", []))
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
	meta.other_license_url = d.get("otherLicenseUrl", "")
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
	
	if d.has("rangeMapHorizontalInner"):
		look_at.range_map_horizontal_inner = _parse_look_at_range_map(d["rangeMapHorizontalInner"])
	if d.has("rangeMapHorizontalOuter"):
		look_at.range_map_horizontal_outer = _parse_look_at_range_map(d["rangeMapHorizontalOuter"])
	if d.has("rangeMapVerticalDown"):
		look_at.range_map_vertical_down = _parse_look_at_range_map(d["rangeMapVerticalDown"])
	if d.has("rangeMapVerticalUp"):
		look_at.range_map_vertical_up = _parse_look_at_range_map(d["rangeMapVerticalUp"])
		
	return look_at


func _parse_look_at_range_map(d: Dictionary) -> Vrm1LookAt.RangeMap:
	var rm: Vrm1LookAt.RangeMap = Vrm1LookAt.RangeMap.new()
	rm.input_max_value = d.get("inputMaxValue", 90.0)
	rm.output_scale = d.get("outputScale", 10.0)
	return rm


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


## Parses a single node's VRMC_node_constraint extension dict into a Vrm1NodeConstraint.
## Returns null if the constraint object has none of roll/aim/rotation (malformed per spec,
## which requires exactly one of the three).
func _parse_node_constraint(node_idx: int, d: Dictionary) -> Vrm1NodeConstraint:
	if not d.has("constraint"):
		return null

	var c: Dictionary = d["constraint"]
	var nc: Vrm1NodeConstraint = Vrm1NodeConstraint.new()
	nc.node = node_idx

	if c.has("roll"):
		var r: Dictionary = c["roll"]
		nc.type = "roll"
		nc.source = r.get("source", -1)
		nc.roll_axis = r.get("rollAxis", "X")
		nc.weight = r.get("weight", 1.0)
	elif c.has("aim"):
		var a: Dictionary = c["aim"]
		nc.type = "aim"
		nc.source = a.get("source", -1)
		nc.aim_axis = a.get("aimAxis", "PositiveX")
		nc.weight = a.get("weight", 1.0)
	elif c.has("rotation"):
		var rt: Dictionary = c["rotation"]
		nc.type = "rotation"
		nc.source = rt.get("source", -1)
		nc.weight = rt.get("weight", 1.0)
	else:
		return null

	return nc


func _import_post(state: GLTFState, root: Node) -> Error:
	var vrm_top_level: Vrm1TopLevel = state.get_additional_data("vrm1") as Vrm1TopLevel
	if vrm_top_level == null:
		return OK

	# Store the parsed VRM data as node metadata so the EditorInspectorPlugin can access it.
	VRMUtil.set_vrm1_data(root, vrm_top_level)

	# Store a vrm_role -> actual_bone_name lookup on the root so VrmaAnimationLibraryBuilder
	# can retarget animations to this avatar's real bone names at import/runtime.
	var humanoid_bone_map: Dictionary[String, String] = {}
	if vrm_top_level.humanoid != null:
		var gltf_nodes: Array[GLTFNode] = state.get_nodes()
		for vrm_bone_name: String in vrm_top_level.humanoid.human_bones:
			var bone_data: Vrm1HumanoidBone = vrm_top_level.humanoid.human_bones[vrm_bone_name]
			if bone_data.node < 0 or bone_data.node >= gltf_nodes.size():
				continue
			var bone_name: String = VrmSceneComposer.resolve_node_name(gltf_nodes[bone_data.node])
			humanoid_bone_map[vrm_bone_name.to_lower()] = bone_name
		VRMUtil.set_humanoid_bone_map(root, humanoid_bone_map)
		VrmSceneComposer.validate_required_humanoid_bones("Vrm1Extension", humanoid_bone_map, VrmConstants.VRM1_REQUIRED_HUMANOID_BONES)

	VrmSceneComposer.attach_retargeter(root)

	var skeleton: Skeleton3D = VRMUtil.find_skeleton(root)
	VrmSceneComposer.rename_skeleton_to_general(skeleton)
	if skeleton != null and not humanoid_bone_map.is_empty():
		VrmSceneComposer.validate_humanoid_bone_scales("Vrm1Extension", skeleton, humanoid_bone_map)

	var node_constraints_variant: Variant = state.get_additional_data("vrm1_node_constraints")
	var has_node_constraints: bool = node_constraints_variant is Dictionary and not (node_constraints_variant as Dictionary).is_empty()
	var need_node_names: bool = skeleton != null and (vrm_top_level.spring_bone != null or has_node_constraints)
	var gltf_node_names: Dictionary[int, String] = (
		VrmSceneComposer.resolve_all_node_names(state) if need_node_names else {}
	)

	if skeleton != null and vrm_top_level.spring_bone != null:
		var spring_sim: Vrm1SpringBoneSimulator = Vrm1SpringBoneSimulator.new()
		spring_sim.name = "Vrm1SpringBoneSimulator"
		spring_sim.spring_bone_data = vrm_top_level.spring_bone
		spring_sim.gltf_node_names = gltf_node_names

		skeleton.add_child(spring_sim, true)
		spring_sim.owner = root

	if skeleton != null and has_node_constraints:
		var constraint_sim: Vrm1NodeConstraintSimulator = Vrm1NodeConstraintSimulator.new()
		constraint_sim.name = "Vrm1NodeConstraintSimulator"
		constraint_sim.node_constraints = node_constraints_variant
		constraint_sim.gltf_node_names = gltf_node_names

		skeleton.add_child(constraint_sim, true)
		constraint_sim.owner = root

	# MToon materials must be swapped in before expression binds are compiled - material
	# color/UV binds resolve their target by walking the live scene tree, and need to find
	# the actual MToon ShaderMaterial rather than the pre-swap glTF-imported one.
	VrmSceneComposer.apply_mtoon_materials(root, state.get_additional_data("vrm1_mtoon"), state)

	var expr_controller: Vrm1ExpressionController = null
	if vrm_top_level.expressions != null:
		expr_controller = Vrm1ExpressionController.new()
		expr_controller.name = "Vrm1ExpressionController"
		expr_controller.unique_name_in_owner = true
		root.add_child(expr_controller, true)
		expr_controller.owner = root
		expr_controller.compile_vrm1_binds(vrm_top_level.expressions, state, root)

	if vrm_top_level.look_at != null:
		var look_at_script := load("res://addons/vrm/vrm1/nodes/vrm1_look_at_controller.gd")
		if look_at_script != null:
			var look_at_controller: Node = look_at_script.new()
			look_at_controller.name = "Vrm1LookAtController"
			look_at_controller.unique_name_in_owner = true
			root.add_child(look_at_controller, true)
			look_at_controller.owner = root
			look_at_controller.setup(vrm_top_level.look_at, skeleton, root, expr_controller)

	_apply_first_person_visibility(root, vrm_top_level.first_person, state)

	return OK


## Moves thirdPersonOnly/firstPersonOnly-annotated meshes off Godot's default render layer
## (1) onto VrmConstants.THIRD_PERSON_ONLY_LAYER / FIRST_PERSON_ONLY_LAYER respectively -
## see those constants for how a game's own cameras need to be configured to use this.
##
## The spec's `auto` classification (splitting a single mesh into head/non-head triangle
## groups by per-vertex skin weight) is deliberately NOT implemented: real VRM content
## commonly has one "Body" mesh whose vertices span both the head and the rest of the
## body (confirmed against this repo's own test assets), so a whole-mesh auto-detection
## heuristic would misclassify it and hide the entire avatar in first-person view - worse
## than doing nothing. `auto` and meshes with no annotation at all are left on the default
## layer, matching the `both` behavior, until a real per-triangle split is implemented.
func _apply_first_person_visibility(root: Node, first_person: Vrm1FirstPerson, state: GLTFState) -> void:
	if first_person == null:
		return
	for annotation: Vrm1FirstPersonMeshAnnotation in first_person.mesh_annotations:
		if annotation.type != "thirdPersonOnly" and annotation.type != "firstPersonOnly":
			continue
		var mesh_node: Node = VrmSceneComposer.resolve_scene_node(state, root, annotation.node)
		if not (mesh_node is VisualInstance3D):
			continue
		var visual: VisualInstance3D = mesh_node
		visual.set_layer_mask_value(1, false)
		visual.set_layer_mask_value(
				VrmConstants.THIRD_PERSON_ONLY_LAYER if annotation.type == "thirdPersonOnly" else VrmConstants.FIRST_PERSON_ONLY_LAYER,
				true,
		)


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
	p["emissive_multiplier"] = _resolve_emissive_multiplier(mat_json)

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


## Reads the emissive multiplier from whichever sibling material extension carries it.
## VRMC_materials_hdr_emissiveMultiplier (archived VRM1) and KHR_materials_emissive_strength
## (its Khronos-standard successor) both sit alongside VRMC_materials_mtoon under
## material.extensions, not nested inside it. Defaults to 1.0 (no-op) if neither is present.
func _resolve_emissive_multiplier(mat_json: Dictionary) -> float:
	var mat_ext: Dictionary = mat_json.get("extensions", {})
	if mat_ext.has("VRMC_materials_hdr_emissiveMultiplier"):
		return mat_ext["VRMC_materials_hdr_emissiveMultiplier"].get("emissiveMultiplier", 1.0)
	if mat_ext.has("KHR_materials_emissive_strength"):
		return mat_ext["KHR_materials_emissive_strength"].get("emissiveStrength", 1.0)
	return 1.0


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
## Follows the chain: textureInfo.index -> textures[n].src_image -> images[n].
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
