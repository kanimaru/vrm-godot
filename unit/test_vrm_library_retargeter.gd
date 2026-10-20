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
