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


# ---------------------------------------------------------------------------
# find_leaf_bones
# VRM0 spring bones only name a chain's root; the whole subtree beneath it sways, so the
# simulator needs every root-to-leaf path enumerated explicitly (Godot's native
# SpringBoneSimulator3D has no "simulate this whole subtree" mode, only linear chains).
# ---------------------------------------------------------------------------

func _linear_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var root_idx := skeleton.add_bone("Root")
	var mid_idx := skeleton.add_bone("Mid")
	skeleton.set_bone_parent(mid_idx, root_idx)
	var tip_idx := skeleton.add_bone("Tip")
	skeleton.set_bone_parent(tip_idx, mid_idx)
	return skeleton


func test_find_leaf_bones_linear_chain_returns_single_leaf() -> void:
	var skeleton := _linear_skeleton()
	autofree(skeleton)

	var leaves: PackedInt32Array = VrmSceneComposer.find_leaf_bones(skeleton, skeleton.find_bone("Root"))

	assert_eq(leaves, PackedInt32Array([skeleton.find_bone("Tip")]))


func test_find_leaf_bones_root_with_no_children_returns_itself() -> void:
	var skeleton := Skeleton3D.new()
	autofree(skeleton)
	var root_idx := skeleton.add_bone("Root")

	var leaves: PackedInt32Array = VrmSceneComposer.find_leaf_bones(skeleton, root_idx)

	assert_eq(leaves, PackedInt32Array([root_idx]))


func test_find_leaf_bones_branching_hierarchy_returns_every_leaf() -> void:
	var skeleton := Skeleton3D.new()
	autofree(skeleton)
	var root_idx := skeleton.add_bone("Root")
	var strand_a_idx := skeleton.add_bone("StrandA")
	skeleton.set_bone_parent(strand_a_idx, root_idx)
	var strand_b_idx := skeleton.add_bone("StrandB")
	skeleton.set_bone_parent(strand_b_idx, root_idx)

	var leaves: PackedInt32Array = VrmSceneComposer.find_leaf_bones(skeleton, root_idx)

	assert_eq(leaves.size(), 2)
	assert_true(strand_a_idx in leaves)
	assert_true(strand_b_idx in leaves)


# ---------------------------------------------------------------------------
# build_spring_bone_collision
# ---------------------------------------------------------------------------

func test_build_spring_bone_collision_sphere() -> void:
	var node: SpringBoneCollision3D = VrmSceneComposer.build_spring_bone_collision(
			"sphere", "Head", Vector3(0.1, 0.2, 0.3), 0.5
	)
	autofree(node)

	assert_true(node is SpringBoneCollisionSphere3D)
	assert_eq(node.bone_name, "Head")
	assert_eq(node.position_offset, Vector3(0.1, 0.2, 0.3))
	assert_almost_eq(node.radius, 0.5, 0.0001)


func test_build_spring_bone_collision_sphere_inside_flag() -> void:
	var node: SpringBoneCollisionSphere3D = VrmSceneComposer.build_spring_bone_collision(
			"sphere", "Head", Vector3.ZERO, 0.5, Vector3.ZERO, Vector3.UP, true
	)
	autofree(node)

	assert_true(node.inside)


## Godot's capsule is centered at position_offset and extends along local +Y for `height`;
## VRM's capsule is defined by two end-point offsets (offset/tail). Verify the conversion:
## position_offset is the midpoint, height covers the full offset-to-tail span plus both
## end caps, and rotation_offset aims local +Y at the offset->tail direction.
func test_build_spring_bone_collision_capsule_geometry() -> void:
	var offset := Vector3(0, 0, 0)
	var tail := Vector3(0, 1, 0)  # tail directly above offset, i.e. already along +Y
	var radius := 0.2
	var node: SpringBoneCollisionCapsule3D = VrmSceneComposer.build_spring_bone_collision(
			"capsule", "Head", offset, radius, tail
	)
	autofree(node)

	assert_true(node is SpringBoneCollisionCapsule3D)
	assert_eq(node.position_offset, Vector3(0, 0.5, 0), "position_offset should be the offset/tail midpoint")
	assert_almost_eq(node.height, 1.0 + radius * 2.0, 0.0001, "height should span offset-to-tail distance plus both hemisphere caps")
	assert_almost_eq(node.radius, radius, 0.0001)
	assert_eq_relative_rotation(node.rotation_offset, Quaternion.IDENTITY, "offset->tail already points along +Y, so no rotation should be needed")


