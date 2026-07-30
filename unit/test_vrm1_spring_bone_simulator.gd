extends "res://unit/vrm_gut_test.gd"

## Wiring/configuration tests for Vrm1SpringBoneSimulator against Godot's native
## SpringBoneSimulator3D. These assert what got CONFIGURED (root/end bone names, per-joint
## properties, collision registration, center), not the resulting physics simulation -
## Godot's modifier pipeline only exposes its effect through mesh skin rendering, not
## through queryable bone-pose getters after a frame, so runtime swing/collision behavior
## isn't assertable this way and needs a manual visual check in the editor instead.

const Vrm1SpringBoneSimulator = preload("res://addons/vrm/vrm1/nodes/vrm1_spring_bone.gd")


func _make_linear_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var root_idx := skeleton.add_bone("Root")
	skeleton.set_bone_rest(root_idx, Transform3D.IDENTITY)
	var mid_idx := skeleton.add_bone("Mid")
	skeleton.set_bone_parent(mid_idx, root_idx)
	skeleton.set_bone_rest(mid_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	var tip_idx := skeleton.add_bone("Tip")
	skeleton.set_bone_parent(tip_idx, mid_idx)
	skeleton.set_bone_rest(tip_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	skeleton.reset_bone_poses()
	return skeleton


func _make_joint(node_idx: int, stiffness: float = 0.5, drag: float = 0.4, gravity: float = 0.3, hit_radius: float = 0.05) -> Vrm1SpringBoneJoint:
	var joint := Vrm1SpringBoneJoint.new()
	joint.node = node_idx
	joint.stiffness = stiffness
	joint.drag_force = drag
	joint.gravity_power = gravity
	joint.gravity_dir = Vector3(0, -1, 0)
	joint.hit_radius = hit_radius
	return joint


## Attaches a configured Vrm1SpringBoneSimulator as a child of skeleton and adds the
## skeleton to the tree (autofreed) - required for the native SkeletonModifier3D's lazy
## get_skeleton() resolution to succeed synchronously within _ready().
func _attach_and_ready(skeleton: Skeleton3D, spring_bone_data: Vrm1SpringBone, gltf_node_names: Dictionary) -> Vrm1SpringBoneSimulator:
	var sim := Vrm1SpringBoneSimulator.new()
	sim.spring_bone_data = spring_bone_data
	sim.gltf_node_names = gltf_node_names
	skeleton.add_child(sim)
	add_child_autofree(skeleton)
	return sim


func test_joint_chain_sets_root_and_end_bone_from_first_and_last_joint() -> void:
	var skeleton := _make_linear_skeleton()
	var spring := Vrm1SpringBoneSpring.new()
	spring.joints = [_make_joint(0), _make_joint(1), _make_joint(2)]
	var spring_bone_data := Vrm1SpringBone.new()
	spring_bone_data.springs = [spring]
	var gltf_node_names := {0: "Root", 1: "Mid", 2: "Tip"}

	var sim := _attach_and_ready(skeleton, spring_bone_data, gltf_node_names)

	assert_eq(sim.get_setting_count(), 1)
	assert_eq(sim.get_root_bone_name(0), "Root")
	assert_eq(sim.get_end_bone_name(0), "Tip")
	assert_true(sim.is_end_bone_extended(0))


func test_per_joint_properties_applied_individually() -> void:
	var skeleton := _make_linear_skeleton()
	var spring := Vrm1SpringBoneSpring.new()
	spring.joints = [
		_make_joint(0, 0.2, 0.1, 0.0, 0.01),
		_make_joint(1, 0.9, 0.5, 0.4, 0.08),
	]
	var spring_bone_data := Vrm1SpringBone.new()
	spring_bone_data.springs = [spring]
	var gltf_node_names := {0: "Root", 1: "Mid"}

	var sim := _attach_and_ready(skeleton, spring_bone_data, gltf_node_names)

	assert_true(sim.is_config_individual(0), "VRM1 springs should use per-joint config, not a single flat setting")
	assert_almost_eq(sim.get_joint_stiffness(0, 0), 0.2, 0.0001)
	assert_almost_eq(sim.get_joint_stiffness(0, 1), 0.9, 0.0001)
	assert_almost_eq(sim.get_joint_radius(0, 0), 0.01, 0.0001)
	assert_almost_eq(sim.get_joint_radius(0, 1), 0.08, 0.0001)


func test_collider_group_registers_collision_node_with_capsule_geometry() -> void:
	var skeleton := _make_linear_skeleton()

	var shape := Vrm1SpringBoneShape.new()
	shape.type = "capsule"
	shape.offset = Vector3(0, 0, 0)
	shape.tail = Vector3(0, 0.3, 0)
	shape.radius = 0.1

	var collider := Vrm1SpringBoneCollider.new()
	collider.node = 1  # resolves to "Mid"
	collider.shape = shape

	var collider_group := Vrm1SpringBoneColliderGroup.new()
	collider_group.colliders = PackedInt32Array([0])

	var spring := Vrm1SpringBoneSpring.new()
	spring.joints = [_make_joint(0)]
	spring.collider_groups = PackedInt32Array([0])

	var spring_bone_data := Vrm1SpringBone.new()
	spring_bone_data.colliders = [collider]
	spring_bone_data.collider_groups = [collider_group]
	spring_bone_data.springs = [spring]
	var gltf_node_names := {0: "Root", 1: "Mid"}

	var sim := _attach_and_ready(skeleton, spring_bone_data, gltf_node_names)

	assert_eq(sim.get_collision_count(0), 1)
	var collision_node: Node = sim.get_node(sim.get_collision_path(0, 0))
	assert_true(collision_node is SpringBoneCollisionCapsule3D)
	assert_eq(collision_node.bone_name, "Mid")
	assert_almost_eq(collision_node.radius, 0.1, 0.0001)
	assert_almost_eq(collision_node.height, 0.3 + 0.2, 0.0001)


func test_two_springs_sharing_a_collider_reuse_the_same_node() -> void:
	var skeleton := Skeleton3D.new()
	var root_a_idx := skeleton.add_bone("RootA")
	skeleton.set_bone_rest(root_a_idx, Transform3D.IDENTITY)
	var root_b_idx := skeleton.add_bone("RootB")
	skeleton.set_bone_rest(root_b_idx, Transform3D.IDENTITY)
	skeleton.reset_bone_poses()

	var shape := Vrm1SpringBoneShape.new()
	shape.type = "sphere"
	shape.radius = 0.1
	var collider := Vrm1SpringBoneCollider.new()
	collider.node = 0  # resolves to "RootA", shared by both springs' colliders
	collider.shape = shape

	var collider_group := Vrm1SpringBoneColliderGroup.new()
	collider_group.colliders = PackedInt32Array([0])

	var spring_a := Vrm1SpringBoneSpring.new()
	spring_a.joints = [_make_joint(0)]
	spring_a.collider_groups = PackedInt32Array([0])
	var spring_b := Vrm1SpringBoneSpring.new()
	spring_b.joints = [_make_joint(1)]
	spring_b.collider_groups = PackedInt32Array([0])

	var spring_bone_data := Vrm1SpringBone.new()
	spring_bone_data.colliders = [collider]
	spring_bone_data.collider_groups = [collider_group]
	spring_bone_data.springs = [spring_a, spring_b]
	var gltf_node_names := {0: "RootA", 1: "RootB"}

	var sim := _attach_and_ready(skeleton, spring_bone_data, gltf_node_names)

	var node_a: Node = sim.get_node(sim.get_collision_path(0, 0))
	var node_b: Node = sim.get_node(sim.get_collision_path(1, 0))
	assert_eq(node_a, node_b, "two springs referencing the same collider should share one collision node, not duplicate it")


func test_center_bone_is_applied_when_present() -> void:
	var skeleton := _make_linear_skeleton()
	var spring := Vrm1SpringBoneSpring.new()
	spring.joints = [_make_joint(0)]
	spring.center = 0
	var spring_bone_data := Vrm1SpringBone.new()
	spring_bone_data.springs = [spring]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, spring_bone_data, gltf_node_names)

	assert_eq(sim.get_center_from(0), sim.CENTER_FROM_BONE)
	assert_eq(sim.get_center_bone_name(0), "Root")


func test_no_center_leaves_default_world_origin() -> void:
	var skeleton := _make_linear_skeleton()
	var spring := Vrm1SpringBoneSpring.new()
	spring.joints = [_make_joint(0)]
	var spring_bone_data := Vrm1SpringBone.new()
	spring_bone_data.springs = [spring]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, spring_bone_data, gltf_node_names)

	assert_eq(sim.get_center_from(0), sim.CENTER_FROM_WORLD_ORIGIN)
