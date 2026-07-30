@tool
extends SpringBoneSimulator3D
class_name Vrm1SpringBoneSimulator

const VrmSceneComposer = preload("../../common/vrm_scene_composer.gd")


## The parsed VRM 1.0 SpringBone definitions.
@export var spring_bone_data: Vrm1SpringBone

## Since VRM structures use GLTF integer node indices to address joints,
## this dictionary provides the int -> String resolution so they can be matched
## to the Godot Skeleton3D structure at runtime.
@export var gltf_node_names: Dictionary = {}

## VRM1's colliders array is flat and shared by index across springs/collider groups;
## built once in _ready() and looked up by index rather than rebuilt per spring.
var _collider_nodes: Dictionary = {}


func _ready() -> void:
	if spring_bone_data == null:
		return

	_build_colliders()

	# Inform the native simulator how many individual bone chains we have
	var num_springs: int = spring_bone_data.springs.size()
	set_setting_count(num_springs)

	for i: int in range(num_springs):
		var spring: Vrm1SpringBoneSpring = spring_bone_data.springs[i]
		var num_joints: int = spring.joints.size()
		if num_joints == 0:
			continue

		# Map the root bone for this chain
		var root_node_idx: int = spring.joints[0].node
		if root_node_idx != -1 and gltf_node_names.has(root_node_idx):
			var root_name: String = gltf_node_names[root_node_idx]
			set_root_bone_name(i, root_name)

		# Map the terminal bone for this chain
		var end_node_idx: int = spring.joints[num_joints - 1].node
		if end_node_idx != -1 and gltf_node_names.has(end_node_idx):
			var end_name: String = gltf_node_names[end_node_idx]
			set_end_bone_name(i, end_name)

			# VRM usually expects terminal leaves to extend procedurally into space
			set_extend_end_bone(i, true)

		# Enable per-joint configuration mirroring VRM 1.0 explicit logic
		set_individual_config(i, true)

		# Apply verlet properties on a per-bone basis into the C++ native properties
		for j: int in range(num_joints):
			var joint: Vrm1SpringBoneJoint = spring.joints[j]

			set_joint_stiffness(i, j, joint.stiffness)
			set_joint_drag(i, j, joint.drag_force)
			set_joint_gravity(i, j, joint.gravity_power)
			set_joint_gravity_direction(i, j, joint.gravity_dir)
			set_joint_radius(i, j, joint.hit_radius)

		_apply_center(i, spring.center)
		_apply_colliders(i, spring.collider_groups)


## Builds one SpringBoneCollision3D child per VRM1 collider that resolves to a real bone,
## keyed by its index into spring_bone_data.colliders so multiple springs referencing the
## same collider (or collider group) share a single node instead of duplicating it.
func _build_colliders() -> void:
	_collider_nodes.clear()
	for idx: int in range(spring_bone_data.colliders.size()):
		var collider: Vrm1SpringBoneCollider = spring_bone_data.colliders[idx]
		if collider.shape == null or not gltf_node_names.has(collider.node):
			continue
		var shape: Vrm1SpringBoneShape = collider.shape
		var node: SpringBoneCollision3D = VrmSceneComposer.build_spring_bone_collision(
				shape.type, gltf_node_names[collider.node], shape.offset, shape.radius, shape.tail, shape.normal, shape.inside
		)
		add_child(node)
		_collider_nodes[idx] = node


## Points setting_idx's center-of-simulation at the spring's authored center bone, if any;
## otherwise leaves it at the native default (world origin).
func _apply_center(setting_idx: int, center_node_idx: int) -> void:
	if center_node_idx == -1 or not gltf_node_names.has(center_node_idx):
		return
	set_center_from(setting_idx, CENTER_FROM_BONE)
	set_center_bone_name(setting_idx, gltf_node_names[center_node_idx])


## Registers setting_idx's referenced collider groups' colliders against the native
## per-setting allow-list (enable_all_child_collisions off, so springs only collide with
## what they actually reference, matching the VRM spec's per-spring collider group model).
func _apply_colliders(setting_idx: int, collider_group_indices: PackedInt32Array) -> void:
	var nodes: Array[SpringBoneCollision3D] = []
	for group_idx: int in collider_group_indices:
		if group_idx < 0 or group_idx >= spring_bone_data.collider_groups.size():
			continue
		var group: Vrm1SpringBoneColliderGroup = spring_bone_data.collider_groups[group_idx]
		for collider_idx: int in group.colliders:
			if _collider_nodes.has(collider_idx):
				nodes.append(_collider_nodes[collider_idx])

	set_enable_all_child_collisions(setting_idx, false)
	set_collision_count(setting_idx, nodes.size())
	for k: int in range(nodes.size()):
		set_collision_path(setting_idx, k, get_path_to(nodes[k]))