func test_build_spring_bone_collision_capsule_aims_rotation_at_sideways_tail() -> void:
	var offset := Vector3(0, 0, 0)
	var tail := Vector3(1, 0, 0)  # tail sideways along +X, perpendicular to Godot's default +Y
	var node: SpringBoneCollisionCapsule3D = VrmSceneComposer.build_spring_bone_collision(
			"capsule", "Head", offset, 0.1, tail
	)
	autofree(node)

	var rotated_up: Vector3 = node.rotation_offset * Vector3.UP
	assert_almost_eq(rotated_up.x, 1.0, 0.0001, "local +Y rotated by rotation_offset should point along the offset->tail direction")
	assert_almost_eq(rotated_up.y, 0.0, 0.0001)
	assert_almost_eq(rotated_up.z, 0.0, 0.0001)


func test_build_spring_bone_collision_capsule_degenerate_zero_length_falls_back_to_sphere_like_height() -> void:
	var node: SpringBoneCollisionCapsule3D = VrmSceneComposer.build_spring_bone_collision(
			"capsule", "Head", Vector3.ZERO, 0.3, Vector3.ZERO
	)
	autofree(node)

	assert_almost_eq(node.height, 0.6, 0.0001, "a zero-length offset->tail should collapse to a sphere-equivalent capsule (height = 2*radius)")


## The plane collider's normal is always local +Y in Godot's convention; verify
## rotation_offset aims that at the VRM-authored normal.
func test_build_spring_bone_collision_plane_aims_normal() -> void:
	var node: SpringBoneCollisionPlane3D = VrmSceneComposer.build_spring_bone_collision(
			"plane", "Head", Vector3(0, 0.1, 0), 0.0, Vector3.ZERO, Vector3(0, 0, 1)
	)
	autofree(node)

	assert_true(node is SpringBoneCollisionPlane3D)
	assert_eq(node.position_offset, Vector3(0, 0.1, 0))
	var rotated_up: Vector3 = node.rotation_offset * Vector3.UP
	assert_almost_eq(rotated_up.z, 1.0, 0.0001, "local +Y rotated by rotation_offset should point along the authored normal")


# ---------------------------------------------------------------------------
# resolve_scene_node
# GLTFState.get_scene_node() only resolves once a real generate_scene() has populated its
# internal cache, so a synthetic GLTFState (no real import) always falls through to the
# name-based find_child - these tests exercise exactly that fallback path.
# ---------------------------------------------------------------------------

func _make_state_with_node(original_name: String) -> GLTFState:
	var gnode := GLTFNode.new()
	gnode.original_name = original_name
	var state := GLTFState.new()
	var nodes: Array[GLTFNode] = [gnode]
	state.nodes = nodes
	return state


func test_resolve_scene_node_finds_by_name_fallback() -> void:
	var state := _make_state_with_node("Foo")
	var root := Node3D.new()
	add_child_autofree(root)
	var foo := Node3D.new()
	foo.name = "Foo"
	root.add_child(foo)

	var found: Node = VrmSceneComposer.resolve_scene_node(state, root, 0)

	assert_eq(found, foo)


func test_resolve_scene_node_handles_dot_to_underscore_sanitization() -> void:
	var state := _make_state_with_node("Foo.Bar")
	var root := Node3D.new()
	add_child_autofree(root)
	var sanitized := Node3D.new()
	sanitized.name = "Foo_Bar"  # Godot's own node-name sanitization replaces "." with "_"
	root.add_child(sanitized)

	var found: Node = VrmSceneComposer.resolve_scene_node(state, root, 0)

	assert_eq(found, sanitized)


func test_resolve_scene_node_returns_null_for_out_of_range_index() -> void:
	var state := _make_state_with_node("Foo")
	var root := Node3D.new()
	add_child_autofree(root)

	assert_null(VrmSceneComposer.resolve_scene_node(state, root, 5))
	assert_null(VrmSceneComposer.resolve_scene_node(state, root, -1))


func test_resolve_scene_node_returns_null_when_no_matching_child() -> void:
	var state := _make_state_with_node("DoesNotExist")
	var root := Node3D.new()
	add_child_autofree(root)

	assert_null(VrmSceneComposer.resolve_scene_node(state, root, 0))


# ---------------------------------------------------------------------------
# validate_required_humanoid_bones
# ---------------------------------------------------------------------------

func test_validate_required_humanoid_bones_returns_empty_when_all_present() -> void:
	var human_bone_map: Dictionary = {"hips": "Hips", "head": "Head"}
	var required: PackedStringArray = PackedStringArray(["hips", "head"])

	var missing: PackedStringArray = VrmSceneComposer.validate_required_humanoid_bones("Test", human_bone_map, required)

	assert_eq(missing, PackedStringArray())


func test_validate_required_humanoid_bones_lists_missing_roles() -> void:
	var human_bone_map: Dictionary = {"hips": "Hips"}
	var required: PackedStringArray = PackedStringArray(["hips", "head", "leftUpperArm"])

	var missing: PackedStringArray = VrmSceneComposer.validate_required_humanoid_bones("Test", human_bone_map, required)

	assert_eq(missing, PackedStringArray(["head", "leftUpperArm"]))


