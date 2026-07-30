extends "res://unit/vrm_gut_test.gd"

## Unit tests for Vrm1Extension._apply_first_person_visibility - moving
## thirdPersonOnly/firstPersonOnly-annotated meshes onto their dedicated render layers
## (VrmConstants.THIRD_PERSON_ONLY_LAYER / FIRST_PERSON_ONLY_LAYER) so a game's own
## first-person and third-person cameras can cull them via their own cull_masks.

var _ext: Vrm1Extension


func before_each() -> void:
	_ext = Vrm1Extension.new()


func after_each() -> void:
	_ext = null


func _make_state_with_mesh_node(original_name: String) -> GLTFState:
	var gnode := GLTFNode.new()
	gnode.original_name = original_name
	var state := GLTFState.new()
	var nodes: Array[GLTFNode] = [gnode]
	state.nodes = nodes
	return state


func _make_annotation(node_idx: int, type: String) -> Vrm1FirstPersonMeshAnnotation:
	var a := Vrm1FirstPersonMeshAnnotation.new()
	a.node = node_idx
	a.type = type
	return a


func test_third_person_only_moves_mesh_off_default_layer() -> void:
	var state := _make_state_with_mesh_node("Face")
	var root := Node3D.new()
	add_child_autofree(root)
	var face := MeshInstance3D.new()
	face.name = "Face"
	root.add_child(face)

	var fp := Vrm1FirstPerson.new()
	fp.mesh_annotations = [_make_annotation(0, "thirdPersonOnly")]

	_ext.call("_apply_first_person_visibility", root, fp, state)

	assert_false(face.get_layer_mask_value(1), "thirdPersonOnly mesh should leave the default layer")
	assert_true(face.get_layer_mask_value(VrmConstants.THIRD_PERSON_ONLY_LAYER))
	assert_false(face.get_layer_mask_value(VrmConstants.FIRST_PERSON_ONLY_LAYER))


func test_first_person_only_moves_mesh_to_its_own_layer() -> void:
	var state := _make_state_with_mesh_node("UI")
	var root := Node3D.new()
	add_child_autofree(root)
	var ui := MeshInstance3D.new()
	ui.name = "UI"
	root.add_child(ui)

	var fp := Vrm1FirstPerson.new()
	fp.mesh_annotations = [_make_annotation(0, "firstPersonOnly")]

	_ext.call("_apply_first_person_visibility", root, fp, state)

	assert_false(ui.get_layer_mask_value(1))
	assert_true(ui.get_layer_mask_value(VrmConstants.FIRST_PERSON_ONLY_LAYER))
	assert_false(ui.get_layer_mask_value(VrmConstants.THIRD_PERSON_ONLY_LAYER))


func test_both_leaves_default_layer_untouched() -> void:
	var state := _make_state_with_mesh_node("Body")
	var root := Node3D.new()
	add_child_autofree(root)
	var body := MeshInstance3D.new()
	body.name = "Body"
	root.add_child(body)

	var fp := Vrm1FirstPerson.new()
	fp.mesh_annotations = [_make_annotation(0, "both")]

	_ext.call("_apply_first_person_visibility", root, fp, state)

	assert_true(body.get_layer_mask_value(1))
	assert_false(body.get_layer_mask_value(VrmConstants.THIRD_PERSON_ONLY_LAYER))
	assert_false(body.get_layer_mask_value(VrmConstants.FIRST_PERSON_ONLY_LAYER))


## `auto` classification (per-triangle head/non-head splitting) isn't implemented - see the
## doc comment on _apply_first_person_visibility for why a whole-mesh heuristic would be
## unsafe against real content. `auto` is treated the same as `both`: left alone.
func test_auto_leaves_default_layer_untouched() -> void:
	var state := _make_state_with_mesh_node("Body")
	var root := Node3D.new()
	add_child_autofree(root)
	var body := MeshInstance3D.new()
	body.name = "Body"
	root.add_child(body)

	var fp := Vrm1FirstPerson.new()
	fp.mesh_annotations = [_make_annotation(0, "auto")]

	_ext.call("_apply_first_person_visibility", root, fp, state)

	assert_true(body.get_layer_mask_value(1))


func test_mesh_with_no_annotation_at_all_stays_on_default_layer() -> void:
	var state := _make_state_with_mesh_node("Hat")
	var root := Node3D.new()
	add_child_autofree(root)
	var hat := MeshInstance3D.new()
	hat.name = "Hat"
	root.add_child(hat)

	var fp := Vrm1FirstPerson.new()
	fp.mesh_annotations = []

	_ext.call("_apply_first_person_visibility", root, fp, state)

	assert_true(hat.get_layer_mask_value(1))


func test_null_first_person_is_a_no_op() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh := MeshInstance3D.new()
	root.add_child(mesh)

	_ext.call("_apply_first_person_visibility", root, null, GLTFState.new())

	assert_true(mesh.get_layer_mask_value(1))


func test_annotation_targeting_non_visual_node_is_skipped_without_error() -> void:
	var state := _make_state_with_mesh_node("Bone")
	var root := Node3D.new()
	add_child_autofree(root)
	var non_visual := Node3D.new()
	non_visual.name = "Bone"
	root.add_child(non_visual)

	var fp := Vrm1FirstPerson.new()
	fp.mesh_annotations = [_make_annotation(0, "thirdPersonOnly")]

	_ext.call("_apply_first_person_visibility", root, fp, state)

	assert_true(non_visual.get("layers") == null, "Node3D has no 'layers' property - this just confirms the call didn't crash")
