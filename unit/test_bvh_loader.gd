extends GutTest

const BvhLoader = preload("res://addons/vrm/bvh/bvh_loader.gd")
const BvhAnimationLibraryBuilder = preload("res://addons/vrm/bvh/bvh_animation_library_builder.gd")

## Two-frame root-only BVH fixture. Root OFFSET Y (90.0) is the rest-pose hips height
## used for auto-scale; the MOTION Yposition delta between frame 0 and frame 1 (10.0)
## is what the resulting animation's position track should reflect, scaled.
const MOCK_BVH := """HIERARCHY
ROOT Hips
{
	OFFSET 0.0 90.0 0.0
	CHANNELS 6 Xposition Yposition Zposition Xrotation Yrotation Zrotation
	End Site
	{
		OFFSET 0.0 0.0 0.0
	}
}
MOTION
Frames: 2
Frame Time: 0.033333
0.0 90.0 0.0 0.0 0.0 0.0
0.0 100.0 0.0 0.0 0.0 0.0
"""

var _mock_path: String = "user://test_mock.bvh"


func before_each() -> void:
	var f := FileAccess.open(_mock_path, FileAccess.WRITE)
	f.store_string(MOCK_BVH)
	f.close()


func after_each() -> void:
	if FileAccess.file_exists(_mock_path):
		DirAccess.remove_absolute(_mock_path)


func _get_hips_pos_track(library: AnimationLibrary) -> int:
	var anim: Animation = library.get_animation("Take 001")
	for i: int in range(anim.get_track_count()):
		if (
			anim.track_get_type(i) == Animation.TYPE_POSITION_3D
			and str(anim.track_get_path(i)) == "%GeneralSkeleton:Hips"
		):
			return i
	return -1


func test_explicit_scale_factor_used_when_no_target_hips_height() -> void:
	var library := BvhLoader.load_animation_library(
		_mock_path, 30.0, 0.01, BvhAnimationLibraryBuilder.PRESET_RAW
	)
	assert_not_null(library, "Library should be built")

	var track: int = _get_hips_pos_track(library)
	assert_ne(track, -1, "Hips position track should exist")

	var frame1_pos: Vector3 = library.get_animation("Take 001").track_get_key_value(track, 1)
	assert_almost_eq(frame1_pos.y, 0.1, 0.0001, "10.0 unit delta * explicit scale 0.01 = 0.1")


func test_target_hips_height_overrides_explicit_scale_factor() -> void:
	# BVH root OFFSET Y is 90.0; target_hips_height 1.8 -> auto scale = 1.8 / 90.0 = 0.02,
	# overriding the explicit (and otherwise-unused) scale_factor of 0.01.
	var library := BvhLoader.load_animation_library(
		_mock_path, 30.0, 0.01, BvhAnimationLibraryBuilder.PRESET_RAW, 1.8
	)
	assert_not_null(library, "Library should be built")

	var track: int = _get_hips_pos_track(library)
	assert_ne(track, -1, "Hips position track should exist")

	var frame1_pos: Vector3 = library.get_animation("Take 001").track_get_key_value(track, 1)
	assert_almost_eq(frame1_pos.y, 0.2, 0.0001, "10.0 unit delta * auto scale 0.02 = 0.2")


func test_negative_target_hips_height_is_treated_as_no_override() -> void:
	var library := BvhLoader.load_animation_library(
		_mock_path, 30.0, 0.01, BvhAnimationLibraryBuilder.PRESET_RAW, -1.0
	)
	var track: int = _get_hips_pos_track(library)
	var frame1_pos: Vector3 = library.get_animation("Take 001").track_get_key_value(track, 1)
	assert_almost_eq(frame1_pos.y, 0.1, 0.0001, "negative target_hips_height keeps explicit scale_factor")


func test_parsed_hierarchy_is_released_once_dropped() -> void:
	# Each joint pointed back at its parent, which held it in children: a reference cycle
	# that kept every parsed BvhNode alive until exit.
	var data: BvhParser.BvhData = BvhParser.parse(MOCK_BVH)
	var root_ref: WeakRef = weakref(data.root)
	var end_site: BvhParser.BvhNode = data.root.children[0]
	assert_same(end_site.parent, data.root, "a joint still reaches its parent")
	end_site = null
	data = null
	assert_null(root_ref.get_ref(), "the parsed hierarchy should be freed once nothing holds it")
