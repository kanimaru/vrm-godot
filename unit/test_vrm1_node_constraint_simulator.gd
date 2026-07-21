extends "res://unit/vrm_gut_test.gd"

## Runtime behavior tests for Vrm1NodeConstraintSimulator: the roll/aim/rotation formulas,
## dependency-ordered evaluation, cycle detection, and unresolved-bone handling.

const Vrm1NodeConstraintSimulator = preload("res://addons/vrm/vrm1/nodes/vrm1_node_constraint_simulator.gd")


## Builds a minimal skeleton with a root bone plus however many named child bones are
## requested (all parented directly to root, all rests at identity unless the caller
## overrides them afterward). Returns the Skeleton3D, not yet added to the tree.
func _make_skeleton(bone_names: Array[String]) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var root_idx := skeleton.add_bone("Root")
	skeleton.set_bone_rest(root_idx, Transform3D.IDENTITY)
	for bone_name: String in bone_names:
		var idx := skeleton.add_bone(bone_name)
		skeleton.set_bone_parent(idx, root_idx)
		skeleton.set_bone_rest(idx, Transform3D.IDENTITY)
	return skeleton


func _make_constraint(node: int, source: int, type: String, weight: float = 1.0, roll_axis: String = "X", aim_axis: String = "PositiveX") -> Vrm1NodeConstraint:
	var nc := Vrm1NodeConstraint.new()
	nc.node = node
	nc.source = source
	nc.type = type
	nc.weight = weight
	nc.roll_axis = roll_axis
	nc.aim_axis = aim_axis
	return nc


## Attaches a configured simulator to skeleton and adds the skeleton to the tree
## (autofreed), which fires _ready() -> _resolve_constraints() with the bones already set up.
func _attach_and_ready(skeleton: Skeleton3D, node_constraints: Dictionary[int, Vrm1NodeConstraint], gltf_node_names: Dictionary[int, String]) -> Vrm1NodeConstraintSimulator:
	var sim := Vrm1NodeConstraintSimulator.new()
	sim.node_constraints = node_constraints
	sim.gltf_node_names = gltf_node_names
	skeleton.add_child(sim)
	add_child_autofree(skeleton)
	return sim


func test_rotation_constraint_weight_one_fully_copies_delta() -> void:
	var skeleton := _make_skeleton(["Src", "Dst"])
	var src_idx := skeleton.find_bone("Src")
	var dst_idx := skeleton.find_bone("Dst")

	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {1: _make_constraint(1, 0, "rotation", 1.0)}
	var gltf_node_names: Dictionary[int, String] = {0: "Src", 1: "Dst"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	var src_pose := Quaternion(Vector3(0, 1, 0), deg_to_rad(90.0))
	skeleton.set_bone_pose_rotation(src_idx, src_pose)
	skeleton.force_update_all_bone_transforms()

	sim._process_modification()

	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(dst_idx), src_pose, "weight 1.0 rotation constraint should fully copy the source's rotation delta")


func test_rotation_constraint_weight_half_slerps_to_midpoint() -> void:
	var skeleton := _make_skeleton(["Src", "Dst"])
	var src_idx := skeleton.find_bone("Src")
	var dst_idx := skeleton.find_bone("Dst")

	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {1: _make_constraint(1, 0, "rotation", 0.5)}
	var gltf_node_names: Dictionary[int, String] = {0: "Src", 1: "Dst"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	var src_pose := Quaternion(Vector3(0, 1, 0), deg_to_rad(90.0))
	skeleton.set_bone_pose_rotation(src_idx, src_pose)
	skeleton.force_update_all_bone_transforms()

	sim._process_modification()

	var expected := Quaternion.IDENTITY.slerp(src_pose, 0.5)
	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(dst_idx), expected, "weight 0.5 should slerp halfway between rest and the full-weight result")


func test_roll_constraint_transfers_rotation_on_its_own_axis() -> void:
	var skeleton := _make_skeleton(["Src", "Dst"])
	var src_idx := skeleton.find_bone("Src")
	var dst_idx := skeleton.find_bone("Dst")

	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {1: _make_constraint(1, 0, "roll", 1.0, "Y")}
	var gltf_node_names: Dictionary[int, String] = {0: "Src", 1: "Dst"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	# Pure Y-axis rotation on the source, matching the roll axis - should fully transfer.
	var src_pose := Quaternion(Vector3(0, 1, 0), deg_to_rad(60.0))
	skeleton.set_bone_pose_rotation(src_idx, src_pose)
	skeleton.force_update_all_bone_transforms()

	sim._process_modification()

	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(dst_idx), src_pose, "a pure on-axis source rotation should fully transfer through the roll constraint")


func test_roll_constraint_does_not_leak_off_axis_rotation() -> void:
	var skeleton := _make_skeleton(["Src", "Dst"])
	var src_idx := skeleton.find_bone("Src")
	var dst_idx := skeleton.find_bone("Dst")

	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {1: _make_constraint(1, 0, "roll", 1.0, "Y")}
	var gltf_node_names: Dictionary[int, String] = {0: "Src", 1: "Dst"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	# Pure X-axis rotation on the source - none of this should leak into a Y-roll constraint.
	var src_pose := Quaternion(Vector3(1, 0, 0), deg_to_rad(45.0))
	skeleton.set_bone_pose_rotation(src_idx, src_pose)
	skeleton.force_update_all_bone_transforms()

	sim._process_modification()

	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(dst_idx), Quaternion.IDENTITY, "an off-axis source rotation should not leak into the destination's roll")


