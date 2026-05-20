extends SceneTree

func _init() -> void:
	var skeleton := Skeleton3D.new()
	get_root().add_child(skeleton)
	
	var parent_idx := skeleton.add_bone("parent")
	var child_idx := skeleton.add_bone("child")
	
	skeleton.set_bone_parent(child_idx, parent_idx)
	
	# Set rests
	skeleton.set_bone_rest(parent_idx, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	skeleton.set_bone_rest(child_idx, Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)))
	
	# Reset bone poses to their rest transforms
	skeleton.reset_bone_poses()
	
	# Force update
	skeleton.force_update_all_bone_transforms()
	
	print("No poses modified (after reset_bone_poses):")
	print("  Parent rest: ", skeleton.get_bone_rest(parent_idx))
	print("  Parent pose: ", skeleton.get_bone_pose(parent_idx))
	print("  Parent global pose: ", skeleton.get_bone_global_pose(parent_idx))
	print("  Child rest: ", skeleton.get_bone_rest(child_idx))
	print("  Child pose: ", skeleton.get_bone_pose(child_idx))
	print("  Child global pose: ", skeleton.get_bone_global_pose(child_idx))
	
	# Modify pose
	skeleton.set_bone_pose_position(parent_idx, Vector3(0, 10, 0))
	skeleton.force_update_all_bone_transforms()
	
	print("\nParent pose position modified:")
	print("  Parent global pose: ", skeleton.get_bone_global_pose(parent_idx))
	print("  Child global pose: ", skeleton.get_bone_global_pose(child_idx))
	
	# Clean up
	skeleton.queue_free()
	quit()
