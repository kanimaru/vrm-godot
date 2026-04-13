@tool
extends SpringBoneSimulator3D
class_name VrmSpringBone


## The parsed VRM 1.0 SpringBone definitions.
@export var spring_bone_data: Vrm1SpringBone

## Since VRM structures use GLTF integer node indices to address joints, 
## this dictionary provides the int -> String resolution so they can be matched
## to the Godot Skeleton3D structure at runtime.
@export var gltf_node_names: Dictionary = {}


func _ready() -> void:
	if spring_bone_data == null:
		return
		
	# Inform the native simulator how many individual bone chains we have
	var num_springs: int = spring_bone_data.springs.size()
	set_setting_count(num_springs)
	
	for i: int in range(num_springs):
		var spring: Vrm1SpringBone.Spring = spring_bone_data.springs[i]
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
			var joint: Vrm1SpringBone.Joint = spring.joints[j]
			
			set_joint_stiffness(i, j, joint.stiffness)
			set_joint_drag(i, j, joint.drag_force)
			set_joint_gravity(i, j, joint.gravity_power)
			set_joint_gravity_direction(i, j, joint.gravity_dir)
			set_joint_radius(i, j, joint.hit_radius)

