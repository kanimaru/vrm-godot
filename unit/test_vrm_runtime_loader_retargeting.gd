extends GutTest

const VrmRuntimeLoader = preload("res://runtime/vrm_runtime_loader.gd")


# The VMD builder emits IK positions as DELTAS from each bone's rest ("VMD
# positions are deltas from rest" — vmd_animation_library_builder), so the
# retarget maps them: final = foot_world_rest + zmirror(delta − hips_key0_xz) * S
# where S is the leg-length translation scale (1.0 for the skeletons below) and
# zmirror = (x, y, −z): the single-axis mirror that converts left-handed MMD to
# right-handed Godot. X is PRESERVED — MMD left = Godot left; flipping X swaps
# each leg across the body (empirically verified). The SAME mapping applies on
# every facing — hips and feet must never get facing-dependent conventions
# (that was the hips-ahead-of-feet bug).
#
# The mock legs are sized so hips_rest_y − foot_world_rest_y = 0.9 → S = 1.0.
func _build_leg_model(vrm0: bool) -> Node3D:
	var model := Node3D.new()
	if vrm0:
		model.transform.basis = Basis(Vector3.UP, PI)
	add_child_autofree(model)
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)

	var hips_idx := skeleton.add_bone("hips")
	var upper_idx := skeleton.add_bone("leftUpperLeg")
	var lower_idx := skeleton.add_bone("leftLowerLeg")
	var foot_idx := skeleton.add_bone("leftFoot")
	skeleton.set_bone_parent(upper_idx, hips_idx)
	skeleton.set_bone_parent(lower_idx, upper_idx)
	skeleton.set_bone_parent(foot_idx, lower_idx)

	# Foot world rest lands at skeleton-space (-0.15, 0.08, 0); leg length 0.9.
	skeleton.set_bone_rest(hips_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.98, 0.0)))
	skeleton.set_bone_rest(upper_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
	skeleton.set_bone_rest(lower_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
	skeleton.set_bone_rest(foot_idx, Transform3D(Basis.IDENTITY, Vector3(-0.15, -0.1, 0.0)))
	skeleton.reset_bone_poses()

	model.set_meta("vrm_humanoid_bones", {
		"hips": "hips",
		"leftupperleg": "leftUpperLeg",
		"leftlowerleg": "leftLowerLeg",
		"leftfoot": "leftFoot",
	})
	if vrm0:
		model.set_meta("vrm_version", 0.0)
	return model


func _build_ik_library(delta: Vector3) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("%leftLegIk"))
	anim.track_insert_key(track, 0.0, delta)
	library.add_animation("default", anim)
	return library


func test_vmd_ik_retargeting_vrm1() -> void:
	var loader := VrmRuntimeLoader.new()
	autofree(loader)
	var model := _build_leg_model(false)

	# Builder-style DELTA: the foot moves 0.0136 toward MMD −X and lifts 0.05.
	var library := _build_ik_library(Vector3(-0.0136, 0.05, 0.0))
	loader._retarget_library_for_model(library, model, true)

	var anim: Animation = library.get_animation("default")
	var retargeted_pos: Vector3 = anim.track_get_key_value(0, 0)

	# foot world rest (-0.15, 0.08, 0) + zmirror(-0.0136, 0.05, 0) * S(=1)
	#   = (-0.15 - 0.0136, 0.08 + 0.05, 0)
	var expected_pos := Vector3(-0.1636, 0.13, 0.0)
	assert_true(retargeted_pos.is_equal_approx(expected_pos),
		"Retargeted pos %s should be approximately equal to %s" % [retargeted_pos, expected_pos])


func test_vmd_ik_retargeting_vrm0() -> void:
	var loader := VrmRuntimeLoader.new()
	autofree(loader)
	var model := _build_leg_model(true)

	var library := _build_ik_library(Vector3(-0.0136, 0.05, 0.0))
	loader._retarget_library_for_model(library, model, true)

	var anim: Animation = library.get_animation("default")
	var retargeted_pos: Vector3 = anim.track_get_key_value(0, 0)

	# VRM0: foot world rest picks up the importer's 180° model rotation →
	# (0.15, 0.08, 0). The DELTA mapping is the same facing-independent
	# z-mirror: (0.15 - 0.0136, 0.08 + 0.05, 0)
	var expected_pos := Vector3(0.1364, 0.13, 0.0)
	assert_true(retargeted_pos.is_equal_approx(expected_pos),
		"Retargeted pos %s should be approximately equal to %s" % [retargeted_pos, expected_pos])


func test_vmd_ik_zero_delta_lands_on_the_foot_rest() -> void:
	# THE stance property that was broken twice: with no authored motion, each
	# foot must sit exactly on its own world rest — not crossed (fake MMD rest
	# offset), not widened, and never anchored to the OTHER foot's side.
	var loader := VrmRuntimeLoader.new()
	autofree(loader)
	var model := _build_leg_model(false)

	var library := _build_ik_library(Vector3.ZERO)
	loader._retarget_library_for_model(library, model, true)

	var anim: Animation = library.get_animation("default")
	var retargeted_pos: Vector3 = anim.track_get_key_value(0, 0)
	assert_true(retargeted_pos.is_equal_approx(Vector3(-0.15, 0.08, 0.0)),
		"Zero delta should land on the foot's world rest, got %s" % retargeted_pos)
