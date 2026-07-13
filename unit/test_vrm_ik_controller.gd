extends GutTest

const VrmIkController = preload("res://addons/vrm/common/vrm_ik_controller.gd")


func test_foot_rotation_sync_vrm1() -> void:
	# Create parent node
	var model := Node3D.new()
	add_child_autofree(model)
	model.name = "Model"

	# Create skeleton
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)
	
	# Add bones
	var hips_idx := skeleton.add_bone("hips")
	var left_upper_leg_idx := skeleton.add_bone("leftUpperLeg")
	var left_lower_leg_idx := skeleton.add_bone("leftLowerLeg")
	var left_foot_idx := skeleton.add_bone("leftFoot")
	var left_toes_idx := skeleton.add_bone("leftToes")
	
	var right_upper_leg_idx := skeleton.add_bone("rightUpperLeg")
	var right_lower_leg_idx := skeleton.add_bone("rightLowerLeg")
	var right_foot_idx := skeleton.add_bone("rightFoot")
	var right_toes_idx := skeleton.add_bone("rightToes")
	
	skeleton.set_bone_parent(left_upper_leg_idx, hips_idx)
	skeleton.set_bone_parent(left_lower_leg_idx, left_upper_leg_idx)
	skeleton.set_bone_parent(left_foot_idx, left_lower_leg_idx)
	skeleton.set_bone_parent(left_toes_idx, left_foot_idx)
	
	skeleton.set_bone_parent(right_upper_leg_idx, hips_idx)
	skeleton.set_bone_parent(right_lower_leg_idx, right_upper_leg_idx)
	skeleton.set_bone_parent(right_foot_idx, right_lower_leg_idx)
	skeleton.set_bone_parent(right_toes_idx, right_foot_idx)
	
	# Set some dummy rest transforms
	skeleton.set_bone_rest(hips_idx, Transform3D.IDENTITY)
	skeleton.set_bone_rest(left_upper_leg_idx, Transform3D(Basis.IDENTITY, Vector3(-0.2, 1, 0)))
	skeleton.set_bone_rest(left_lower_leg_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	
	skeleton.set_bone_rest(right_upper_leg_idx, Transform3D(Basis.IDENTITY, Vector3(0.2, 1, 0)))
	skeleton.set_bone_rest(right_lower_leg_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	
	# Give the foot bone a rest pitch angle (pointing down and forward, say 20 degrees pitch)
	var foot_rest_basis := Basis(Vector3.RIGHT, deg_to_rad(-20.0))
	skeleton.set_bone_rest(left_foot_idx, Transform3D(foot_rest_basis, Vector3(0, -0.5, 0)))
	skeleton.set_bone_rest(left_toes_idx, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)))
	
	skeleton.set_bone_rest(right_foot_idx, Transform3D(foot_rest_basis, Vector3(0, -0.5, 0)))
	skeleton.set_bone_rest(right_toes_idx, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)))
	
	# Reset bone poses to match rests
	skeleton.reset_bone_poses()
	
	# Instantiate VRM IK Controller
	var ik_controller := VrmIkController.new()
	add_child_autofree(ik_controller)
	
	# Set metadata that VRMUtil expects
	var bone_map := {
		"leftupperleg": "leftUpperLeg",
		"leftfoot": "leftFoot",
		"lefttoes": "leftToes",
		"rightupperleg": "rightUpperLeg",
		"rightfoot": "rightFoot",
		"righttoes": "rightToes",
	}
	model.set_meta("vrm_humanoid_bones", bone_map)
	
	# Setup controller for VRM1 (is_vrm0 = false)
	ik_controller.setup(skeleton, model, false)
	ik_controller.enabled = true
	
	# Stop the IK solvers so they don't override poses during our manual testing
	ik_controller.left_leg_ik.stop()
	ik_controller.right_leg_ik.stop()
	
	# Verify cached rest orientations
	assert_eq_relative_rotation(ik_controller._left_foot_rest_skel, foot_rest_basis.get_rotation_quaternion(), "Left foot rest skel should be cached correctly")
	
	# Simulate parent bone rotation due to IK solver (e.g. lower leg rotates)
	var parent_rot := Quaternion(Vector3.RIGHT, deg_to_rad(30.0))
	var lower_leg_rest := skeleton.get_bone_rest(left_lower_leg_idx)
	skeleton.set_bone_pose(left_lower_leg_idx, Transform3D(Basis(parent_rot), lower_leg_rest.origin))
	skeleton.force_update_all_bone_transforms()
	
	# Verify parent skeleton-local rotation
	var parent_skel_q := skeleton.get_bone_global_pose(left_lower_leg_idx).basis.orthonormalized().get_rotation_quaternion()
	assert_eq_relative_rotation(parent_skel_q, parent_rot, "Parent skeleton-local rotation should match pose rotation")
	
	# Set a world rotation target for the foot (e.g. flat on the ground = Quaternion.IDENTITY)
	var vmd_target := Quaternion.IDENTITY
	ik_controller.left_target.global_transform.basis = Basis(vmd_target)
	
	# Run sync
	ik_controller._process(0.01)
	skeleton.force_update_all_bone_transforms()
	
	# Assert foot global rotation (in skeleton space, which aligns with world for VRM1 identity root)
	var foot_global_q := skeleton.get_bone_global_pose(left_foot_idx).basis.orthonormalized().get_rotation_quaternion()
	assert_eq_relative_rotation(foot_global_q, foot_rest_basis.get_rotation_quaternion(), "Foot global rotation should match rest rotation when target is identity")


