extends "res://unit/vrm_gut_test.gd"

## Unit tests for Vrm1LookAtController: bone resolution through the VRM humanoid role map
## (not hardcoded PascalCase bone names - real files rarely use those) and per-eye
## convergence (opposite eyes use opposite inner/outer range maps for the same yaw sign).
## Unlike the native SpringBoneSimulator3D, this controller writes bone poses via a plain
## set_bone_pose_rotation() call from _process(), not through the skeleton modifier
## pipeline, so its effect IS directly queryable via get_bone_pose_rotation() afterward.

const Vrm1LookAtController = preload("res://addons/vrm/vrm1/nodes/vrm1_look_at_controller.gd")


## Builds a skeleton with realistic (non-"Head"/"LeftEye"/"RightEye") bone names, matching
## how real VRM1 avatars are actually rigged, plus the humanoid role metadata a real import
## would have set via VRMUtil.set_humanoid_bone_map.
func _make_rig() -> Dictionary:
	var skeleton := Skeleton3D.new()
	var hips_idx := skeleton.add_bone("Hips")
	skeleton.set_bone_rest(hips_idx, Transform3D.IDENTITY)
	var head_idx := skeleton.add_bone("head")
	skeleton.set_bone_parent(head_idx, hips_idx)
	skeleton.set_bone_rest(head_idx, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)))
	var left_eye_idx := skeleton.add_bone("eye.L")
	skeleton.set_bone_parent(left_eye_idx, head_idx)
	skeleton.set_bone_rest(left_eye_idx, Transform3D(Basis.IDENTITY, Vector3(-0.03, 0.05, 0.05)))
	var right_eye_idx := skeleton.add_bone("eye.R")
	skeleton.set_bone_parent(right_eye_idx, head_idx)
	skeleton.set_bone_rest(right_eye_idx, Transform3D(Basis.IDENTITY, Vector3(0.03, 0.05, 0.05)))
	skeleton.reset_bone_poses()

	var model := Node3D.new()
	model.set_meta("vrm_humanoid_bones", {"head": "head", "lefteye": "eye.L", "righteye": "eye.R"})

	return {
		"skeleton": skeleton,
		"model": model,
		"head_idx": head_idx,
		"left_eye_idx": left_eye_idx,
		"right_eye_idx": right_eye_idx,
	}


func _make_range_map(input_max: float, output_scale: float) -> Vrm1LookAt.RangeMap:
	var rm := Vrm1LookAt.RangeMap.new()
	rm.input_max_value = input_max
	rm.output_scale = output_scale
	return rm


func _make_look_at(type: String) -> Vrm1LookAt:
	var la := Vrm1LookAt.new()
	la.type = type
	la.range_map_horizontal_inner = _make_range_map(90.0, 10.0)
	la.range_map_horizontal_outer = _make_range_map(90.0, 30.0)
	la.range_map_vertical_down = _make_range_map(90.0, 20.0)
	la.range_map_vertical_up = _make_range_map(90.0, 40.0)
	return la


func _attach(skeleton: Skeleton3D, model: Node3D, look_at: Vrm1LookAt) -> Vrm1LookAtController:
	var controller := Vrm1LookAtController.new()
	model.add_child(skeleton)
	add_child_autofree(model)
	controller.setup(look_at, skeleton, model, null)
	model.add_child(controller)
	return controller


# ---------------------------------------------------------------------------
# Bone resolution through the humanoid role map
# ---------------------------------------------------------------------------

func test_resolves_eye_bones_by_role_not_hardcoded_pascal_case_names() -> void:
	var rig: Dictionary = _make_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	assert_eq(controller._head_bone_idx, rig.head_idx, "head should resolve via the humanoid role map even though the bone isn't named 'Head'")
	assert_eq(controller._left_eye_bone_idx, rig.left_eye_idx, "leftEye should resolve to 'eye.L', not fail because it isn't named 'LeftEye'")
	assert_eq(controller._right_eye_bone_idx, rig.right_eye_idx)


func test_target_node_drives_eye_rotation_using_resolved_head_bone() -> void:
	var rig: Dictionary = _make_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	var target := Node3D.new()
	rig.model.add_child(target)
	# Placed to the head's left and roughly level - should produce a nonzero left-ward yaw.
	target.global_position = rig.skeleton.get_bone_global_pose(rig.head_idx).origin + Vector3(1.0, 0.0, 1.0)
	controller.target_node = controller.get_path_to(target)

	controller._process(0.0)

	var left_rot: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.left_eye_idx)
	assert_false(left_rot.is_equal_approx(Quaternion.IDENTITY), "eye rotation should have moved off identity - proves _head_bone_idx resolved correctly and the target-node path engaged")


