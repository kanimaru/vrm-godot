extends "res://unit/vrm_gut_test.gd"

## Wiring/configuration tests for Vrm0SpringBoneSimulator against Godot's native
## SpringBoneSimulator3D. These assert what got CONFIGURED (root/end bone names, collision
## registration, center), not the resulting physics simulation - Godot's modifier pipeline
## only exposes its effect through mesh skin rendering, not through queryable bone-pose
## getters after a frame, so runtime swing/collision behavior isn't assertable this way and
## needs a manual visual check in the editor instead.

const Vrm0SpringBoneSimulator = preload("res://addons/vrm/vrm0/nodes/vrm0_spring_bone.gd")


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


func _make_spring(root_node_idx: int, collider_group_indices: PackedInt32Array = PackedInt32Array(), center: int = -1) -> Vrm0Spring:
	var spring := Vrm0Spring.new()
	spring.bones = PackedInt32Array([root_node_idx])
	spring.stiffness = 0.7
	spring.gravity_power = 0.3
	spring.gravity_dir = Vector3(0, -1, 0)
	spring.drag_force = 0.4
	spring.hit_radius = 0.05
	spring.collider_groups = collider_group_indices
	spring.center = center
	return spring


## Attaches a configured Vrm0SpringBoneSimulator as a child of skeleton and adds the
## skeleton to the tree (autofreed) - the same "build fully offline, then attach to an
## already-live parent" pattern the real import pipeline follows, which is required for
## the native SkeletonModifier3D's lazy get_skeleton() resolution to succeed synchronously
## within _ready().
func _attach_and_ready(
		skeleton: Skeleton3D,
		secondary_animation: Vrm0SecondaryAnimation,
		gltf_node_names: Dictionary,
) -> Vrm0SpringBoneSimulator:
	var sim := Vrm0SpringBoneSimulator.new()
	sim.secondary_animation = secondary_animation
	sim.gltf_node_names = gltf_node_names
	skeleton.add_child(sim)
	add_child_autofree(skeleton)
	return sim


func test_linear_chain_sets_root_and_leaf_as_end_bone() -> void:
	var skeleton := _make_linear_skeleton()
	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.bone_groups = [_make_spring(0)]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_eq(sim.get_setting_count(), 1, "a linear (non-branching) chain should produce exactly one setting")
	assert_eq(sim.get_root_bone_name(0), "Root")
	assert_eq(sim.get_end_bone_name(0), "Tip", "the end bone should be the deepest leaf descendant, not the named root itself")


func test_branching_hierarchy_creates_one_setting_per_leaf() -> void:
	var skeleton := Skeleton3D.new()
	var root_idx := skeleton.add_bone("Root")
	skeleton.set_bone_rest(root_idx, Transform3D.IDENTITY)
	var strand_a_idx := skeleton.add_bone("StrandA")
	skeleton.set_bone_parent(strand_a_idx, root_idx)
	skeleton.set_bone_rest(strand_a_idx, Transform3D(Basis.IDENTITY, Vector3(-0.1, -0.5, 0)))
	var strand_b_idx := skeleton.add_bone("StrandB")
	skeleton.set_bone_parent(strand_b_idx, root_idx)
	skeleton.set_bone_rest(strand_b_idx, Transform3D(Basis.IDENTITY, Vector3(0.1, -0.5, 0)))
	skeleton.reset_bone_poses()

	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.bone_groups = [_make_spring(0)]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_eq(sim.get_setting_count(), 2, "a root with two branches should produce two settings, one per leaf path")
	var end_names: Array = [sim.get_end_bone_name(0), sim.get_end_bone_name(1)]
	assert_true("StrandA" in end_names)
	assert_true("StrandB" in end_names)
	assert_eq(sim.get_root_bone_name(0), "Root")
	assert_eq(sim.get_root_bone_name(1), "Root")


