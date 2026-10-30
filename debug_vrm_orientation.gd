@tool
extends EditorScript

# ==============================================================================
# DIAGNOSTIC SCRIPT: Compare VRMA and VRM Rest Orientations
# ==============================================================================
# Instructions:
# 1. Open this script in the Godot Script Editor.
# 2. Change VRMA_PATH and VRM_PATH below to point to your files.
# 3. Go to File -> Run (or press Ctrl+Shift+X) to execute.
# 4. Check the Output panel for the results.

const VRMA_PATH = "res://assets/private/VRMA/Clapping.vrma"
#const VRM_PATH = "res://assets/private/temptic/model.vrm"
const VRM_PATH = "res://assets/private/luna/luna.vrm"

func _run() -> void:
	print("\n================================================================================")
	print("VRM ORIENTATION DIAGNOSTIC TOOL")
	print("================================================================================")
	
	if not FileAccess.file_exists(VRMA_PATH) or not FileAccess.file_exists(VRM_PATH):
		print("ERROR: Please update VRMA_PATH and VRM_PATH in the script to point to valid files.")
		print("VRMA_PATH: ", VRMA_PATH, " exists? ", FileAccess.file_exists(VRMA_PATH))
		print("VRM_PATH: ", VRM_PATH, " exists? ", FileAccess.file_exists(VRM_PATH))
		return
		
	# --- 1. LOAD VRMA ---
	var vrma_extension = load("res://addons/vrm/vrma/vrma_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrma_extension)
	
	var vrma_gltf := GLTFDocument.new()
	var vrma_state := GLTFState.new()
	var err := vrma_gltf.append_from_file(VRMA_PATH, vrma_state)
	GLTFDocument.unregister_gltf_document_extension(vrma_extension)
	
	if err != OK:
		print("ERROR: Failed to load VRMA")
		return
		
	var vrma_top_level = vrma_state.get_additional_data("vrma")
	if not vrma_top_level or not vrma_top_level.humanoid:
		print("ERROR: No VRMA humanoid data found")
		return
		
	var vrma_nodes: Array[GLTFNode] = vrma_state.get_nodes()
	var vrma_bone_map: Dictionary = vrma_top_level.humanoid.human_bones
	
	# Compute VRMA World Rests
	var vrma_world_rests = {}
	for i in range(vrma_nodes.size()):
		var local_rot: Quaternion = vrma_nodes[i].rotation
		var parent: int = vrma_nodes[i].parent
		if parent >= 0 and vrma_world_rests.has(parent):
			vrma_world_rests[i] = (vrma_world_rests[parent] as Quaternion) * local_rot
		else:
			vrma_world_rests[i] = local_rot
	
	# --- 2. LOAD VRM ---
	var vrm0_ext = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	var vrm1_ext = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0_ext)
	GLTFDocument.register_gltf_document_extension(vrm1_ext)
	
	var vrm_gltf := GLTFDocument.new()
	var vrm_state := GLTFState.new()
	err = vrm_gltf.append_from_file(VRM_PATH, vrm_state)
	
	GLTFDocument.unregister_gltf_document_extension(vrm0_ext)
	GLTFDocument.unregister_gltf_document_extension(vrm1_ext)
	
	if err != OK:
		print("ERROR: Failed to load VRM")
		return
		
	var vrm_scene = vrm_gltf.generate_scene(vrm_state)
	var skeleton: Skeleton3D = _find_skeleton(vrm_scene)
	if not skeleton:
		print("ERROR: No skeleton found in VRM")
		return
		
	var vrm_humanoid_bones: Dictionary = vrm_scene.get_meta("vrm_humanoid_bones", {})
	
	# Compute VRM World Rests
	var avatar_world_rests = {}
	for i in range(skeleton.get_bone_count()):
		var rot = skeleton.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		var parent = skeleton.get_bone_parent(i)
		while parent >= 0:
			rot = skeleton.get_bone_rest(parent).basis.orthonormalized().get_rotation_quaternion() * rot
			parent = skeleton.get_bone_parent(parent)
		avatar_world_rests[i] = rot
	
	print("\n--- BONE ORIENTATIONS: LOCAL REST (Euler XYZ in degrees) ---")
	print("%-15s | %-30s | %-30s" % ["Bone Role", "VRMA (glTF Node)", "Avatar (Skeleton3D)"])
	print("-".repeat(80))
	
	var roles_to_check = [
		"hips", "spine", "chest", "upperChest", "neck", "head", 
		"leftShoulder", "leftUpperArm", "leftLowerArm", "leftHand",
		"rightShoulder", "rightUpperArm", "rightLowerArm", "rightHand",
		"leftUpperLeg", "leftLowerLeg", "leftFoot", "leftToes",
		"rightUpperLeg", "rightLowerLeg", "rightFoot", "rightToes"
	]
	
	var vrma_world_data = {}
	var avatar_world_data = {}
						  
	for role in roles_to_check:
		# VRMA Data
		var vrma_rot_str = "N/A"
		if vrma_bone_map.has(role) and vrma_bone_map[role] >= 0:
			var idx = vrma_bone_map[role]
			var gnode = vrma_nodes[idx]
			var euler = gnode.rotation.get_euler()
			vrma_rot_str = "(%5.1f, %5.1f, %5.1f)" % [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)]
			vrma_world_data[role] = vrma_world_rests[idx]
			
		# Avatar Data
		var avatar_rot_str = "N/A"
		var role_lower = role.to_lower()
		var bone_name = ""
		if vrm_humanoid_bones.has(role_lower):
			bone_name = vrm_humanoid_bones[role_lower]
		elif vrm_humanoid_bones.has(role):
			bone_name = vrm_humanoid_bones[role]
			
		if not bone_name.is_empty():
			var b_idx = skeleton.find_bone(bone_name)
			if b_idx >= 0:
				var q = skeleton.get_bone_rest(b_idx).basis.orthonormalized().get_rotation_quaternion()
				var euler = q.get_euler()
				avatar_rot_str = "(%5.1f, %5.1f, %5.1f)" % [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)]
				avatar_world_data[role] = avatar_world_rests[b_idx]
				
		print("%-15s | %-30s | %-30s" % [role, vrma_rot_str, avatar_rot_str])
	
	print("\n--- BONE ORIENTATIONS: WORLD REST (Euler XYZ in degrees) ---")
	print("%-15s | %-30s | %-30s" % ["Bone Role", "VRMA World", "Avatar World"])
	print("-".repeat(80))
	
	for role in roles_to_check:
		var v_str = "N/A"
		if vrma_world_data.has(role):
			var euler = vrma_world_data[role].get_euler()
			v_str = "(%5.1f, %5.1f, %5.1f)" % [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)]
			
		var a_str = "N/A"
		if avatar_world_data.has(role):
			var euler = avatar_world_data[role].get_euler()
			a_str = "(%5.1f, %5.1f, %5.1f)" % [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)]
			
		print("%-15s | %-30s | %-30s" % [role, v_str, a_str])
		
	vrm_scene.queue_free()
	print("\nDiagnostic complete.")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for c in node.get_children(true):
		var res = _find_skeleton(c)
		if res: return res
	return null