func test_aim_constraint_points_destination_axis_at_source() -> void:
	var skeleton := _make_skeleton(["Src", "Dst"])
	var src_idx := skeleton.find_bone("Src")
	var dst_idx := skeleton.find_bone("Dst")

	# Place Src off to the side of Dst so the constraint actually has to rotate something.
	skeleton.set_bone_rest(src_idx, Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, 3.0)))
	skeleton.set_bone_rest(dst_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)))
	skeleton.reset_bone_poses()

	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {1: _make_constraint(1, 0, "aim", 1.0, "X", "PositiveZ")}
	var gltf_node_names: Dictionary[int, String] = {0: "Src", 1: "Dst"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)
	skeleton.force_update_all_bone_transforms()

	sim._process_modification()
	skeleton.force_update_all_bone_transforms()

	var dst_world_basis: Basis = skeleton.global_transform.basis * skeleton.get_bone_global_pose(dst_idx).basis
	var aimed_dir: Vector3 = (dst_world_basis * Vector3(0, 0, 1)).normalized()

	var src_world_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(src_idx).origin
	var dst_world_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(dst_idx).origin
	var expected_dir: Vector3 = (src_world_pos - dst_world_pos).normalized()

	assert_almost_eq(aimed_dir.dot(expected_dir), 1.0, 0.001, "destination's aim axis should point at the source in world space")


func test_dependency_chain_uses_post_constraint_state() -> void:
	# Bone1 (independent) -> Bone2 (rotation constraint, src=Bone1) -> Bone3 (rotation constraint, src=Bone2).
	# Bone3 must see Bone2's post-constraint pose, not Bone2's rest value, proving the
	# dependency-ordered evaluation actually orders things.
	var skeleton := _make_skeleton(["Bone1", "Bone2", "Bone3"])
	var bone1_idx := skeleton.find_bone("Bone1")
	var bone2_idx := skeleton.find_bone("Bone2")
	var bone3_idx := skeleton.find_bone("Bone3")

	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {
		1: _make_constraint(1, 0, "rotation", 1.0),  # Bone2 <- Bone1
		2: _make_constraint(2, 1, "rotation", 1.0),  # Bone3 <- Bone2
	}
	var gltf_node_names: Dictionary[int, String] = {0: "Bone1", 1: "Bone2", 2: "Bone3"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	var bone1_pose := Quaternion(Vector3(0, 0, 1), deg_to_rad(50.0))
	skeleton.set_bone_pose_rotation(bone1_idx, bone1_pose)
	skeleton.force_update_all_bone_transforms()

	sim._process_modification()

	# Both constraints have identity rests and weight 1.0, so Bone2 should exactly equal
	# Bone1's pose, and (if ordering is correct) Bone3 should exactly equal Bone2's pose too.
	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(bone2_idx), bone1_pose, "Bone2 should copy Bone1")
	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(bone3_idx), bone1_pose, "Bone3 should copy Bone2's already-updated pose, not its rest value")


func test_circular_dependency_is_skipped_without_crashing() -> void:
	var skeleton := _make_skeleton(["BoneA", "BoneB"])
	var a_idx := skeleton.find_bone("BoneA")
	var b_idx := skeleton.find_bone("BoneB")

	# BoneA's source is BoneB, and BoneB's source is BoneA - a direct cycle.
	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {
		0: _make_constraint(0, 1, "rotation", 1.0),  # BoneA <- BoneB
		1: _make_constraint(1, 0, "rotation", 1.0),  # BoneB <- BoneA
	}
	var gltf_node_names: Dictionary[int, String] = {0: "BoneA", 1: "BoneB"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	assert_eq(sim._eval_order.size(), 0, "a fully cyclic pair should produce an empty evaluation order")

	# Should not raise/crash.
	sim._process_modification()

	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(a_idx), Quaternion.IDENTITY, "cyclic constraints should never be applied")
	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(b_idx), Quaternion.IDENTITY, "cyclic constraints should never be applied")


func test_unresolved_source_bone_is_dropped_without_crashing() -> void:
	var skeleton := _make_skeleton(["Dst"])
	var dst_idx := skeleton.find_bone("Dst")

	# source node index 99 has no entry in gltf_node_names, so it can never resolve to a bone.
	var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {0: _make_constraint(0, 99, "rotation", 1.0)}
	var gltf_node_names: Dictionary[int, String] = {0: "Dst"}
	var sim := _attach_and_ready(skeleton, node_constraints, gltf_node_names)

	assert_false(sim._by_dst.has(dst_idx), "a constraint with an unresolved source bone should be dropped at setup")

	# Should not raise/crash.
	sim._process_modification()

	assert_eq_relative_rotation(skeleton.get_bone_pose_rotation(dst_idx), Quaternion.IDENTITY, "an unresolved constraint should leave the bone at rest")