func test_foot_rotation_sync_vrm0() -> void:
	# Create parent node
	var model := Node3D.new()
	add_child_autofree(model)
	model.name = "Model"

	# Create skeleton and rotate it 180 degrees around Y axis (typical for VRM 0.0 retargeting)
	var skeleton := Skeleton3D.new()
	model.add_child(skeleton)
	skeleton.transform.basis = Basis(Vector3.UP, PI)
	
	# Add bones
	var hips_idx := skeleton.add_bone("hips")
	var left_upper_leg_idx := skeleton.add_bone("leftUpperLeg")
	var left_lower_leg_idx := skeleton.add_bone("leftLowerLeg")
	var left_foot_idx := skeleton.add_bone("leftFoot")
	var left_toes_idx := skeleton.add_bone("leftToes")
	
	var right_upper_leg_idx := skeleton.add_bone("rightUpperLeg")
	var right_lower_leg_idx := skeleton.add_bone("rightLowerLeg")
	var right_foot_idx := skeleton.add_bone("rightFoot")
	var right_toes_idx := skeleton.add_bone("rightToes")
	
	skeleton.set_bone_parent(left_upper_leg_idx, hips_idx)
	skeleton.set_bone_parent(left_lower_leg_idx, left_upper_leg_idx)
	skeleton.set_bone_parent(left_foot_idx, left_lower_leg_idx)
	skeleton.set_bone_parent(left_toes_idx, left_foot_idx)
	
	skeleton.set_bone_parent(right_upper_leg_idx, hips_idx)
	skeleton.set_bone_parent(right_lower_leg_idx, right_upper_leg_idx)
	skeleton.set_bone_parent(right_foot_idx, right_lower_leg_idx)
	skeleton.set_bone_parent(right_toes_idx, right_foot_idx)
	
	# Set some dummy rest transforms
	skeleton.set_bone_rest(hips_idx, Transform3D.IDENTITY)
	skeleton.set_bone_rest(left_upper_leg_idx, Transform3D(Basis.IDENTITY, Vector3(-0.2, 1, 0)))
	skeleton.set_bone_rest(left_lower_leg_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	
	skeleton.set_bone_rest(right_upper_leg_idx, Transform3D(Basis.IDENTITY, Vector3(0.2, 1, 0)))
	skeleton.set_bone_rest(right_lower_leg_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	
	# Give the foot bone a rest pitch angle (pointing down and forward, say 20 degrees pitch)
	var foot_rest_basis := Basis(Vector3.RIGHT, deg_to_rad(-20.0))
	skeleton.set_bone_rest(left_foot_idx, Transform3D(foot_rest_basis, Vector3(0, -0.5, 0)))
	skeleton.set_bone_rest(left_toes_idx, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)))
	
	skeleton.set_bone_rest(right_foot_idx, Transform3D(foot_rest_basis, Vector3(0, -0.5, 0)))
	skeleton.set_bone_rest(right_toes_idx, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)))
	
	# Reset bone poses to match rests
	skeleton.reset_bone_poses()
	
	# Instantiate VRM IK Controller
	var ik_controller := VrmIkController.new()
	add_child_autofree(ik_controller)
	
	# Set metadata that VRMUtil expects
	var bone_map := {
		"leftupperleg": "leftUpperLeg",
		"leftfoot": "leftFoot",
		"lefttoes": "leftToes",
		"rightupperleg": "rightUpperLeg",
		"rightfoot": "rightFoot",
		"righttoes": "rightToes",
	}
	model.set_meta("vrm_humanoid_bones", bone_map)
	
	# Setup controller for VRM0 (is_vrm0 = true)
	ik_controller.setup(skeleton, model, true)
	ik_controller.enabled = true
	
	# Stop the IK solvers so they don't override poses during our manual testing
	ik_controller.left_leg_ik.stop()
	ik_controller.right_leg_ik.stop()
	
	# Simulate parent bone rotation due to IK solver (e.g. lower leg rotates)
	var parent_rot := Quaternion(Vector3.RIGHT, deg_to_rad(30.0))
	var lower_leg_rest := skeleton.get_bone_rest(left_lower_leg_idx)
	skeleton.set_bone_pose(left_lower_leg_idx, Transform3D(Basis(parent_rot), lower_leg_rest.origin))
	skeleton.force_update_all_bone_transforms()
	
	# Set a world rotation target for the foot (e.g. flat on the ground = Quaternion.IDENTITY)
	var vmd_target := Quaternion.IDENTITY
	ik_controller.left_target.global_transform.basis = Basis(vmd_target)
	
	# Run sync
	ik_controller._process(0.01)
	skeleton.force_update_all_bone_transforms()
	
	# With the corrected formula the controller converts vmd_target into
	# skeleton-local space: vmd_target_skel = skel_world_q⁻¹ × vmd_target.
	# The resulting skeleton-local global pose should be:
	#   desired_global_pose = bone_rest_skel × vmd_target_skel
	#
	# For this test: skel_world_q = 180°Y, vmd_target = identity
	#   vmd_target_skel  = 180°Y⁻¹ × identity = 180°Y
	#   desired_global_pose = foot_rest_skel × 180°Y
	var skel_world_q := skeleton.global_transform.basis.orthonormalized().get_rotation_quaternion()
	var vmd_target_skel := skel_world_q.inverse() * Quaternion.IDENTITY
	var expected_skel_q := ik_controller._left_foot_rest_skel * vmd_target_skel

	var foot_global_skel := skeleton.get_bone_global_pose(left_foot_idx).basis.orthonormalized().get_rotation_quaternion()
	assert_eq_relative_rotation(foot_global_skel, expected_skel_q, "Foot skeleton-local global rotation should match expected pose")


# Helper to assert quaternions are approximately equal
func assert_eq_relative_rotation(q1: Quaternion, q2: Quaternion, msg: String = "") -> void:
	var diff := q1.inverse() * q2
	var angle := 2.0 * acos(clampf(absf(diff.w), -1.0, 1.0))
	assert_lt(rad_to_deg(angle), 1.0, msg + " (diff angle: %f deg)" % rad_to_deg(angle))
