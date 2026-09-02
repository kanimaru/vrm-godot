@tool
class_name VmdAnimationLibraryBuilder
extends RefCounted

## Converts parsed [VmdParser.VmdData] into a Godot [AnimationLibrary].
##
## Bone and morph names are translated from MMD Japanese to VRM humanoid names,
## multiple contributing MMD bones are merged per frame, interpolation curves
## are expanded into per-frame keyframes, and A-Pose → T-Pose corrections are
## applied to shoulder and arm bones when requested.


const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
const VmdFormat = preload("res://addons/vrm/vmd/vmd_format.gd")
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

## Among hips-mapped bones, only these contribute POSITION (センター bounce/sway).
## 下半身 (lower body) is a rotation-only divider and must not add position.
const HIP_POSITION_BONES: Array[String] = ["センター", "グルーブ"]

## Among hips-mapped bones, only these contribute ROTATION.
const HIP_ROTATION_BONES: Array[String] = ["センター", "グルーブ", "下半身"]

## The MMD global root bone that drives world locomotion.
## This maps to a dedicated %ModelRoot track rather than the hips bone.
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


## Populates [param bone_name_map] with finger bone name translations.
##
## Generates every combination of side (left/right), finger (thumb through
## little), and joint (proximal/intermediate/distal) and inserts a mapping
## from the MMD Japanese compound name to the VRM camelCase bone name.
static func _setup_finger_map(bone_name_map: Dictionary[String, String]) -> void:
	var sides: Array[String] = ["左", "右"]
	var vrm_sides: Array[String] = ["left", "right"]
	var fingers: Array[String] = ["親指", "人指", "中指", "薬指", "小指"]
	var vrm_fingers: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Little"]
	var joints: Array[String] = ["１", "２", "３"]
	var vrm_joints: Array[String] = ["Proximal", "Intermediate", "Distal"]

	for side_idx: int in range(2):
		for finger_idx: int in range(5):
			for joint_idx: int in range(3):
				var mmd_name: String = sides[side_idx] + fingers[finger_idx] + joints[joint_idx]
				var vrm_joint: String = vrm_joints[joint_idx]
				if vrm_fingers[finger_idx] == "Thumb":
					vrm_joint = (["Metacarpal", "Proximal", "Distal"] as Array[String])[joint_idx]
				var vrm_name: String = vrm_sides[side_idx] + vrm_fingers[finger_idx] + vrm_joint
				bone_name_map[mmd_name] = vrm_name


