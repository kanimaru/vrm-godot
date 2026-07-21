extends "res://unit/vrm_gut_test.gd"

## Regression coverage for the MToon-swap material identity bug: expression controllers
## resolve their material binds by walking the live scene tree and matching resource_name
## (VrmSceneComposer.find_material_by_name), which only works if apply_mtoon_materials
## actually carries the original glTF material's name forward onto the swapped-in
## ShaderMaterial. Without that, VRM material color/UV binds silently target a material
## object that's no longer part of what's rendered.

const VrmSceneComposer = preload("res://addons/vrm/common/vrm_scene_composer.gd")


func _make_mesh_with_material(mat: Material) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, mat)
	mesh_inst.mesh = array_mesh
	return mesh_inst


# ---------------------------------------------------------------------------
# find_material_by_name
# ---------------------------------------------------------------------------

func test_find_material_by_name_locates_surface_override_material() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var placeholder := StandardMaterial3D.new()
	placeholder.resource_name = "TestMat"
	var mesh_inst := _make_mesh_with_material(placeholder)
	root.add_child(mesh_inst)
	mesh_inst.set_surface_override_material(0, placeholder)

	var found: Material = VrmSceneComposer.find_material_by_name(root, "TestMat")

	assert_eq(found, placeholder)


func test_find_material_by_name_returns_null_for_unknown_name() -> void:
	var root := Node3D.new()
	add_child_autofree(root)

	var found: Material = VrmSceneComposer.find_material_by_name(root, "DoesNotExist")

	assert_null(found)


func test_find_material_by_name_returns_null_for_empty_name() -> void:
	var root := Node3D.new()
	add_child_autofree(root)

	var found: Material = VrmSceneComposer.find_material_by_name(root, "")

	assert_null(found)


# ---------------------------------------------------------------------------
# apply_mtoon_materials — resource_name propagation onto the swapped ShaderMaterial
# ---------------------------------------------------------------------------

func test_apply_mtoon_materials_carries_resource_name_onto_swapped_material() -> void:
	var root := Node3D.new()
	add_child_autofree(root)

	var placeholder := StandardMaterial3D.new()
	placeholder.resource_name = "TestMat"
	var mesh_inst := _make_mesh_with_material(placeholder)
	root.add_child(mesh_inst)

	var state := GLTFState.new()
	var materials: Array[Material] = [placeholder]
	state.materials = materials

	VrmSceneComposer.apply_mtoon_materials(root, [{}], state)

	var swapped: Material = mesh_inst.get_surface_override_material(0)
	assert_true(swapped is ShaderMaterial, "the placeholder should have been swapped for an MToon ShaderMaterial")
	assert_eq(swapped.resource_name, "TestMat", "the swapped material must keep the original glTF material's name so binds can find it by name afterward")

	var found_post_swap: Material = VrmSceneComposer.find_material_by_name(root, "TestMat")
	assert_eq(found_post_swap, swapped, "find_material_by_name must resolve to the live post-swap material, not the placeholder")