# ---------------------------------------------------------------------------
# Per-eye convergence (bone type)
# Per lookAt.md's table: Yaw>0 (left) -> leftEye uses Outer, rightEye uses Inner.
#                        Yaw<0 (right) -> leftEye uses Inner, rightEye uses Outer.
# ---------------------------------------------------------------------------

func test_looking_left_gives_left_eye_outer_and_right_eye_inner() -> void:
	var rig: Dictionary = _make_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	controller.target_yaw = 45.0  # positive = look left, per lookAt.md's yaw convention
	controller._process(0.0)

	# factor = min(45, 90)/90 = 0.5 -> inner-mapped = 0.5*10 = 5deg, outer-mapped = 0.5*30 = 15deg
	var left_yaw: float = rig.skeleton.get_bone_pose_rotation(rig.left_eye_idx).get_euler().y
	var right_yaw: float = rig.skeleton.get_bone_pose_rotation(rig.right_eye_idx).get_euler().y
	assert_almost_eq(rad_to_deg(left_yaw), 15.0, 0.01, "left eye should swing outward (Outer map) when looking toward its own side")
	assert_almost_eq(rad_to_deg(right_yaw), 5.0, 0.01, "right eye should swing inward (Inner map), converging toward the nose")


func test_looking_right_gives_left_eye_inner_and_right_eye_outer() -> void:
	var rig: Dictionary = _make_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	controller.target_yaw = -45.0
	controller._process(0.0)

	var left_yaw: float = rig.skeleton.get_bone_pose_rotation(rig.left_eye_idx).get_euler().y
	var right_yaw: float = rig.skeleton.get_bone_pose_rotation(rig.right_eye_idx).get_euler().y
	assert_almost_eq(rad_to_deg(left_yaw), -5.0, 0.01, "left eye should swing inward (Inner map) when looking away from its own side")
	assert_almost_eq(rad_to_deg(right_yaw), -15.0, 0.01, "right eye should swing outward (Outer map)")


func test_pitch_is_shared_identically_between_both_eyes() -> void:
	var rig: Dictionary = _make_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	controller.target_pitch = 30.0  # positive = up (rangeMapVerticalUp)
	controller._process(0.0)

	var left_pitch: float = rig.skeleton.get_bone_pose_rotation(rig.left_eye_idx).get_euler().x
	var right_pitch: float = rig.skeleton.get_bone_pose_rotation(rig.right_eye_idx).get_euler().x
	assert_almost_eq(left_pitch, right_pitch, 0.0001, "vertical range maps have no inner/outer distinction - both eyes should pitch identically")


# ---------------------------------------------------------------------------
# Eye bones with a rest rotation (Blender exports eye.L/eye.R pointing along their roll)
# ---------------------------------------------------------------------------

## A rest rotation like the eye bones of a Blender-rigged avatar: about -106 degrees
## around a tilted axis, nowhere near identity.
const TILTED_EYE_REST := Quaternion(0.0, -0.8037946, -0.5949070, 0.0)


func _make_tilted_rig() -> Dictionary:
	var rig: Dictionary = _make_rig()
	for idx: int in [rig.left_eye_idx, rig.right_eye_idx]:
		var rest: Transform3D = rig.skeleton.get_bone_rest(idx)
		rest.basis = Basis(TILTED_EYE_REST.normalized())
		rig.skeleton.set_bone_rest(idx, rest)
	rig.skeleton.reset_bone_poses()
	return rig


## Where the eye's rest gaze (+Z in model axes) points now, in skeleton space.
func _gaze(skeleton: Skeleton3D, idx: int) -> Vector3:
	var now: Quaternion = skeleton.get_bone_global_pose(idx).basis.get_rotation_quaternion()
	var rest: Quaternion = skeleton.get_bone_global_rest(idx).basis.get_rotation_quaternion()
	return (now * rest.inverse()) * Vector3.BACK


func test_centered_gaze_keeps_a_rotated_eye_rest() -> void:
	var rig: Dictionary = _make_tilted_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	controller.target_yaw = 30.0
	controller._process(0.0)
	controller.target_yaw = 0.0
	controller._process(0.0)

	var pose: Quaternion = rig.skeleton.get_bone_pose_rotation(rig.left_eye_idx)
	# q and -q are the same rotation, so compare by |dot| rather than component-wise.
	assert_almost_eq(absf(pose.dot(TILTED_EYE_REST.normalized())), 1.0, 0.0001,
			"looking straight ahead must leave the eye at its rest rotation, not at identity")


