@tool
class_name VRMUtil
extends Object

## Centralized utility for VRM-related operations, node finding, and metadata access.

const META_HUMANOID_BONES = "vrm_humanoid_bones"
const META_VRM0_DATA = "vrm0_data"
const META_VRM1_DATA = "vrm1_data"


# --- Metadata Access ---

## Returns the vrm_role -> actual_bone_name mapping dictionary.
static func get_humanoid_bone_map(model: Node) -> Dictionary:
	if model and model.has_meta(META_HUMANOID_BONES):
		return model.get_meta(META_HUMANOID_BONES)
	return {}


## Returns the actual bone name for a given VRM humanoid role (e.g., "head").
## This only checks the metadata map. Use find_bone() for a comprehensive search.
static func get_humanoid_bone(model: Node, role: String) -> StringName:
	var bone_map = get_humanoid_bone_map(model)
	return bone_map.get(role.to_lower(), "")


## Comprehensive bone resolution: checks exact match, VRM humanoid metadata,
## and finally case-insensitive match against the skeleton.
static func find_bone(skeleton: Skeleton3D, model: Node, bone_name: String) -> String:
	if skeleton == null:
		return ""

	# 1. Exact match
	if skeleton.find_bone(bone_name) != -1:
		return bone_name

	# 2. Metadata lookup (VRM Role -> Actual Name)
	var role_name = get_humanoid_bone(model, bone_name)
	if not role_name.is_empty():
		if skeleton.find_bone(role_name) != -1:
			return role_name

	# 3. Case-insensitive match
	var lower_name = bone_name.to_lower()
	for i in range(skeleton.get_bone_count()):
		var b_name = skeleton.get_bone_name(i)
		if b_name.to_lower() == lower_name:
			return b_name

	return ""


## Sets the vrm_role -> actual_bone_name mapping dictionary.
static func set_humanoid_bone_map(model: Node, bone_map: Dictionary) -> void:
	if model:
		model.set_meta(META_HUMANOID_BONES, bone_map)


## Returns the VRM 0.0 top-level data structure.
static func get_vrm0_data(model: Node) -> Vrm0TopLevel:
	if model and model.has_meta(META_VRM0_DATA):
		return model.get_meta(META_VRM0_DATA) as Vrm0TopLevel
	return null


## Sets the VRM 0.0 top-level data structure.
static func set_vrm0_data(model: Node, data: Vrm0TopLevel) -> void:
	if model:
		model.set_meta(META_VRM0_DATA, data)


## Returns the VRM 1.0 top-level data structure.
static func get_vrm1_data(model: Node) -> Vrm1TopLevel:
	if model and model.has_meta(META_VRM1_DATA):
		return model.get_meta(META_VRM1_DATA) as Vrm1TopLevel
	return null


## Sets the VRM 1.0 top-level data structure.
static func set_vrm1_data(model: Node, data: Vrm1TopLevel) -> void:
	if model:
		model.set_meta(META_VRM1_DATA, data)


# --- Node Finding ---

## Recursively finds the first Skeleton3D node in the given hierarchy.
static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children(true):
		var res = find_skeleton(child)
		if res:
			return res
	return null


## Recursively finds the first AnimationPlayer node in the given hierarchy.
static func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children(true):
		var res = find_animation_player(child)
		if res:
			return res
	return null


## Finds the VRM Expression Controller node (0.0 or 1.0) among the direct children.
static func find_expression_controller(root: Node) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child is Vrm0ExpressionController or child is Vrm1ExpressionController:
			return child
		# Fallback for GDExtension or classes that might not report 'is' correctly in some contexts
		var cname = child.get_class()
		if cname == "Vrm0ExpressionController" or cname == "Vrm1ExpressionController":
			return child
	return null


## Returns true if the node has any VRM metadata.
static func is_vrm(node: Node) -> bool:
	if node == null: return false
	return node.has_meta(META_VRM0_DATA) or node.has_meta(META_VRM1_DATA)


## Returns true if the node has VRM 0.0 metadata.
static func is_vrm0(node: Node) -> bool:
	if node == null: return false
	return node.has_meta(META_VRM0_DATA)


## Returns true if the node has VRM 1.0 metadata.
static func is_vrm1(node: Node) -> bool:
	if node == null: return false
	return node.has_meta(META_VRM1_DATA)
