@tool
extends GLTFDocumentExtension
class_name Vrm1Extension

## Handles VRM 1.0 avatars (VRMC_vrm, VRMC_materials_mtoon, VRMC_springBone).


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
	# Empty stub for now; fully typed dictionaries
	if d.has("preset"):
		pass
	if d.has("custom"):
		pass
	return exp_node


func _parse_spring_bone(d: Dictionary) -> Vrm1SpringBone:
	var sec: Vrm1SpringBone = Vrm1SpringBone.new()
	# Empty stub; strictly explicit types
	return sec


func _import_post(state: GLTFState, root: Node) -> Error:
	var vrm_top_level: Vrm1TopLevel = state.get_additional_data("vrm1") as Vrm1TopLevel
	if vrm_top_level == null:
		return OK
		
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
		
	return OK
