extends GutTest

## Compiled expression binds are made at import time from GLTFState (glTF node
## index -> scene node) and cannot be rebuilt by an instantiated scene, which has
## no GLTFState. So they must travel WITH the scene. Before this was fixed the
## Runtime* bind classes were RefCounted in a non-exported var: PackedScene.pack()
## dropped them, every avatar instantiated from an editor-imported .vrm came up
## with `expressions == []`, and Node.duplicate() (used for animation ghost rigs)
## produced controllers with no binds either. These tests pin both boundaries.

const BODY_PATH := NodePath("../Body")
const SMILE_INDEX := 0


func _mesh_with_blend_shape() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_blend_shape("smile")

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])

	var smile: Array = []
	smile.resize(Mesh.ARRAY_MAX)
	smile[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP * 2.0])

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [smile])
	return mesh


## A minimal avatar: root, controller, one mesh with one blend shape, one bind.
## Owners are set so PackedScene.pack() includes every node.
func _build_avatar() -> Node3D:
	var root := Node3D.new()
	root.name = "Avatar"

	var controller := Vrm1ExpressionController.new()
	controller.name = "Vrm1ExpressionController"
	root.add_child(controller)
	controller.owner = root

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh_with_blend_shape()
	root.add_child(body)
	body.owner = root

	var bind := RuntimeMorphBind.new()
	bind.path = BODY_PATH
	bind.index = SMILE_INDEX
	bind.weight = 1.0

	var expression := RuntimeExpression.new()
	expression.morph_binds.append(bind)
	controller._binds["happy"] = expression

	return root


func _assert_happy_drives_body(avatar: Node3D, context: String) -> void:
	var controller: Vrm1ExpressionController = avatar.get_node("Vrm1ExpressionController")
	assert_eq(controller.expressions, ["happy"], context + ": the compiled bind should be present")

	var bind: RuntimeMorphBind = controller._binds["happy"].morph_binds[0]
	assert_eq(bind.path, BODY_PATH, context + ": the bind path should be intact")
	assert_eq(bind.index, SMILE_INDEX, context + ": the bind index should be intact")

	controller.set_expression("happy", 1.0)
	controller._apply_expressions()
	var body: MeshInstance3D = avatar.get_node("Body")
	assert_almost_eq(body.get_blend_shape_value(SMILE_INDEX), 1.0, 0.01, context + ": the bind should actually move the mesh")


func test_binds_survive_packed_scene_round_trip() -> void:
	var original := _build_avatar()
	autofree(original)

	var packed := PackedScene.new()
	assert_eq(packed.pack(original), OK, "the avatar should pack")

	var restored: Node3D = packed.instantiate()
	add_child_autofree(restored)
	_assert_happy_drives_body(restored, "after pack/instantiate")


func test_binds_survive_node_duplicate() -> void:
	var original := _build_avatar()
	add_child_autofree(original)

	var ghost: Node3D = original.duplicate()
	add_child_autofree(ghost)
	_assert_happy_drives_body(ghost, "after duplicate")


## The real thing, when the licensed asset is present locally: import, pack,
## instantiate, and expect the full expression set - not the empty list.
func test_imported_luna_keeps_every_expression_through_pack() -> void:
	var path := "res://assets/luna/luna.vrm"
	if not FileAccess.file_exists(path):
		pending("Luna VRM is a licensed asset kept locally only (gitignored) - not present here")
		return

	GLTFDocument.register_gltf_document_extension(load("res://addons/vrm/vrm1/vrm1_extension.gd").new())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert_eq(doc.append_from_file(path, state), OK)
	var imported: Node = doc.generate_scene(state)
	autofree(imported)

	var before: Array[String] = imported.get_node("Vrm1ExpressionController").expressions
	assert_gt(before.size(), 0, "the import itself should compile binds")

	var packed := PackedScene.new()
	assert_eq(packed.pack(imported), OK)
	var restored: Node = packed.instantiate()
	add_child_autofree(restored)

	var after: Array[String] = restored.get_node("Vrm1ExpressionController").expressions
	assert_eq(after.size(), before.size(), "every compiled expression should survive serialization")