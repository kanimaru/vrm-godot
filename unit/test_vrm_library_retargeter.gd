extends GutTest

const VrmLibraryRetargeter = preload("res://addons/vrm/common/vrm_library_retargeter.gd")

# The retarget folds the MODEL's rotation into the rests (a VRM0 model is turned 180° on
# its own root), and only that: whatever turns the model's parents is the scene placing
# the avatar, not part of the clip. A ghost rig parented under a turned avatar once had
# that turn folded into every key, and a held arm swung out sideways.


func _build_arm_model(facing: Basis) -> Node3D:
	var model := Node3D.new()
	model.transform.basis = facing
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)
	var hips := skeleton.add_bone("hips")
	var arm := skeleton.add_bone("leftUpperArm")
	skeleton.set_bone_parent(arm, hips)
	skeleton.set_bone_rest(hips, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
	# A tilted rest, so the world-rest conjugation actually changes the key.
	skeleton.set_bone_rest(arm, Transform3D(Basis(Vector3.BACK, deg_to_rad(30.0)), Vector3(0.2, 0.4, 0.0)))
	skeleton.reset_bone_poses()
	model.set_meta("vrm_humanoid_bones", {"hips": "hips", "leftupperarm": "leftUpperArm"})
	return model


func _build_arm_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath("%GeneralSkeleton:leftUpperArm"))
	# About X, not the up axis the turns below use: rotations about one axis commute and would hide them.
	anim.track_insert_key(track, 0.0, Quaternion(Vector3.RIGHT, deg_to_rad(40.0)))
	library.add_animation("default", anim)
	return library


## The first key of the arm track after retargeting [param model] wherever it hangs.
func _retargeted_key(model: Node3D) -> Quaternion:
	var library := _build_arm_library()
	VrmLibraryRetargeter.retarget_library_for_model(library, model, false)
	var anim := library.get_animation("default")
	return anim.track_get_key_value(0, 0)


func _assert_same(actual: Quaternion, expected: Quaternion, why: String) -> void:
	# q and -q are the same rotation.
	assert_almost_eq(absf(actual.dot(expected)), 1.0, 0.0001, why)


func test_a_turned_parent_does_not_change_the_retarget() -> void:
	var at_root := _build_arm_model(Basis.IDENTITY)
	add_child_autofree(at_root)
	var turned := Node3D.new()
	turned.transform.basis = Basis(Vector3.UP, deg_to_rad(41.0))
	add_child_autofree(turned)
	var under_turned := _build_arm_model(Basis.IDENTITY)
	turned.add_child(under_turned)

	_assert_same(_retargeted_key(under_turned), _retargeted_key(at_root),
		"the parent's turn places the avatar; it is not folded into the clip")


func test_the_models_own_facing_still_counts() -> void:
	var facing_front := _build_arm_model(Basis.IDENTITY)
	add_child_autofree(facing_front)
	var turned_around := _build_arm_model(Basis(Vector3.UP, PI))
	add_child_autofree(turned_around)

	var front := _retargeted_key(facing_front)
	var around := _retargeted_key(turned_around)

	assert_lt(absf(front.dot(around)), 0.9999, "a VRM0 model's own 180° turn still enters the rests")


func test_a_turned_parent_does_not_change_a_turned_models_retarget() -> void:
	var at_root := _build_arm_model(Basis(Vector3.UP, PI))
	add_child_autofree(at_root)
	var turned := Node3D.new()
	turned.transform.basis = Basis(Vector3.UP, deg_to_rad(-60.0))
	add_child_autofree(turned)
	var under_turned := _build_arm_model(Basis(Vector3.UP, PI))
	turned.add_child(under_turned)

	_assert_same(_retargeted_key(under_turned), _retargeted_key(at_root),
		"only the model's own facing enters the rests, not its parent's")


# VMD with leg IK: the centre's height is a delta from the STANDING rest, like the IK targets.
# A dance that opens crouched once had that crouch taken for standing, so every later stand put
# the hips a crouch too high: legs straight, feet off the floor targets, the whole model bobbing
# instead of bending its knees (a regression seen several times).

const HIPS_REST_Y := 0.9
const CROUCH := 0.1


func _build_leg_model() -> Node3D:
	var model := Node3D.new()
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)
	var hips := skeleton.add_bone("hips")
	skeleton.set_bone_rest(hips, Transform3D(Basis.IDENTITY, Vector3(0.0, HIPS_REST_Y, 0.0)))
	var bones := {"hips": "hips"}
	for side: String in ["left", "right"]:
		var x := 0.1 if side == "left" else -0.1
		var upper := skeleton.add_bone(side + "UpperLeg")
		skeleton.set_bone_parent(upper, hips)
		skeleton.set_bone_rest(upper, Transform3D(Basis.IDENTITY, Vector3(x, -0.05, 0.0)))
		var lower := skeleton.add_bone(side + "LowerLeg")
		skeleton.set_bone_parent(lower, upper)
		skeleton.set_bone_rest(lower, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
		var foot := skeleton.add_bone(side + "Foot")
		skeleton.set_bone_parent(foot, lower)
		skeleton.set_bone_rest(foot, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0)))
		for part: String in ["UpperLeg", "LowerLeg", "Foot"]:
			bones[(side + part).to_lower()] = side + part
	skeleton.reset_bone_poses()
	model.set_meta("vrm_humanoid_bones", bones)
	return model


## Hips heights after retargeting a VMD clip that opens crouched and then stands.
func _retargeted_hips_heights(with_leg_ik: bool) -> Array[float]:
	var model := _build_leg_model()
	add_child_autofree(model)
	var library := AnimationLibrary.new()
	library.set_meta(&"pre_scaled", true)
	var anim := Animation.new()
	var hips := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips, NodePath("%GeneralSkeleton:hips"))
	anim.track_insert_key(hips, 0.0, Vector3(0.0, -CROUCH, 0.0))
	anim.track_insert_key(hips, 1.0, Vector3.ZERO)
	if with_leg_ik:
		var ik := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(ik, NodePath("%leftLegIk"))
		anim.track_insert_key(ik, 0.0, Vector3.ZERO)
		anim.track_insert_key(ik, 1.0, Vector3.ZERO)
	library.add_animation("default", anim)
	VrmLibraryRetargeter.retarget_library_for_model(library, model, true)
	var out := library.get_animation("default")
	return [
		(out.track_get_key_value(hips, 0) as Vector3).y,
		(out.track_get_key_value(hips, 1) as Vector3).y,
	]


func test_an_ik_dance_that_opens_crouched_stands_at_rest_height() -> void:
	var heights := _retargeted_hips_heights(true)

	assert_almost_eq(heights[0], HIPS_REST_Y - CROUCH, 0.0001, "the opening crouch stays a crouch")
	assert_almost_eq(heights[1], HIPS_REST_Y, 0.0001,
		"standing up lands at the rest height, not a crouch above it")
