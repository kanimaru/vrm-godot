@tool
extends RefCounted

## Gives every image of a glTF document a name of its own before Godot extracts them.
##
## GLTFDocument::_parse_images names an extracted texture <file>_<name>.png after
## name.get_file().get_basename(), so everything after the last dot is dropped:
## Blender's exporter writes "Pants.Simple" for a packed "Pants.Simple.LowPoly_Normal",
## Godot turns it into "Pants", and it lands on the same file as the real "Pants". The
## import settings of one (a normal map) then apply to the other (a colour map). Godot
## breaks such clashes with "_<index>", which shifts between exports, and compares
## names case-sensitively, while Windows file names are not.
##
## Call rename_images() from _import_preflight, which runs before _parse_images.

const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "ktx2", "basis"]


## Renames json["images"][i]["name"] in place: dots become underscores, a known image
## extension is dropped, and a name that clashes (ignoring case) gets "_2", "_3", ...
## in document order. Images without a name keep none; Godot names them by index.
static func rename_images(json: Dictionary) -> void:
	var images: Variant = json.get("images")
	if not images is Array:
		return

	var taken: Dictionary[String, bool] = {}
	for index: int in images.size():
		var image: Variant = images[index]
		if not image is Dictionary or not image.has("name"):
			taken[str(index)] = true
			continue
		var name: String = file_name_for(str(image["name"]))
		if name.is_empty():
			taken[str(index)] = true
			continue
		var unique: String = name
		var suffix: int = 2
		while taken.has(unique.to_lower()):
			unique = "%s_%d" % [name, suffix]
			suffix += 1
		taken[unique.to_lower()] = true
		image["name"] = unique


## The dot-free name Godot keeps whole: "textures/Body.normal.png" -> "Body_normal".
static func file_name_for(name: String) -> String:
	var file: String = name.get_file()
	if file.get_extension().to_lower() in IMAGE_EXTENSIONS:
		file = file.get_basename()
	return file.replace(".", "_").validate_filename()
