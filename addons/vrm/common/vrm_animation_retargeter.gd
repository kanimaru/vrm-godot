@tool
extends Node
class_name VrmAnimationRetargeter

## This node automatically fixes AnimationLibrary tracks to match the avatar's actual bone names.
## It is useful for making standalone VRMA animations work with avatars that have naming variations
## (e.g. lowercase 'hips' vs camelCase 'hips').

@export var animation_player: AnimationPlayer
@export var skeleton: Skeleton3D

func _ready() -> void:
	# Use push_warning to ensure it shows up in the Godot Output tab
	push_warning("[VRM Retargeter] Ready on node: " + name)
	
	if Engine.is_editor_hint() and not get_viewport() is Window:
		return
	
	if skeleton == null:
		skeleton = _find_skeleton(get_parent())
		
	if animation_player == null:
		animation_player = _find_animation_player_anywhere(get_parent())
		
	if skeleton == null:
		push_error("[VRM Retargeter] ERROR: Could not find Skeleton3D!")
		return

	if animation_player == null:
		push_warning("[VRM Retargeter] No AnimationPlayer found. Creating one...")
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		get_parent().add_child.call_deferred(animation_player)
		# We'll wait a frame to retarget if we had to create the player
		_setup_signal.call_deferred()
	else:
		_setup_signal()

func _setup_signal() -> void:
	if animation_player.has_signal("animation_libraries_updated"):
		if not animation_player.is_connected("animation_libraries_updated", _retarget_all_animations):
			animation_player.animation_libraries_updated.connect(_retarget_all_animations)
	
	_retarget_all_animations()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children(true):
		var res = _find_skeleton(child)
		if res: return res
	return null

func _find_animation_player_anywhere(node: Node) -> AnimationMixer:
	# 1. Search children
	var res = _find_animation_player_recursive(node)
	if res: return res
	
	# 2. Search parents
	var p = node.get_parent()
	while p != null:
		if p is AnimationMixer: return p
		p = p.get_parent()
	return null

func _find_animation_player_recursive(node: Node) -> AnimationMixer:
	if node is AnimationMixer: return node
	for child in node.get_children(true):
		var res = _find_animation_player_recursive(child)
		if res: return res
	return null

func _retarget_all_animations() -> void:
	var root: Node = get_parent()
	var role_to_bone: Dictionary = root.get_meta("vrm_humanoid_bones", {})
	
	push_warning("[VRM Retargeter] Starting retargeting for avatar: " + root.name)

	# Build a case-insensitive lookup for the skeleton
	var bone_names_lower: Dictionary = {}
	for i in range(skeleton.get_bone_count()):
		var b_name: String = skeleton.get_bone_name(i)
		bone_names_lower[b_name.to_lower()] = b_name

	for lib_name in animation_player.get_animation_library_list():
		var lib: AnimationLibrary = animation_player.get_animation_library(lib_name)
		push_warning("[VRM Retargeter] Checking library: " + str(lib_name))
		for anim_name in lib.get_animation_list():
			var anim: Animation = lib.get_animation(anim_name)
			_retarget_animation(anim, role_to_bone, bone_names_lower)

func _retarget_animation(anim: Animation, role_to_bone: Dictionary, bone_names_lower: Dictionary) -> void:
	var fixed_count: int = 0
	var total_bone_tracks: int = 0
	
	for i in range(anim.get_track_count()):
		var path: NodePath = anim.track_get_path(i)
		var path_str: String = str(path)
		
		if not "%GeneralSkeleton:" in path_str:
			continue
			
		total_bone_tracks += 1
		var parts: Array = path_str.split(":")
		if parts.size() < 2:
			continue
			
		var bone_name: String = parts[1]
		
		# 1. Check if it already matches (exact match)
		if skeleton.find_bone(bone_name) != -1:
			continue
			
		# 2. Try the metadata lookup (VRM Role -> Actual Name)
		if role_to_bone.has(bone_name):
			var actual_name: String = role_to_bone[bone_name]
			_update_track_path(anim, i, parts, actual_name)
			fixed_count += 1
			continue
			
		# 3. Try case-insensitive match
		var lower_name: String = bone_name.to_lower()
		if bone_names_lower.has(lower_name):
			var actual_name: String = bone_names_lower[lower_name]
			_update_track_path(anim, i, parts, actual_name)
			fixed_count += 1
			continue
		
		push_warning("[VRM Retargeter] FAILED to resolve bone: " + bone_name)

	if fixed_count > 0:
		push_warning("[VRM Retargeter] Fixed " + str(fixed_count) + "/" + str(total_bone_tracks) + " tracks in animation: " + anim.resource_name)

func _update_track_path(anim: Animation, track_idx: int, path_parts: Array, new_bone_name: String) -> void:
	path_parts[1] = new_bone_name
	var new_path: String = ":".join(path_parts)
	anim.track_set_path(track_idx, NodePath(new_path))
