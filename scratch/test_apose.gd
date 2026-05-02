extends SceneTree

func _init():
	var left_arm = Vector3(-1, 0, 0)
	var right_arm = Vector3(1, 0, 0)
	
	var q_left_up = Quaternion(Vector3.FORWARD, deg_to_rad(-40.0))
	var q_right_up = Quaternion(Vector3.FORWARD, deg_to_rad(40.0))
	
	print("Left arm (-X) with -40 deg around FORWARD: ", q_left_up * left_arm)
	print("Right arm (+X) with +40 deg around FORWARD: ", q_right_up * right_arm)
	
	var q_left_down = Quaternion(Vector3.FORWARD, deg_to_rad(40.0))
	var q_right_down = Quaternion(Vector3.FORWARD, deg_to_rad(-40.0))
	
	print("Left arm (-X) with +40 deg around FORWARD: ", q_left_down * left_arm)
	print("Right arm (+X) with -40 deg around FORWARD: ", q_right_down * right_arm)

	quit()
