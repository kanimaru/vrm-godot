extends GutTest

## Unit tests for VRMUtil static helper functions.
## Builds minimal Node/Skeleton hierarchies in-process — no assets required.


# ---------------------------------------------------------------------------
# get_humanoid_bone_map / set_humanoid_bone_map
# ---------------------------------------------------------------------------

func test_get_humanoid_bone_map_returns_empty_when_meta_absent() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)

	var result: Dictionary = VRMUtil.get_humanoid_bone_map(node)

	assert_eq(result.size(), 0)


func test_get_humanoid_bone_map_returns_stored_map() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	var expected: Dictionary = { "head": "Head", "hips": "Hips" }
	VRMUtil.set_humanoid_bone_map(node, expected)

	var result: Dictionary = VRMUtil.get_humanoid_bone_map(node)

	assert_eq(result, expected)


func test_get_humanoid_bone_map_returns_empty_for_null_node() -> void:
	var result: Dictionary = VRMUtil.get_humanoid_bone_map(null)

	assert_eq(result.size(), 0)


# ---------------------------------------------------------------------------
# get_humanoid_bone
# ---------------------------------------------------------------------------

func test_get_humanoid_bone_returns_correct_name() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	VRMUtil.set_humanoid_bone_map(node, { "head": "HeadBone" })

	var result: StringName = VRMUtil.get_humanoid_bone(node, "head")

	assert_eq(result, "HeadBone")


func test_get_humanoid_bone_returns_empty_when_not_found() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	VRMUtil.set_humanoid_bone_map(node, { "head": "HeadBone" })

	var result: StringName = VRMUtil.get_humanoid_bone(node, "spine")

	assert_eq(result, "")


func test_get_humanoid_bone_lookup_is_lowercase() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	VRMUtil.set_humanoid_bone_map(node, { "head": "HeadBone" })

	# Passing upper-case role; function should normalise with to_lower().
	var result: StringName = VRMUtil.get_humanoid_bone(node, "HEAD")

	assert_eq(result, "HeadBone")


# ---------------------------------------------------------------------------
# find_bone
# ---------------------------------------------------------------------------

func _make_skeleton_with_bones(bone_names: Array[String]) -> Skeleton3D:
	var skel: Skeleton3D = Skeleton3D.new()
	for name: String in bone_names:
		skel.add_bone(name)
	return skel


func test_find_bone_exact_match() -> void:
	var skel: Skeleton3D = _make_skeleton_with_bones(["Head", "Hips", "Spine"])
	autofree(skel)

	var result: String = VRMUtil.find_bone(skel, null, "Head")

	assert_eq(result, "Head")


func test_find_bone_case_insensitive_fallback() -> void:
	var skel: Skeleton3D = _make_skeleton_with_bones(["Head", "Hips"])
	autofree(skel)

	var result: String = VRMUtil.find_bone(skel, null, "head")

	assert_eq(result, "Head")


func test_find_bone_via_humanoid_metadata() -> void:
	# Simulates a retargeted skeleton where the bone has a non-standard name
	# that only matches via the VRM humanoid role metadata, not by exact/case match.
	var skel: Skeleton3D = _make_skeleton_with_bones(["MixHead"])
	autofree(skel)
	var model: Node3D = Node3D.new()
	autofree(model)
	VRMUtil.set_humanoid_bone_map(model, { "head": "MixHead" })

	var result: String = VRMUtil.find_bone(skel, model, "head")

	assert_eq(result, "MixHead")


func test_find_bone_returns_empty_when_not_found() -> void:
	var skel: Skeleton3D = _make_skeleton_with_bones(["Head"])
	autofree(skel)

	var result: String = VRMUtil.find_bone(skel, null, "LeftFoot")

	assert_eq(result, "")


func test_find_bone_returns_empty_for_null_skeleton() -> void:
	var result: String = VRMUtil.find_bone(null, null, "Head")

	assert_eq(result, "")


# ---------------------------------------------------------------------------
# find_skeleton
# ---------------------------------------------------------------------------

func test_find_skeleton_direct_child() -> void:
	var root: Node3D = Node3D.new()
	var skel: Skeleton3D = Skeleton3D.new()
	root.add_child(skel)
	autofree(root)

	var result: Skeleton3D = VRMUtil.find_skeleton(root)

	assert_eq(result, skel)


