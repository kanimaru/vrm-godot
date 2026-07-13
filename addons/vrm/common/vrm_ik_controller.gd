@tool
class_name VrmIkController
extends Node
const VRMUtil = preload("vrm_util.gd")

## Manages runtime IK for VRM models, specifically for VMD leg movement.
## It creates virtual target nodes and configures SkeletonIK3D for the legs.
##
## Foot rotation is solved by mapping the VMD target to the bone's actual rest
## world orientation. This makes the solver model-agnostic (no manual offsets).

var skeleton: Skeleton3D = null
var left_leg_ik: SkeletonIK3D = null
var right_leg_ik: SkeletonIK3D = null

var left_target: Marker3D = null
var right_target: Marker3D = null
var left_toe_target: Marker3D = null
var right_toe_target: Marker3D = null

var enabled: bool = false:
	set(v):
		enabled = v
		_update_ik_state()

var debug: bool = false:
	set(v):
		debug = v
		_update_debug_viz()

var is_vrm0: bool = false

# Bone rest orientations in skeleton-local space, cached at setup time.
# These are used in _process() to correctly remap VMD world-space orientations
# onto the model's actual rest pose, fixing the VRM 0/1 discrepancy without
# requiring any manual pitch offset.
var _left_foot_rest_skel: Quaternion = Quaternion.IDENTITY
var _right_foot_rest_skel: Quaternion = Quaternion.IDENTITY
var _left_toe_rest_skel: Quaternion = Quaternion.IDENTITY
var _right_toe_rest_skel: Quaternion = Quaternion.IDENTITY


func setup(p_skeleton: Skeleton3D, p_target_parent: Node = null, p_is_vrm0: bool = false) -> void:
	skeleton = p_skeleton
	is_vrm0 = p_is_vrm0
	if not skeleton: return

	# Ensure we run after AnimationPlayer to override its rotation tracks
	process_priority = 10

	var model: Node = skeleton.get_parent()
	var target_parent: Node = p_target_parent if p_target_parent else model

	# Create Targets as children of the target parent (to avoid root motion bobbing)
	left_target = Marker3D.new()
	left_target.name = "leftLegIk"
	left_target.unique_name_in_owner = true
	target_parent.add_child(left_target)
	left_target.owner = target_parent.owner if target_parent.owner else target_parent

	right_target = Marker3D.new()
	right_target.name = "rightLegIk"
	right_target.unique_name_in_owner = true
	target_parent.add_child(right_target)
	right_target.owner = target_parent.owner if target_parent.owner else target_parent

	left_toe_target = Marker3D.new()
	left_toe_target.name = "leftToeIk"
	left_toe_target.unique_name_in_owner = true
	target_parent.add_child(left_toe_target)
	left_toe_target.owner = target_parent.owner if target_parent.owner else target_parent

	right_toe_target = Marker3D.new()
	right_toe_target.name = "rightToeIk"
	right_toe_target.unique_name_in_owner = true
	target_parent.add_child(right_toe_target)
	right_toe_target.owner = target_parent.owner if target_parent.owner else target_parent

	# Magnet orientation depends on model facing and bone rest.
	# VRM 1.0 typically bends forward with +Z, while our retargeted VRM 0.0 needs -Z.
	var magnet_v := Vector3(0.0, 0.0, -1.0) if is_vrm0 else Vector3(0.0, 0.0, 1.0)

	# Setup SkeletonIK3D for Left Leg
	left_leg_ik = SkeletonIK3D.new()
	left_leg_ik.name = "LeftLegIK"
	left_leg_ik.root_bone = VRMUtil.get_humanoid_bone(model, "leftUpperLeg")
	left_leg_ik.tip_bone = VRMUtil.get_humanoid_bone(model, "leftFoot")
	left_leg_ik.use_magnet = true
	left_leg_ik.magnet = magnet_v
	left_leg_ik.target_node = left_target.get_path()
	left_leg_ik.override_tip_basis = false # We handle rotation manually in _process
	skeleton.add_child(left_leg_ik)

	# Setup SkeletonIK3D for Right Leg
	right_leg_ik = SkeletonIK3D.new()
	right_leg_ik.name = "RightLegIK"
	right_leg_ik.root_bone = VRMUtil.get_humanoid_bone(model, "rightUpperLeg")
	right_leg_ik.tip_bone = VRMUtil.get_humanoid_bone(model, "rightFoot")
	right_leg_ik.use_magnet = true
	right_leg_ik.magnet = magnet_v
	right_leg_ik.target_node = right_target.get_path()
	right_leg_ik.override_tip_basis = false # We handle rotation manually in _process
	skeleton.add_child(right_leg_ik)

	# Cache each foot/toe bone's rest orientation in skeleton-local space.
	# get_bone_global_rest() accumulates all parent rests up to (but not including)
	# the skeleton node itself, so it is skeleton-local — not scene-world.
	# In _process() we multiply by skeleton.global_transform to get true world space.
	_left_foot_rest_skel = _bone_rest_skel_quat(left_leg_ik.tip_bone)
	_right_foot_rest_skel = _bone_rest_skel_quat(right_leg_ik.tip_bone)

	var left_toe_name: StringName = VRMUtil.get_humanoid_bone(model, "leftToes")
	var right_toe_name: StringName = VRMUtil.get_humanoid_bone(model, "rightToes")
	_left_toe_rest_skel = _bone_rest_skel_quat(left_toe_name)
	_right_toe_rest_skel = _bone_rest_skel_quat(right_toe_name)


