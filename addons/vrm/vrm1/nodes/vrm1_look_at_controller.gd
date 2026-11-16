@tool
class_name Vrm1LookAtController
extends Node3D

const VRMUtil = preload("../../common/vrm_util.gd")

@export var target_node: NodePath
@export var target_yaw: float = 0.0:
	set(value):
		target_yaw = value
		_request_update()
@export var target_pitch: float = 0.0:
	set(value):
		target_pitch = value
		_request_update()

# Saved with the imported scene: setup() runs only while importing, so anything it fills in
# that is not stored here is gone once the .vrm is loaded back as a scene.
@export var look_at_data: Vrm1LookAt
@export var skeleton: Skeleton3D
@export var expression_controller: Vrm1ExpressionController

@export_storage var _head_bone_idx: int = -1
@export_storage var _left_eye_bone_idx: int = -1
@export_storage var _right_eye_bone_idx: int = -1
var _is_dirty: bool = false


func _request_update() -> void:
	_is_dirty = true


## p_root is the avatar's scene root, needed to resolve head/leftEye/rightEye through the
## VRM humanoid role map (VRMUtil.set_humanoid_bone_map) rather than assuming a fixed bone
## name - real VRM files rarely name their bones exactly "Head"/"LeftEye"/"RightEye".
func setup(p_look_at: Vrm1LookAt, p_skeleton: Skeleton3D, p_root: Node, p_expr: Vrm1ExpressionController) -> void:
	look_at_data = p_look_at
	skeleton = p_skeleton
	expression_controller = p_expr

	if skeleton:
		_head_bone_idx = skeleton.find_bone(VRMUtil.find_bone(skeleton, p_root, "head"))
		_left_eye_bone_idx = skeleton.find_bone(VRMUtil.find_bone(skeleton, p_root, "leftEye"))
		_right_eye_bone_idx = skeleton.find_bone(VRMUtil.find_bone(skeleton, p_root, "rightEye"))


func _process(_delta: float) -> void:
	if not look_at_data:
		return

	var yaw: float = target_yaw
	var pitch: float = target_pitch

	if has_node(target_node):
		var t_node: Node3D = get_node_or_null(target_node) as Node3D
		if t_node and skeleton and _head_bone_idx >= 0:
			var head_global_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_head_bone_idx)
			var local_target: Vector3 = head_global_pose.affine_inverse() * t_node.global_position
			local_target -= look_at_data.offset_from_head_bone

			yaw = rad_to_deg(atan2(local_target.x, local_target.z))
			var xz_len: float = Vector2(local_target.x, local_target.z).length()
			pitch = rad_to_deg(atan2(local_target.y, xz_len))
			_is_dirty = true

	if not _is_dirty:
		return
	_is_dirty = false

	# Vertical mapping has no inside/outside distinction - both eyes (and the vertical
	# expressions) share the same mapped pitch.
	var pitch_mapped: float = 0.0
	if pitch < 0.0:
		pitch_mapped = _map_range(pitch, look_at_data.range_map_vertical_down)
	elif pitch > 0.0:
		pitch_mapped = _map_range(pitch, look_at_data.range_map_vertical_up)

	if look_at_data.type == "bone" and skeleton:
		# Per spec, the two eyes use OPPOSITE horizontal range maps for the same yaw sign,
		# producing natural convergence: the eye on the side being looked toward swings
		# outward (Outer), the other eye swings inward toward the nose (Inner).
		var outer_map: Vrm1LookAtRangeMap = look_at_data.range_map_horizontal_outer
		var inner_map: Vrm1LookAtRangeMap = look_at_data.range_map_horizontal_inner
		var left_yaw_mapped: float = _map_range(yaw, outer_map if yaw > 0.0 else inner_map)
		var right_yaw_mapped: float = _map_range(yaw, inner_map if yaw > 0.0 else outer_map)
		_apply_bone(left_yaw_mapped, right_yaw_mapped, pitch_mapped)
	elif look_at_data.type == "expression" and expression_controller:
		# Per spec, expressions have no inner/outer distinction (both eyes move together
		# in one expression) - always use the Outer map.
		var yaw_mapped: float = _map_range(yaw, look_at_data.range_map_horizontal_outer)
		_apply_expression(yaw_mapped, pitch_mapped)


func _map_range(value: float, range_map: Vrm1LookAtRangeMap) -> float:
	if not range_map:
		return 0.0
	var sign_val: float = sign(value)
	var abs_val: float = abs(value)
	var factor: float = clampf(abs_val / max(range_map.input_max_value, 0.001), 0.0, 1.0)
	return factor * range_map.output_scale * sign_val


func _apply_bone(left_yaw_mapped: float, right_yaw_mapped: float, pitch_mapped: float) -> void:
	_apply_eye(_left_eye_bone_idx, left_yaw_mapped, pitch_mapped)
	_apply_eye(_right_eye_bone_idx, right_yaw_mapped, pitch_mapped)


## Turns one eye by yaw/pitch (degrees) on top of its rest pose. The turn is measured in the
## model's axes (VRM 1.0 faces +Z, so yaw > 0 swings the gaze toward +X, the avatar's left,
## and pitch > 0 lifts it toward +Y), not in the eye bone's own local axes: exporters leave
## eye bones with arbitrary rest rotations (Blender's eye.L/eye.R point along their bone
## roll), and writing the bare yaw/pitch rotation as the pose would throw that rest away and
## spin the eye. Expressed in the bone's local frame the model-axes turn D becomes
## rest_local * E^-1 * D * E, with E the eye's rest rotation in skeleton space; at 0/0 that
## is exactly the rest rotation.
func _apply_eye(bone_idx: int, yaw_deg: float, pitch_deg: float) -> void:
	if bone_idx < 0:
		return
	var turn := Quaternion.from_euler(Vector3(-deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0))
	var rest_local: Quaternion = skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()
	var rest_global: Quaternion = (
			skeleton.get_bone_global_rest(bone_idx).basis.get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(
			bone_idx, rest_local * rest_global.inverse() * turn * rest_global)


func _apply_expression(yaw_mapped: float, pitch_mapped: float) -> void:
	if yaw_mapped < 0.0:
		expression_controller.look_right = abs(yaw_mapped)
		expression_controller.look_left = 0.0
	else:
		expression_controller.look_left = abs(yaw_mapped)
		expression_controller.look_right = 0.0

	if pitch_mapped < 0.0:
		expression_controller.look_down = abs(pitch_mapped)
		expression_controller.look_up = 0.0
	else:
		expression_controller.look_up = abs(pitch_mapped)
		expression_controller.look_down = 0.0
