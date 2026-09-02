extends SceneTree
## Headless spring-bone probe: loads a VRM the same way the runtime demo does,
## dumps every SpringBoneSimulator3D setting the chain builder produced
## (root -> end bone, physics params, center, collisions), then ticks frames
## and measures end-bone drift from rest — a monotonically growing drift means
## the simulation is running away (the "VRM0 avatars distort over time" bug).
##
## Usage:
##   godot --headless --path . -s res://tools/spring_probe.gd \
##       ++ model=res://assets/temptic/model.vrm frames=300


func _initialize() -> void:
	_run()


func _run() -> void:
	var model_path: String = "res://assets/temptic/model.vrm"
	var frames: int = 300
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("model="):
			model_path = arg.trim_prefix("model=")
		elif arg.begins_with("frames="):
			frames = int(arg.trim_prefix("frames="))

	var vrm0_ext: GLTFDocumentExtension = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	var vrm1_ext: GLTFDocumentExtension = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0_ext, true)
	GLTFDocument.register_gltf_document_extension(vrm1_ext, true)

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	if gltf.append_from_file(model_path, state) != OK:
		print("[probe] FAILED to load ", model_path)
		quit(1)
		return
	var model: Node = gltf.generate_scene(state)
	root.add_child(model)
	await process_frame

	print("[probe] model=", model_path)

	var skeleton: Skeleton3D = _find_first(model, "Skeleton3D") as Skeleton3D
	if skeleton == null:
		print("[probe] no skeleton found")
		quit(1)
		return

	var sims: Array[Node] = []
	_collect(model, "SpringBoneSimulator3D", sims)
	print("[probe] simulators=", sims.size())

	var watch: Dictionary = {}  # bone name -> rest global origin
	for sim: Node in sims:
		var s: SpringBoneSimulator3D = sim as SpringBoneSimulator3D
		print("[probe] sim '%s' (%s) settings=%d" % [
			s.name, s.get_script().get_global_name() if s.get_script() else "native",
			s.get_setting_count(),
		])
		for i: int in range(s.get_setting_count()):
			var root_name: String = s.get_root_bone_name(i)
			var end_name: String = s.get_end_bone_name(i)
			var depth: int = _chain_depth(skeleton, root_name, end_name)
			print("[probe]   #%d %s -> %s (len=%d) stiff=%.2f drag=%.2f grav=%.3f dir=%s r=%.3f centerFrom=%d center='%s' coll=%d" % [
				i, root_name, end_name, depth,
				s.get_stiffness(i), s.get_drag(i), s.get_gravity(i),
				s.get_gravity_direction(i), s.get_radius(i),
				s.get_center_from(i), s.get_center_bone_name(i),
				s.get_collision_count(i),
			])
			if not watch.has(end_name):
				var idx: int = skeleton.find_bone(end_name)
				if idx >= 0:
					watch[end_name] = skeleton.get_bone_global_rest(idx).origin

	# Track post-modifier poses: modifier results only exist during the
	# skeleton update, so read them inside skeleton_updated.
	var latest: Dictionary = {}
	skeleton.skeleton_updated.connect(func() -> void:
		for bone_name: String in watch:
			var idx: int = skeleton.find_bone(bone_name)
			if idx >= 0:
				latest[bone_name] = skeleton.get_bone_global_pose(idx).origin
	)

	for f: int in range(frames):
		skeleton.force_update_all_bone_transforms()
		await process_frame
		if f % 60 == 59 or f == frames - 1:
			var worst_name: String = ""
			var worst: float = 0.0
			for bone_name: String in watch:
				if not latest.has(bone_name):
					continue
				var drift: float = (latest[bone_name] as Vector3).distance_to(watch[bone_name])
				if drift > worst:
					worst = drift
					worst_name = bone_name
			print("[probe] frame=%d worstDrift=%.4f bone='%s'" % [f + 1, worst, worst_name])

	print("[probe] done")
	quit(0)


func _find_first(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_first(child, cls)
		if found != null:
			return found
	return null


func _collect(node: Node, cls: String, out: Array[Node]) -> void:
	if node.is_class(cls):
		out.append(node)
	for child: Node in node.get_children():
		_collect(child, cls, out)


## Bones from root to end inclusive, or -1 when end is not beneath root.
func _chain_depth(skeleton: Skeleton3D, root_name: String, end_name: String) -> int:
	var root_idx: int = skeleton.find_bone(root_name)
	var idx: int = skeleton.find_bone(end_name)
	if root_idx < 0 or idx < 0:
		return -1
	var depth: int = 1
	while idx != root_idx and idx >= 0:
		idx = skeleton.get_bone_parent(idx)
		depth += 1
	return depth if idx == root_idx else -1
