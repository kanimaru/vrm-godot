extends GutTest

## The addon must not load its own scripts by `uid://`. On a project's first scan
## (a fresh clone, CI, a new worktree) the UID cache is not built yet when scripts
## are parsed, so a `preload("uid://...")` fails, the script does not compile, and
## anything that calls `.new()` on it during that same scan gets nothing. That is
## how both expression controllers were silently missing from every VRM imported
## on a first open. Paths resolve without the cache; drag-and-drop into the script
## editor writes UIDs, which is how they crept in.

const ADDON_ROOT := "res://addons/vrm"
const UID_LOAD := "load(\"uid://"


func test_no_script_loads_by_uid() -> void:
	var offenders: Array[String] = []
	_collect_uid_loads(ADDON_ROOT, offenders)
	assert_eq(offenders, [] as Array[String],
			"load these by relative path instead:\n" + "\n".join(offenders))


func _collect_uid_loads(dir_path: String, offenders: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect_uid_loads(dir_path.path_join(sub), offenders)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() != "gd":
			continue
		var path := dir_path.path_join(file)
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			if lines[i].contains(UID_LOAD):
				offenders.append("%s:%d" % [path, i + 1])
