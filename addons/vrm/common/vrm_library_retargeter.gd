@tool
class_name VrmLibraryRetargeter
extends RefCounted

## The FULL animation-library retarget for a concrete VRM model — the code that
## makes VMD (and standalone VRMA) actually fit an avatar. Extracted verbatim
## from vrm-plugin's runtime loader so every consumer (the runtime app, VBeami's
## ghost rig, future tools) shares ONE implementation instead of the
## rename-only VrmAnimationRetargeter node.
##
## What it does, per animation:
##  - renames %GeneralSkeleton bone tracks to the model's real bone names
##  - VRM0: remaps expression tracks to %Vrm0ExpressionController + VRM0 names
##  - conjugates every rotation key through the bone's world rest
##    (L_dst * W⁻¹ * q * W) so values fit this skeleton's axes
##  - VMD hips: FK-computes where the feet land each key and grounds the hips
##    height, scaling deltas by the model's leg length
##  - VRMA hips: proportional height-ratio scaling from the source rest
##  - IK target tracks: MMD-rest-relative deltas rotated into the model's frame
##
## Mutates the animations IN PLACE. Model must carry the VRM humanoid meta
## (and VRM0 data meta for VRM0 models); skeleton is found beneath it.

const VRMUtil = preload("vrm_util.gd")
static func retarget_library_for_model(library: AnimationLibrary, model: Node, is_vmd: bool = false) -> void:
	var skeleton: Skeleton3D = VRMUtil.find_skeleton(model)
	if skeleton == null: return
	var is_vrm0: bool = VRMUtil.is_vrm0(model)
	# The skeleton's turn within the model, up to and including the model's own (a VRM0
	# model faces backwards on its root). Not above it: whatever turns the model's parents
	# places the avatar in the scene and must not be folded into the clip's rests.
	var skeleton_rot: Quaternion = Quaternion.IDENTITY
	var root_node: Node = skeleton.get_parent()
	while root_node != null and root_node is Node3D:
		skeleton_rot = root_node.transform.basis.orthonormalized().get_rotation_quaternion() * skeleton_rot
		if root_node == model:
			break
		root_node = root_node.get_parent()
	var world_rests: Array[Transform3D] = []
	world_rests.resize(skeleton.get_bone_count())
	for i: int in range(skeleton.get_bone_count()):
		world_rests[i] = _compute_bone_world_rest(skeleton, i, skeleton_rot)

	# Resolve standard bone names to model's skeleton bone names for kinematics
	var hips_resolved_name: String = VRMUtil.find_bone(skeleton, model, "hips")
	var left_up_leg_name: String = VRMUtil.find_bone(skeleton, model, "leftUpperLeg")
	var left_low_leg_name: String = VRMUtil.find_bone(skeleton, model, "leftLowerLeg")
	var left_foot_name: String = VRMUtil.find_bone(skeleton, model, "leftFoot")
	var right_up_leg_name: String = VRMUtil.find_bone(skeleton, model, "rightUpperLeg")
	var right_low_leg_name: String = VRMUtil.find_bone(skeleton, model, "rightLowerLeg")
	var right_foot_name: String = VRMUtil.find_bone(skeleton, model, "rightFoot")

	# Find their indices in the skeleton
	var hips_idx: int = skeleton.find_bone(hips_resolved_name)
	var left_up_leg_idx: int = skeleton.find_bone(left_up_leg_name)
	var left_low_leg_idx: int = skeleton.find_bone(left_low_leg_name)
	var left_foot_idx: int = skeleton.find_bone(left_foot_name)
	var right_up_leg_idx: int = skeleton.find_bone(right_up_leg_name)
	var right_low_leg_idx: int = skeleton.find_bone(right_low_leg_name)
	var right_foot_idx: int = skeleton.find_bone(right_foot_name)

	var can_do_kinematics: bool = (
		hips_idx >= 0 and
		left_up_leg_idx >= 0 and left_low_leg_idx >= 0 and left_foot_idx >= 0 and
		right_up_leg_idx >= 0 and right_low_leg_idx >= 0 and right_foot_idx >= 0
	)

	for anim_name: StringName in library.get_animation_list():
		var anim: Animation = library.get_animation(anim_name)

		var hips_pos_key0 := Vector3.ZERO
		if is_vmd:
			var raw_hips_track := anim.find_track(NodePath("%GeneralSkeleton:hips"), Animation.TYPE_POSITION_3D)
			if raw_hips_track >= 0 and anim.track_get_key_count(raw_hips_track) > 0:
				hips_pos_key0 = anim.track_get_key_value(raw_hips_track, 0)

		# Shared translation scale for VMD: the hips grounding scales its deltas
		# to this model's leg length (S below) — the IK targets must move by the
		# SAME factor or hips and feet drift apart as the dance travels.
		var vmd_translation_scale: float = 1.0
		if is_vmd and can_do_kinematics:
			var hips_rest_y: float = skeleton.get_bone_rest(hips_idx).origin.y
			var l_fy: float = _compute_bone_world_rest(skeleton, left_foot_idx, Quaternion.IDENTITY).origin.y
			var r_fy: float = _compute_bone_world_rest(skeleton, right_foot_idx, Quaternion.IDENTITY).origin.y
			vmd_translation_scale = maxf((hips_rest_y - 0.5 * (l_fy + r_fy)) / 0.9, 0.001)
			if library.has_meta(&"pre_scaled") and library.get_meta(&"pre_scaled"):
				vmd_translation_scale = 1.0

		# Pass 1: Rename and retarget all rotation tracks first
		for i: int in range(anim.get_track_count()):
			var path_str: String = str(anim.track_get_path(i))
			if "Vrm1ExpressionController:" in path_str and is_vrm0:
				var prop_name: String = path_str.split(":")[1]
				var target_prop: String = VrmConstants.EXPRESSION_VRM1_TO_VRM0.get(prop_name, prop_name)
				anim.track_set_path(i, NodePath("%Vrm0ExpressionController:"+ target_prop))
				continue

			var is_ik: bool = "leftLegIk" in path_str or "rightLegIk" in path_str
			var is_root: bool = "%ModelRoot" in path_str
			if not "%GeneralSkeleton:" in path_str and not is_ik and not is_root: continue

			var bone_name: String = ""
			if is_root:
				bone_name = "hips" # Use hips as proxy for root orientation
			elif is_ik:
				bone_name = "leftFoot" if "leftLegIk" in path_str else "rightFoot"
			else:
				bone_name = path_str.split(":")[1]

			var resolved_name: String = VRMUtil.find_bone(skeleton, model, bone_name)
			if resolved_name.is_empty() and not is_root: continue

			if not is_ik and not is_root and resolved_name != bone_name:
				var parts: PackedStringArray = path_str.split(":")
				if parts.size() > 1:
					parts[1] = resolved_name
					anim.track_set_path(i, NodePath(":".join(parts)))
					path_str = str(anim.track_get_path(i))

			if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				var bone_idx: int = skeleton.find_bone(resolved_name)
				if bone_idx >= 0 or is_root:
					var W_dst_node: Transform3D = world_rests[bone_idx] if bone_idx >= 0 else Transform3D(Basis(skeleton_rot), Vector3.ZERO)
					var W_dst_q: Quaternion = W_dst_node.basis.get_rotation_quaternion()
					var W_dst_q_inv: Quaternion = W_dst_q.inverse()
					var L_dst: Quaternion = Quaternion.IDENTITY
					if bone_idx >= 0:
						L_dst = skeleton.get_bone_rest(bone_idx).basis.orthonormalized().get_rotation_quaternion()

					for k: int in range(anim.track_get_key_count(i)):
						var nlr: Quaternion = anim.track_get_key_value(i, k)
						if is_vmd:
							if is_root or is_ik:
								anim.track_set_key_value(i, k, nlr)
							else:
								anim.track_set_key_value(i, k, L_dst * W_dst_q_inv * nlr * W_dst_q)
						else:
							anim.track_set_key_value(i, k, L_dst * W_dst_q_inv * nlr * W_dst_q)

		# Find the rotation track indices for kinematics in this animation
		var track_hips_rot: int = -1
		var track_l_up_leg_rot: int = -1
		var track_l_low_leg_rot: int = -1
		var track_r_up_leg_rot: int = -1
		var track_r_low_leg_rot: int = -1

		if is_vmd and can_do_kinematics:
			var skeleton_path: String = "%GeneralSkeleton:"
			track_hips_rot = anim.find_track(NodePath(skeleton_path + hips_resolved_name), Animation.TYPE_ROTATION_3D)
			track_l_up_leg_rot = anim.find_track(NodePath(skeleton_path + left_up_leg_name), Animation.TYPE_ROTATION_3D)
			track_l_low_leg_rot = anim.find_track(NodePath(skeleton_path + left_low_leg_name), Animation.TYPE_ROTATION_3D)
			track_r_up_leg_rot = anim.find_track(NodePath(skeleton_path + right_up_leg_name), Animation.TYPE_ROTATION_3D)
			track_r_low_leg_rot = anim.find_track(NodePath(skeleton_path + right_low_leg_name), Animation.TYPE_ROTATION_3D)


		# Pass 2: Rename and retarget all position tracks
		for i: int in range(anim.get_track_count()):
			var path_str: String = str(anim.track_get_path(i))
			if "Vrm1ExpressionController:" in path_str and is_vrm0:
				continue

			var is_ik: bool = "leftLegIk" in path_str or "rightLegIk" in path_str
			var is_root: bool = "%ModelRoot" in path_str
			if not "%GeneralSkeleton:" in path_str and not is_ik and not is_root: continue

			var bone_name: String = ""
			if is_root:
				bone_name = "hips"
			elif is_ik:
				bone_name = "leftFoot" if "leftLegIk" in path_str else "rightFoot"
			else:
				bone_name = path_str.split(":")[1]

			var resolved_name: String = VRMUtil.find_bone(skeleton, model, bone_name)
			if resolved_name.is_empty() and not is_root: continue

			if not is_ik and not is_root and resolved_name != bone_name:
				var parts: PackedStringArray = path_str.split(":")
				if parts.size() > 1:
					parts[1] = resolved_name
					anim.track_set_path(i, NodePath(":".join(parts)))
					path_str = str(anim.track_get_path(i))

			if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				var bone_idx: int = skeleton.find_bone(resolved_name)
				if bone_idx >= 0 or is_root:
					var W_dst_node: Transform3D = world_rests[bone_idx] if bone_idx >= 0 else Transform3D(Basis(skeleton_rot), Vector3.ZERO)
					var W_dst_inv_basis: Basis = W_dst_node.basis.inverse()

					var local_rest: Vector3 = Vector3.ZERO
					if is_vmd:
						if is_root:
							local_rest = Vector3.ZERO
						elif is_ik:
							local_rest = world_rests[bone_idx].origin
						else:
							local_rest = skeleton.get_bone_rest(bone_idx).origin
					elif bone_idx >= 0:
						if not is_ik:
							local_rest = skeleton.get_bone_rest(bone_idx).origin
						else:
							local_rest = world_rests[bone_idx].origin

					if is_vmd and bone_idx == hips_idx and can_do_kinematics:
						# VMD: FK-based grounding — compute where feet land
						# and use that to anchor the hips height.
						var T_left_up_leg_rest: Transform3D = skeleton.get_bone_rest(left_up_leg_idx)
						var T_left_low_leg_rest: Transform3D = skeleton.get_bone_rest(left_low_leg_idx)
						var T_left_foot_rest: Transform3D = skeleton.get_bone_rest(left_foot_idx)

						var T_right_up_leg_rest: Transform3D = skeleton.get_bone_rest(right_up_leg_idx)
						var T_right_low_leg_rest: Transform3D = skeleton.get_bone_rest(right_low_leg_idx)
						var T_right_foot_rest: Transform3D = skeleton.get_bone_rest(right_foot_idx)

						var left_foot_skel_rest_y: float = _compute_bone_world_rest(skeleton, left_foot_idx, Quaternion.IDENTITY).origin.y
						var right_foot_skel_rest_y: float = _compute_bone_world_rest(skeleton, right_foot_idx, Quaternion.IDENTITY).origin.y

						var q_hips_rest: Quaternion = skeleton.get_bone_rest(hips_idx).basis.get_rotation_quaternion()
						var q_l_up_rest: Quaternion = T_left_up_leg_rest.basis.get_rotation_quaternion()
						var q_l_low_rest: Quaternion = T_left_low_leg_rest.basis.get_rotation_quaternion()
						var q_r_up_rest: Quaternion = T_right_up_leg_rest.basis.get_rotation_quaternion()
						var q_r_low_rest: Quaternion = T_right_low_leg_rest.basis.get_rotation_quaternion()

						var target_leg_length: float = local_rest.y - 0.5 * (left_foot_skel_rest_y + right_foot_skel_rest_y)
						var S: float = maxf(target_leg_length / 0.9, 0.001)
						if library.has_meta(&"pre_scaled") and library.get_meta(&"pre_scaled"):
							S = 1.0

						var pos_key0 := Vector3.ZERO
						if anim.track_get_key_count(i) > 0:
							pos_key0 = anim.track_get_key_value(i, 0)

						# Does this clip drive the legs through IK targets? If so
						# the FK leg rotation keys are junk: MMD ignores FK keys
						# on IK-controlled bones, and motion files carry baked
						# residue there. Grounding the hips against that residue
						# PER KEY made the base height flutter at key rate — the
						# whole body bobbed against the fixed floor targets, and
						# whenever the flutter pushed the hips out of leg reach
						# the IK could only stretch: feet hovering and jumping.
						# With rest leg rotations the grounding formula collapses
						# to exactly the hips rest height, so IK-driven clips use
						# local_rest.y as the base and let the センター deltas
						# (scaled by S below) carry every authored dip and jump.
						# FK-only clips keep the per-key grounding: there the FK
						# keys ARE the motion, and grounding them plants the feet.
						var has_leg_ik := false
						for j: int in range(anim.get_track_count()):
							var p_j: String = str(anim.track_get_path(j))
							if (anim.track_get_type(j) == Animation.TYPE_POSITION_3D
									and ("leftLegIk" in p_j or "rightLegIk" in p_j)):
								has_leg_ik = true
								break

						for k: int in range(anim.track_get_key_count(i)):
							var pos: Vector3 = anim.track_get_key_value(i, k)
							var delta_pos: Vector3 = pos - pos_key0

							var y_grounded: float = local_rest.y
							if not has_leg_ik:
								var Q_hips: Quaternion = _get_track_rotation_at_key(anim, track_hips_rot, k, q_hips_rest)
								var Q_left_up_leg: Quaternion = _get_track_rotation_at_key(anim, track_l_up_leg_rot, k, q_l_up_rest)
								var Q_left_low_leg: Quaternion = _get_track_rotation_at_key(anim, track_l_low_leg_rot, k, q_l_low_rest)
								var Q_right_up_leg: Quaternion = _get_track_rotation_at_key(anim, track_r_up_leg_rot, k, q_r_up_rest)
								var Q_right_low_leg: Quaternion = _get_track_rotation_at_key(anim, track_r_low_leg_rot, k, q_r_low_rest)

								var T_left_low_pose := Transform3D(Basis(Q_left_low_leg), T_left_low_leg_rest.origin)
								var T_left_up_pose := Transform3D(Basis(Q_left_up_leg), T_left_up_leg_rest.origin)
								var v_left_hips: Vector3 = T_left_up_pose * (T_left_low_pose * T_left_foot_rest.origin)

								var T_right_low_pose := Transform3D(Basis(Q_right_low_leg), T_right_low_leg_rest.origin)
								var T_right_up_pose := Transform3D(Basis(Q_right_up_leg), T_right_up_leg_rest.origin)
								var v_right_hips: Vector3 = T_right_up_pose * (T_right_low_pose * T_right_foot_rest.origin)

								var y_hips_left: float = left_foot_skel_rest_y - (Basis(Q_hips) * v_left_hips).y
								var y_hips_right: float = right_foot_skel_rest_y - (Basis(Q_hips) * v_right_hips).y
								y_grounded = maxf(y_hips_left, y_hips_right)

							# MMD → Godot translations are a Z-MIRROR (x, y, −z): the single-
							# axis mirror that converts left-handed MMD to right-handed
							# Godot, with X preserved (MMD left = Godot left = +X;
							# empirically settled — flipping X swapped the legs across the
							# body). ONE convention for hips AND IK targets, every facing,
							# so they keep the authored relationship.
							#
							# Downward center motion MUST pass through: an MMD knee bend
							# is authored as the center dipping while the planted IK
							# targets stay on the floor — the IK folds the legs between
							# them. Clamping negative Y kept the hips high, put the
							# floor targets out of the straight legs' reach, and the
							# solver could only stretch: straight knees, feet hovering.
							var godot_delta := Vector3(delta_pos.x, delta_pos.y, -delta_pos.z)
							var local_delta: Vector3 = Basis(skeleton_rot).inverse() * godot_delta

							var final_pos := Vector3(
								local_rest.x + S * local_delta.x,
								y_grounded + S * local_delta.y,
								local_rest.z + S * local_delta.z,
							)
							anim.track_set_key_value(i, k, final_pos)

					elif not is_vmd and bone_idx == hips_idx and anim.has_meta(&"vrma_hips_rest_pos"):
						# VRMA: proportional height-ratio scaling.
						# The builder stored (pos - vrma_rest) so each key is already
						# a delta from the source T-pose — no frame-0 bias.
						var vrma_hips_rest_y: float = (anim.get_meta(&"vrma_hips_rest_pos") as Vector3).y
						var target_hips_world_y: float = world_rests[hips_idx].origin.y
						var height_ratio: float = (
							target_hips_world_y / vrma_hips_rest_y
							if absf(vrma_hips_rest_y) > 0.001 else 1.0
						)

						for k: int in range(anim.track_get_key_count(i)):
							var delta: Vector3 = anim.track_get_key_value(i, k)
							var scaled_delta: Vector3 = delta * height_ratio
							var local_delta: Vector3 = Basis(skeleton_rot).inverse() * scaled_delta
							var final_pos := Vector3(
								local_rest.x + local_delta.x,
								local_rest.y + local_delta.y,
								local_rest.z + local_delta.z,
							)
							anim.track_set_key_value(i, k, final_pos)

					else:
						for k: int in range(anim.track_get_key_count(i)):
							var pos: Vector3 = anim.track_get_key_value(i, k)
							var final_pos: Vector3 = local_rest
							if is_root:
								final_pos += pos
							elif is_ik:
								if is_vmd:
									var horizontal_offset := Vector3(hips_pos_key0.x, 0.0, hips_pos_key0.z)
									# The VMD builder emits DELTAS from each bone's rest (see
									# vmd_animation_library_builder: "VMD positions are deltas from
									# rest") - there is no MMD stance offset in the data. The old
									# +/-1.83-unit "MMD rest" subtraction injected a fake ~0.15 m
									# stance offset that nothing cancelled: too-wide or crossed feet,
									# depending on the X convention of the day. Each foot must land
									# on its own world rest at the neutral stance.
									var delta := pos - horizontal_offset
									# MMD → Godot for a WORLD-space marker: Z-MIRROR (x, y, −z),
									# the same convention and leg-length scale as the hips
									# grounding, so hips and feet keep the authored relationship.
									# X preserved — flipping it swaps each leg across the body.
									# (In MMD the leg IK bones are children of 全ての親,
									# root-space — independent of センター/hips — so the data
									# itself keeps them aligned; the retarget must not tear
									# them.) The old skeleton_rot rotation made the mapping
									# facing-dependent: opposed Z on VRM1 = hips visibly ahead
									# of the feet.
									var world_delta := Vector3(delta.x, delta.y, -delta.z) * vmd_translation_scale
									final_pos = local_rest + world_delta
								else:
									final_pos += pos
							else:
								var godot_delta := Vector3(pos.x, pos.y, -pos.z)
								if not is_vmd:
									var parent_idx: int = skeleton.get_bone_parent(bone_idx)
									var parent_basis: Basis = world_rests[parent_idx].basis if parent_idx >= 0 else Basis(skeleton_rot)
									final_pos += parent_basis.inverse() * godot_delta
								else:
									final_pos += W_dst_inv_basis * godot_delta
							anim.track_set_key_value(i, k, final_pos)


static func _compute_bone_world_rest(skeleton: Skeleton3D, bone_idx: int, skeleton_rot: Quaternion) -> Transform3D:
	var rest: Transform3D = skeleton.get_bone_rest(bone_idx)
	var parent: int = skeleton.get_bone_parent(bone_idx)
	while parent >= 0:
		rest = skeleton.get_bone_rest(parent) * rest
		parent = skeleton.get_bone_parent(parent)
	return Transform3D(Basis(skeleton_rot), Vector3.ZERO) * rest


static func _get_track_rotation_at_key(anim: Animation, track_idx: int, key_idx: int, default_rot: Quaternion) -> Quaternion:
	if track_idx >= 0 and anim.track_get_key_count(track_idx) > 0:
		var idx := clampi(key_idx, 0, anim.track_get_key_count(track_idx) - 1)
		var val = anim.track_get_key_value(track_idx, idx)
		if val is Quaternion:
			return val
	return default_rot

