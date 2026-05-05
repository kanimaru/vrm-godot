@tool
class_name VmdAnimationLibraryBuilder
extends RefCounted


const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
const VmdBezier = preload("res://addons/vrm/vmd/vmd_bezier.gd")


# MMD Bone Name (Japanese) -> VRM Humanoid Bone Name (camelCase)
const BONE_MAP: Dictionary[String, String] = {
	# 全ての親 intentionally excluded — it drives world locomotion (ModelRoot), not hips bone
	"センター": "hips",
	"グルーブ": "hips",
	"下半身": "hips",
	"上半身": "spine",
	"上半身2": "chest",
	"上半身3": "upperChest",
	"首": "neck",
	"頭": "head",
	"左肩": "leftShoulder",
	"左腕": "leftUpperArm",
	"左ひじ": "leftLowerArm",
	"左手首": "leftHand",
	"右肩": "rightShoulder",
	"右腕": "rightUpperArm",
	"右ひじ": "rightLowerArm",
	"右手首": "rightHand",
	"左足": "leftUpperLeg",
	"左ひざ": "leftLowerLeg",
	"左足首": "leftFoot",
	"左つま先": "leftToes",
	"右足": "rightUpperLeg",
	"右ひざ": "rightLowerLeg",
	"右足首": "rightFoot",
	"右つま先": "rightToes",
	"左目": "leftEye",
	"右目": "rightEye",
}

# Among hips-mapped bones, only these contribute POSITION (センター bounce/sway).
# 下半身 (lower body) is a rotation-only divider and must not add position.
const HIP_POSITION_BONES: Array[String] = ["センター", "グルーブ"]


# Among hips-mapped bones, only these contribute ROTATION.
const HIP_ROTATION_BONES: Array[String] = ["センター", "グルーブ", "下半身"]

# The MMD global root bone that drives world locomotion.
# This maps to a dedicated %ModelRoot track rather than the hips bone.
const ROOT_PARENT_BONE: String = "全ての親"
const MODEL_ROOT_VRM_NAME: String = "ModelRoot"


# MMD Morph Name (Japanese) -> VRM Expression Name (camelCase)
const MORPH_MAP: Dictionary[String, String] = {
	"真面目": "neutral",
	"にっこり": "happy",
	"困る": "sad",
	"怒り": "angry",
	"上": "lookUp",
	"下": "lookDown",
	"左": "lookLeft",
	"右": "lookRight",
	"まばたき": "blink",
	"笑い": "happy",
	"あ": "aa",
	"い": "ih",
	"う": "ou",
	"え": "ee",
	"お": "oh",
}


# Simplified Finger Mapping
static func _setup_finger_map(m: Dictionary[String, String]) -> void:
	var sides: Array[String] = ["左", "右"]
	var vrm_sides: Array[String] = ["left", "right"]
	var fingers: Array[String] = ["親指", "人指", "中指", "薬指", "小指"]
	var vrm_fingers: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Little"]
	var joints: Array[String] = ["１", "２", "３"]
	var vrm_joints: Array[String] = ["Proximal", "Intermediate", "Distal"]

	for s in range(2):
		for f in range(5):
			for j in range(3):
				var mmd_name: String = sides[s] + fingers[f] + joints[j]
				var vrm_joint: String = vrm_joints[j]
				if vrm_fingers[f] == "Thumb":
					vrm_joint = (["Metacarpal", "Proximal", "Distal"] as Array[String])[j]
				var vrm_name: String = vrm_sides[s] + vrm_fingers[f] + vrm_joint
				m[mmd_name] = vrm_name


