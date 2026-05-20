extends GutTest

const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
const VmdAnimationLibraryBuilder = preload("res://addons/vrm/vmd/vmd_animation_library_builder.gd")
const VmdLoader = preload("res://addons/vrm/vmd/vmd_loader.gd")

func test_vmd_parser_with_mock_data():
	# Create a very small mock VMD file in memory
	var bytes := PackedByteArray()
	
	# Signature (30 bytes)
	var sig := "Vocaloid Motion Data 0002"
	bytes.append_array(sig.to_ascii_buffer())
	bytes.resize(30)
	
	# Model Name (20 bytes)
	var model := "Test Model"
	bytes.append_array(model.to_ascii_buffer())
	bytes.resize(30 + 20)
	
	# Bone Count (4 bytes) - 1 bone
	_append_u32(bytes, 1)
	
	# Bone Frame (111 bytes)
	# Name (15)
	var bname := "センター" # Center
	var bname_bytes = _to_cp932(bname)
	bytes.append_array(bname_bytes)
	bytes.resize(bytes.size() + (15 - bname_bytes.size()))
	# Frame (4)
	_append_u32(bytes, 10)
	# Pos (12)
	_append_float(bytes, 1.0)
	_append_float(bytes, 2.0)
	_append_float(bytes, 3.0)
	# Rot (16)
	_append_float(bytes, 0.0)
	_append_float(bytes, 0.0)
	_append_float(bytes, 0.0)
	_append_float(bytes, 1.0)
	# Interpolation (64)
	bytes.resize(bytes.size() + 64)
	
	# Morph Count (4) - 0
	_append_u32(bytes, 0)
	
	# Save to a temporary file
	var path := "user://test_mock.vmd"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	
	# Test Parser
	var data := VmdParser.parse_file(path)
	assert_not_null(data, "Data should be parsed")
	assert_eq(data.bone_frames.size(), 1, "Should have 1 bone frame")
	assert_eq(data.bone_frames[0].name, "センター", "Bone name should match")
	assert_eq(data.bone_frames[0].frame, 10, "Frame number should match")
	assert_eq(data.bone_frames[0].position, Vector3(1, 2, -3), "Position should match")

func test_vmd_builder():
	var data := VmdParser.VmdData.new()
	var bf := VmdParser.VmdBoneFrame.new()
	bf.name = "センター"
	bf.frame = 30
	bf.position = Vector3(1, 1, 1)
	bf.rotation = Quaternion.IDENTITY
	data.bone_frames.append(bf)
	
	var library := VmdAnimationLibraryBuilder.build(data)
	assert_not_null(library, "Library should be built")
	assert_true(library.has_animation("default"), "Should have default animation")
	
	var anim := library.get_animation("default")
	assert_gt(anim.length, 0.9, "Animation length should be approx 1s (30 frames)")
	assert_gt(anim.get_track_count(), 0, "Should have tracks")

# Helper to append Little-Endian U32
func _append_u32(arr: PackedByteArray, val: int):
	arr.append(val & 0xFF)
	arr.append((val >> 8) & 0xFF)
	arr.append((val >> 16) & 0xFF)
	arr.append((val >> 24) & 0xFF)

# Helper to append Little-Endian Float32
func _append_float(arr: PackedByteArray, val: float):
	var b := var_to_bytes(val)
	# Godot 4 var_to_bytes(float) returns 8 bytes (double)
	# We need 4 bytes (float32)
	# Actually, PackedByteArray.encode_float exists!
	var pos = arr.size()
	arr.resize(pos + 4)
	arr.encode_float(pos, val)

# Simple mock CP932 conversion for "センター"
func _to_cp932(s: String) -> PackedByteArray:
	if s == "センター":
		return PackedByteArray([0x83, 0x5A, 0x83, 0x93, 0x83, 0x5E, 0x81, 0x5B])
	return s.to_ascii_buffer()
