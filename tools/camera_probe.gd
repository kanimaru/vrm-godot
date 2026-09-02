extends SceneTree
## Headless probe for the VMD camera path: load a camera .vmd through
## vmd_loader exactly like VBeami's VmdCameraNode does, then sample the
## %VmdCamera tracks at several times. Varying samples = data + sampling fine;
## constant samples = the builder's camera tracks are the problem.
##
## Usage:
##   godot --headless --path . -s res://tools/camera_probe.gd \
##       ++ file=res://assets/vmd/Caramell Dansen/camera.vmd


func _initialize() -> void:
	_run()


func _run() -> void:
	var file: String = "res://assets/vmd/Caramell Dansen/camera.vmd"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("file="):
			file = arg.trim_prefix("file=")

	var library: AnimationLibrary = load("res://addons/vrm/vmd/vmd_loader.gd") \
		.load_animation_library(file, 30.0, 0.0, false, 0.08)
	if library == null:
		print("[cam] load failed: ", file)
		quit(1)
		return

	var clips: Array = library.get_animation_list()
	if clips.is_empty():
		print("[cam] no clips")
		quit(1)
		return
	var anim: Animation = library.get_animation(clips[0])
	print("[cam] file=", file, " length=", anim.length, " tracks=", anim.get_track_count())

	var pos_track: int = -1
	var rot_track: int = -1
	var fov_track: int = -1
	for i: int in range(anim.get_track_count()):
		var path: String = str(anim.track_get_path(i))
		print("[cam]   track %d type=%d path=%s keys=%d" % [
			i, anim.track_get_type(i), path, anim.track_get_key_count(i)])
		if not "VmdCamera" in path:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D: pos_track = i
			Animation.TYPE_ROTATION_3D: rot_track = i
			Animation.TYPE_VALUE: if path.ends_with(":fov"): fov_track = i

	print("[cam] posTrack=", pos_track, " rotTrack=", rot_track, " fovTrack=", fov_track)
	if pos_track < 0:
		quit(1)
		return

	for t: float in [0.0, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0]:
		var p: Vector3 = anim.position_track_interpolate(pos_track, t)
		var q: Quaternion = anim.rotation_track_interpolate(rot_track, t) if rot_track >= 0 else Quaternion.IDENTITY
		var f: float = anim.value_track_interpolate(fov_track, t) if fov_track >= 0 else -1.0
		print("[cam] t=%5.1f pos=%s rot=%s fov=%.1f" % [t, p, q, f])

	print("[cam] done")
	quit(0)