func _update_ik_state() -> void:
	if left_leg_ik:
		if enabled: left_leg_ik.start()
		else: left_leg_ik.stop()
	if right_leg_ik:
		if enabled: right_leg_ik.start()
		else: right_leg_ik.stop()
	set_process(enabled)
	_update_debug_viz()


func _update_debug_viz() -> void:
	_setup_debug_mesh(left_target, Color.RED)
	_setup_debug_mesh(right_target, Color.GREEN)
	_setup_debug_mesh(left_toe_target, Color.ORANGE)
	_setup_debug_mesh(right_toe_target, Color.CYAN)


func _setup_debug_mesh(target: Marker3D, color: Color) -> void:
	if not target: return
	var mesh_name = "DebugMesh"
	var existing = target.find_child(mesh_name)
	if existing:
		existing.visible = debug
	elif debug:
		var mi := MeshInstance3D.new()
		mi.name = mesh_name
		var box := BoxMesh.new()
		box.size = Vector3(0.1, 0.1, 0.2) # Long side is Z (forward)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		target.add_child(mi)


func _process(_delta: float) -> void:
	if not enabled or not skeleton: return

	# Force skeleton to update global poses so we can calculate relative rotation
	# based on the latest IK solver positions.
	skeleton.force_update_all_bone_transforms()

	# SkeletonIK3D only solves position. We must manually sync rotation for the feet.
	if left_leg_ik and left_target:
		_sync_bone_rotation(
				left_leg_ik.tip_bone,
				left_target.global_transform.basis.get_rotation_quaternion(),
				_left_foot_rest_skel
		)

	if right_leg_ik and right_target:
		_sync_bone_rotation(
				right_leg_ik.tip_bone,
				right_target.global_transform.basis.get_rotation_quaternion(),
				_right_foot_rest_skel
		)

	# Toe IK Sync (Rotation only)
	var model: Node = skeleton.get_parent()
	var left_toe_name: StringName = VRMUtil.get_humanoid_bone(model, "leftToes")
	var right_toe_name: StringName = VRMUtil.get_humanoid_bone(model, "rightToes")

	if left_toe_target and not left_toe_name.is_empty():
		_sync_bone_rotation(
				left_toe_name,
				left_toe_target.global_transform.basis.get_rotation_quaternion(),
				_left_toe_rest_skel
		)

	if right_toe_target and not right_toe_name.is_empty():
		_sync_bone_rotation(
				right_toe_name,
				right_toe_target.global_transform.basis.get_rotation_quaternion(),
				_right_toe_rest_skel
		)


## Returns the rest orientation of a named bone in skeleton-local space by
## accumulating get_bone_rest() through all ancestors. This is equivalent to
## get_bone_global_rest() but expressed purely from local rests so it is valid
## even before the skeleton node has been placed in the scene tree.
func _bone_rest_skel_quat(bone_name: StringName) -> Quaternion:
	if not skeleton: return Quaternion.IDENTITY
	var idx: int = skeleton.find_bone(bone_name)
	if idx == -1: return Quaternion.IDENTITY

	var basis: Basis = skeleton.get_bone_rest(idx).basis
	var parent: int = skeleton.get_bone_parent(idx)
	while parent >= 0:
		basis = skeleton.get_bone_rest(parent).basis * basis
		parent = skeleton.get_bone_parent(parent)

	return basis.orthonormalized().get_rotation_quaternion()


## Drives bone_name to the given VMD target orientation.
##
## Converts the world-space vmd_target into skeleton-local space so the
## formula works regardless of whether the skeleton is rotated (VRM 0)
## or identity (VRM 1).  The IK targets may be parented to any ancestor
## of the skeleton, so we use the skeleton's own global rotation as the
## reference rather than its immediate parent.
##
##   desired_global_pose = bone_rest_skel × vmd_target_skel
##   pose_quat           = parent_skel⁻¹ × desired_global_pose
##
## vmd_target is the IK marker's world-space rotation.
func _sync_bone_rotation(
		bone_name: StringName,
		vmd_target: Quaternion,
		bone_rest_skel: Quaternion
) -> void:
	var bone_idx: int = skeleton.find_bone(bone_name)
	if bone_idx == -1: return

	var parent_idx: int = skeleton.get_bone_parent(bone_idx)
	if parent_idx == -1: return

	# Parent's CURRENT global pose in SKELETON-LOCAL space (no skel_world here).
	# IK may have moved the parent, but skel_world cancels in the final result.
	var parent_skel_q: Quaternion = (
			skeleton.get_bone_global_pose(parent_idx).basis.orthonormalized().get_rotation_quaternion()
	)

	# Convert world-space target into skeleton-local space.
	# We use the skeleton's OWN global rotation (not its parent's) so the
	# formula is correct even when the skeleton has an extra rotation
	# relative to the scene root (e.g. VRM 0's 180° Y offset).
	var skel_world_q: Quaternion = (
			skeleton.global_transform.basis.orthonormalized().get_rotation_quaternion()
	)
	var vmd_target_skel: Quaternion = skel_world_q.inverse() * vmd_target

	# desired global pose (skeleton-local) = rest_skel × target_skel
	# pose = parent_skel⁻¹ × desired_global_pose
	var pose_quat: Quaternion = parent_skel_q.inverse() * bone_rest_skel * vmd_target_skel
	skeleton.set_bone_pose_rotation(bone_idx, pose_quat)