func test_rotated_eye_rest_looks_left_and_up_in_model_axes() -> void:
	var rig: Dictionary = _make_tilted_rig()
	var controller := _attach(rig.skeleton, rig.model, _make_look_at("bone"))

	controller.target_yaw = 90.0  # full left: outer map 30 deg on the left eye
	controller._process(0.0)
	var left: Vector3 = _gaze(rig.skeleton, rig.left_eye_idx)
	assert_almost_eq(rad_to_deg(atan2(left.x, left.z)), 30.0, 0.01,
			"yaw > 0 turns the gaze toward +X (the avatar's left) whatever the bone's rest")
	assert_almost_eq(left.y, 0.0, 0.0001, "pure yaw must not tilt the gaze")

	controller.target_yaw = 0.0
	controller.target_pitch = 90.0  # full up: up map 40 deg
	controller._process(0.0)
	var up: Vector3 = _gaze(rig.skeleton, rig.right_eye_idx)
	assert_almost_eq(rad_to_deg(asin(up.y)), 40.0, 0.01, "pitch > 0 lifts the gaze toward +Y")
	assert_almost_eq(up.x, 0.0, 0.0001, "pure pitch must not swing the gaze sideways")


# ---------------------------------------------------------------------------
# Expression type - always uses the Outer map, no inner/outer split
# ---------------------------------------------------------------------------

func test_expression_type_always_uses_outer_map_regardless_of_sign() -> void:
	var rig: Dictionary = _make_rig()
	var expr_script = load("res://addons/vrm/vrm1/nodes/vrm1_expression_controller.gd")
	var expr_controller = expr_script.new()
	rig.model.add_child(expr_controller)

	# Sub-1.0 output scales so Inner (0.2) vs Outer (0.6) stay distinguishable after the
	# exported look_left/look_right properties' [0,1] clamp - large values from
	# _make_look_at() would saturate both to 1.0 and the test couldn't tell them apart.
	var look_at := _make_look_at("expression")
	look_at.range_map_horizontal_inner = _make_range_map(90.0, 0.2)
	look_at.range_map_horizontal_outer = _make_range_map(90.0, 0.6)

	var controller := Vrm1LookAtController.new()
	rig.model.add_child(rig.skeleton)
	add_child_autofree(rig.model)
	controller.setup(look_at, rig.skeleton, rig.model, expr_controller)
	rig.model.add_child(controller)

	controller.target_yaw = 45.0
	controller._process(0.0)

	# factor = min(45,90)/90 = 0.5 -> Outer-mapped = 0.5*0.6 = 0.3. If Inner (0.2) had been
	# used instead, this would read 0.1.
	assert_almost_eq(expr_controller.look_left, 0.3, 0.0001, "expression type has no inner/outer distinction and must always use the Outer map")
	assert_almost_eq(expr_controller.look_right, 0.0, 0.0001)


# ---------------------------------------------------------------------------
# Saved with the imported scene: setup() only runs while importing
# ---------------------------------------------------------------------------

func test_controller_keeps_its_setup_through_a_saved_scene() -> void:
	var rig: Dictionary = _make_tilted_rig()
	var controller := Vrm1LookAtController.new()
	controller.name = "Vrm1LookAtController"
	rig.model.add_child(rig.skeleton)
	rig.skeleton.owner = rig.model
	rig.model.add_child(controller)
	controller.owner = rig.model
	controller.setup(_make_look_at("bone"), rig.skeleton, rig.model, null)

	var path := "user://test_look_at_controller_saved.scn"
	var packed := PackedScene.new()
	assert_eq(packed.pack(rig.model), OK)
	assert_eq(ResourceSaver.save(packed, path), OK)
	rig.model.free()

	var loaded: Node3D = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			as PackedScene).instantiate()
	add_child_autofree(loaded)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var restored: Vrm1LookAtController = loaded.get_node("Vrm1LookAtController")
	var skeleton: Skeleton3D = loaded.get_child(0)

	assert_not_null(restored.look_at_data, "the look-at data must be saved with the scene")
	assert_not_null(restored.look_at_data.range_map_horizontal_outer,
			"and its range maps, which an inner-class resource could not be")
	assert_eq(restored.skeleton, skeleton, "the skeleton reference must survive the save")

	restored.target_yaw = 90.0
	restored._process(0.0)
	var left: Vector3 = _gaze(skeleton, rig.left_eye_idx)
	assert_almost_eq(rad_to_deg(atan2(left.x, left.z)), 30.0, 0.01,
			"a loaded scene's controller must still turn the eyes")
