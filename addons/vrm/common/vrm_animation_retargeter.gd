@tool
extends Node

## This node automatically fixes AnimationLibrary tracks to match the avatar's actual bone names.
## It is useful for making standalone VRMA animations work with avatars that have naming variations
## (e.g. lowercase 'hips' vs camelCase 'hips').
class_name VrmAnimationRetargeter

@export var animation_player: AnimationPlayer
@export var skeleton: Skeleton3D

## The AnimationPlayer this node created, until it is added to the parent. The parent is
## still adding children in _ready, so the player goes in one deferred call later; if this
## node is freed first (its avatar freed in the same frame), it frees the player itself.
var _pending_player: AnimationPlayer


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_pending_player):
		if _pending_player.get_parent() == null:
			_pending_player.free()
		_pending_player = null


func _ready() -> void:
	print("[VRM Retargeter] Ready on node: ", name)
	
	#if Engine.is_editor_hint() and not get_viewport() is Window:
		#return
	
	if skeleton == null:
		skeleton = VRMUtil.find_skeleton(get_parent())
		
	if animation_player == null:
		animation_player = VRMUtil.find_animation_player(get_parent())
		
	if skeleton == null:
		push_error("[VRM Retargeter] ERROR: Could not find Skeleton3D!")
		return

	if animation_player == null:
		print("[VRM Retargeter] No AnimationPlayer found. Creating one...")
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		_pending_player = animation_player
		# The parent is busy adding children now; add the player and retarget a call later.
		_attach_pending_player.call_deferred()
	else:
		_setup_signal()


func _attach_pending_player() -> void:
	if not is_instance_valid(_pending_player) or get_parent() == null:
		return
	var player: AnimationPlayer = _pending_player
	_pending_player = null
	if player.get_parent() == null:
		get_parent().add_child(player)
	_setup_signal()


func _setup_signal() -> void:
	if animation_player.has_signal("animation_libraries_updated"):
		if not animation_player.is_connected("animation_libraries_updated", _retarget_all_animations):
			animation_player.animation_libraries_updated.connect(_retarget_all_animations)
	
	_retarget_all_animations()




func _retarget_all_animations() -> void:
	if skeleton == null or animation_player == null:
		return

	var root: Node = get_parent()
	print("[VRM Retargeter] Starting retargeting for avatar: " + root.name)

	var libs_to_replace: Dictionary = {}
	for lib_name: StringName in animation_player.get_animation_library_list():
		var lib: AnimationLibrary = animation_player.get_animation_library(lib_name)
		if lib.has_meta(&"retargeted_for_skeleton"):
			var target_id: int = lib.get_meta(&"retargeted_for_skeleton")
			if target_id == skeleton.get_instance_id():
				continue
		libs_to_replace[lib_name] = lib

	for lib_name: StringName in libs_to_replace:
		var lib: AnimationLibrary = libs_to_replace[lib_name]
		var new_lib: AnimationLibrary = AnimationLibrary.new()
		for anim_name: StringName in lib.get_animation_list():
			var anim: Animation = lib.get_animation(anim_name)
			var new_anim: Animation = anim.duplicate(true)
			_retarget_animation(new_anim)
			new_lib.add_animation(anim_name, new_anim)

		new_lib.set_meta(&"retargeted_for_skeleton", skeleton.get_instance_id())
		animation_player.remove_animation_library(lib_name)
		animation_player.add_animation_library(lib_name, new_lib)


func _retarget_animation(anim: Animation) -> void:
	var fixed_count: int = 0
	var total_bone_tracks: int = 0
	var root: Node = get_parent()

	var resolved_hips_name: String = VRMUtil.find_bone(skeleton, root, "hips")
	var has_hips_scale: bool = false
	var scale_factor: float = 1.0
	var vrma_hips_rest_pos: Vector3 = Vector3.ZERO
	var target_hips_rest_pos: Vector3 = Vector3.ZERO

	if not resolved_hips_name.is_empty() and anim.has_meta(&"vrma_hips_rest_pos"):
		var hips_bone_idx: int = skeleton.find_bone(resolved_hips_name)
		if hips_bone_idx != -1:
			var meta_pos: Variant = anim.get_meta(&"vrma_hips_rest_pos")
			if meta_pos is Vector3:
				vrma_hips_rest_pos = meta_pos
				target_hips_rest_pos = skeleton.get_bone_rest(hips_bone_idx).origin
				if vrma_hips_rest_pos.y > 0.0001 and target_hips_rest_pos.y > 0.0001:
					scale_factor = target_hips_rest_pos.y / vrma_hips_rest_pos.y
					has_hips_scale = true
					print("[VRM Retargeter] Hips scaling enabled. Source height: ", vrma_hips_rest_pos.y, ", Target height: ", target_hips_rest_pos.y, ", Scale factor: ", scale_factor)

	for i: int in range(anim.get_track_count()):
		var path: NodePath = anim.track_get_path(i)
		var path_str: String = str(path)

		if not "%GeneralSkeleton:" in path_str:
			continue

		total_bone_tracks += 1
		var parts: Array = path_str.split(":")
		if parts.size() < 2:
			continue

		var bone_name: String = parts[1]
		var resolved_name: String = VRMUtil.find_bone(skeleton, root, bone_name)

		if resolved_name.is_empty():
			print("[VRM Retargeter] FAILED to resolve bone: " + bone_name)
			continue

		if resolved_name != bone_name:
			_update_track_path(anim, i, parts, resolved_name)
			fixed_count += 1

		if has_hips_scale and resolved_name == resolved_hips_name and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var key_count: int = anim.track_get_key_count(i)
			for k: int in range(key_count):
				var pos: Vector3 = anim.track_get_key_value(i, k)
				var new_pos: Vector3 = target_hips_rest_pos + (pos - vrma_hips_rest_pos) * scale_factor
				anim.track_set_key_value(i, k, new_pos)
			print("[VRM Retargeter] Scaled hips position track for bone: ", resolved_name, " in animation: ", anim.resource_name)

	if fixed_count > 0:
		print("[VRM Retargeter] Fixed " + str(fixed_count) + "/" + str(total_bone_tracks) + " tracks in animation: " + anim.resource_name)


func _update_track_path(anim: Animation, track_idx: int, path_parts: Array, new_bone_name: String) -> void:
	path_parts[1] = new_bone_name
	var new_path: String = ":".join(path_parts)
	anim.track_set_path(track_idx, NodePath(new_path))
