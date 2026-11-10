extends GutTest

## The VRM extensions rename the glTF images in _import_preflight, before Godot's
## _parse_images names the textures it extracts. Godot names an extracted texture
## <file>_<image name>.png after name.get_file().get_basename().validate_filename(),
## so "Pants.Simple" became "Pants" and clashed with the real "Pants": the import
## settings of one texture (a normal map) landed on the other (a colour map).
## Godot breaks such clashes with "_<index>", which changes between exports, and
## compares case-sensitively while Windows file names do not.

const CLASHING_NAMES: Array[String] = [
	"Pants",
	"Pants.Simple",
	"Pants.Simple",
	"Pants.Black.Normal",
	"Pants.Black",
	"Hair.png",
	"hair",
	"textures/Body.normal.png",
]


func _json_with_images(names: Array[String]) -> Dictionary:
	var images: Array = []
	for name: String in names:
		images.append({ "name": name, "bufferView": images.size() })
	images.append({ "bufferView": images.size() })
	return { "images": images }


func _state_with_images(names: Array[String]) -> GLTFState:
	var state: GLTFState = GLTFState.new()
	state.set_json(_json_with_images(names))
	return state


## The extracted texture's file name, as GLTFDocument::_parse_images builds it.
func _godot_file_name(image: Dictionary) -> String:
	if not image.has("name"):
		return ""
	var name: String = image["name"]
	return name.get_file().get_basename().validate_filename()


func _file_names(state: GLTFState) -> Array[String]:
	var names: Array[String] = []
	for image: Dictionary in state.get_json()["images"]:
		names.append(_godot_file_name(image))
	return names


func _assert_unique_dot_free(names: Array[String]) -> void:
	var seen: Dictionary[String, String] = {}
	for name: String in names:
		if name.is_empty():
			continue
		assert_false(name.contains("."), "'%s' still holds a dot" % name)
		var key: String = name.to_lower()
		assert_false(seen.has(key), "'%s' clashes with '%s'" % [name, seen.get(key, "")])
		seen[key] = name


func test_vrm1_preflight_gives_every_image_its_own_file_name() -> void:
	var state: GLTFState = _state_with_images(CLASHING_NAMES)

	var err: Error = Vrm1Extension.new()._import_preflight(state, PackedStringArray(["VRMC_vrm"]))

	assert_eq(err, OK)
	_assert_unique_dot_free(_file_names(state))


func test_vrm0_preflight_gives_every_image_its_own_file_name() -> void:
	var state: GLTFState = _state_with_images(CLASHING_NAMES)

	var err: Error = Vrm0Extension.new()._import_preflight(state, PackedStringArray(["VRM"]))

	assert_eq(err, OK)
	_assert_unique_dot_free(_file_names(state))


func test_names_keep_their_words() -> void:
	var state: GLTFState = _state_with_images(CLASHING_NAMES)

	Vrm1Extension.new()._import_preflight(state, PackedStringArray(["VRMC_vrm"]))

	var names: Array[String] = _file_names(state)
	assert_eq(names[0], "Pants")
	assert_eq(names[1], "Pants_Simple")
	assert_eq(names[2], "Pants_Simple_2")
	assert_eq(names[3], "Pants_Black_Normal")
	assert_eq(names[4], "Pants_Black")
	assert_eq(names[5], "Hair")
	assert_eq(names[6], "hair_2")
	assert_eq(names[7], "Body_normal")
	assert_eq(names[8], "", "an image without a name keeps Godot's index name")


func test_renaming_is_stable_across_imports() -> void:
	var first: GLTFState = _state_with_images(CLASHING_NAMES)
	var second: GLTFState = _state_with_images(CLASHING_NAMES)

	Vrm1Extension.new()._import_preflight(first, PackedStringArray(["VRMC_vrm"]))
	Vrm1Extension.new()._import_preflight(second, PackedStringArray(["VRMC_vrm"]))

	assert_eq(_file_names(first), _file_names(second))


func test_other_gltf_files_are_left_alone() -> void:
	var state: GLTFState = _state_with_images(CLASHING_NAMES)

	var err: Error = Vrm1Extension.new()._import_preflight(state, PackedStringArray())

	assert_eq(err, ERR_SKIP)
	assert_eq(state.get_json()["images"][1]["name"], "Pants.Simple")
