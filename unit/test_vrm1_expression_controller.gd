extends GutTest

## End-to-end regression coverage for Vrm1ExpressionController's material color bind
## resolution. VrmSceneComposer.apply_mtoon_materials swaps a new MToon ShaderMaterial
## into the scene tree but never updates gltf_state.materials, so binds must resolve
## their target by walking the live scene tree (VrmSceneComposer.find_material_by_name)
## to land on the material that's actually rendering - using its real shader uniform
## name, not a stale pre-swap material or a Godot-native property name that doesn't
## exist on the shader.

func test_rim_color_bind_applies_to_real_mtoon_shader_uniform() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var controller := Vrm1ExpressionController.new()
	root.add_child(controller)

	var mesh_inst := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_inst.mesh = array_mesh
	root.add_child(mesh_inst)

	# Simulate the post-MToon-swap scene: the live mesh already has the real MToon
	# ShaderMaterial, but gltf_state.materials still holds a totally separate, unparented
	# placeholder - exactly the disconnect apply_mtoon_materials leaves behind.
	var VrmMtoonBuilder = load("res://addons/vrm/common/vrm_mtoon_builder.gd")
	var shader_mat: ShaderMaterial = VrmMtoonBuilder.build_body({})
	shader_mat.resource_name = "TestMat"
	mesh_inst.set_surface_override_material(0, shader_mat)

	var placeholder := StandardMaterial3D.new()
	placeholder.resource_name = "TestMat"
	var state := GLTFState.new()
	var materials: Array[Material] = [placeholder]
	state.materials = materials

	var cb := Vrm1ExpressionMaterialColorBind.new()
	cb.material = 0
	cb.type = "rimColor"
	cb.target_value = PackedFloat32Array([1.0, 0.0, 0.0, 1.0])

	var expr_data := Vrm1ExpressionData.new()
	expr_data.material_color_binds.append(cb)

	var expressions := Vrm1Expressions.new()
	expressions.preset["happy"] = expr_data

	controller.compile_vrm1_binds(expressions, state, root)
	controller.set_expression("happy", 1.0)
	controller._apply_expressions()

	var applied: Variant = shader_mat.get_shader_parameter("_RimColor")
	assert_eq(typeof(applied), TYPE_COLOR, "the bind should have resolved to the live post-swap ShaderMaterial and written its real _RimColor uniform")
	assert_almost_eq(applied.r, 1.0, 0.01)