## Builds an [AnimationLibrary] containing a single [code]"default"[/code]
## [Animation] from the given [VmdParser.VmdData].
##
## [param data]             — Parsed VMD data to convert.[br]
## [param _fps]             — Reserved; the VMD timeline is always 30 fps.[br]
## [param camera_y_offset]  — Metres to add to the camera target Y position.[br]
## [param a_pose_to_t_pose] — When [code]true[/code], applies shoulder/arm
##                            corrective rotations to convert A-Pose to T-Pose.[br]
## [param position_scale]   — Scale factor applied to VMD bone positions.
static func build(
		data: VmdFormat.VmdData,
		_fps: float = 30.0,
		camera_y_offset: float = 0.0,
		a_pose_to_t_pose: bool = true,
		position_scale: float = 0.08
) -> AnimationLibrary:
	var library: AnimationLibrary = AnimationLibrary.new()
	var anim: Animation = Animation.new()
	var time_scale: float = 1.0 / 30.0

	var bone_map_full: Dictionary = BONE_MAP.duplicate()
	_setup_finger_map(bone_map_full)

	var max_frame: int = 0

	# 1. Group Bone Frames by MMD bone name.
	var bone_frames_map: Dictionary[String, Array] = {}
	for bone_frame: VmdFormat.VmdBoneFrame in data.bone_frames:
		if not bone_frames_map.has(bone_frame.name):
			bone_frames_map[bone_frame.name] = []
		bone_frames_map[bone_frame.name].append(bone_frame)
		max_frame = max(max_frame, bone_frame.frame)

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
			frames.sort_custom(
				func(frame_a: VmdFormat.VmdBoneFrame, frame_b: VmdFormat.VmdBoneFrame) -> bool:
					return frame_a.frame < frame_b.frame
			)
			mmd_bone_tracks[mmd_name] = frames
			for bone_frame: VmdFormat.VmdBoneFrame in frames:
				if not bone_frame.frame in all_frames: all_frames.append(bone_frame.frame)

		all_frames.sort()
		merged_bone_data[vrm_name] = {}

		for frame_idx: int in all_frames:
			var total_pos: Vector3 = Vector3.ZERO
			var total_rot: Quaternion = Quaternion.IDENTITY
			var frame_interp: PackedByteArray = PackedByteArray()

			for mmd_name: String in mmd_names:
				var frames: Array = mmd_bone_tracks[mmd_name]
				# Sample/Interpolate MMD bone at frame_idx
				var sampled_pos: Vector3 = Vector3.ZERO
				var sampled_rot: Quaternion = Quaternion.IDENTITY
				var exact_interp: PackedByteArray = PackedByteArray()

				if frames.size() > 0:
					var found: bool = false
					for search_idx: int in range(frames.size()):
						var bone_frame: VmdFormat.VmdBoneFrame = frames[search_idx]
						if bone_frame.frame == frame_idx:
							sampled_pos = bone_frame.position * position_scale
							sampled_rot = bone_frame.rotation
							exact_interp = bone_frame.interpolation
							found = true
							break
						elif bone_frame.frame > frame_idx:
							# Interpolate between the previous key and this one
							# through THIS key's authored Bezier easing — MMD
							# stores each segment's curves on the arriving key.
							# The old linear shortcut here flattened every
							# ease-in/out that crossed a merge boundary.
							if search_idx > 0:
								var prev: VmdFormat.VmdBoneFrame = frames[search_idx - 1]
								var next: VmdFormat.VmdBoneFrame = frames[search_idx]
								var ft: float = (
									float(frame_idx - prev.frame) / (next.frame - prev.frame)
								)
								var curves: Array[VmdBezier] = _extract_curves(next.interpolation)
								sampled_pos = Vector3(
									lerpf(prev.position.x, next.position.x, curves[0].evaluate(ft)),
									lerpf(prev.position.y, next.position.y, curves[1].evaluate(ft)),
									lerpf(prev.position.z, next.position.z, curves[2].evaluate(ft)),
								) * position_scale
								sampled_rot = prev.rotation.slerp(next.rotation, curves[3].evaluate(ft))
							else:
								sampled_pos = frames[0].position * position_scale
								sampled_rot = frames[0].rotation
							found = true
							break
					if not found:
						var last_frame: VmdFormat.VmdBoneFrame = frames.back()
						sampled_pos = last_frame.position * position_scale
						sampled_rot = last_frame.rotation

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

				# Carry the easing for the segment ARRIVING at this key so the
				# track subdivision below can reproduce it. When several MMD
				# bones merge (hips), the position driver's curves win — an
				# approximation, but exact for the single-contributor majority.
				if not exact_interp.is_empty() and (frame_interp.is_empty() or contributes_pos):
					frame_interp = exact_interp

			merged_bone_data[vrm_name][frame_idx] = {
				"pos": total_pos,
				"rot": total_rot,
				"interp": frame_interp,
			}

	# 2. Calculate initial offsets for centering and grounding.
	# Horizontal Centering: Use Hips X,Z from first frame.
	# Vertical Grounding: Use ModelRoot (All Parent) Y from first frame.
	var initial_root_offset: Vector3 = Vector3.ZERO
	if merged_bone_data.has("hips"):
		var hips_frames: Dictionary = merged_bone_data["hips"]
		var hips_keys: Array[int] = []
		for key in hips_frames.keys(): hips_keys.append(key as int)
		hips_keys.sort()
		if not hips_keys.is_empty():
			initial_root_offset.x = hips_frames[hips_keys[0]].pos.x
			initial_root_offset.z = hips_frames[hips_keys[0]].pos.z

	if merged_bone_data.has(MODEL_ROOT_VRM_NAME):
		var root_frames: Dictionary = merged_bone_data[MODEL_ROOT_VRM_NAME]
		var root_keys: Array[int] = []
		for key in root_frames.keys(): root_keys.append(key as int)
		root_keys.sort()
		if not root_keys.is_empty():
			initial_root_offset.y = root_frames[root_keys[0]].pos.y

	# 3. Build Bone Tracks from merged data
	for vrm_name: String in merged_bone_data:
		var track_path: NodePath
		if vrm_name == MODEL_ROOT_VRM_NAME:
			track_path = NodePath("%ModelRoot")
		elif "Ik" in vrm_name:
			track_path = NodePath("%" + vrm_name)
		else:
			track_path = NodePath("%GeneralSkeleton:" + vrm_name)

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
		for key: Variant in vrm_frames.keys(): frame_indices.append(key as int)
		frame_indices.sort()

		for key_idx: int in range(frame_indices.size()):
			var frame_idx: int = frame_indices[key_idx]
			var data_at_frame: Dictionary = vrm_frames[frame_idx]

			if rot_track != -1:
				anim.track_insert_key(rot_track, frame_idx * time_scale, pre_rot * data_at_frame.rot)

			if pos_track != -1:
				var root_pos: Vector3 = Vector3.ZERO
				if (
					merged_bone_data.has(MODEL_ROOT_VRM_NAME)
					and merged_bone_data[MODEL_ROOT_VRM_NAME].has(frame_idx)
				):
					root_pos = merged_bone_data[MODEL_ROOT_VRM_NAME][frame_idx].pos

				var final_pos: Vector3
				if vrm_name == MODEL_ROOT_VRM_NAME:
					# Locomotion track: center character at start
					final_pos = data_at_frame.pos - initial_root_offset
				else:
					# Other tracks: VMD positions are deltas from rest.
					# We keep them raw so they can be added to the Godot rest pose.
					final_pos = data_at_frame.pos
				anim.track_insert_key(pos_track, frame_idx * time_scale, final_pos)

			# Subdivide each authored segment per frame THROUGH the segment's
			# Bezier easing (carried on the arriving key). The old linear bake
			# hard-coded constant velocity into dense keys: every authored
			# ease-in/out became a robotic move with a velocity snap at each
			# key — the "way too harsh" transitions.
			if key_idx + 1 < frame_indices.size():
				var next_frame_idx: int = frame_indices[key_idx + 1]
				var frame_diff: int = next_frame_idx - frame_idx
				if frame_diff > 1:
					var next_data: Dictionary = vrm_frames[next_frame_idx]
					var curves: Array[VmdBezier] = _extract_curves(
						next_data.get("interp", PackedByteArray()))
					for sub_step: int in range(1, frame_diff):
						var ft: float = float(sub_step) / frame_diff
						var sub_frame: int = frame_idx + sub_step

						if rot_track != -1:
							var sampled_q: Quaternion = data_at_frame.rot.slerp(
								next_data.rot, curves[3].evaluate(ft))
							anim.track_insert_key(rot_track, sub_frame * time_scale, pre_rot * sampled_q)

						if pos_track != -1:
							var a: Vector3 = data_at_frame.pos
							var b: Vector3 = next_data.pos
							var sampled_p := Vector3(
								lerpf(a.x, b.x, curves[0].evaluate(ft)),
								lerpf(a.y, b.y, curves[1].evaluate(ft)),
								lerpf(a.z, b.z, curves[2].evaluate(ft)),
							)
							var final_pos: Vector3 = (
								sampled_p - initial_root_offset
								if vrm_name == MODEL_ROOT_VRM_NAME
								else sampled_p
							)
							anim.track_insert_key(pos_track, sub_frame * time_scale, final_pos)

	# 3. Build Camera Tracks
	if data.camera_frames.size() > 0:
		var camera_path: NodePath = NodePath("%VmdCamera")
		var cam_frames: Array = data.camera_frames.duplicate()
		cam_frames.sort_custom(
			func(frame_a: VmdFormat.VmdCameraFrame, frame_b: VmdFormat.VmdCameraFrame) -> bool:
				return frame_a.frame < frame_b.frame
		)

		# Camera frames must count toward the animation length: a camera-only
		# .vmd has no bone/morph frames, so without this the length stayed at
		# ~0 and every sample clamped to the first key — a frozen camera.
		var last_cam_frame: VmdFormat.VmdCameraFrame = cam_frames.back()
		max_frame = maxi(max_frame, last_cam_frame.frame)

		var cam_pos_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(cam_pos_track, camera_path)

		var cam_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(cam_rot_track, camera_path)

		var cam_fov_track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(cam_fov_track, NodePath(str(camera_path) + ":fov"))

		for cam_idx: int in range(cam_frames.size()):
			var curr: VmdFormat.VmdCameraFrame = cam_frames[cam_idx]

			# Insert keyframe at current time
			var curr_transform: Transform3D = _get_camera_transform(curr, camera_y_offset, position_scale)
			anim.track_insert_key(cam_pos_track, curr.frame * time_scale, curr_transform.origin)
			anim.track_insert_key(cam_rot_track, curr.frame * time_scale, curr_transform.basis.get_rotation_quaternion())
			anim.track_insert_key(cam_fov_track, curr.frame * time_scale, curr.fov)

			# Sample interpolation if there's a next frame
			if cam_idx + 1 < cam_frames.size():
				var next: VmdFormat.VmdCameraFrame = cam_frames[cam_idx + 1]
				var frame_diff: int = next.frame - curr.frame
				if frame_diff > 1:
					var curves: Array[VmdBezier] = _extract_camera_curves(next.interpolation)

					for frame_step: int in range(1, frame_diff):
						var interp_factor: float = float(frame_step) / frame_diff
						var sub_frame_idx: int = curr.frame + frame_step

						# Sample individual components with per-axis Bezier curves.
						var ratio_x: float = curves[0].evaluate(interp_factor)
						var ratio_y: float = curves[1].evaluate(interp_factor)
						var ratio_z: float = curves[2].evaluate(interp_factor)
						var ratio_rot: float = curves[3].evaluate(interp_factor)
						var ratio_dist: float = curves[4].evaluate(interp_factor)
						var ratio_fov: float = curves[5].evaluate(interp_factor)

						# Interpolate raw values
						var sampled_target: Vector3 = Vector3(
							lerp(curr.target_position.x, next.target_position.x, ratio_x),
							lerp(curr.target_position.y, next.target_position.y, ratio_y),
							lerp(curr.target_position.z, next.target_position.z, ratio_z)
						)
						var sampled_rot: Vector3 = Vector3(
							lerp_angle(curr.rotation.x, next.rotation.x, ratio_rot),
							lerp_angle(curr.rotation.y, next.rotation.y, ratio_rot),
							lerp_angle(curr.rotation.z, next.rotation.z, ratio_rot)
						)
						var sampled_dist: float = lerp(curr.distance, next.distance, ratio_dist)
						var sampled_fov: float = lerp(curr.fov, next.fov, ratio_fov)

						# Create virtual frame to calculate transform
						var virtual_frame: VmdFormat.VmdCameraFrame = VmdFormat.VmdCameraFrame.new()
						virtual_frame.target_position = sampled_target
						virtual_frame.rotation = sampled_rot
						virtual_frame.distance = sampled_dist

						var interpolated_transform: Transform3D = _get_camera_transform(virtual_frame, camera_y_offset, position_scale)
						anim.track_insert_key(cam_pos_track, sub_frame_idx * time_scale, interpolated_transform.origin)
						anim.track_insert_key(cam_rot_track, sub_frame_idx * time_scale, interpolated_transform.basis.get_rotation_quaternion())
						anim.track_insert_key(cam_fov_track, sub_frame_idx * time_scale, sampled_fov)


	# 4. Process Morphs
	var morph_frames_map: Dictionary = {}
	for morph_frame: VmdFormat.VmdMorphFrame in data.morph_frames:
		if not morph_frames_map.has(morph_frame.name):
			morph_frames_map[morph_frame.name] = []
		morph_frames_map[morph_frame.name].append(morph_frame)
		max_frame = max(max_frame, morph_frame.frame)

	for mmd_name: String in morph_frames_map:
		var vrm_expr: String = MORPH_MAP.get(mmd_name, mmd_name)
		var prop_name: String = vrm_expr.to_snake_case()
		var track_path: NodePath = NodePath("%Vrm1ExpressionController:" + prop_name)

		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, track_path)

		var frames: Array = morph_frames_map[mmd_name]
		frames.sort_custom(
			func(frame_a: VmdFormat.VmdMorphFrame, frame_b: VmdFormat.VmdMorphFrame) -> bool:
				return frame_a.frame < frame_b.frame
		)

		for morph_frame: VmdFormat.VmdMorphFrame in frames:
			anim.track_insert_key(track, morph_frame.frame * time_scale, morph_frame.weight)

	anim.length = max_frame * time_scale
	library.add_animation("default", anim)
	return library


