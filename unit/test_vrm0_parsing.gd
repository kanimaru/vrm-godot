extends GutTest

## Unit tests for Vrm0Extension JSON-to-struct parsing functions.
## All tests use synthetic Dictionary inputs — no proprietary asset files required.

var _ext: Vrm0Extension


func before_each() -> void:
	_ext = Vrm0Extension.new()


func after_each() -> void:
	_ext = null


# ---------------------------------------------------------------------------
# _parse_meta
# ---------------------------------------------------------------------------

func test_parse_meta_all_fields() -> void:
	var d: Dictionary = {
		"title": "My Avatar",
		"version": "1.0",
		"author": "Test Author",
		"contactInformation": "test@example.com",
		"reference": "https://example.com",
		"texture": 3,
		"allowedUserName": "Everyone",
		"violentUssageName": "Disallow",
		"sexualUssageName": "Disallow",
		"commercialUssageName": "Allow",
		"otherPermissionUrl": "https://example.com/other",
		"licenseName": "CC0",
		"otherLicenseUrl": "https://example.com/license",
	}

	var meta: Vrm0Meta = _ext.call("_parse_meta", d)

	assert_eq(meta.title, "My Avatar")
	assert_eq(meta.version, "1.0")
	assert_eq(meta.author, "Test Author")
	assert_eq(meta.contact_information, "test@example.com")
	assert_eq(meta.reference, "https://example.com")
	assert_eq(meta.texture, 3)
	assert_eq(meta.allowed_user_name, "Everyone")
	assert_eq(meta.violent_ussage_name, "Disallow")
	assert_eq(meta.sexual_ussage_name, "Disallow")
	assert_eq(meta.commercial_ussage_name, "Allow")
	assert_eq(meta.other_permission_url, "https://example.com/other")
	assert_eq(meta.license_name, "CC0")
	assert_eq(meta.other_license_url, "https://example.com/license")


func test_parse_meta_missing_optional_fields_use_defaults() -> void:
	var meta: Vrm0Meta = _ext.call("_parse_meta", {})

	assert_eq(meta.title, "")
	assert_eq(meta.version, "")
	assert_eq(meta.author, "")
	assert_eq(meta.texture, -1)
	assert_eq(meta.license_name, "")


# ---------------------------------------------------------------------------
# _parse_humanoid
# ---------------------------------------------------------------------------

func test_parse_humanoid_default_stretch_values() -> void:
	var h: Vrm0Humanoid = _ext.call("_parse_humanoid", {})

	assert_eq(h.arm_stretch, 0.05)
	assert_eq(h.leg_stretch, 0.05)
	assert_eq(h.upper_arm_twist, 0.5)
	assert_eq(h.lower_arm_twist, 0.5)
	assert_eq(h.upper_leg_twist, 0.5)
	assert_eq(h.lower_leg_twist, 0.5)
	assert_eq(h.feet_spacing, 0.0)
	assert_false(h.has_translation_dof)


func test_parse_humanoid_explicit_values() -> void:
	var d: Dictionary = {
		"armStretch": 0.1,
		"legStretch": 0.2,
		"upperArmTwist": 0.3,
		"lowerArmTwist": 0.4,
		"upperLegTwist": 0.6,
		"lowerLegTwist": 0.7,
		"feetSpacing": 0.05,
		"hasTranslationDoF": true,
	}

	var h: Vrm0Humanoid = _ext.call("_parse_humanoid", d)

	assert_eq(h.arm_stretch, 0.1)
	assert_eq(h.leg_stretch, 0.2)
	assert_eq(h.upper_arm_twist, 0.3)
	assert_eq(h.lower_arm_twist, 0.4)
	assert_eq(h.upper_leg_twist, 0.6)
	assert_eq(h.lower_leg_twist, 0.7)
	assert_eq(h.feet_spacing, 0.05)
	assert_true(h.has_translation_dof)


