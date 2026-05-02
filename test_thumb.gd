extends SceneTree
func _init():
	var thumb = Vector3(0, 0, 1)
	
	var twist_r = Quaternion(Vector3.RIGHT, deg_to_rad(-90.0))
	print("Right Thumb (-90): ", twist_r * thumb)
	
	var twist_l = Quaternion(Vector3.LEFT, deg_to_rad(-90.0))
	print("Left Thumb (-90): ", twist_l * thumb)
	
	var twist_l2 = Quaternion(Vector3.LEFT, deg_to_rad(90.0))
	print("Left Thumb (90): ", twist_l2 * thumb)
	quit()
