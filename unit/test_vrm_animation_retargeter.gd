extends GutTest

# An avatar without an AnimationPlayer gets one from its VrmAnimationRetargeter, added one
# call later because the parent is still busy adding children in _ready. An avatar freed
# before that call once left the new player behind as an orphan.


func _build_avatar() -> Node3D:
	var avatar := Node3D.new()
	avatar.name = "Avatar"
	var skeleton := Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	avatar.add_child(skeleton)
	var retargeter := VrmAnimationRetargeter.new()
	retargeter.name = "VrmAnimationRetargeter"
	avatar.add_child(retargeter)
	return avatar


func test_creates_an_animation_player_when_the_avatar_has_none() -> void:
	var avatar: Node3D = _build_avatar()
	add_child_autofree(avatar)
	await wait_process_frames(1)

	var player: AnimationPlayer = avatar.get_node_or_null("AnimationPlayer") as AnimationPlayer
	assert_not_null(player, "the retargeter should add an AnimationPlayer to the avatar")
	var retargeter: VrmAnimationRetargeter = avatar.get_node("VrmAnimationRetargeter")
	assert_same(retargeter.animation_player, player)


func test_avatar_freed_before_the_player_is_added_leaves_no_orphan() -> void:
	var avatar: Node3D = _build_avatar()
	add_child(avatar)
	avatar.free()
	await wait_process_frames(1)

	assert_no_new_orphans("the AnimationPlayer the retargeter created must not outlive it")
