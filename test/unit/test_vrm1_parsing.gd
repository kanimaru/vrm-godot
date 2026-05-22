extends GutTest

## Unit tests for Vrm1Extension JSON-to-struct parsing functions.
## All tests use synthetic Dictionary inputs — no proprietary asset files required.

var _ext: Vrm1Extension


func before_each() -> void:
	_ext = Vrm1Extension.new()


func after_each() -> void:
	_ext = null


# ---------------------------------------------------------------------------
# _parse_meta
# ---------------------------------------------------------------------------

func test_parse_meta_all_fields() -> void:
	var d: Dictionary = {
		"name": "Test Avatar",
		"version": "2.0",
		"copyrightInformation": "© 2024",
		"contactInformation": "contact@example.com",
		"thirdPartyLicenses": "Some licenses",
		"thumbnailImage": 5,
		"licenseUrl": "https://creativecommons.org/licenses/by/4.0/",
		"avatarPermission": "everyone",
		"allowExcessivelyViolentUsage": true,
		"allowExcessivelySexualUsage": false,
		"commercialUsage": "corporation",
		"allowPoliticalOrReligiousUsage": true,
		"allowAntisocialOrHateUsage": false,
		"creditNotation": "unnecessary",
		"allowRedistribution": true,
		"modification": "allowModification",
	}

	var meta: Vrm1Meta = _ext.call("_parse_meta", d)

	assert_eq(meta.name, "Test Avatar")
	assert_eq(meta.version, "2.0")
	assert_eq(meta.copyright_information, "© 2024")
	assert_eq(meta.contact_information, "contact@example.com")
	assert_eq(meta.third_party_licenses, "Some licenses")
	assert_eq(meta.thumbnail_image, 5)
	assert_eq(meta.license_url, "https://creativecommons.org/licenses/by/4.0/")
	assert_eq(meta.avatar_permission, "everyone")
	assert_true(meta.allow_excessively_violent_usage)
	assert_false(meta.allow_excessively_sexual_usage)
	assert_eq(meta.commercial_usage, "corporation")
	assert_true(meta.allow_political_or_religious_usage)
	assert_false(meta.allow_antisocial_or_hate_usage)
	assert_eq(meta.credit_notation, "unnecessary")
	assert_true(meta.allow_redistribution)
	assert_eq(meta.modification, "allowModification")


func test_parse_meta_defaults_when_empty() -> void:
	var meta: Vrm1Meta = _ext.call("_parse_meta", {})

	assert_eq(meta.name, "")
	assert_eq(meta.thumbnail_image, -1)
	assert_eq(meta.license_url, "https://vrm.dev/licenses/1.0/")
	assert_eq(meta.avatar_permission, "onlyAuthor")
	assert_false(meta.allow_excessively_violent_usage)
	assert_eq(meta.commercial_usage, "personalNonProfit")
	assert_eq(meta.credit_notation, "required")
	assert_false(meta.allow_redistribution)
	assert_eq(meta.modification, "prohibited")


# ---------------------------------------------------------------------------
# _parse_humanoid
# ---------------------------------------------------------------------------

func test_parse_humanoid_bone_map_populated() -> void:
	var d: Dictionary = {
		"humanBones": {
			"head": { "node": 10 },
			"hips": { "node": 2 },
		},
	}

	var h: Vrm1Humanoid = _ext.call("_parse_humanoid", d)

	assert_true(h.human_bones.has("head"))
	assert_true(h.human_bones.has("hips"))
	assert_eq((h.human_bones["head"] as Vrm1HumanoidBone).node, 10)
	assert_eq((h.human_bones["hips"] as Vrm1HumanoidBone).node, 2)


func test_parse_humanoid_empty_bones() -> void:
	var h: Vrm1Humanoid = _ext.call("_parse_humanoid", {})

	assert_eq(h.human_bones.size(), 0)


func test_parse_humanoid_bone_default_node_index() -> void:
	var d: Dictionary = {
		"humanBones": {
			"spine": {},
		},
	}

	var h: Vrm1Humanoid = _ext.call("_parse_humanoid", d)
	var bone: Vrm1HumanoidBone = h.human_bones["spine"]

	assert_eq(bone.node, -1)


# ---------------------------------------------------------------------------
# _parse_first_person
# ---------------------------------------------------------------------------

func test_parse_first_person_empty() -> void:
	var fp: Vrm1FirstPerson = _ext.call("_parse_first_person", {})

	assert_eq(fp.mesh_annotations.size(), 0)


