@tool
extends GLTFDocumentExtension
class_name VrmaExtension

const VrmSceneComposer = preload("../common/vrm_scene_composer.gd")

## GLTFState additional-data key: glTF node index -> generated scene node name, recorded in
## _import_post for VrmaAnimationLibraryBuilder.
const SCENE_NODE_NAMES_KEY: StringName = &"vrma_scene_node_names"


func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray(["VRMC_vrm_animation"])


func _import_node(state: GLTFState, gltf_node: GLTFNode, _json: Dictionary, node: Node) -> Error:
	# This extension has no _import_preflight filter, so it sees every glTF in the project:
	# tag only VRMA scenes, for VrmaAnimationLibraryBuilder (never get_scene_node()).
	if state.get_additional_data("vrma") is VrmaTopLevel:
		VrmSceneComposer.tag_scene_node(state, gltf_node, node, self)
	return OK


## VrmaAnimationLibraryBuilder runs after generate_scene, when the tags are gone, so the
## names it needs are read off the tagged nodes here and kept on the state (plain strings,
## unaffected by Godot replacing nodes later).
func _import_post(state: GLTFState, root: Node) -> Error:
	if state.get_additional_data("vrma") is VrmaTopLevel:
		var node_names: Dictionary[int, String] = {}
		var scene_nodes: Dictionary[int, Node] = VrmSceneComposer.collect_scene_nodes(root)
		for node_index: int in scene_nodes:
			node_names[node_index] = String(scene_nodes[node_index].name)
		state.set_additional_data(SCENE_NODE_NAMES_KEY, node_names)
	VrmSceneComposer.release_scene_node_tags(state, root, self)
	return OK


func _import_post_parse(state: GLTFState) -> Error:
	var json: Dictionary = state.get_json()
	if not json.has("extensions"):
		return OK
		
	var extensions: Dictionary = json["extensions"]
	if not extensions.has("VRMC_vrm_animation"):
		return OK
		
	var vrma_dict: Dictionary = extensions["VRMC_vrm_animation"]
	var top_level: VrmaTopLevel = VrmaTopLevel.new()
	top_level.spec_version = vrma_dict.get("specVersion", "")
	
	if vrma_dict.has("humanoid"):
		top_level.humanoid = _parse_humanoid(vrma_dict["humanoid"])
		
	if vrma_dict.has("expressions"):
		top_level.expressions = _parse_expressions(vrma_dict["expressions"])
		
	if vrma_dict.has("lookAt"):
		top_level.look_at = _parse_look_at(vrma_dict["lookAt"])
		
	state.set_additional_data("vrma", top_level)
	return OK


func _parse_humanoid(d: Dictionary) -> VrmaHumanoid:
	var humanoid: VrmaHumanoid = VrmaHumanoid.new()
	if d.has("humanBones"):
		var raw_bones: Dictionary = d["humanBones"]
		for key: String in raw_bones:
			var bd: Dictionary = raw_bones[key]
			humanoid.human_bones[key] = bd.get("node", -1)
	return humanoid


func _parse_expressions(d: Dictionary) -> VrmaExpressions:
	var expressions: VrmaExpressions = VrmaExpressions.new()
	if d.has("preset"):
		for key: String in d["preset"]:
			var expr_d: Dictionary = d["preset"][key]
			expressions.preset[key] = expr_d.get("node", -1)
			
	if d.has("custom"):
		for key: String in d["custom"]:
			var expr_d: Dictionary = d["custom"][key]
			expressions.custom[key] = expr_d.get("node", -1)
			
	return expressions


func _parse_look_at(d: Dictionary) -> VrmaLookAt:
	var look_at: VrmaLookAt = VrmaLookAt.new()
	look_at.node = d.get("node", -1)
	if d.has("offsetFromHeadBone"):
		var offset: Array = d["offsetFromHeadBone"]
		look_at.offset_from_head_bone = Vector3(offset[0], offset[1], offset[2])
	return look_at
