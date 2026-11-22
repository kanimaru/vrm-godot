extends GutTest

## Regression coverage for the import-time use-after-free on GLTFState.get_scene_node().
##
## Outside the editor Godot registers GLTFDocumentExtensionConvertImporterMesh before any
## script extension. Its import_post swaps every ImporterMeshInstance3D for a new
## MeshInstance3D and frees the old node, but leaves GLTFState's scene_nodes pointing at it.
## The VRM extensions' _import_post ran later and resolved expression binds through
## get_scene_node(): null when the freed memory was untouched (the name fallback then
## worked), another object when it was reused - and the bind was silently dropped
## (luna.vrm lost browOuterUp*/eyeLook* in some runs). Heap reuse is random, so these tests
## do not wait for it to happen: they assert that every bind lands on the node named after
## its glTF node, and that the import-time tags the fix relies on survive the conversion.
## (Against the old code the VRM 0.x test still failed about 3 runs in 10, its joy bind
## landing on Vrm0SpringBoneSimulator.)
##
## The committed tester avatars have no morph binds, so the tests patch one onto them in
## memory (a morph target on the Cube mesh plus a happy/joy bind) before importing.

const VrmSceneComposer = preload("res://addons/vrm/common/vrm_scene_composer.gd")

const VRM1_PATH := "res://assets/tester/tester-vrm1.0.vrm"
const VRM0_PATH := "res://assets/tester/tester-vrm0.0.vrm"
const LUNA_PATH := "res://assets/private/luna/luna.vrm"
const GLB_MAGIC := 0x46546c67
const GLB_CHUNK_JSON := 0x4e4f534a
const GLB_CHUNK_BIN := 0x004e4942

var _extensions: Array[GLTFDocumentExtension] = []


func before_all() -> void:
	# Default priority: after Godot's own mesh converter, which is the order that broke.
	_extensions = [
		load("res://addons/vrm/vrm0/vrm0_extension.gd").new(),
		load("res://addons/vrm/vrm1/vrm1_extension.gd").new(),
	]
	for extension: GLTFDocumentExtension in _extensions:
		GLTFDocument.register_gltf_document_extension(extension)


func after_all() -> void:
	for extension: GLTFDocumentExtension in _extensions:
		GLTFDocument.unregister_gltf_document_extension(extension)
	_extensions.clear()


func test_vrm1_expression_binds_target_their_gltf_node_after_runtime_import() -> void:
	var state := GLTFState.new()
	var root: Node = _import_buffer(_with_vrm1_morph_bind(_read_glb(VRM1_PATH)), state)
	assert_not_null(root, "the patched tester VRM 1.0 should import")
	if root == null:
		return

	var checked: int = _assert_vrm1_binds_hit_their_nodes(state, root)
	assert_eq(checked, 1, "the patched happy bind should compile")


func test_vrm0_expression_binds_target_their_gltf_node_after_runtime_import() -> void:
	var state := GLTFState.new()
	var root: Node = _import_buffer(_with_vrm0_morph_bind(_read_glb(VRM0_PATH)), state)
	assert_not_null(root, "the patched tester VRM 0.x should import")
	if root == null:
		return

	var controller: Vrm0ExpressionController = root.get_node_or_null(
			"Vrm0ExpressionController")
	assert_not_null(controller, "Vrm0ExpressionController should be attached")
	if controller == null:
		return
	assert_true(controller._binds.has("joy"), "the patched joy bind should compile")
	if not controller._binds.has("joy"):
		return
	var morph_binds: Array = controller._binds["joy"].morph_binds
	assert_eq(morph_binds.size(), 1, "joy should have its one morph bind")
	for bind: Variant in morph_binds:
		var target: Node = controller.get_node_or_null(bind.path)
		assert_true(target is MeshInstance3D, "the joy bind should target the converted mesh")
		if target != null:
			assert_eq(String(target.name), "Cube", "the joy bind should target node Cube")