func test_parse_humanoid_bone_list_count_and_fields() -> void:
	var d: Dictionary = {
		"humanBones": [
			{ "bone": "head", "node": 5, "useDefaultValues": true },
			{ "bone": "hips", "node": 2, "useDefaultValues": false, "axisLength": 0.5 },
		],
	}

	var h: Vrm0Humanoid = _ext.call("_parse_humanoid", d)

	assert_eq(h.human_bones.size(), 2)

	var head: Vrm0Humanoid.Bone = h.human_bones[0]
	assert_eq(head.bone, "head")
	assert_eq(head.node, 5)
	assert_true(head.use_default_values)

	var hips: Vrm0Humanoid.Bone = h.human_bones[1]
	assert_eq(hips.bone, "hips")
	assert_eq(hips.node, 2)
	assert_false(hips.use_default_values)
	assert_eq(hips.axis_length, 0.5)


func test_parse_humanoid_axis_length_absent_when_key_missing() -> void:
	var d: Dictionary = {
		"humanBones": [
			{ "bone": "spine", "node": 3 },
		],
	}

	var h: Vrm0Humanoid = _ext.call("_parse_humanoid", d)
	var bone: Vrm0Humanoid.Bone = h.human_bones[0]

	assert_eq(bone.axis_length, 0.0)


# ---------------------------------------------------------------------------
# _parse_first_person
# ---------------------------------------------------------------------------

func test_parse_first_person_defaults() -> void:
	var fp: Vrm0FirstPerson = _ext.call("_parse_first_person", {})

	assert_eq(fp.first_person_bone, -1)
	assert_eq(fp.look_at_type_name, "Bone")
	assert_eq(fp.mesh_annotations.size(), 0)


func test_parse_first_person_annotations() -> void:
	var d: Dictionary = {
		"firstPersonBone": 7,
		"lookAtTypeName": "BlendShape",
		"meshAnnotations": [
			{ "mesh": 0, "firstPersonFlag": "FirstPersonOnly" },
			{ "mesh": 1, "firstPersonFlag": "ThirdPersonOnly" },
		],
	}

	var fp: Vrm0FirstPerson = _ext.call("_parse_first_person", d)

	assert_eq(fp.first_person_bone, 7)
	assert_eq(fp.look_at_type_name, "BlendShape")
	assert_eq(fp.mesh_annotations.size(), 2)

	var ann: Vrm0FirstPerson.MeshAnnotation = fp.mesh_annotations[0]
	assert_eq(ann.mesh, 0)
	assert_eq(ann.first_person_flag, "FirstPersonOnly")


func test_parse_first_person_annotation_defaults() -> void:
	var d: Dictionary = {
		"meshAnnotations": [{}],
	}

	var fp: Vrm0FirstPerson = _ext.call("_parse_first_person", d)
	var ann: Vrm0FirstPerson.MeshAnnotation = fp.mesh_annotations[0]

	assert_eq(ann.mesh, -1)
	assert_eq(ann.first_person_flag, "Auto")


# ---------------------------------------------------------------------------
# _parse_blend_shape
# ---------------------------------------------------------------------------

func test_parse_blend_shape_empty_returns_no_groups() -> void:
	var bs: Vrm0BlendShape = _ext.call("_parse_blend_shape", {})

	assert_eq(bs.blend_shape_groups.size(), 0)


func test_parse_blend_shape_group_fields() -> void:
	var d: Dictionary = {
		"blendShapeGroups": [
			{
				"name": "Joy",
				"presetName": "joy",
				"isBinary": false,
				"binds": [
					{ "mesh": 0, "index": 3, "weight": 75.0 },
				],
			},
		],
	}

	var bs: Vrm0BlendShape = _ext.call("_parse_blend_shape", d)

	assert_eq(bs.blend_shape_groups.size(), 1)
	var group: Vrm0BlendShapeGroup = bs.blend_shape_groups[0]
	assert_eq(group.name, "Joy")
	assert_eq(group.preset_name, "joy")
	assert_false(group.is_binary)
	assert_eq(group.binds.size(), 1)

	var bind: Vrm0BlendShapeBind = group.binds[0]
	assert_eq(bind.mesh, 0)
	assert_eq(bind.index, 3)
	assert_eq(bind.weight, 75.0)


