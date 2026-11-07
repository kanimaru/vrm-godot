extends GutTest

## Unit tests for VrmMaterialVariantController - the runtime switcher for glTF's
## KHR_materials_variants extension, which Godot's built-in glTF importer has no native
## support for.

const VrmMaterialVariantMapping = preload("res://addons/vrm/common/vrm_material_variant_mapping.gd")


func _make_mesh_instance() -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_inst.mesh = array_mesh
	return mesh_inst


## The mesh must already be a child of the root the controller will sit under.
func _make_mapping(mesh_inst: MeshInstance3D, surface: int, variant_materials: Dictionary) -> VrmMaterialVariantMapping:
	var mapping := VrmMaterialVariantMapping.new()
	mapping.mesh_path = NodePath("../" + String(mesh_inst.name))
	mapping.surface = surface
	for k: int in variant_materials:
		mapping.variant_materials[k] = variant_materials[k]
	return mapping


func test_get_variant_names_returns_configured_names() -> void:
	var controller := VrmMaterialVariantController.new()
	autofree(controller)
	controller.variant_names = ["Default", "Winter"]

	assert_eq(controller.get_variant_names(), (["Default", "Winter"] as Array[String]))


func test_set_variant_applies_mapped_material_to_the_surface() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh_inst := _make_mesh_instance()
	root.add_child(mesh_inst)

	var target_mat := StandardMaterial3D.new()
	var controller := VrmMaterialVariantController.new()
	root.add_child(controller)
	controller.variant_names = ["Default", "Winter"]
	controller.mappings = [_make_mapping(mesh_inst, 0, {1: target_mat})]

	controller.set_variant(1)

	assert_eq(mesh_inst.get_surface_override_material(0), target_mat)
	assert_eq(controller.get_current_variant(), 1)


func test_set_variant_leaves_unmapped_surfaces_untouched() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh_inst := _make_mesh_instance()
	root.add_child(mesh_inst)
	var original_override := StandardMaterial3D.new()
	mesh_inst.set_surface_override_material(0, original_override)

	var controller := VrmMaterialVariantController.new()
	root.add_child(controller)
	controller.variant_names = ["Default", "Winter"]
	# This mapping only covers variant 0, not variant 1.
	controller.mappings = [_make_mapping(mesh_inst, 0, {0: StandardMaterial3D.new()})]

	controller.set_variant(1)

	assert_eq(mesh_inst.get_surface_override_material(0), original_override, "a surface with no mapping for the selected variant should keep its current material")


func test_set_variant_out_of_range_is_a_no_op() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh_inst := _make_mesh_instance()
	root.add_child(mesh_inst)
	var original_override := StandardMaterial3D.new()
	mesh_inst.set_surface_override_material(0, original_override)

	var controller := VrmMaterialVariantController.new()
	root.add_child(controller)
	controller.variant_names = ["Default"]
	controller.mappings = [_make_mapping(mesh_inst, 0, {0: StandardMaterial3D.new()})]

	controller.set_variant(5)

	assert_eq(mesh_inst.get_surface_override_material(0), original_override)
	assert_eq(controller.get_current_variant(), -1, "an out-of-range call should not update the current-variant state either")


func test_set_variant_by_name_resolves_index_and_applies() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh_inst := _make_mesh_instance()
	root.add_child(mesh_inst)

	var target_mat := StandardMaterial3D.new()
	var controller := VrmMaterialVariantController.new()
	root.add_child(controller)
	controller.variant_names = ["Default", "Winter"]
	controller.mappings = [_make_mapping(mesh_inst, 0, {1: target_mat})]

	var found: bool = controller.set_variant_by_name("Winter")

	assert_true(found)
	assert_eq(mesh_inst.get_surface_override_material(0), target_mat)
	assert_eq(controller.get_current_variant(), 1)


func test_set_variant_by_name_returns_false_for_unknown_name() -> void:
	var controller := VrmMaterialVariantController.new()
	autofree(controller)
	controller.variant_names = ["Default"]

	var found: bool = controller.set_variant_by_name("DoesNotExist")

	assert_false(found)
	assert_eq(controller.get_current_variant(), -1)


func test_multiple_mapped_surfaces_all_switch_together() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh_a := _make_mesh_instance()
	var mesh_b := _make_mesh_instance()
	root.add_child(mesh_a)
	root.add_child(mesh_b)

	var target_a := StandardMaterial3D.new()
	var target_b := StandardMaterial3D.new()
	var controller := VrmMaterialVariantController.new()
	root.add_child(controller)
	controller.variant_names = ["Default", "Winter"]
	controller.mappings = [
		_make_mapping(mesh_a, 0, {1: target_a}),
		_make_mapping(mesh_b, 0, {1: target_b}),
	]

	controller.set_variant(1)

	assert_eq(mesh_a.get_surface_override_material(0), target_a)
	assert_eq(mesh_b.get_surface_override_material(0), target_b)


## The editor importer saves the avatar scene after the controller is attached. Its
## names and mappings used to be plain vars on RefCounted values holding a node
## reference, so an imported avatar came back with a controller that knew no variants.
func test_variants_survive_packing_the_scene() -> void:
	var root := Node3D.new()
	autofree(root)
	var mesh_inst := _make_mesh_instance()
	mesh_inst.name = "Outfit"
	root.add_child(mesh_inst)
	mesh_inst.owner = root

	var target_mat := StandardMaterial3D.new()
	target_mat.resource_name = "Outfit_Winter"
	var controller := VrmMaterialVariantController.new()
	controller.name = "VrmMaterialVariantController"
	root.add_child(controller)
	controller.owner = root
	controller.variant_names = ["Default", "Winter"]
	controller.mappings = [_make_mapping(mesh_inst, 0, {1: target_mat})]

	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	var copy: Node3D = packed.instantiate()
	add_child_autofree(copy)
	var copy_controller: VrmMaterialVariantController = copy.get_node("VrmMaterialVariantController")
	var copy_mesh: MeshInstance3D = copy.get_node("Outfit")

	assert_eq(copy_controller.get_variant_names(), (["Default", "Winter"] as Array[String]),
		"variant names must be stored with the scene")
	assert_true(copy_controller.set_variant_by_name("Winter"))
	var applied: Material = copy_mesh.get_surface_override_material(0)
	assert_not_null(applied, "the stored mapping must reach the instanced mesh")
	if applied != null:
		assert_eq(applied.resource_name, "Outfit_Winter")


func test_a_mapping_whose_mesh_is_gone_is_skipped() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mapping := VrmMaterialVariantMapping.new()
	mapping.mesh_path = NodePath("../Missing")
	mapping.surface = 0
	mapping.variant_materials[1] = StandardMaterial3D.new()
	var controller := VrmMaterialVariantController.new()
	root.add_child(controller)
	controller.variant_names = ["Default", "Winter"]
	controller.mappings = [mapping]

	controller.set_variant(1)

	assert_eq(controller.get_current_variant(), 1, "the other mappings still switch")