## The fix rests on Godot copying node metadata from the freed ImporterMeshInstance3D onto
## its MeshInstance3D replacement (GLTFDocumentExtensionConvertImporterMesh::_copy_meta).
## If a Godot update drops that, this fails instead of binds quietly vanishing again. The
## tags are stripped before generate_scene returns, so a probe extension registered after
## the converter reads them from inside the import, as a tag reader like the VRM ones.
func test_import_tags_survive_the_runtime_mesh_conversion() -> void:
	var probe := TagProbe.new()
	GLTFDocument.register_gltf_document_extension(probe)
	var state := GLTFState.new()
	var root: Node = _import_buffer(FileAccess.get_file_as_bytes(VRM1_PATH), state)
	GLTFDocument.unregister_gltf_document_extension(probe)
	assert_not_null(root, "the tester VRM 1.0 should import")
	if root == null:
		return

	var scene_nodes: Dictionary = state.get_additional_data(TagProbe.SCENE_NODES_KEY)
	var gltf_nodes: Array[GLTFNode] = state.get_nodes()
	assert_eq(scene_nodes.size(), gltf_nodes.size(), "every glTF node should be tagged")
	for i: int in range(gltf_nodes.size()):
		var node: Node = scene_nodes.get(i)
		assert_not_null(node, "glTF node %d should resolve" % i)
		if node == null:
			continue
		if gltf_nodes[i].mesh >= 0:
			assert_true(node is MeshInstance3D,
					"glTF node %d should resolve to the converted MeshInstance3D" % i)
		if node is Skeleton3D:
			var bone_name: String = VrmSceneComposer.resolve_node_name(gltf_nodes[i])
			assert_ne((node as Skeleton3D).find_bone(bone_name), -1,
					"joint node %d should resolve to the skeleton that holds it" % i)
		else:
			assert_eq(String(node.name), VrmSceneComposer.resolve_node_name(gltf_nodes[i]),
					"glTF node %d should resolve to the node named after it" % i)
	assert_eq(_tagged_nodes(root), [] as Array[String],
			"the tags should be gone once the last reader released them")


func test_runtime_import_leaves_no_tags() -> void:
	for path: String in [VRM1_PATH, VRM0_PATH]:
		var state := GLTFState.new()
		var root: Node = _import_buffer(FileAccess.get_file_as_bytes(path), state)
		assert_not_null(root, "%s should import" % path)
		if root != null:
			assert_eq(_tagged_nodes(root), [] as Array[String], "%s should keep no tags" % path)


## Stripping must not depend on extension order: a tag reader running before Godot's mesh
## converter and the VRM extensions must neither strip early (binds still resolve) nor
## leave the tags behind.
func test_tags_are_stripped_whatever_the_extension_order() -> void:
	var early_probe := TagProbe.new()
	GLTFDocument.register_gltf_document_extension(early_probe, true)
	var state := GLTFState.new()
	var root: Node = _import_buffer(_with_vrm1_morph_bind(_read_glb(VRM1_PATH)), state)
	GLTFDocument.unregister_gltf_document_extension(early_probe)
	assert_not_null(root, "the patched tester VRM 1.0 should import")
	if root == null:
		return

	assert_eq(_assert_vrm1_binds_hit_their_nodes(state, root), 1,
			"the happy bind should still compile after an early reader released")
	assert_eq(_tagged_nodes(root), [] as Array[String], "no tags should be left")


