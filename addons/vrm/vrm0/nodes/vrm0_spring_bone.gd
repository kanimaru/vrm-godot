@tool
extends SpringBoneSimulator3D
class_name Vrm0SpringBoneSimulator

const VrmSceneComposer = preload("../../common/vrm_scene_composer.gd")

@export var secondary_animation: Vrm0SecondaryAnimation
@export var gltf_node_names: Dictionary = {}

## VRM0's collider_groups array is shared by index across springs; built once per group
## the first time it's referenced, so multiple springs sharing a group (e.g. a head
## collider used by both left and right hair springs) reuse the same collision nodes.
var _collider_group_nodes: Dictionary = {}


func _ready() -> void:
	if secondary_animation == null:
		return

	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return

	_collider_group_nodes.clear()

	# VRM0 has no explicit joint list like VRM1 - a spring's `bones` array only names
	# each chain's root, and the spec's intent is that the whole subtree beneath it
	# sways. The native simulator needs an explicit end_bone per setting, so every
	# linear root-to-leaf path in that subtree becomes its own setting (a branching
	# hierarchy, e.g. a two-strand ponytail, becomes two settings sharing the same
	# root/physics properties).
	var chains: Array[Dictionary] = []
	for group: Vrm0Spring in secondary_animation.bone_groups:
		for bone_node_idx: int in group.bones:
			if not gltf_node_names.has(bone_node_idx):
				continue
			var root_idx: int = skeleton.find_bone(gltf_node_names[bone_node_idx])
			if root_idx == -1:
				continue
			for leaf_idx: int in VrmSceneComposer.find_leaf_bones(skeleton, root_idx):
				chains.append({"group": group, "root_idx": root_idx, "leaf_idx": leaf_idx})

	set_setting_count(chains.size())

	for setting_idx: int in range(chains.size()):
		var chain: Dictionary = chains[setting_idx]
		var group: Vrm0Spring = chain.group

		set_root_bone_name(setting_idx, skeleton.get_bone_name(chain.root_idx))
		set_end_bone_name(setting_idx, skeleton.get_bone_name(chain.leaf_idx))

		# VRM 0.0 specifies properties per chain group flatly (no per-joint array like VRM 1.0)
		set_individual_config(setting_idx, false)

		set_stiffness(setting_idx, group.stiffness)
		set_drag(setting_idx, group.drag_force)
		set_gravity(setting_idx, group.gravity_power)
		set_gravity_direction(setting_idx, group.gravity_dir)
		set_radius(setting_idx, group.hit_radius)

		_apply_center(setting_idx, group.center)
		_apply_colliders(setting_idx, group.collider_groups)


## Points setting_idx's center-of-simulation at the spring's authored center bone, if any;
## otherwise leaves it at the native default (world origin).
func _apply_center(setting_idx: int, center_node_idx: int) -> void:
	if center_node_idx == -1 or not gltf_node_names.has(center_node_idx):
		return
	set_center_from(setting_idx, CENTER_FROM_BONE)
	set_center_bone_name(setting_idx, gltf_node_names[center_node_idx])


## Registers setting_idx's referenced collider groups against the native per-setting
## allow-list (enable_all_child_collisions off, so springs only collide with what they
## actually reference, matching the VRM spec's per-spring collider group model).
func _apply_colliders(setting_idx: int, collider_group_indices: PackedInt32Array) -> void:
	var nodes: Array[SpringBoneCollision3D] = []
	for group_idx: int in collider_group_indices:
		if not _collider_group_nodes.has(group_idx):
			_collider_group_nodes[group_idx] = _build_collider_group(group_idx)
		nodes.append_array(_collider_group_nodes[group_idx])

	set_enable_all_child_collisions(setting_idx, false)
	set_collision_count(setting_idx, nodes.size())
	for k: int in range(nodes.size()):
		set_collision_path(setting_idx, k, get_path_to(nodes[k]))


## Builds one SpringBoneCollision3D child per sphere collider in the given collider group
## (VRM0 colliders are sphere-only, per spec).
func _build_collider_group(collider_group_idx: int) -> Array[SpringBoneCollision3D]:
	var nodes: Array[SpringBoneCollision3D] = []
	if collider_group_idx < 0 or collider_group_idx >= secondary_animation.collider_groups.size():
		return nodes
	var group: Vrm0ColliderGroup = secondary_animation.collider_groups[collider_group_idx]
	if not gltf_node_names.has(group.node):
		return nodes
	var bone_name: String = gltf_node_names[group.node]
	for collider: Vrm0Collider in group.colliders:
		var node: SpringBoneCollision3D = VrmSceneComposer.build_spring_bone_collision("sphere", bone_name, collider.offset, collider.radius)
		add_child(node)
		nodes.append(node)
	return nodes