func test_parse_first_person_annotations() -> void:
	var d: Dictionary = {
		"meshAnnotations": [
			{ "node": 3, "type": "firstPersonOnly" },
			{ "node": 7, "type": "thirdPersonOnly" },
		],
	}

	var fp: Vrm1FirstPerson = _ext.call("_parse_first_person", d)

	assert_eq(fp.mesh_annotations.size(), 2)
	assert_eq(fp.mesh_annotations[0].node, 3)
	assert_eq(fp.mesh_annotations[0].type, "firstPersonOnly")
	assert_eq(fp.mesh_annotations[1].node, 7)


func test_parse_first_person_annotation_defaults() -> void:
	var d: Dictionary = {
		"meshAnnotations": [{}],
	}

	var fp: Vrm1FirstPerson = _ext.call("_parse_first_person", d)
	var ann: Vrm1FirstPersonMeshAnnotation = fp.mesh_annotations[0]

	assert_eq(ann.node, -1)
	assert_eq(ann.type, "auto")


# ---------------------------------------------------------------------------
# _parse_look_at
# ---------------------------------------------------------------------------

func test_parse_look_at_offset_and_type() -> void:
	var d: Dictionary = {
		"offsetFromHeadBone": [0.0, 0.06, 0.0],
		"type": "expression",
	}

	var la: Vrm1LookAt = _ext.call("_parse_look_at", d)

	assert_eq(la.offset_from_head_bone, Vector3(0.0, 0.06, 0.0))
	assert_eq(la.type, "expression")


func test_parse_look_at_default_type() -> void:
	var la: Vrm1LookAt = _ext.call("_parse_look_at", {})

	assert_eq(la.type, "bone")


func test_parse_look_at_range_maps_populated() -> void:
	var d: Dictionary = {
		"rangeMapHorizontalInner": { "inputMaxValue": 15.0, "outputScale": 8.0 },
		"rangeMapHorizontalOuter": { "inputMaxValue": 20.0, "outputScale": 10.0 },
		"rangeMapVerticalDown": { "inputMaxValue": 10.0, "outputScale": 5.0 },
		"rangeMapVerticalUp": { "inputMaxValue": 12.0, "outputScale": 6.0 },
	}

	var la: Vrm1LookAt = _ext.call("_parse_look_at", d)

	assert_not_null(la.range_map_horizontal_inner)
	assert_eq(la.range_map_horizontal_inner.input_max_value, 15.0)
	assert_eq(la.range_map_horizontal_inner.output_scale, 8.0)
	assert_not_null(la.range_map_horizontal_outer)
	assert_not_null(la.range_map_vertical_down)
	assert_not_null(la.range_map_vertical_up)
	assert_eq(la.range_map_vertical_down.input_max_value, 10.0)


func test_parse_look_at_missing_range_maps_are_null() -> void:
	var la: Vrm1LookAt = _ext.call("_parse_look_at", {})

	assert_null(la.range_map_horizontal_inner)
	assert_null(la.range_map_horizontal_outer)
	assert_null(la.range_map_vertical_down)
	assert_null(la.range_map_vertical_up)


# ---------------------------------------------------------------------------
# _parse_expressions
# ---------------------------------------------------------------------------

func test_parse_expressions_preset_keys_stored() -> void:
	var d: Dictionary = {
		"preset": {
			"happy": { "isBinary": false },
			"sad": { "isBinary": true },
		},
	}

	var exprs: Vrm1Expressions = _ext.call("_parse_expressions", d)

	assert_true(exprs.preset.has("happy"))
	assert_true(exprs.preset.has("sad"))
	assert_false(exprs.preset["happy"].is_binary)
	assert_true(exprs.preset["sad"].is_binary)


func test_parse_expressions_custom_keys_stored_separately() -> void:
	var d: Dictionary = {
		"preset": {
			"happy": {},
		},
		"custom": {
			"myCustomExpr": {},
		},
	}

	var exprs: Vrm1Expressions = _ext.call("_parse_expressions", d)

	assert_true(exprs.preset.has("happy"))
	assert_false(exprs.preset.has("myCustomExpr"))
	assert_true(exprs.custom.has("myCustomExpr"))
	assert_false(exprs.custom.has("happy"))


func test_parse_expressions_empty() -> void:
	var exprs: Vrm1Expressions = _ext.call("_parse_expressions", {})

	assert_eq(exprs.preset.size(), 0)
	assert_eq(exprs.custom.size(), 0)


# ---------------------------------------------------------------------------
# _parse_expression_data
# ---------------------------------------------------------------------------

