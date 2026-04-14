@tool
extends RefCounted
class_name VrmRetargeting


## Creates a Godot BoneMap for humanoid retargeting from a parsed VRM bone dictionary.
## Takes the Godot Skeleton3D, the GLTFState to resolve GLTF node indices into Godot bone names,
## and the parsed VRM 1.0 humanoid bone dictionary (which contains node indices).
static func create_bone_map(skeleton: Skeleton3D, gltf_state: GLTFState, vrm_human_bones: Dictionary) -> BoneMap:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	var bone_map: BoneMap = BoneMap.new()
	bone_map.profile = profile
	
	for vrm_bone: String in vrm_human_bones.keys():
		var bone_data: Vrm1HumanoidBone = vrm_human_bones[vrm_bone]
		var gltf_node_index: int = bone_data.node
		
		if gltf_node_index >= 0:
			var skeleton_bone_name: String = gltf_state.get_node_name(gltf_node_index)
			
			# VRM 1.0 bone names (e.g. "leftUpperArm") neatly map 1:1 to Godot's 
			# SkeletonProfileHumanoid names (e.g. "LeftUpperArm") by capitalizing the first letter.
			var godot_profile_name: String = vrm_bone.substr(0, 1).to_upper() + vrm_bone.substr(1)
			
			# Verify the bone target exists in Godot's standard profile
			if profile.find_bone(godot_profile_name) != -1:
				# Verify the actual bone name exists on the provided Skeleton3D node
				if skeleton.find_bone(skeleton_bone_name) != -1:
					bone_map.set_skeleton_bone_name(godot_profile_name, skeleton_bone_name)
					
	return bone_map
