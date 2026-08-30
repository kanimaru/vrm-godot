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
	var r_upper_idx := skeleton.add_bone("rightUpperLeg")
	var r_lower_idx := skeleton.add_bone("rightLowerLeg")
	var r_foot_idx := skeleton.add_bone("rightFoot")
	skeleton.set_bone_parent(upper_idx, hips_idx)
	skeleton.set_bone_parent(lower_idx, upper_idx)
	skeleton.set_bone_parent(foot_idx, lower_idx)
	skeleton.set_bone_parent(r_upper_idx, hips_idx)
	skeleton.set_bone_parent(r_lower_idx, r_upper_idx)
	skeleton.set_bone_parent(r_foot_idx, r_lower_idx)

	# Foot world rests land at skeleton-space (∓0.15, 0.08, 0); leg length 0.9,
	# so the leg-length scale S = (0.98 − 0.08) / 0.9 = 1.0 exactly.
	skeleton.set_bone_rest(hips_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.98, 0.0)))
	skeleton.set_bone_rest(upper_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
	skeleton.set_bone_rest(lower_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
	skeleton.set_bone_rest(foot_idx, Transform3D(Basis.IDENTITY, Vector3(-0.15, -0.1, 0.0)))
	skeleton.set_bone_rest(r_upper_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
	skeleton.set_bone_rest(r_lower_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
	skeleton.set_bone_rest(r_foot_idx, Transform3D(Basis.IDENTITY, Vector3(0.15, -0.1, 0.0)))
	skeleton.reset_bone_poses()

	model.set_meta("vrm_humanoid_bones", {
		"hips": "hips",
		"leftupperleg": "leftUpperLeg",
		"leftlowerleg": "leftLowerLeg",
		"leftfoot": "leftFoot",
		"rightupperleg": "rightUpperLeg",
		"rightlowerleg": "rightLowerLeg",
		"rightfoot": "rightFoot",
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


# Library with a hips position track, 90°-bent FK rotation keys on BOTH upper
# legs (the junk MMD bakes onto IK-controlled bones), and optionally a leg IK
# position track marking the clip as IK-driven.
func _build_hips_library(with_leg_ik: bool) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var anim := Animation.new()

	var hips_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_track, NodePath("%GeneralSkeleton:hips"))
	anim.track_insert_key(hips_track, 0.0, Vector3.ZERO)
	anim.track_insert_key(hips_track, 1.0, Vector3(0.0, -0.5, 0.0))

	var bent := Quaternion(Vector3.RIGHT, PI / 2.0)
	for leg in ["leftUpperLeg", "rightUpperLeg"]:
		var rot_track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, NodePath("%GeneralSkeleton:" + leg))
		anim.track_insert_key(rot_track, 0.0, bent)

	if with_leg_ik:
		var ik_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(ik_track, NodePath("%leftLegIk"))
		anim.track_insert_key(ik_track, 0.0, Vector3.ZERO)

	library.add_animation("default", anim)
	return library


func _get_hips_track(library: AnimationLibrary) -> Array:
	var anim: Animation = library.get_animation("default")
	var track := anim.find_track(NodePath("%GeneralSkeleton:hips"), Animation.TYPE_POSITION_3D)
	assert_true(track >= 0, "hips position track should survive the retarget")
	return [anim, track]


func test_vmd_hips_ignores_junk_fk_legs_when_ik_drives_them() -> void:
	# MMD ignores FK keys on IK-controlled bones — motion files carry baked
	# residue there. Grounding the hips against that residue per key made the
	# base height flutter (body bobbing, feet hovering). With leg IK tracks in
	# the clip the base must be the hips REST height, moved only by センター
	# deltas: rest 0.98 at key0, 0.98 − 0.5 at the dip key.
	var loader := VrmRuntimeLoader.new()
	autofree(loader)
	var model := _build_leg_model(false)

	var library := _build_hips_library(true)
	loader._retarget_library_for_model(library, model, true)

	var pair := _get_hips_track(library)
	var anim: Animation = pair[0]
	var track: int = pair[1]
	var key0: Vector3 = anim.track_get_key_value(track, 0)
	var key1: Vector3 = anim.track_get_key_value(track, 1)
	assert_true(key0.is_equal_approx(Vector3(0.0, 0.98, 0.0)),
		"IK-driven clip: key0 should sit at hips rest despite bent FK junk, got %s" % key0)
	assert_true(key1.is_equal_approx(Vector3(0.0, 0.48, 0.0)),
		"IK-driven clip: dip should be rest + S*delta = 0.48, got %s" % key1)


func test_vmd_hips_fk_grounding_still_applies_without_ik() -> void:
	# FK-only clip: the FK leg keys ARE the motion, so the per-key grounding
	# must keep planting the feet. Both upper legs bent 90° about X put the
	# FK feet 0.5 above their rests → hips base drops to 0.48.
	var loader := VrmRuntimeLoader.new()
	autofree(loader)
	var model := _build_leg_model(false)

	var library := _build_hips_library(false)
	loader._retarget_library_for_model(library, model, true)

	var pair := _get_hips_track(library)
	var anim: Animation = pair[0]
	var track: int = pair[1]
	var key0: Vector3 = anim.track_get_key_value(track, 0)
	var key1: Vector3 = anim.track_get_key_value(track, 1)
	assert_true(key0.is_equal_approx(Vector3(0.0, 0.48, 0.0)),
		"FK-only clip: key0 should ground the bent legs at 0.48, got %s" % key0)
	assert_true(key1.is_equal_approx(Vector3(0.0, -0.02, 0.0)),
		"FK-only clip: dip should be grounded base + S*delta = -0.02, got %s" % key1)


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
