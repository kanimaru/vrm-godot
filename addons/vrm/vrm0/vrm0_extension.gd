@tool
extends GLTFDocumentExtension
class_name Vrm0Extension

## Handles legacy VRM 0.0 avatars.


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
	var vrm_top_level := Vrm0TopLevel.new()
	
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
	return OK


func _parse_meta(d: Dictionary) -> Vrm0Meta:
	var meta := Vrm0Meta.new()
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
	var h := Vrm0Humanoid.new()
	h.arm_stretch = d.get("armStretch", 0.05)
	h.leg_stretch = d.get("legStretch", 0.05)
	h.upper_arm_twist = d.get("upperArmTwist", 0.5)
	h.lower_arm_twist = d.get("lowerArmTwist", 0.5)
	h.upper_leg_twist = d.get("upperLegTwist", 0.5)
	h.lower_leg_twist = d.get("lowerLegTwist", 0.5)
	h.feet_spacing = d.get("feetSpacing", 0.0)
	h.has_translation_dof = d.get("hasTranslationDoF", false)
	
	if d.has("humanBones"):
		for bd in d["humanBones"]:
			var bone := Vrm0Humanoid.Bone.new()
			bone.bone = bd.get("bone", "")
			bone.node = bd.get("node", -1)
			bone.use_default_values = bd.get("useDefaultValues", true)
			if bd.has("axisLength"):
				bone.axis_length = bd["axisLength"]
			h.human_bones.append(bone)
	return h


func _parse_first_person(d: Dictionary) -> Vrm0FirstPerson:
	var fp := Vrm0FirstPerson.new()
	fp.first_person_bone = d.get("firstPersonBone", -1)
	fp.look_at_type_name = d.get("lookAtTypeName", "Bone")
	if d.has("meshAnnotations"):
		for md in d["meshAnnotations"]:
			var m := Vrm0FirstPerson.MeshAnnotation.new()
			m.mesh = md.get("mesh", -1)
			m.first_person_flag = md.get("firstPersonFlag", "Auto")
			fp.mesh_annotations.append(m)
	return fp


func _parse_blend_shape(d: Dictionary) -> Vrm0BlendShape:
	var bs := Vrm0BlendShape.new()
	if d.has("blendShapeGroups"):
		for g in d["blendShapeGroups"]:
			var group := Vrm0BlendShape.BlendShapeGroup.new()
			group.name = g.get("name", "")
			group.preset_name = g.get("presetName", "")
			group.is_binary = g.get("isBinary", false)
			
			if g.has("binds"):
				for b in g["binds"]:
					var bind := Vrm0BlendShape.Bind.new()
					bind.mesh = b.get("mesh", -1)
					bind.index = b.get("index", -1)
					bind.weight = b.get("weight", 0.0)
					group.binds.append(bind)
			
			bs.blend_shape_groups.append(group)
	return bs


func _parse_secondary_animation(d: Dictionary) -> Vrm0SecondaryAnimation:
	var sec := Vrm0SecondaryAnimation.new()
	if d.has("boneGroups"):
		for s in d["boneGroups"]:
			var spring := Vrm0SecondaryAnimation.Spring.new()
			spring.comment = s.get("comment", "")
			spring.stiffness = s.get("stiffiness", 1.0) # Handling typo in schema
			spring.gravity_power = s.get("gravityPower", 0.0)
			if s.has("gravityDir"):
				spring.gravity_dir = Vector3(s["gravityDir"].get("x",0), s["gravityDir"].get("y", -1), s["gravityDir"].get("z", 0))
			spring.drag_force = s.get("dragForce", 0.4)
			spring.center = s.get("center", -1)
			spring.hit_radius = s.get("hitRadius", 0.02)
			
			if s.has("bones"):
				var arr := PackedInt32Array()
				for b in s["bones"]:
					arr.push_back(b)
				spring.bones = arr
				
			if s.has("colliderGroups"):
				var arr := PackedInt32Array()
				for cg in s["colliderGroups"]:
					arr.push_back(cg)
				spring.collider_groups = arr
				
			sec.bone_groups.append(spring)
			
	if d.has("colliderGroups"):
		for cg in d["colliderGroups"]:
			var group := Vrm0SecondaryAnimation.ColliderGroup.new()
			group.node = cg.get("node", -1)
			if cg.has("colliders"):
				for c in cg["colliders"]:
					var col := Vrm0SecondaryAnimation.Collider.new()
					col.radius = c.get("radius", 0.0)
					if c.has("offset"):
						col.offset = Vector3(c["offset"].get("x",0), c["offset"].get("y",0), c["offset"].get("z",0))
					group.colliders.append(col)
			sec.collider_groups.append(group)
			
	return sec
