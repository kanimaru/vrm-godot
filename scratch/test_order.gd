extends SceneTree

func _init():
	var names = ["Center", "Groove", "LowerBody"]
	var total_rot = "I"
	for name in names:
		var sampled_rot = name
		total_rot = sampled_rot + " * " + total_rot
		
	print("Final: ", total_rot)
	quit()
