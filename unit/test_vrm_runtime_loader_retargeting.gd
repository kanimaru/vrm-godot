extends GutTest

const VrmRuntimeLoader = preload("res://runtime/vrm_runtime_loader.gd")


func test_vmd_ik_retargeting_vrm1() -> void:
	var loader := VrmRuntimeLoader.new()
	autofree(loader)

	# Setup a mock model and skeleton (VRM1: identity rotation relative to model)
	var model := Node3D.new()
	add_child_autofree(model)
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)

	var hips_idx := skeleton.add_bone("hips")
	var left_upper_leg_idx := skeleton.add_bone("leftUpperLeg")
	var left_lower_leg_idx := skeleton.add_bone("leftLowerLeg")
	var left_foot_idx := skeleton.add_bone("leftFoot")

	skeleton.set_bone_parent(left_upper_leg_idx, hips_idx)
	skeleton.set_bone_parent(left_lower_leg_idx, left_upper_leg_idx)
	skeleton.set_bone_parent(left_foot_idx, left_lower_leg_idx)

	# Rest position of left foot at X = -0.15, Y = 0.08
	var left_foot_rest := Transform3D(Basis.IDENTITY, Vector3(-0.15, 0.08, 0.0))
	skeleton.set_bone_rest(left_foot_idx, left_foot_rest)
	skeleton.reset_bone_poses()

	# Metadata for bones lookup
	var bone_map := {
		"hips": "hips",
		"leftupperleg": "leftUpperLeg",
		"leftlowerleg": "leftLowerLeg",
		"leftfoot": "leftFoot",
	}
	model.set_meta("vrm_humanoid_bones", bone_map)

	# Set up a test animation library with a leftLegIk position track
	var library := AnimationLibrary.new()
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	# MMD Left foot standard rest position is at X = -1.83 units. With position_scale = 0.08,
	# scaled rest is at -0.1464.
	# Let's say target moves left to -2.0 units (-0.16m scaled)
	var vmd_absolute_pos := Vector3(-0.16, 0.05, 0.0)
	anim.track_set_path(track, NodePath("%leftLegIk"))
	anim.track_insert_key(track, 0.0, vmd_absolute_pos)
	library.add_animation("default", anim)

	# Run retargeting
	# position_scale will be dynamically calculated as 0.08 because we don't have a "head" bone
	# (so it falls back to 0.08).
	loader._retarget_library_for_model(library, model, true)

	var retargeted_pos: Vector3 = anim.track_get_key_value(track, 0)
	
	# Calculation check:
	# mmd_rest_godot = Vector3(-1.83, 0, 0) * 0.08 = Vector3(-0.1464, 0, 0)
	# delta = vmd_absolute_pos - mmd_rest_godot = Vector3(-0.16, 0.05, 0) - Vector3(-0.1464, 0, 0) = Vector3(-0.0136, 0.05, 0)
	# rotated_delta = delta (since skeleton_rot is identity)
	# local_rest = left_foot_rest.origin in ModelRoot space = Vector3(-0.15, 0.08, 0.0) (since identity skeleton_rot)
	# final_pos = local_rest + rotated_delta = Vector3(-0.15 - 0.0136, 0.08 + 0.05, 0.0) = Vector3(-0.1636, 0.13, 0.0)
	var expected_pos := Vector3(-0.1636, 0.13, 0.0)
	assert_true(retargeted_pos.is_equal_approx(expected_pos), "Retargeted pos %s should be approximately equal to %s" % [retargeted_pos, expected_pos])


func test_vmd_ik_retargeting_vrm0() -> void:
	var loader := VrmRuntimeLoader.new()
	autofree(loader)

	# Setup a mock model and skeleton (VRM0: 180 Y rotation relative to model)
	var model := Node3D.new()
	model.transform.basis = Basis(Vector3.UP, PI)
	add_child_autofree(model)
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)

	var hips_idx := skeleton.add_bone("hips")
	var left_upper_leg_idx := skeleton.add_bone("leftUpperLeg")
	var left_lower_leg_idx := skeleton.add_bone("leftLowerLeg")
	var left_foot_idx := skeleton.add_bone("leftFoot")

	skeleton.set_bone_parent(left_upper_leg_idx, hips_idx)
	skeleton.set_bone_parent(left_lower_leg_idx, left_upper_leg_idx)
	skeleton.set_bone_parent(left_foot_idx, left_lower_leg_idx)

	# Rest position of left foot in skeleton space at X = -0.15, Y = 0.08
	# In ModelRoot space (rotated 180 Y), it maps to X = 0.15, Y = 0.08
	var left_foot_rest := Transform3D(Basis.IDENTITY, Vector3(-0.15, 0.08, 0.0))
	skeleton.set_bone_rest(left_foot_idx, left_foot_rest)
	skeleton.reset_bone_poses()

	# Metadata for bones lookup
	var bone_map := {
		"hips": "hips",
		"leftupperleg": "leftUpperLeg",
		"leftlowerleg": "leftLowerLeg",
		"leftfoot": "leftFoot",
	}
	model.set_meta("vrm_humanoid_bones", bone_map)
	model.set_meta("vrm_version", 0.0) # VRM0

	# Set up a test animation library with a leftLegIk position track
	var library := AnimationLibrary.new()
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	# MMD Left foot standard rest position is at X = -1.83 units. With position_scale = 0.08,
	# scaled rest is at -0.1464.
	# Let's say target moves left to -2.0 units (-0.16m scaled)
	var vmd_absolute_pos := Vector3(-0.16, 0.05, 0.0)
	anim.track_set_path(track, NodePath("%leftLegIk"))
	anim.track_insert_key(track, 0.0, vmd_absolute_pos)
	library.add_animation("default", anim)

	# Run retargeting
	loader._retarget_library_for_model(library, model, true)

	var retargeted_pos: Vector3 = anim.track_get_key_value(track, 0)
	
	# Calculation check:
	# mmd_rest_godot = Vector3(-1.83, 0, 0) * 0.08 = Vector3(-0.1464, 0, 0)
	# delta = vmd_absolute_pos - mmd_rest_godot = Vector3(-0.0136, 0.05, 0)
	# skeleton_rot = 180 Y = Basis(Vector3.UP, PI)
	# rotated_delta = skeleton_rot * delta = Vector3(0.0136, 0.05, 0)
	# local_rest = world_rests[left_foot_idx].origin = Basis(180 Y) * Vector3(-0.15, 0.08, 0) = Vector3(0.15, 0.08, 0)
	# final_pos = local_rest + rotated_delta = Vector3(0.15 + 0.0136, 0.08 + 0.05, 0.0) = Vector3(0.1636, 0.13, 0.0)
	var expected_pos := Vector3(0.1636, 0.13, 0.0)
	assert_true(retargeted_pos.is_equal_approx(expected_pos), "Retargeted pos %s should be approximately equal to %s" % [retargeted_pos, expected_pos])
