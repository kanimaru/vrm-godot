@tool
extends SpringBoneSimulator3D
class_name Vrm0SpringBoneSimulator

@export var secondary_animation: Vrm0SecondaryAnimation
@export var gltf_node_names: Dictionary = {}

func _ready() -> void:
	if secondary_animation == null:
		return
		
	# Count the total number of root bones across all spring groups
	var total_roots: int = 0
	for group: Vrm0Spring in secondary_animation.bone_groups:
		total_roots += group.bones.size()
		
	set_setting_count(total_roots)
	
	var setting_idx: int = 0
	for group: Vrm0Spring in secondary_animation.bone_groups:
		for bone_node_idx: int in group.bones:
			if not gltf_node_names.has(bone_node_idx):
				setting_idx += 1
				continue
				
			var root_name: String = gltf_node_names[bone_node_idx]
			set_root_bone_name(setting_idx, root_name)
			
			# VRM 0.0 specifies properties per chain group flatly (no per-joint array like VRM 1.0)
			set_individual_config(setting_idx, false)
			
			# Apply verlet properties on a per-bone basis into the C++ native properties
			
			# Map the global properties directly to the native setting
			# The native simulator will recursively simulate all leaf paths from the root automatically.
			# Using check for existence before calling if API changed to set_setting_stiffness etc.			

			set_stiffness(setting_idx, group.stiffness)
			set_drag(setting_idx, group.drag_force)
			set_gravity(setting_idx, group.gravity_power)
			set_gravity_direction(setting_idx, group.gravity_dir)
			set_radius(setting_idx, group.hit_radius)
				
			setting_idx += 1