static func build(data: VmdParser.VmdData, _fps: float = 30.0, camera_y_offset: float = 0.0, a_pose_to_t_pose: bool = true, position_scale: float = 0.08) -> AnimationLibrary:
	var library: AnimationLibrary = AnimationLibrary.new()
	var anim: Animation = Animation.new()
	var time_scale: float = 1.0 / 30.0

	var bone_map_full: Dictionary = BONE_MAP.duplicate()
	_setup_finger_map(bone_map_full)

	var max_frame: int = 0

	# 1. Group Bone Frames
	var bone_frames_map: Dictionary[String, Array] = {}
	for f: VmdParser.VmdBoneFrame in data.bone_frames:
		if not bone_frames_map.has(f.name):
			bone_frames_map[f.name] = []
		bone_frames_map[f.name].append(f)
		max_frame = max(max_frame, f.frame)

	# 1. Map and Merge Bone Frames
	# 全ての親 (Root Parent) drives world locomotion and gets its OWN ModelRoot track.
	# センター + グルーブ contribute position+rotation to hips.
	# 下半身 contributes rotation-only to hips.
	var vrm_contributors: Dictionary[String, Array] = {} # VRM_Name -> Array[MMD_Name]
	for mmd_name: String in bone_frames_map:
		var vrm_name: String
		if mmd_name == ROOT_PARENT_BONE:
			vrm_name = MODEL_ROOT_VRM_NAME
		elif mmd_name == "左足ＩＫ":
			vrm_name = "leftLegIk"
		elif mmd_name == "右足ＩＫ":
			vrm_name = "rightLegIk"
		elif mmd_name == "左つま先ＩＫ":
			vrm_name = "leftToeIk"
		elif mmd_name == "右つま先ＩＫ":
			vrm_name = "rightToeIk"
		else:
			vrm_name = bone_map_full.get(mmd_name, "")
		if vrm_name == "": continue
		if not vrm_contributors.has(vrm_name): vrm_contributors[vrm_name] = []
		(vrm_contributors[vrm_name] as Array).append(mmd_name)

	# 2. Map and Merge Bone Frames with Interpolation
	var merged_bone_data: Dictionary = {} # VRM_Name -> { frame_idx -> { pos: Vector3, rot: Quaternion } }

	for vrm_name: String in vrm_contributors:
		var mmd_names: Array = vrm_contributors[vrm_name]
		var all_frames: Array[int] = []
		var mmd_bone_tracks: Dictionary[String, Array] = {} # MMD_Name -> Sorted Frames Array

		for mmd_name: String in mmd_names:
			var frames: Array = bone_frames_map[mmd_name]
			frames.sort_custom(func(a: VmdParser.VmdBoneFrame, b: VmdParser.VmdBoneFrame) -> bool: return a.frame < b.frame)
			mmd_bone_tracks[mmd_name] = frames
			for f: VmdParser.VmdBoneFrame in frames:
				if not f.frame in all_frames: all_frames.append(f.frame)

		all_frames.sort()
		merged_bone_data[vrm_name] = {}

		for frame_idx: int in all_frames:
			var total_pos: Vector3 = Vector3.ZERO
			var total_rot: Quaternion = Quaternion.IDENTITY

			for mmd_name: String in mmd_names:
				var frames: Array = mmd_bone_tracks[mmd_name]
				# Sample/Interpolate MMD bone at frame_idx
				var sampled_pos: Vector3 = Vector3.ZERO
				var sampled_rot: Quaternion = Quaternion.IDENTITY

				if frames.size() > 0:
					var found: bool = false
					for i: int in range(frames.size()):
						var frame: VmdParser.VmdBoneFrame = frames[i]
						if frame.frame == frame_idx:
							sampled_pos = frames[i].position * position_scale
							sampled_rot = frames[i].rotation
							found = true
							break
						elif frames[i].frame > frame_idx:
							# Interpolate
							if i > 0:
								var prev: VmdParser.VmdBoneFrame = frames[i - 1]
								var next: VmdParser.VmdBoneFrame = frames[i]
								var t: float = float(frame_idx - prev.frame) / (next.frame - prev.frame)
								# Simplified linear for merge sampling
								sampled_pos = prev.position.lerp(next.position, t) * position_scale
								sampled_rot = prev.rotation.slerp(next.rotation, t)
							else:
								sampled_pos = frames[0].position * position_scale
								sampled_rot = frames[0].rotation
							found = true
							break
					if not found:
						var last = frames.back()
						sampled_pos = last.position * position_scale
						sampled_rot = last.rotation

				# For hips, guard which bones contribute position vs rotation.
				# 下半身 (lower body) is rotation-only; 全ての親 is translation-only.
				var contributes_pos: bool = true
				var contributes_rot: bool = true
				if vrm_name == "hips":
					contributes_pos = mmd_name in HIP_POSITION_BONES
					contributes_rot = mmd_name in HIP_ROTATION_BONES

				if contributes_pos:
					total_pos += sampled_pos
				if contributes_rot:
					total_rot = total_rot * sampled_rot

			merged_bone_data[vrm_name][frame_idx] = {"pos": total_pos, "rot": total_rot}

	# 2. Calculate initial offsets for centering and grounding.
	# Horizontal Centering: Use Hips X,Z from first frame.
	# Vertical Grounding: Use ModelRoot (All Parent) Y from first frame.
	var initial_root_offset: Vector3 = Vector3.ZERO
	if merged_bone_data.has("hips"):
		var h_frames: Dictionary = merged_bone_data["hips"]
		var h_keys: Array[int] = []
		for k in h_frames.keys(): h_keys.append(k as int)
		h_keys.sort()
		if not h_keys.is_empty():
			initial_root_offset.x = h_frames[h_keys[0]].pos.x
			initial_root_offset.z = h_frames[h_keys[0]].pos.z

	if merged_bone_data.has(MODEL_ROOT_VRM_NAME):
		var r_frames: Dictionary = merged_bone_data[MODEL_ROOT_VRM_NAME]
		var r_keys: Array[int] = []
		for k in r_frames.keys(): r_keys.append(k as int)
		r_keys.sort()
		if not r_keys.is_empty():
			initial_root_offset.y = r_frames[r_keys[0]].pos.y

	# 3. Build Bone Tracks from merged data
	for vrm_name: String in merged_bone_data:
		var track_path: NodePath
		if vrm_name == MODEL_ROOT_VRM_NAME:
			track_path = NodePath("%ModelRoot")
		elif "Ik" in vrm_name:
			track_path = NodePath("%"+ vrm_name)
		else:
			track_path = NodePath("%GeneralSkeleton:"+ vrm_name)

		# ModelRoot is a Node3D locomotion target, not a skeleton bone.
		var is_model_root: bool = vrm_name == MODEL_ROOT_VRM_NAME

		# A-Pose to T-Pose correction (skeleton bones only)
		var pre_rot: Quaternion = Quaternion.IDENTITY
		if a_pose_to_t_pose and not is_model_root:
			if vrm_name == "leftShoulder":
				pre_rot = Quaternion(Vector3.FORWARD, deg_to_rad(10.0))
			elif vrm_name == "rightShoulder":
				pre_rot = Quaternion(Vector3.FORWARD, deg_to_rad(-10.0))
			elif vrm_name == "leftUpperArm":
				pre_rot = Quaternion(Vector3.FORWARD, deg_to_rad(20.0))
			elif vrm_name == "leftLowerArm":
				pre_rot = Quaternion(Vector3.LEFT, deg_to_rad(-50.0))
			elif vrm_name == "rightUpperArm":
				pre_rot = Quaternion(Vector3.FORWARD, deg_to_rad(-20.0))
			elif vrm_name == "rightLowerArm":
				pre_rot = Quaternion(Vector3.RIGHT, deg_to_rad(50.0))


		# ModelRoot only needs a POSITION track (world locomotion, consumed by root_motion_track).
		# All other bones get a rotation track.
		var rot_track: int = -1
		if not is_model_root:
			rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(rot_track, track_path)

		var pos_track: int = -1
		if is_model_root or vrm_name == "hips" or vrm_name == "Root" or "Ik" in vrm_name:
			pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pos_track, track_path)

		var vrm_frames: Dictionary = merged_bone_data[vrm_name]
		var frame_indices: Array[int] = []
		for k: Variant in vrm_frames.keys(): frame_indices.append(k as int)
		frame_indices.sort()

		for i: int in range(frame_indices.size()):
			var frame_idx: int = frame_indices[i]
			var data_at_frame: Dictionary = vrm_frames[frame_idx]

			if rot_track != -1:
				anim.track_insert_key(rot_track, frame_idx * time_scale, pre_rot * data_at_frame.rot)

			if pos_track != -1:
				var root_pos: Vector3 = Vector3.ZERO
				if merged_bone_data.has(MODEL_ROOT_VRM_NAME) and merged_bone_data[MODEL_ROOT_VRM_NAME].has(frame_idx):
					root_pos = merged_bone_data[MODEL_ROOT_VRM_NAME][frame_idx].pos

				var final_p: Vector3
				if vrm_name == MODEL_ROOT_VRM_NAME:
					# Locomotion track: center character at start
					final_p = data_at_frame.pos - initial_root_offset
				else:
					# Other tracks: VMD positions are deltas from rest.
					# We keep them raw so they can be added to the Godot rest pose.
					final_p = data_at_frame.pos
				anim.track_insert_key(pos_track, frame_idx * time_scale, final_p)

			# Interpolation (linear fallback for merged keys)
			if i + 1 < frame_indices.size():
				var next_frame_idx: int = frame_indices[i + 1]
				var frame_diff: int = next_frame_idx - frame_idx
				if frame_diff > 1:
					var next_data: Dictionary = vrm_frames[next_frame_idx]
					for j: int in range(1, frame_diff):
						var t: float = float(j) / frame_diff
						var sub_frame: int = frame_idx + j

						if rot_track != -1:
							var sampled_q: Quaternion = data_at_frame.rot.slerp(next_data.rot, t)
							anim.track_insert_key(rot_track, sub_frame * time_scale, pre_rot * sampled_q)

						if pos_track != -1:
							var sampled_p: Vector3 = data_at_frame.pos.lerp(next_data.pos, t)
							var current_root_pos: Vector3 = Vector3.ZERO
							if merged_bone_data.has(MODEL_ROOT_VRM_NAME):
								# For simplicity, we'll lerp the root too
								var r_frames: Dictionary = merged_bone_data[MODEL_ROOT_VRM_NAME]
								var root_start: Vector3 = r_frames.get(frame_idx, {"pos": Vector3.ZERO}).pos
								var root_end: Vector3 = r_frames.get(next_frame_idx, {"pos": root_start}).pos
								current_root_pos = root_start.lerp(root_end, t)

							var final_p: Vector3
							if vrm_name == MODEL_ROOT_VRM_NAME:
								final_p = sampled_p - initial_root_offset
							else:
								# Pure delta interpolation
								final_p = sampled_p
							anim.track_insert_key(pos_track, sub_frame * time_scale, final_p)

	# 3. Build Camera Tracks
	if data.camera_frames.size() > 0:
		var camera_path: NodePath = NodePath("%VmdCamera")
		var cam_frames: Array = data.camera_frames.duplicate()
		cam_frames.sort_custom(func(a: VmdParser.VmdCameraFrame, b: VmdParser.VmdCameraFrame) -> bool: return a.frame < b.frame)

		var cam_pos_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(cam_pos_track, camera_path)

		var cam_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(cam_rot_track, camera_path)

		var cam_fov_track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(cam_fov_track, NodePath(str(camera_path) + ":fov"))

		for i: int in range(cam_frames.size()):
			var curr: VmdParser.VmdCameraFrame = cam_frames[i]

			# Insert keyframe at current time
			var curr_transform: Transform3D = _get_camera_transform(curr, camera_y_offset)
			anim.track_insert_key(cam_pos_track, curr.frame * time_scale, curr_transform.origin)
			anim.track_insert_key(cam_rot_track, curr.frame * time_scale, curr_transform.basis.get_rotation_quaternion())
			anim.track_insert_key(cam_fov_track, curr.frame * time_scale, curr.fov)

			# Sample interpolation if there's a next frame
			if i + 1 < cam_frames.size():
				var next: VmdParser.VmdCameraFrame = cam_frames[i + 1]
				var frame_diff: int = next.frame - curr.frame
				if frame_diff > 1:
					var curves: Array[VmdBezier] = _extract_camera_curves(next.interpolation)

					for f: int in range(1, frame_diff):
						var t: float = float(f) / frame_diff
						var sub_frame_idx: int = curr.frame + f

						# Sample individual components
						var ratio_x: float = curves[0].evaluate(t)
						var ratio_y: float = curves[1].evaluate(t)
						var ratio_z: float = curves[2].evaluate(t)
						var ratio_r: float = curves[3].evaluate(t)
						var ratio_d: float = curves[4].evaluate(t)
						var ratio_f: float = curves[5].evaluate(t)

						# Interpolate raw values
						var sampled_target: Vector3 = Vector3(
							lerp(curr.target_position.x, next.target_position.x, ratio_x),
							lerp(curr.target_position.y, next.target_position.y, ratio_y),
							lerp(curr.target_position.z, next.target_position.z, ratio_z)
						)
						var sampled_rot: Vector3 = Vector3(
							lerp_angle(curr.rotation.x, next.rotation.x, ratio_r),
							lerp_angle(curr.rotation.y, next.rotation.y, ratio_r),
							lerp_angle(curr.rotation.z, next.rotation.z, ratio_r)
						)
						var sampled_dist: float = lerp(curr.distance, next.distance, ratio_d)
						var sampled_fov: float = lerp(curr.fov, next.fov, ratio_f)

						# Create virtual frame to calculate transform
						var virtual_frame: VmdParser.VmdCameraFrame = VmdParser.VmdCameraFrame.new()
						virtual_frame.target_position = sampled_target
						virtual_frame.rotation = sampled_rot
						virtual_frame.distance = sampled_dist

						var trans: Transform3D = _get_camera_transform(virtual_frame, camera_y_offset)
						anim.track_insert_key(cam_pos_track, sub_frame_idx * time_scale, trans.origin)
						anim.track_insert_key(cam_rot_track, sub_frame_idx * time_scale, trans.basis.get_rotation_quaternion())
						anim.track_insert_key(cam_fov_track, sub_frame_idx * time_scale, sampled_fov)


	# 4. Process Morphs
	var morph_frames_map: Dictionary = {}
	for f: VmdParser.VmdMorphFrame in data.morph_frames:
		if not morph_frames_map.has(f.name):
			morph_frames_map[f.name] = []
		morph_frames_map[f.name].append(f)
		max_frame = max(max_frame, f.frame)

	for mmd_name: String in morph_frames_map:
		var vrm_expr: String = MORPH_MAP.get(mmd_name, mmd_name)
		var prop_name: String = vrm_expr.to_snake_case()
		var track_path: NodePath = NodePath("%Vrm1ExpressionController:"+ prop_name)

		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, track_path)

		var frames: Array = morph_frames_map[mmd_name]
		frames.sort_custom(func(a, b): return a.frame < b.frame)

		for f: VmdParser.VmdMorphFrame in frames:
			anim.track_insert_key(track, f.frame * time_scale, f.weight)

	anim.length = max_frame * time_scale
	library.add_animation("default", anim)
	return library


