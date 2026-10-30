extends SceneTree
## Verifies VMD Bezier easing survives the bake: inside one authored segment,
## per-frame rotation steps should ACCELERATE and DECELERATE (ease-in/out).
## The old linear bake produced constant step sizes — flat runs in this dump.
##
## Usage:
##   godot --headless --path . -s res://tools/easing_probe.gd \
##       ++ file=res://assets/private/vmd/Caramell Dansen/motion.vmd bone=leftUpperArm


func _initialize() -> void:
	_run()


func _run() -> void:
	var file: String = "res://assets/private/vmd/Caramell Dansen/motion.vmd"
	var bone: String = "leftUpperArm"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("file="):
			file = arg.trim_prefix("file=")
		elif arg.begins_with("bone="):
			bone = arg.trim_prefix("bone=")

	var library: AnimationLibrary = load("res://addons/vrm/vmd/vmd_loader.gd") \
		.load_animation_library(file, 30.0, 0.0, false, 0.08)
	if library == null:
		print("[ease] load failed")
		quit(1)
		return
	var anim: Animation = library.get_animation(library.get_animation_list()[0])

	var track: int = anim.find_track(
		NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D)
	if track < 0:
		print("[ease] no rotation track for ", bone)
		quit(1)
		return

	var keys: int = anim.track_get_key_count(track)
	print("[ease] bone=", bone, " keys=", keys)

	# Find the largest-motion window and dump per-frame step angles there:
	# varying steps = easing baked; constant runs = linear.
	var best_start: int = 0
	var best_sum: float = 0.0
	for i: int in range(0, keys - 24):
		var s: float = 0.0
		for j: int in range(i, i + 24):
			var q0: Quaternion = anim.track_get_key_value(track, j)
			var q1: Quaternion = anim.track_get_key_value(track, j + 1)
			s += q0.angle_to(q1)
		if s > best_sum:
			best_sum = s
			best_start = i

	var steps: PackedFloat32Array = PackedFloat32Array()
	for j: int in range(best_start, best_start + 24):
		var q0: Quaternion = anim.track_get_key_value(track, j)
		var q1: Quaternion = anim.track_get_key_value(track, j + 1)
		steps.append(rad_to_deg(q0.angle_to(q1)))

	print("[ease] window at key ", best_start, " step angles (deg/frame):")
	var line: String = "[ease]  "
	for s: float in steps:
		line += " %5.2f" % s
	print(line)

	# Constant-run detector: longest run of near-identical consecutive steps.
	var longest_run: int = 1
	var run: int = 1
	for i: int in range(1, steps.size()):
		if absf(steps[i] - steps[i - 1]) < 0.02 and steps[i] > 0.1:
			run += 1
			longest_run = maxi(longest_run, run)
		else:
			run = 1
	print("[ease] longest constant run: ", longest_run,
		" (linear bake shows long runs, easing shows short ones)")
	quit(0)
