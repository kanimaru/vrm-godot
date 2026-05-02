extends SceneTree

func _init():
	var q_x = Quaternion(Vector3.RIGHT, PI/2)
	var q_y = Quaternion(Vector3.UP, PI/2)
	
	var q1 = q_x * q_y
	var q2 = q_y * q_x
	
	print("q_x * q_y applied to RIGHT: ", q1 * Vector3.RIGHT)
	print("q_y * q_x applied to RIGHT: ", q2 * Vector3.RIGHT)
	
	print("q_y * (q_x * RIGHT): ", q_y * (q_x * Vector3.RIGHT))
	print("q_x * (q_y * RIGHT): ", q_x * (q_y * Vector3.RIGHT))
	
	quit()