## Converts a [VmdParser.VmdCameraFrame] to a Godot [Transform3D].
##
## MMD cameras use a target-and-distance model in left-handed space.
## This function converts that to a right-handed camera [Transform3D]
## by inverting pitch (X) and yaw (Y) and applying the [param y_offset].
static func _get_camera_transform(
		frame: VmdFormat.VmdCameraFrame,
		y_offset: float = 0.0,
		position_scale: float = 0.08,
) -> Transform3D:
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

	# MMD Target: Z is already flipped in parser. Scaled by the SAME factor as
	# the motion data — the camera used a hardcoded 0.1 while motion used 0.08,
	# so the camera lived in a world 25% larger than the dance it was filming:
	# targets aimed high and close-up dollies overshot INTO the face.
	var target: Vector3 = frame.target_position * position_scale

	# Apply Y offset in meters (after scaling)
	target.y += y_offset

	# MMD distance is distance AWAY from target, and typically negative in VMD files.
	# In Godot, Camera looks at -Z, so the 'back' vector is +Z.
	var camera_pos: Vector3 = target + (basis * Vector3(0.0, 0.0, -frame.distance * position_scale))

	return Transform3D(basis, camera_pos)


## Extracts the 6 Bezier curves from the 24-byte camera interpolation block.
##
## Curves are ordered: X-target, Y-target, Z-target, Rotation, Distance, FOV.
## Each curve occupies 4 consecutive bytes (x1, y1, x2, y2) in [0, 127].
## Returns 6 linear fallback curves when the data is too short.
static func _extract_camera_curves(interp_data: PackedByteArray) -> Array[VmdBezier]:
	var curves: Array[VmdBezier] = []
	# Camera interpolation is 24 bytes (6 curves of 4 bytes each)
	# Order: X-target, Y-target, Z-target, Rotation, Distance, FOV
	if interp_data.size() < 24:
		for _curve_idx: int in range(6): curves.append(VmdBezier.new(20, 20, 107, 107))
		return curves

	for curve_idx: int in range(6):
		var offset: int = curve_idx * 4
		curves.append(VmdBezier.new(
			interp_data[offset],
			interp_data[offset + 1],
			interp_data[offset + 2],
			interp_data[offset + 3],
		))
	return curves


## Extracts 4 Bezier curves from the 64-byte bone interpolation block.
##
## VMD stores 4 curves (X-pos, Y-pos, Z-pos, Rotation) interleaved with
## stride 4. Only the first 16 bytes are needed.
## Returns 4 linear fallback curves when the data is too short.
static func _extract_curves(interp_data: PackedByteArray) -> Array[VmdBezier]:
	var curves: Array[VmdBezier] = []
	if interp_data.size() < 16:
		for _curve_idx: int in range(4): curves.append(VmdBezier.new(20, 20, 107, 107)) # Linear fallback
		return curves

	for curve_idx: int in range(4):
		curves.append(VmdBezier.new(
			interp_data[curve_idx],
			interp_data[curve_idx + 4],
			interp_data[curve_idx + 8],
			interp_data[curve_idx + 12],
		))
	return curves
