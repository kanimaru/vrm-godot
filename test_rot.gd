extends SceneTree
func _init():
	var left_arm = Vector3(-1, 0, 0)
	var right_arm = Vector3(1, 0, 0)
	
	var pre_rot_l = Quaternion(Vector3.FORWARD, deg_to_rad(-40.0))
	var pre_rot_r = Quaternion(Vector3.FORWARD, deg_to_rad(40.0))
	
	print("Left Arm T-Pose: ", left_arm)
	print("Left Arm A-Pose: ", pre_rot_l * left_arm)
	
	print("Right Arm T-Pose: ", right_arm)
	print("Right Arm A-Pose: ", pre_rot_r * right_arm)
	quit()
