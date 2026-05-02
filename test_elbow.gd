extends SceneTree
func _init():
	var bend_target = Vector3(0, 1, 0) # In VRM, elbow bends towards +Y (UP)
	
	var twist_r = Quaternion(Vector3.RIGHT, deg_to_rad(90.0))
	var new_target_r = twist_r * bend_target
	print("Right Arm Bends Towards: ", new_target_r)
	
	var twist_l = Quaternion(Vector3.LEFT, deg_to_rad(-90.0))
	var new_target_l = twist_l * bend_target
	print("Left Arm Bends Towards: ", new_target_l)
	quit()