func test_find_skeleton_nested() -> void:
	var root: Node3D = Node3D.new()
	var mid: Node3D = Node3D.new()
	var skel: Skeleton3D = Skeleton3D.new()
	root.add_child(mid)
	mid.add_child(skel)
	autofree(root)

	var result: Skeleton3D = VRMUtil.find_skeleton(root)

	assert_eq(result, skel)


func test_find_skeleton_returns_null_when_absent() -> void:
	var root: Node3D = Node3D.new()
	autofree(root)

	var result: Skeleton3D = VRMUtil.find_skeleton(root)

	assert_null(result)


func test_find_skeleton_returns_itself_when_is_skeleton() -> void:
	var skel: Skeleton3D = Skeleton3D.new()
	autofree(skel)

	var result: Skeleton3D = VRMUtil.find_skeleton(skel)

	assert_eq(result, skel)


# ---------------------------------------------------------------------------
# is_vrm / is_vrm0 / is_vrm1
# ---------------------------------------------------------------------------

func test_is_vrm_false_with_no_metadata() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)

	assert_false(VRMUtil.is_vrm(node))


func test_is_vrm0_true_after_setting_vrm0_data() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	var data: Vrm0TopLevel = Vrm0TopLevel.new()
	VRMUtil.set_vrm0_data(node, data)

	assert_true(VRMUtil.is_vrm(node))
	assert_true(VRMUtil.is_vrm0(node))
	assert_false(VRMUtil.is_vrm1(node))


func test_is_vrm1_true_after_setting_vrm1_data() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	var data: Vrm1TopLevel = Vrm1TopLevel.new()
	VRMUtil.set_vrm1_data(node, data)

	assert_true(VRMUtil.is_vrm(node))
	assert_false(VRMUtil.is_vrm0(node))
	assert_true(VRMUtil.is_vrm1(node))


func test_is_vrm_false_for_null() -> void:
	assert_false(VRMUtil.is_vrm(null))
	assert_false(VRMUtil.is_vrm0(null))
	assert_false(VRMUtil.is_vrm1(null))


# ---------------------------------------------------------------------------
# get_vrm0_data / get_vrm1_data round-trip
# ---------------------------------------------------------------------------

func test_get_vrm0_data_round_trip() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	var data: Vrm0TopLevel = Vrm0TopLevel.new()
	VRMUtil.set_vrm0_data(node, data)

	var retrieved: Vrm0TopLevel = VRMUtil.get_vrm0_data(node)

	assert_eq(retrieved, data)


func test_get_vrm1_data_round_trip() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)
	var data: Vrm1TopLevel = Vrm1TopLevel.new()
	VRMUtil.set_vrm1_data(node, data)

	var retrieved: Vrm1TopLevel = VRMUtil.get_vrm1_data(node)

	assert_eq(retrieved, data)


func test_get_vrm0_data_returns_null_when_absent() -> void:
	var node: Node3D = Node3D.new()
	autofree(node)

	assert_null(VRMUtil.get_vrm0_data(node))


# ---------------------------------------------------------------------------
# find_expression_controller
# ---------------------------------------------------------------------------

func test_find_expression_controller_returns_null_when_none() -> void:
	var root: Node3D = Node3D.new()
	autofree(root)

	assert_null(VRMUtil.find_expression_controller(root))


func test_find_expression_controller_finds_vrm0_controller() -> void:
	var root: Node3D = Node3D.new()
	var ctrl: Vrm0ExpressionController = Vrm0ExpressionController.new()
	root.add_child(ctrl)
	autofree(root)

	var result: Node = VRMUtil.find_expression_controller(root)

	assert_eq(result, ctrl)


func test_find_expression_controller_finds_vrm1_controller() -> void:
	var root: Node3D = Node3D.new()
	var ctrl: Vrm1ExpressionController = Vrm1ExpressionController.new()
	root.add_child(ctrl)
	autofree(root)

	var result: Node = VRMUtil.find_expression_controller(root)

	assert_eq(result, ctrl)


func test_find_expression_controller_returns_null_for_null_root() -> void:
	assert_null(VRMUtil.find_expression_controller(null))
