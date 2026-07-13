@tool
class_name VrmSceneComposer
extends Object

## Shared post-import scene composition steps used by both Vrm0Extension and Vrm1Extension.
## Everything here is generation-agnostic; generation-specific parsing and node wiring
## (spring bone simulator class, expression controller compile_* method, VRM1's look-at
## controller) stays in each extension's own _import_post.
##
## See docs/adr/0001-extract-shared-vrm-scene-composition.md.

const VrmMtoonBuilder = preload("vrm_mtoon_builder.gd")
const VRMUtil = preload("vrm_util.gd")


## Resolves a single glTF node's Godot-facing name, preferring original_name and
## falling back to resource_name (Godot may rename nodes for uniqueness/validity).
static func resolve_node_name(gnode: GLTFNode) -> String:
	if gnode == null:
		return ""
	var node_name: String = gnode.original_name
	if node_name.is_empty():
		node_name = gnode.resource_name
	return node_name


## Builds a node_index -> resolved_name map for every node in the glTF document.
## Used to feed gltf_node_names into the spring bone simulators.
static func resolve_all_node_names(state: GLTFState) -> Dictionary[int, String]:
	var gltf_nodes: Array[GLTFNode] = state.get_nodes()
	var node_names: Dictionary[int, String] = {}
	for i: int in range(gltf_nodes.size()):
		var gnode: GLTFNode = gltf_nodes[i]
		if gnode != null:
			node_names[i] = resolve_node_name(gnode)
	return node_names


## Creates and attaches a VrmAnimationRetargeter, wiring it to the root's AnimationPlayer
## if one already exists.
static func attach_retargeter(root: Node) -> void:
	var retargeter_script: Script = load("res://addons/vrm/common/vrm_animation_retargeter.gd")
	if retargeter_script == null:
		return

	var retargeter: Node = Node.new()
	retargeter.set_script(retargeter_script)
	retargeter.name = &"VrmAnimationRetargeter"

	var anim_player: AnimationMixer = VRMUtil.find_animation_player(root)
	if anim_player != null:
		retargeter.animation_player = anim_player

	root.add_child(retargeter, true)
	retargeter.owner = root


## Renames the skeleton to the plugin-wide "GeneralSkeleton" convention that animation
## retargeting (VRMA/VMD/BVH) relies on, and makes it addressable via %GeneralSkeleton.
static func rename_skeleton_to_general(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	skeleton.name = &"GeneralSkeleton"
	skeleton.unique_name_in_owner = true


## Builds MToon ShaderMaterials from the parsed per-material configs, swaps them into
## the scene tree's meshes by matching glTF material resource_name, and attaches an
## MtoonController to drive the runtime MToon shader uniforms. No-op if mtoon_configs
## is not an Array or resolves to no materials.
static func apply_mtoon_materials(root: Node, mtoon_configs: Variant, state: GLTFState) -> void:
	if not (mtoon_configs is Array):
		return

	var gltf_materials: Array = state.get_materials()

	# Build a name -> ShaderMaterial map for scene-tree lookup.
	# The surface material resource_name on baked ArrayMesh surfaces matches
	# the resource_name of the corresponding glTF material.
	var name_to_shader: Dictionary[String, ShaderMaterial] = {}
	var active_mtoons: Array[Material] = []
	for mat_idx: int in range(mtoon_configs.size()):
		var params: Variant = mtoon_configs[mat_idx]
		if not (params is Dictionary):
			continue

		var body_mat: ShaderMaterial = VrmMtoonBuilder.build_body(params)
		var outline_mat: ShaderMaterial = VrmMtoonBuilder.build_outline(params)
		if outline_mat != null:
			body_mat.next_pass = outline_mat

		# Map by glTF material name so the scene-tree walker can look it up.
		var gltf_mat: Material = gltf_materials[mat_idx] as Material if mat_idx < gltf_materials.size() else null
		if gltf_mat != null and not gltf_mat.resource_name.is_empty():
			name_to_shader[gltf_mat.resource_name] = body_mat

		active_mtoons.append(body_mat)
		if outline_mat != null:
			active_mtoons.append(outline_mat)

	if name_to_shader.is_empty():
		return

	_apply_materials_to_scene_tree(root, name_to_shader)

	var mtoon_controller_script: Script = load("res://addons/Godot-MToon-Shader/mtoon_controller.gd")
	if mtoon_controller_script != null:
		var controller: Node = mtoon_controller_script.new()
		controller.name = &"MtoonController"
		controller.set("mtoon_materials", active_mtoons)
		root.add_child(controller, true)
		controller.owner = root


## Recursively walks the scene tree from root, swapping in MToon materials by matching
## surface material resource_name against name_to_shader.
## During _import_post, mesh nodes are ImporterMeshInstance3D with an ImporterMesh, which
## uses get_surface_material()/set_surface_material() to bake the replacement directly
## into the final ArrayMesh. Already-baked MeshInstance3D nodes are also handled so this
## can be reused outside the import pipeline.
static func _apply_materials_to_scene_tree(
		node: Node,
		name_to_shader: Dictionary[String, ShaderMaterial],
) -> void:
	if node is ImporterMeshInstance3D:
		var importer_inst: ImporterMeshInstance3D = node as ImporterMeshInstance3D
		var importer_mesh: ImporterMesh = importer_inst.mesh
		if importer_mesh != null:
			for i: int in range(importer_mesh.get_surface_count()):
				var surf_mat: Material = importer_mesh.get_surface_material(i)
				if surf_mat == null or surf_mat.resource_name.is_empty():
					continue
				if name_to_shader.has(surf_mat.resource_name):
					importer_mesh.set_surface_material(i, name_to_shader[surf_mat.resource_name])
	elif node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		if mesh_inst.mesh != null:
			for i: int in range(mesh_inst.mesh.get_surface_count()):
				var surf_mat: Material = mesh_inst.mesh.surface_get_material(i)
				if surf_mat == null or surf_mat.resource_name.is_empty():
					continue
				if name_to_shader.has(surf_mat.resource_name):
					mesh_inst.set_surface_override_material(i, name_to_shader[surf_mat.resource_name])

	for child: Node in node.get_children():
		_apply_materials_to_scene_tree(child, name_to_shader)