func test_parse_blend_shape_material_values() -> void:
	var d: Dictionary = {
		"blendShapeGroups": [
			{
				"name": "Neutral",
				"presetName": "neutral",
				"materialValues": [
					{
						"materialName": "Face",
						"propertyName": "_Color",
						"targetValue": [1.0, 0.5, 0.5, 1.0],
					},
				],
			},
		],
	}

	var bs: Vrm0BlendShape = _ext.call("_parse_blend_shape", d)
	var group: Vrm0BlendShapeGroup = bs.blend_shape_groups[0]

	assert_eq(group.material_binds.size(), 1)
	var m_bind: Vrm0MaterialBind = group.material_binds[0]
	assert_eq(m_bind.material_name, "Face")
	assert_eq(m_bind.property_name, "_Color")
	assert_eq(m_bind.target_value.size(), 4)
	assert_eq(m_bind.target_value[0], 1.0)


func test_parse_blend_shape_binary_flag() -> void:
	var d: Dictionary = {
		"blendShapeGroups": [
			{ "name": "Blink", "presetName": "blink", "isBinary": true },
		],
	}

	var bs: Vrm0BlendShape = _ext.call("_parse_blend_shape", d)
	assert_true(bs.blend_shape_groups[0].is_binary)


# ---------------------------------------------------------------------------
# _parse_secondary_animation
# ---------------------------------------------------------------------------

func test_parse_secondary_animation_empty() -> void:
	var sec: Vrm0SecondaryAnimation = _ext.call("_parse_secondary_animation", {})

	assert_eq(sec.bone_groups.size(), 0)
	assert_eq(sec.collider_groups.size(), 0)


func test_parse_secondary_animation_spring_defaults() -> void:
	var d: Dictionary = {
		"boneGroups": [{}],
	}

	var sec: Vrm0SecondaryAnimation = _ext.call("_parse_secondary_animation", d)
	var spring: Vrm0Spring = sec.bone_groups[0]

	# Spec defaults
	assert_eq(spring.stiffness, 1.0)
	assert_eq(spring.gravity_power, 0.0)
	assert_eq(spring.drag_force, 0.4)
	assert_eq(spring.center, -1)
	assert_eq(spring.hit_radius, 0.02)


func test_parse_secondary_animation_spring_fields() -> void:
	var d: Dictionary = {
		"boneGroups": [
			{
				"comment": "Hair",
				"stiffiness": 3.0,
				"gravityPower": 0.1,
				"gravityDir": { "x": 0.0, "y": -1.0, "z": 0.0 },
				"dragForce": 0.6,
				"center": 4,
				"hitRadius": 0.05,
				"bones": [1, 2, 3],
				"colliderGroups": [0],
			},
		],
	}

	var sec: Vrm0SecondaryAnimation = _ext.call("_parse_secondary_animation", d)
	var spring: Vrm0Spring = sec.bone_groups[0]

	assert_eq(spring.comment, "Hair")
	assert_eq(spring.stiffness, 3.0, "Typo key 'stiffiness' must be handled")
	assert_eq(spring.gravity_power, 0.1)
	assert_eq(spring.gravity_dir, Vector3(0.0, -1.0, 0.0))
	assert_eq(spring.drag_force, 0.6)
	assert_eq(spring.center, 4)
	assert_eq(spring.hit_radius, 0.05)
	assert_eq(spring.bones.size(), 3)
	assert_eq(spring.bones[0], 1)
	assert_eq(spring.collider_groups.size(), 1)


func test_parse_secondary_animation_collider_groups() -> void:
	var d: Dictionary = {
		"colliderGroups": [
			{
				"node": 2,
				"colliders": [
					{
						"radius": 0.07,
						"offset": { "x": 0.1, "y": 0.2, "z": 0.3 },
					},
				],
			},
		],
	}

	var sec: Vrm0SecondaryAnimation = _ext.call("_parse_secondary_animation", d)

	assert_eq(sec.collider_groups.size(), 1)
	var cg: Vrm0ColliderGroup = sec.collider_groups[0]
	assert_eq(cg.node, 2)
	assert_eq(cg.colliders.size(), 1)

	var col: Vrm0Collider = cg.colliders[0]
	assert_eq(col.radius, 0.07)
	assert_eq(col.offset, Vector3(0.1, 0.2, 0.3))