func test_parse_expression_data_override_defaults() -> void:
	var ed: Vrm1ExpressionData = _ext.call("_parse_expression_data", {})

	assert_eq(ed.override_blink, "none")
	assert_eq(ed.override_look_at, "none")
	assert_eq(ed.override_mouth, "none")
	assert_false(ed.is_binary)


func test_parse_expression_data_morph_binds() -> void:
	var d: Dictionary = {
		"morphTargetBinds": [
			{ "node": 4, "index": 2, "weight": 0.8 },
		],
	}

	var ed: Vrm1ExpressionData = _ext.call("_parse_expression_data", d)

	assert_eq(ed.morph_binds.size(), 1)
	var mb: Vrm1ExpressionMorphBind = ed.morph_binds[0]
	assert_eq(mb.node, 4)
	assert_eq(mb.index, 2)
	assert_eq(mb.weight, 0.8)


func test_parse_expression_data_material_color_binds() -> void:
	var d: Dictionary = {
		"materialColorBinds": [
			{
				"material": 1,
				"type": "color",
				"targetValue": [1.0, 0.0, 0.0, 1.0],
			},
		],
	}

	var ed: Vrm1ExpressionData = _ext.call("_parse_expression_data", d)

	assert_eq(ed.material_color_binds.size(), 1)
	var cb: Vrm1ExpressionMaterialColorBind = ed.material_color_binds[0]
	assert_eq(cb.material, 1)
	assert_eq(cb.type, "color")
	assert_eq(cb.target_value.size(), 4)
	assert_eq(cb.target_value[0], 1.0)


func test_parse_expression_data_texture_transform_binds() -> void:
	var d: Dictionary = {
		"textureTransformBinds": [
			{
				"material": 2,
				"scale": [2.0, 3.0],
				"offset": [0.1, 0.2],
			},
		],
	}

	var ed: Vrm1ExpressionData = _ext.call("_parse_expression_data", d)

	assert_eq(ed.texture_transform_binds.size(), 1)
	var tb: Vrm1ExpressionTextureTransformBind = ed.texture_transform_binds[0]
	assert_eq(tb.material, 2)
	assert_eq(tb.scale, Vector2(2.0, 3.0))
	assert_eq(tb.offset, Vector2(0.1, 0.2))


func test_parse_expression_data_texture_transform_defaults_when_absent() -> void:
	var d: Dictionary = {
		"textureTransformBinds": [
			{ "material": 0 },
		],
	}

	var ed: Vrm1ExpressionData = _ext.call("_parse_expression_data", d)
	var tb: Vrm1ExpressionTextureTransformBind = ed.texture_transform_binds[0]

	assert_eq(tb.scale, Vector2(1.0, 1.0))
	assert_eq(tb.offset, Vector2(0.0, 0.0))


# ---------------------------------------------------------------------------
# _parse_spring_bone
# ---------------------------------------------------------------------------

func test_parse_spring_bone_empty() -> void:
	var sb: Vrm1SpringBone = _ext.call("_parse_spring_bone", {})

	assert_eq(sb.colliders.size(), 0)
	assert_eq(sb.collider_groups.size(), 0)
	assert_eq(sb.springs.size(), 0)


func test_parse_spring_bone_counts() -> void:
	var d: Dictionary = {
		"colliders": [
			{ "node": 0, "shape": { "sphere": { "radius": 0.05 } } },
		],
		"colliderGroups": [
			{ "name": "HeadGroup", "colliders": [0] },
		],
		"springs": [
			{ "name": "HairSpring", "joints": [] },
		],
	}

	var sb: Vrm1SpringBone = _ext.call("_parse_spring_bone", d)

	assert_eq(sb.colliders.size(), 1)
	assert_eq(sb.collider_groups.size(), 1)
	assert_eq(sb.springs.size(), 1)


func test_parse_spring_bone_collider_group_collider_indices() -> void:
	var d: Dictionary = {
		"colliderGroups": [
			{ "name": "Group", "colliders": [0, 2, 5] },
		],
	}

	var sb: Vrm1SpringBone = _ext.call("_parse_spring_bone", d)
	var group: Vrm1SpringBoneColliderGroup = sb.collider_groups[0]

	assert_eq(group.name, "Group")
	assert_eq(group.colliders.size(), 3)
	assert_eq(group.colliders[0], 0)
	assert_eq(group.colliders[2], 5)


# ---------------------------------------------------------------------------
# _parse_spring_bone_collider — standard shapes
# ---------------------------------------------------------------------------

