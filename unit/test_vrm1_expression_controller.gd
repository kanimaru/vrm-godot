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


## Binds are compiled inside GLTFDocumentExtension._import_post, where mesh nodes are still
## ImporterMeshInstance3D (the scene importer bakes them into MeshInstance3D afterwards).
## Material lookup used to walk MeshInstance3D only, so at import time every texture
## transform bind (and color bind) silently resolved to nothing: a VRM 1.0 whose custom
## expressions are pure textureTransformBinds (emote atlases) imported with empty uv_binds.
func test_texture_transform_bind_resolves_on_import_time_importer_mesh() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var controller := Vrm1ExpressionController.new()
	root.add_child(controller)

	var importer_mesh := ImporterMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var VrmMtoonBuilder = load("res://addons/vrm/common/vrm_mtoon_builder.gd")
	var shader_mat: ShaderMaterial = VrmMtoonBuilder.build_body({})
	shader_mat.resource_name = "Emote.Atlas"
	importer_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, shader_mat)
	var importer_inst := ImporterMeshInstance3D.new()
	importer_inst.mesh = importer_mesh
	root.add_child(importer_inst)

	var placeholder := StandardMaterial3D.new()
	placeholder.resource_name = "Emote.Atlas"
	var state := GLTFState.new()
	var materials: Array[Material] = [placeholder]
	state.materials = materials

	var tb := Vrm1ExpressionTextureTransformBind.new()
	tb.material = 0
	tb.offset = Vector2(0.25, 0.5)
	var expr_data := Vrm1ExpressionData.new()
	expr_data.is_binary = true
	expr_data.texture_transform_binds.append(tb)
	var expressions := Vrm1Expressions.new()
	expressions.custom["emote1"] = expr_data

	controller.compile_vrm1_binds(expressions, state, root)

	assert_eq(controller._binds["emote1"].uv_binds.size(), 1,
			"the bind should resolve against the ImporterMesh surface material")
	assert_eq(controller._binds["emote1"].uv_binds[0].material, shader_mat)

	controller.set_expression("emote1", 1.0)
	controller._apply_expressions()
	var st: Variant = shader_mat.get_shader_parameter("_MainTex_ST")
	assert_eq(typeof(st), TYPE_VECTOR4, "the bind should write the MToon _MainTex_ST uniform")
	assert_almost_eq(st.z, 0.25, 0.001)
	assert_almost_eq(st.w, 0.5, 0.001)
	assert_almost_eq(st.x, 1.0, 0.001)


## A bind whose material cannot be found must say so instead of compiling to nothing.
func test_unresolvable_texture_transform_bind_warns() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var controller := Vrm1ExpressionController.new()
	root.add_child(controller)

	var orphan := StandardMaterial3D.new()
	orphan.resource_name = "NotInScene"
	var state := GLTFState.new()
	var materials: Array[Material] = [orphan]
	state.materials = materials

	var tb := Vrm1ExpressionTextureTransformBind.new()
	tb.material = 0
	var expr_data := Vrm1ExpressionData.new()
	expr_data.texture_transform_binds.append(tb)
	var expressions := Vrm1Expressions.new()
	expressions.custom["emote0"] = expr_data

	controller.compile_vrm1_binds(expressions, state, root)

	assert_eq(controller._binds["emote0"].uv_binds.size(), 0)
	assert_eq(controller._unresolved_bind_warnings.size(), 1)
	var warning: String = controller._unresolved_bind_warnings[0] if not controller._unresolved_bind_warnings.is_empty() else ""
	assert_string_contains(warning, "emote0")
	assert_string_contains(warning, "NotInScene")
