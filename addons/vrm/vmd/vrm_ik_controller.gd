@tool
class_name VrmIkController
extends Node
const VRMUtil = preload("../common/vrm_util.gd")

## Manages runtime IK for VRM models, specifically for VMD leg movement.
## It creates virtual target nodes and configures SkeletonIK3D for the legs.

var skeleton: Skeleton3D
var left_leg_ik: SkeletonIK3D
var right_leg_ik: SkeletonIK3D

var left_target: Marker3D
var right_target: Marker3D

var enabled: bool = false:
	set(v):
		enabled = v
		_update_ik_state()

var debug: bool = false:
	set(v):
		debug = v
		_update_debug_viz()

func setup(p_skeleton: Skeleton3D) -> void:
	skeleton = p_skeleton
	if not skeleton: return

	var model = skeleton.get_parent()

	# Create Targets as children of the model root (absolute space)
	left_target = Marker3D.new()
	left_target.name = "leftLegIk"
	left_target.unique_name_in_owner = true
	model.add_child(left_target)
	left_target.owner = model

	right_target = Marker3D.new()
	right_target.name = "rightLegIk"
	right_target.unique_name_in_owner = true
	model.add_child(right_target)
	right_target.owner = model

	# Setup SkeletonIK3D for Left Leg
	left_leg_ik = SkeletonIK3D.new()
	left_leg_ik.name = "LeftLegIK"
	left_leg_ik.root_bone = VRMUtil.get_humanoid_bone(model, "leftUpperLeg")
	left_leg_ik.tip_bone = VRMUtil.get_humanoid_bone(model, "leftFoot")
	left_leg_ik.use_magnet = true
	left_leg_ik.magnet = Vector3(-0.15, 0.1, 1.0) # Bend knee forward and slightly outward
	left_leg_ik.target_node = left_target.get_path()
	left_leg_ik.override_tip_basis = false # We handle rotation manually in _process
	skeleton.add_child(left_leg_ik)

	# Setup SkeletonIK3D for Right Leg
	right_leg_ik = SkeletonIK3D.new()
	right_leg_ik.name = "RightLegIK"
	right_leg_ik.root_bone = VRMUtil.get_humanoid_bone(model, "rightUpperLeg")
	right_leg_ik.tip_bone = VRMUtil.get_humanoid_bone(model, "rightFoot")
	right_leg_ik.use_magnet = true
	right_leg_ik.magnet = Vector3(0.15, 0.1, 1.0) # Bend knee forward and slightly outward
	right_leg_ik.target_node = right_target.get_path()
	right_leg_ik.override_tip_basis = false # We handle rotation manually in _process
	skeleton.add_child(right_leg_ik)

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

	# SkeletonIK3D only solves position. We must manually sync rotation for the feet.
	if left_leg_ik and left_target:
		var bone_idx = skeleton.find_bone(left_leg_ik.tip_bone)
		if bone_idx != -1:
			var target_quat = left_target.global_transform.basis.get_rotation_quaternion()
			var parent_idx = skeleton.get_bone_parent(bone_idx)
			var parent_global_pose = skeleton.get_bone_global_pose(parent_idx)
			var skeleton_global_transform = skeleton.global_transform
			# Corrected Formula: Pose_Local = (Rest_Local).inverse() * (Parent_Global).inverse() * Target_Global
			var rest_local_quat = skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()
			var parent_global_rotation = (skeleton_global_transform.basis * parent_global_pose.basis).get_rotation_quaternion()
			var pose_quat = rest_local_quat.inverse() * parent_global_rotation.inverse() * target_quat
			skeleton.set_bone_pose_rotation(bone_idx, pose_quat)

	if right_leg_ik and right_target:
		var bone_idx = skeleton.find_bone(right_leg_ik.tip_bone)
		if bone_idx != -1:
			var target_quat = right_target.global_transform.basis.get_rotation_quaternion()
			var parent_idx = skeleton.get_bone_parent(bone_idx)
			var parent_global_pose = skeleton.get_bone_global_pose(parent_idx)
			var skeleton_global_transform = skeleton.global_transform
			var rest_local_quat = skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()
			var parent_global_rotation = (skeleton_global_transform.basis * parent_global_pose.basis).get_rotation_quaternion()
			var pose_quat = rest_local_quat.inverse() * parent_global_rotation.inverse() * target_quat
			skeleton.set_bone_pose_rotation(bone_idx, pose_quat)
