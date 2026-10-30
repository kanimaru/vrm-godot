extends SceneTree
## Dumps raw VMD bone interpolation control points for one MMD bone: are the
## authored curves actually non-linear (custom easing), or is the file itself
## linear (20, 20, 107, 107 diagonals)? Decides data-vs-plumbing.
##
## Usage:
##   godot --headless --path . -s res://tools/interp_dump.gd \
##       ++ file=res://assets/private/vmd/Caramell Dansen/motion.vmd


func _initialize() -> void:
	_run()


func _run() -> void:
	var file: String = "res://assets/private/vmd/Caramell Dansen/motion.vmd"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("file="):
			file = arg.trim_prefix("file=")

	var VmdParser = load("res://addons/vrm/vmd/vmd_parser.gd")
	var data = VmdParser.parse_file(file)
	if data == null:
		print("[interp] parse failed")
		quit(1)
		return

	# Count linear vs custom rotation curves per bone.
	var stats: Dictionary = {}
	for frame in data.bone_frames:
		var interp: PackedByteArray = frame.interpolation
		if interp.size() < 16:
			continue
		# Rotation curve: x1=interp[3], y1=interp[7], x2=interp[11], y2=interp[15]
		var linear: bool = (
			absi(interp[3] - interp[7]) <= 1 and absi(interp[11] - interp[15]) <= 1)
		if not stats.has(frame.name):
			stats[frame.name] = { "linear": 0, "custom": 0, "sample": "" }
		var s: Dictionary = stats[frame.name]
		if linear:
			s.linear += 1
		else:
			s.custom += 1
			if s.sample == "":
				s.sample = "R(%d,%d,%d,%d)" % [interp[3], interp[7], interp[11], interp[15]]

	for bone_name: String in stats:
		var s: Dictionary = stats[bone_name]
		if s.custom > 0 or s.linear > 50:
			print("[interp] %s linear=%d custom=%d %s" % [bone_name, s.linear, s.custom, s.sample])
	quit(0)
