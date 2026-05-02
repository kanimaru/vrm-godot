extends SceneTree
func _init():
	var palm = Vector3(0, -1, 0)
	var thumb = Vector3(0, 0, 1)
	
	var twist_r = Quaternion(Vector3.RIGHT, deg_to_rad(-90.0))
	var droop_r = Quaternion(Vector3.FORWARD, deg_to_rad(35.0))
	var pre_rot_r = droop_r * twist_r
	
	print("Right Arm Palm: ", pre_rot_r * palm)
	print("Right Arm Thumb: ", pre_rot_r * thumb)
	
	var twist_l = Quaternion(Vector3.LEFT, deg_to_rad(90.0))
	var droop_l = Quaternion(Vector3.FORWARD, deg_to_rad(-35.0))
	var pre_rot_l = droop_l * twist_l
	print("Left Arm Palm: ", pre_rot_l * palm)
	print("Left Arm Thumb: ", pre_rot_l * thumb)
	
	quit()