func test_validate_required_humanoid_bones_is_case_insensitive_against_the_map() -> void:
	# human_bone_map is keyed by role.to_lower() (the convention both extensions use); the
	# required-role list itself is written in camelCase to match spec spelling, so the
	# comparison must lower it too rather than expecting the map's exact casing.
	var human_bone_map: Dictionary = {"leftupperarm": "UpperArm.L"}
	var required: PackedStringArray = PackedStringArray(["leftUpperArm"])

	var missing: PackedStringArray = VrmSceneComposer.validate_required_humanoid_bones("Test", human_bone_map, required)

	assert_eq(missing, PackedStringArray())


func test_validate_required_humanoid_bones_empty_map_reports_everything_missing() -> void:
	var required: PackedStringArray = PackedStringArray(["hips", "head"])

	var missing: PackedStringArray = VrmSceneComposer.validate_required_humanoid_bones("Test", {}, required)

	assert_eq(missing, required)


# ---------------------------------------------------------------------------
# validate_humanoid_bone_scales
# ---------------------------------------------------------------------------

func _skeleton_with_bone(bone_name: String, basis: Basis) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var idx := skeleton.add_bone(bone_name)
	skeleton.set_bone_rest(idx, Transform3D(basis, Vector3.ZERO))
	return skeleton


func test_validate_humanoid_bone_scales_passes_uniform_positive_scale() -> void:
	var skeleton := _skeleton_with_bone("Hips", Basis.IDENTITY.scaled(Vector3(1, 1, 1)))
	autofree(skeleton)
	var human_bone_map: Dictionary = {"hips": "Hips"}

	var offending: PackedStringArray = VrmSceneComposer.validate_humanoid_bone_scales("Test", skeleton, human_bone_map)

	assert_eq(offending, PackedStringArray())


func test_validate_humanoid_bone_scales_flags_non_uniform_scale() -> void:
	var skeleton := _skeleton_with_bone("Hips", Basis.IDENTITY.scaled(Vector3(1, 2, 1)))
	autofree(skeleton)
	var human_bone_map: Dictionary = {"hips": "Hips"}

	var offending: PackedStringArray = VrmSceneComposer.validate_humanoid_bone_scales("Test", skeleton, human_bone_map)

	assert_eq(offending, PackedStringArray(["Hips"]))


func test_validate_humanoid_bone_scales_flags_non_positive_scale() -> void:
	var skeleton := _skeleton_with_bone("Hips", Basis.IDENTITY.scaled(Vector3(-1, -1, -1)))
	autofree(skeleton)
	var human_bone_map: Dictionary = {"hips": "Hips"}

	var offending: PackedStringArray = VrmSceneComposer.validate_humanoid_bone_scales("Test", skeleton, human_bone_map)

	assert_eq(offending, PackedStringArray(["Hips"]))


func test_validate_humanoid_bone_scales_skips_unresolved_bone_names() -> void:
	var skeleton := _skeleton_with_bone("Hips", Basis.IDENTITY)
	autofree(skeleton)
	var human_bone_map: Dictionary = {"hips": "Hips", "head": "DoesNotExist"}

	var offending: PackedStringArray = VrmSceneComposer.validate_humanoid_bone_scales("Test", skeleton, human_bone_map)

	assert_eq(offending, PackedStringArray())


func test_validate_humanoid_bone_scales_returns_empty_for_null_skeleton() -> void:
	var offending: PackedStringArray = VrmSceneComposer.validate_humanoid_bone_scales("Test", null, {"hips": "Hips"})

	assert_eq(offending, PackedStringArray())


# ---------------------------------------------------------------------------
# resolve_image_index
# ---------------------------------------------------------------------------

func _state_with_images(count: int) -> GLTFState:
	var state := GLTFState.new()
	var images: Array[Texture2D] = []
	for i in range(count):
		var img := PlaceholderTexture2D.new()
		img.size = Vector2(4, 4)
		images.append(img)
	state.images = images
	return state


func test_resolve_image_index_returns_the_image_at_that_index() -> void:
	var state := _state_with_images(3)
	var images: Array[Texture2D] = state.get_images()

	var resolved: Texture2D = VrmSceneComposer.resolve_image_index(1, state)

	assert_eq(resolved, images[1])


func test_resolve_image_index_returns_null_for_unset_index() -> void:
	var state := _state_with_images(3)

	assert_null(VrmSceneComposer.resolve_image_index(-1, state))


func test_resolve_image_index_returns_null_for_out_of_range_index() -> void:
	var state := _state_with_images(2)

	assert_null(VrmSceneComposer.resolve_image_index(5, state))