static func _get_camera_transform(frame: VmdParser.VmdCameraFrame, y_offset: float = 0.0) -> Transform3D:
	# MMD Camera is Target-based:
	# - Target position (X, Y, Z)
	# - Rotation (Euler Radians)
	# - Distance (Float)
	# Mapping MMD Left-Handed to Godot Right-Handed:
	# MMD Z+ is Forward, Godot Z- is Forward.
	# To preserve visual rotation directions:
	# Pitch (X) and Yaw (Y) must be inverted, Roll (Z) stays the same.
	var euler: Vector3 = Vector3(-frame.rotation.x, -frame.rotation.y, frame.rotation.z)
	var basis: Basis = Basis.from_euler(euler, EULER_ORDER_YXZ)

	# MMD Target: Z is already flipped in parser. Scale by 0.1 as per project spec.
	var target: Vector3 = frame.target_position * 0.1

	# Apply Y offset in meters (after scaling)
	target.y += y_offset

	# MMD distance is distance AWAY from target, and typically negative in VMD files.
	# In Godot, Camera looks at -Z, so the 'back' vector is +Z.
	var pos: Vector3 = target + (basis * Vector3(0, 0, -frame.distance * 0.1))

	return Transform3D(basis, pos)


static func _extract_camera_curves(data: PackedByteArray) -> Array[VmdBezier]:
	var curves: Array[VmdBezier] = []
	# Camera interpolation is 24 bytes (6 curves of 4 bytes each)
	# Order: X-target, Y-target, Z-target, Rotation, Distance, FOV
	if data.size() < 24:
		for i: int in range(6): curves.append(VmdBezier.new(20, 20, 107, 107))
		return curves

	for i: int in range(6):
		var offset: int = i * 4
		curves.append(VmdBezier.new(data[offset], data[offset + 1], data[offset + 2], data[offset + 3]))
	return curves


static func _extract_curves(data: PackedByteArray) -> Array[VmdBezier]:
	var curves: Array[VmdBezier] = []
	if data.size() < 16:
		for i: int in range(4): curves.append(VmdBezier.new(20, 20, 107, 107)) # Linear fallback
		return curves

	for i: int in range(4):
		curves.append(VmdBezier.new(data[i], data[i + 4], data[i + 8], data[i + 12]))
	return curves
