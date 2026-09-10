extends SceneTree
## Samples the expression VALUE tracks the VMD builder emits, the same way
## VBeami's VmdSource does (value_track_interpolate at a time). Nonzero,
## varying weights here mean the builder side is fine and the break is in the
## app's emit/apply chain; all-zero means the tracks themselves are wrong.
##
## Usage:
##   godot --headless --path . -s res://tools/morph_probe.gd \
##       ++ file=res://assets/vmd/Caramell Dansen/motion.vmd


func _initialize() -> void:
	_run()


func _run() -> void:
	var file: String = "res://assets/vmd/Caramell Dansen/motion.vmd"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("file="):
			file = arg.trim_prefix("file=")

	# Raw parse first: how many morph frames does the FILE even carry, and
	# under which names? Distinguishes "no face data authored" from "face data
	# lost in the pipeline".
	var data = load("res://addons/vrm/vmd/vmd_parser.gd").parse_file(file)
	if data != null:
		var names: Dictionary = {}
		for mf in data.morph_frames:
			names[mf.name] = int(names.get(mf.name, 0)) + 1
		print("[morph] raw morph frames=", data.morph_frames.size(), " unique names=", names.size())
		for n: String in names:
			print("[morph]   raw '", n, "' x", names[n])

	var library: AnimationLibrary = load("res://addons/vrm/vmd/vmd_loader.gd") \
		.load_animation_library(file, 30.0, 0.0, false, 0.08)
	var anim: Animation = library.get_animation(library.get_animation_list()[0])

	var expr_tracks: Array[int] = []
	for i: int in range(anim.get_track_count()):
		var path: String = str(anim.track_get_path(i))
		if anim.track_get_type(i) == Animation.TYPE_VALUE and "ExpressionController" in path:
			expr_tracks.append(i)
	print("[morph] exprTracks=", expr_tracks.size())

	# Report per-track key count, max key value, and a mid-dance sample.
	var nonzero_tracks: int = 0
	for i: int in expr_tracks:
		var max_val: float = 0.0
		for k: int in range(anim.track_get_key_count(i)):
			max_val = maxf(max_val, float(anim.track_get_key_value(i, k)))
		var sampled: float = float(anim.value_track_interpolate(i, 30.0))
		if max_val > 0.001:
			nonzero_tracks += 1
		if max_val > 0.001 or sampled > 0.001:
			print("[morph]   %-40s keys=%4d maxKey=%.3f sample@30s=%.3f updateMode=%d" % [
				str(anim.track_get_path(i)), anim.track_get_key_count(i),
				max_val, sampled, anim.value_track_get_update_mode(i)])
	print("[morph] tracks with nonzero keys: ", nonzero_tracks, "/", expr_tracks.size())

	# Densely sample one busy track over time to prove interpolate works.
	var busiest: int = -1
	var busiest_keys: int = 0
	for i: int in expr_tracks:
		if anim.track_get_key_count(i) > busiest_keys:
			busiest_keys = anim.track_get_key_count(i)
			busiest = i
	# Full key dump for the blink track — a value stuck at 1 between sparse
	# keys would hold the avatar's eyes shut for whole sections of the dance.
	for i: int in expr_tracks:
		if not str(anim.track_get_path(i)).ends_with(":blink"):
			continue
		var line2: String = "[morph] blink keys:"
		for k: int in range(anim.track_get_key_count(i)):
			line2 += " %.1fs=%.2f" % [anim.track_get_key_time(i, k), float(anim.track_get_key_value(i, k))]
		print(line2)

	if busiest >= 0:
		var line: String = "[morph] %s over time:" % str(anim.track_get_path(busiest))
		for t: float in [0.0, 10.0, 30.0, 60.0, 90.0, 120.0]:
			line += " t%.0f=%.3f" % [t, float(anim.value_track_interpolate(busiest, t))]
		print(line)
	quit(0)