func test_stiffness_gravity_drag_radius_applied_to_setting() -> void:
	var skeleton := _make_linear_skeleton()
	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.bone_groups = [_make_spring(0)]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_almost_eq(sim.get_stiffness(0), 0.7, 0.0001)
	assert_almost_eq(sim.get_drag(0), 0.4, 0.0001)
	assert_almost_eq(sim.get_gravity(0), 0.3, 0.0001)
	assert_almost_eq(sim.get_radius(0), 0.05, 0.0001)


func test_collider_group_registers_collision_node() -> void:
	var skeleton := _make_linear_skeleton()
	var collider := Vrm0Collider.new()
	collider.offset = Vector3(0, 0.2, 0)
	collider.radius = 0.15
	var collider_group := Vrm0ColliderGroup.new()
	collider_group.node = 1  # resolves to "Mid" via gltf_node_names below
	collider_group.colliders = [collider]

	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.collider_groups = [collider_group]
	secondary_animation.bone_groups = [_make_spring(0, PackedInt32Array([0]))]
	var gltf_node_names := {0: "Root", 1: "Mid"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_eq(sim.get_collision_count(0), 1)
	var collision_node: Node = sim.get_node(sim.get_collision_path(0, 0))
	assert_not_null(collision_node)
	assert_true(collision_node is SpringBoneCollisionSphere3D)
	assert_eq(collision_node.bone_name, "Mid")
	assert_eq(collision_node.position_offset, Vector3(0, 0.2, 0))
	assert_almost_eq(collision_node.radius, 0.15, 0.0001)


func test_no_collider_groups_leaves_collision_count_zero() -> void:
	var skeleton := _make_linear_skeleton()
	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.bone_groups = [_make_spring(0)]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_eq(sim.get_collision_count(0), 0)


func test_shared_collider_group_across_two_springs_reuses_the_same_collision_node() -> void:
	var skeleton := Skeleton3D.new()
	var root_a_idx := skeleton.add_bone("RootA")
	skeleton.set_bone_rest(root_a_idx, Transform3D.IDENTITY)
	var tip_a_idx := skeleton.add_bone("TipA")
	skeleton.set_bone_parent(tip_a_idx, root_a_idx)
	skeleton.set_bone_rest(tip_a_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	var root_b_idx := skeleton.add_bone("RootB")
	skeleton.set_bone_rest(root_b_idx, Transform3D.IDENTITY)
	var tip_b_idx := skeleton.add_bone("TipB")
	skeleton.set_bone_parent(tip_b_idx, root_b_idx)
	skeleton.set_bone_rest(tip_b_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	skeleton.reset_bone_poses()

	var collider := Vrm0Collider.new()
	collider.radius = 0.1
	var collider_group := Vrm0ColliderGroup.new()
	collider_group.node = 0  # resolves to "RootA", shared by both springs' colliders
	collider_group.colliders = [collider]

	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.collider_groups = [collider_group]
	secondary_animation.bone_groups = [
		_make_spring(0, PackedInt32Array([0])),
		_make_spring(1, PackedInt32Array([0])),
	]
	var gltf_node_names := {0: "RootA", 1: "RootB"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	var node_a: Node = sim.get_node(sim.get_collision_path(0, 0))
	var node_b: Node = sim.get_node(sim.get_collision_path(1, 0))
	assert_eq(node_a, node_b, "two springs referencing the same collider group should share one collision node, not duplicate it")


func test_center_bone_is_applied_when_present() -> void:
	var skeleton := _make_linear_skeleton()
	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.bone_groups = [_make_spring(0, PackedInt32Array(), 0)]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_eq(sim.get_center_from(0), sim.CENTER_FROM_BONE)
	assert_eq(sim.get_center_bone_name(0), "Root")


func test_no_center_leaves_default_world_origin() -> void:
	var skeleton := _make_linear_skeleton()
	var secondary_animation := Vrm0SecondaryAnimation.new()
	secondary_animation.bone_groups = [_make_spring(0)]
	var gltf_node_names := {0: "Root"}

	var sim := _attach_and_ready(skeleton, secondary_animation, gltf_node_names)

	assert_eq(sim.get_center_from(0), sim.CENTER_FROM_WORLD_ORIGIN)
