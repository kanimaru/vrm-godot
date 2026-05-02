extends SceneTree

const VRMUtil = preload("res://addons/vrm/common/vrm_util.gd")

func _init():
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = gltf.append_from_file("assets/luna/luna.vrm", state)
	var generated_scene = gltf.generate_scene(state)
	
	var skeleton: Skeleton3D = VRMUtil.find_skeleton(generated_scene)
	var out = ""
	for i in range(skeleton.get_bone_count()):
		out += skeleton.get_bone_name(i) + "\n"
	
	var f = FileAccess.open("res://scratch/output.txt", FileAccess.WRITE)
	f.store_string(out)
	f.close()
	quit()

func _compute_bone_world_rest(skeleton: Skeleton3D, bone_idx: int, skeleton_rot: Quaternion) -> Transform3D:
	var rest: Transform3D = skeleton.get_bone_rest(bone_idx)
	var parent: int = skeleton.get_bone_parent(bone_idx)
	while parent >= 0:
		rest = skeleton.get_bone_rest(parent) * rest
		parent = skeleton.get_bone_parent(parent)
	return Transform3D(Basis(skeleton_rot), Vector3.ZERO) * rest