func test_parse_spring_bone_collider_standard_sphere() -> void:
	var d: Dictionary = {
		"node": 3,
		"shape": {
			"sphere": {
				"radius": 0.08,
				"offset": [0.0, 0.1, 0.0],
			},
		},
	}

	var col: Vrm1SpringBoneCollider = _ext.call("_parse_spring_bone_collider", d)

	assert_eq(col.node, 3)
	assert_eq(col.shape.type, "sphere")
	assert_eq(col.shape.radius, 0.08)
	assert_eq(col.shape.offset, Vector3(0.0, 0.1, 0.0))


func test_parse_spring_bone_collider_standard_capsule() -> void:
	var d: Dictionary = {
		"node": 1,
		"shape": {
			"capsule": {
				"radius": 0.04,
				"offset": [0.0, 0.0, 0.0],
				"tail": [0.0, -0.2, 0.0],
			},
		},
	}

	var col: Vrm1SpringBoneCollider = _ext.call("_parse_spring_bone_collider", d)

	assert_eq(col.shape.type, "capsule")
	assert_eq(col.shape.radius, 0.04)
	assert_eq(col.shape.tail, Vector3(0.0, -0.2, 0.0))


# ---------------------------------------------------------------------------
# _parse_spring_bone_collider — extended collider (takes priority)
# ---------------------------------------------------------------------------

func test_parse_spring_bone_collider_extended_sphere_takes_priority() -> void:
	var d: Dictionary = {
		"node": 0,
		# Standard shape also present — extended must win.
		"shape": { "sphere": { "radius": 0.01 } },
		"extensions": {
			"VRMC_springBone_extended_collider": {
				"shape": {
					"sphere": {
						"radius": 0.15,
						"offset": [0.0, 0.5, 0.0],
						"inside": true,
					},
				},
			},
		},
	}

	var col: Vrm1SpringBoneCollider = _ext.call("_parse_spring_bone_collider", d)

	assert_eq(col.shape.type, "sphere")
	assert_eq(col.shape.radius, 0.15, "Extended collider radius must take priority")
	assert_true(col.shape.inside)


func test_parse_spring_bone_collider_extended_capsule() -> void:
	var d: Dictionary = {
		"node": 0,
		"extensions": {
			"VRMC_springBone_extended_collider": {
				"shape": {
					"capsule": {
						"radius": 0.06,
						"offset": [0.0, 0.0, 0.0],
						"tail": [0.0, -0.3, 0.0],
						"inside": false,
					},
				},
			},
		},
	}

	var col: Vrm1SpringBoneCollider = _ext.call("_parse_spring_bone_collider", d)

	assert_eq(col.shape.type, "capsule")
	assert_eq(col.shape.radius, 0.06)
	assert_eq(col.shape.tail, Vector3(0.0, -0.3, 0.0))
	assert_false(col.shape.inside)


func test_parse_spring_bone_collider_extended_plane() -> void:
	var d: Dictionary = {
		"node": 0,
		"extensions": {
			"VRMC_springBone_extended_collider": {
				"shape": {
					"plane": {
						"offset": [0.0, 0.0, 0.0],
						"normal": [0.0, 1.0, 0.0],
					},
				},
			},
		},
	}

	var col: Vrm1SpringBoneCollider = _ext.call("_parse_spring_bone_collider", d)

	assert_eq(col.shape.type, "plane")
	assert_eq(col.shape.normal, Vector3(0.0, 1.0, 0.0))


# ---------------------------------------------------------------------------
# _parse_spring_bone_joint
# ---------------------------------------------------------------------------

func test_parse_spring_bone_joint_defaults() -> void:
	var jt: Vrm1SpringBoneJoint = _ext.call("_parse_spring_bone_joint", {})

	assert_eq(jt.node, -1)
	assert_eq(jt.hit_radius, 0.0)
	assert_eq(jt.stiffness, 1.0)
	assert_eq(jt.gravity_power, 0.0)
	assert_eq(jt.drag_force, 0.5)


func test_parse_spring_bone_joint_explicit_fields() -> void:
	var d: Dictionary = {
		"node": 8,
		"hitRadius": 0.03,
		"stiffness": 2.5,
		"gravityPower": 0.2,
		"dragForce": 0.7,
		"gravityDir": [0.0, -1.0, 0.0],
	}

	var jt: Vrm1SpringBoneJoint = _ext.call("_parse_spring_bone_joint", d)

	assert_eq(jt.node, 8)
	assert_eq(jt.hit_radius, 0.03)
	assert_eq(jt.stiffness, 2.5)
	assert_eq(jt.gravity_power, 0.2)
	assert_eq(jt.drag_force, 0.7)
	assert_eq(jt.gravity_dir, Vector3(0.0, -1.0, 0.0),
			"VRM1 gravityDir is a [x,y,z] array, not a dict")