## The editor-imported scenes (.godot/imported/*.scn) of the committed tester VRMs.
func test_saved_tester_scenes_keep_no_tags() -> void:
	for path: String in [VRM1_PATH, VRM0_PATH]:
		var packed: PackedScene = load(path)
		assert_not_null(packed, "%s should have an imported scene" % path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		autofree(root)
		assert_eq(_tagged_nodes(root), [] as Array[String], "%s should keep no tags" % path)


## The real case, when the licensed asset is present locally.
func test_luna_expression_binds_target_their_gltf_node_after_runtime_import() -> void:
	if not FileAccess.file_exists(LUNA_PATH):
		pending("Luna VRM is a licensed asset kept in the local assets/private repo - not present here")
		return
	var state := GLTFState.new()
	var root: Node = _import_buffer(FileAccess.get_file_as_bytes(LUNA_PATH), state)
	assert_not_null(root, "luna should import")
	if root == null:
		return
	var checked: int = _assert_vrm1_binds_hit_their_nodes(state, root)
	assert_gt(checked, 0, "luna should compile morph binds")


## Checks every VRM 1.0 morph bind against the glTF node it names; returns how many it saw.
func _assert_vrm1_binds_hit_their_nodes(state: GLTFState, root: Node) -> int:
	var controller: Vrm1ExpressionController = root.get_node_or_null(
			"Vrm1ExpressionController")
	assert_not_null(controller, "Vrm1ExpressionController should be attached")
	if controller == null:
		return 0

	var vrm: Vrm1TopLevel = state.get_additional_data("vrm1") as Vrm1TopLevel
	var gltf_nodes: Array[GLTFNode] = state.get_nodes()
	var expressions: Dictionary = {}
	expressions.merge(vrm.expressions.preset)
	expressions.merge(vrm.expressions.custom)
	var checked: int = 0
	for expr_name: String in expressions:
		var expr: Vrm1ExpressionData = expressions[expr_name]
		var expected: Array[String] = []
		for morph_bind: Vrm1ExpressionMorphBind in expr.morph_binds:
			if morph_bind.node >= 0 and morph_bind.node < gltf_nodes.size():
				expected.append(VrmSceneComposer.resolve_node_name(gltf_nodes[morph_bind.node]))
		if expected.is_empty():
			continue

		assert_true(controller._binds.has(expr_name), "%s should compile" % expr_name)
		if not controller._binds.has(expr_name):
			continue
		var compiled: Array = controller._binds[expr_name].morph_binds
		assert_eq(compiled.size(), expected.size(),
				"%s should keep every morph bind" % expr_name)
		for i: int in range(mini(compiled.size(), expected.size())):
			var target: Node = controller.get_node_or_null(compiled[i].path)
			assert_true(target is MeshInstance3D,
					"%s bind %d should target a MeshInstance3D" % [expr_name, i])
			if target != null:
				assert_eq(String(target.name).replace("_", "."), expected[i].replace("_", "."),
						"%s bind %d should target its glTF node" % [expr_name, i])
			checked += 1
	return checked


func _tagged_nodes(root: Node) -> Array[String]:
	var tagged: Array[String] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.has_meta(VrmSceneComposer.GLTF_NODE_INDICES_META):
			tagged.append(String(node.name))
		pending.append_array(node.get_children(true))
	return tagged


func _import_buffer(bytes: PackedByteArray, state: GLTFState) -> Node:
	var doc := GLTFDocument.new()
	if doc.append_from_buffer(bytes, "res://assets/tester/", state) != OK:
		return null
	var root: Node = doc.generate_scene(state)
	if root != null:
		autofree(root)
	return root


func _read_glb(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert_eq(bytes.decode_u32(0), GLB_MAGIC, "%s should be a GLB" % path)
	var json_length: int = bytes.decode_u32(12)
	var json_text: String = bytes.slice(20, 20 + json_length).get_string_from_utf8()
	var bin_offset: int = 20 + json_length
	var bin_length: int = bytes.decode_u32(bin_offset)
	return {
		"json": JSON.parse_string(json_text),
		"bin": bytes.slice(bin_offset + 8, bin_offset + 8 + bin_length),
	}


func _write_glb(glb: Dictionary) -> PackedByteArray:
	var json_bytes: PackedByteArray = JSON.stringify(glb["json"]).to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)
	var bin: PackedByteArray = glb["bin"]
	var out := PackedByteArray()
	out.resize(12)
	out.encode_u32(0, GLB_MAGIC)
	out.encode_u32(4, 2)
	out.encode_u32(8, 12 + 8 + json_bytes.size() + 8 + bin.size())
	out.append_array(_chunk_header(json_bytes.size(), GLB_CHUNK_JSON))
	out.append_array(json_bytes)
	out.append_array(_chunk_header(bin.size(), GLB_CHUNK_BIN))
	out.append_array(bin)
	return out


func _chunk_header(length: int, type: int) -> PackedByteArray:
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u32(0, length)
	header.encode_u32(4, type)
	return header


## Gives the tester's only mesh one morph target (its normals reused as POSITION deltas) and
## returns the index of the node that instances it.
func _add_morph_target(json: Dictionary) -> int:
	var mesh: Dictionary = json["meshes"][0]
	for primitive: Dictionary in mesh["primitives"]:
		primitive["targets"] = [{ "POSITION": primitive["attributes"]["NORMAL"] }]
	mesh["extras"] = { "targetNames": ["Smile"] }
	var nodes: Array = json["nodes"]
	for i: int in range(nodes.size()):
		if int(nodes[i].get("mesh", -1)) == 0:
			return i
	return -1


func _with_vrm1_morph_bind(glb: Dictionary) -> PackedByteArray:
	var json: Dictionary = glb["json"]
	var node_index: int = _add_morph_target(json)
	var happy: Dictionary = json["extensions"]["VRMC_vrm"]["expressions"]["preset"]["happy"]
	happy["morphTargetBinds"] = [{ "node": node_index, "index": 0, "weight": 1.0 }]
	return _write_glb(glb)


func _with_vrm0_morph_bind(glb: Dictionary) -> PackedByteArray:
	var json: Dictionary = glb["json"]
	_add_morph_target(json)
	for group: Dictionary in json["extensions"]["VRM"]["blendShapeMaster"]["blendShapeGroups"]:
		if group["presetName"] == "joy":
			group["binds"] = [{ "mesh": 0, "index": 0, "weight": 100.0 }]
	return _write_glb(glb)


## Tags like the VRM extensions do and reads the tags in its own _import_post. GLTFDocument
## runs its own instance of each registered extension, so the result goes on the state.
class TagProbe:
	extends GLTFDocumentExtension

	const SCENE_NODES_KEY: StringName = &"tag_probe_scene_nodes"

	func _import_node(
			state: GLTFState,
			gltf_node: GLTFNode,
			_json: Dictionary,
			node: Node,
	) -> Error:
		VrmSceneComposer.tag_scene_node(state, gltf_node, node, self)
		return OK

	func _import_post(state: GLTFState, root: Node) -> Error:
		state.set_additional_data(SCENE_NODES_KEY, VrmSceneComposer.collect_scene_nodes(root))
		VrmSceneComposer.release_scene_node_tags(state, root, self)
		return OK
