extends GutTest

const CP932Decoder = preload("res://addons/vrm/vmd/cp932_decoder.gd")

## Tests for the CP932Decoder class.

func test_ascii_decoding():
	var data := PackedByteArray([0x48, 0x65, 0x6C, 0x6C, 0x6F]) # "Hello"
	var result: String = CP932Decoder.decode(data)
	assert_eq(result, "Hello", "Should decode plain ASCII correctly")

func test_half_width_katakana():
	# 0xB1 = ｱ, 0xB2 = ｲ, 0xB3 = ｳ
	var data := PackedByteArray([0xB1, 0xB2, 0xB3])
	var result: String = CP932Decoder.decode(data)
	assert_eq(result, "ｱｲｳ", "Should decode half-width katakana correctly")

func test_full_width_katakana():
	# センター (Center)
	# セ: 0x835A, ン: 0x8393, タ: 0x835E, ー: 0x815B
	var data := PackedByteArray([0x83, 0x5A, 0x83, 0x93, 0x83, 0x5E, 0x81, 0x5B])
	var result: String = CP932Decoder.decode(data)
	assert_eq(result, "センター", "Should decode full-width katakana (Center) correctly")

func test_kanji_decoding():
	# 全ての親 (Mother bone)
	# 全: 0x9153, て: 0x82C4, の: 0x82CC, 親: 0x9065
	var data := PackedByteArray([0x91, 0x53, 0x82, 0xC4, 0x82, 0xCC, 0x90, 0x65])
	var result: String = CP932Decoder.decode(data)
	assert_eq(result, "全ての親", "Should decode common bone kanji correctly")

func test_vmd_padding_handling():
	# Test with null terminator
	var data_null := PackedByteArray([0x41, 0x00, 0x42]) # "A\0B"
	var result_null: String = CP932Decoder.decode(data_null)
	assert_eq(result_null, "A", "Should stop at null terminator")
	
	# Test with 0xFD padding
	var result_fd: String = CP932Decoder.decode(PackedByteArray([0x41, 0xFD, 0x42])) # "A\xfdB"
	assert_eq(result_fd, "A", "Should stop at 0xFD padding")

func test_unknown_character():
	# 0x81 0x01 is likely unmapped in standard tables or at least not in our generated one if invalid
	var data := PackedByteArray([0x81, 0x01])
	var result: String = CP932Decoder.decode(data)
	assert_eq(result, "?", "Should handle unmapped characters gracefully")
