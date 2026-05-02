@tool
extends Node

## This node automatically fixes AnimationLibrary tracks to match the avatar's actual bone names.
## It is useful for making standalone VRMA animations work with avatars that have naming variations
## (e.g. lowercase 'hips' vs camelCase 'hips').
class_name VrmAnimationRetargeter

@export var animation_player: AnimationPlayer
@export var skeleton: Skeleton3D


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




func _retarget_all_animations() -> void:
	var root: Node = get_parent()
	print("[VRM Retargeter] Starting retargeting for avatar: " + root.name)

	# Start retargeting

	for lib_name in animation_player.get_animation_library_list():
		var lib: AnimationLibrary = animation_player.get_animation_library(lib_name)
		print("[VRM Retargeter] Checking library: " + str(lib_name))
		for anim_name in lib.get_animation_list():
			var anim: Animation = lib.get_animation(anim_name)
			_retarget_animation(anim)


func _retarget_animation(anim: Animation) -> void:
	var fixed_count: int = 0
	var total_bone_tracks: int = 0
	var root: Node = get_parent()
	
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
		var resolved_name: String = VRMUtil.find_bone(skeleton, root, bone_name)
		
		if resolved_name.is_empty():
			print("[VRM Retargeter] FAILED to resolve bone: " + bone_name)
			continue
			
		if resolved_name != bone_name:
			_update_track_path(anim, i, parts, resolved_name)
			fixed_count += 1

	if fixed_count > 0:
		print("[VRM Retargeter] Fixed " + str(fixed_count) + "/" + str(total_bone_tracks) + " tracks in animation: " + anim.resource_name)


func _update_track_path(anim: Animation, track_idx: int, path_parts: Array, new_bone_name: String) -> void:
	path_parts[1] = new_bone_name
	var new_path: String = ":".join(path_parts)
	anim.track_set_path(track_idx, NodePath(new_path))
