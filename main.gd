extends Node3D
func _ready():
	var skel = $luna/GeneralSkeleton  # adjust path
	for bone_name in ["upper_arm.L", "upper_arm.R", "upper_leg.L", "upper_leg.R"]:
		var idx = skel.find_bone(bone_name)
		if idx >= 0:
			print("REST: ", bone_name, " = ", skel.get_bone_rest(idx).basis.get_rotation_quaternion())
