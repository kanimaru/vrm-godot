@tool
class_name BvhAnimationLibraryBuilder
extends RefCounted

const PRESET_MIXAMO = "Mixamo"
const PRESET_CMU = "CMU"
const PRESET_RAW = "Raw"

static var MIXAMO_MAP: Dictionary = {
	"Hips": "hips",
	"Spine": "spine",
	"Spine1": "chest",
	"Spine2": "upperChest",
	"Neck": "neck",
	"Head": "head",
	"LeftShoulder": "leftShoulder",
	"LeftArm": "leftUpperArm",
	"LeftForeArm": "leftLowerArm",
	"LeftHand": "leftHand",
	"RightShoulder": "rightShoulder",
	"RightArm": "rightUpperArm",
	"RightForeArm": "rightLowerArm",
	"RightHand": "rightHand",
	"LeftUpLeg": "leftUpperLeg",
	"LeftLeg": "leftLowerLeg",
	"LeftFoot": "leftFoot",
	"LeftToeBase": "leftToes",
	"RightUpLeg": "rightUpperLeg",
	"RightLeg": "rightLowerLeg",
	"RightFoot": "rightFoot",
	"RightToeBase": "rightToes"
}

static var CMU_MAP: Dictionary = {
	"Hips": "hips",
	"LHipJoint": "leftUpperLeg",
	"LeftUpLeg": "leftUpperLeg",
	"LeftLeg": "leftLowerLeg",
	"LeftFoot": "leftFoot",
	"LeftToeBase": "leftToes",
	"RHipJoint": "rightUpperLeg",
	"RightUpLeg": "rightUpperLeg",
	"RightLeg": "rightLowerLeg",
	"RightFoot": "rightFoot",
	"RightToeBase": "rightToes",
	"LowerBack": "spine",
	"Spine": "chest",
	"Spine1": "upperChest",
	"Neck": "neck",
	"Neck1": "head",
	"Head": "head",
	"LeftCollar": "leftShoulder",
	"LeftShoulder": "leftUpperArm",
	"LeftElbow": "leftLowerArm",
	"LeftWrist": "leftHand",
	"RightCollar": "rightShoulder",
	"RightShoulder": "rightUpperArm",
	"RightElbow": "rightLowerArm",
	"RightWrist": "rightHand"
}

static func build(bvh_data: BvhParser.BvhData, fps: float = 30.0, scale_factor: float = 0.01, bone_map_preset: String = PRESET_MIXAMO) -> AnimationLibrary:
	var library = AnimationLibrary.new()
	var anim = Animation.new()
	
	if bvh_data == null or bvh_data.root == null:
		return library
		
	var frame_time = bvh_data.frame_time
	if frame_time <= 0.0:
		frame_time = 1.0 / fps
	
	anim.length = bvh_data.num_frames * frame_time
	anim.loop_mode = Animation.LOOP_NONE
	
	var map: Dictionary = {}
	var use_map = true
	var preset_lower = bone_map_preset.to_lower()
	if preset_lower == PRESET_MIXAMO.to_lower():
		map = MIXAMO_MAP
	elif preset_lower == PRESET_CMU.to_lower():
		map = CMU_MAP
	else:
		use_map = false
		
	for node in bvh_data.nodes:
		if node.is_end_site:
			continue
			
		var node_name = _strip_prefix(node.name)
		var target_name = node_name
		
		if use_map:
			if map.has(node_name):
				target_name = map[node_name]
			else:
				# Try fuzzy match if exact match fails
				var matched = false
				for key in map.keys():
					if node_name.to_lower() == key.to_lower():
						target_name = map[key]
						matched = true
						break
				if not matched:
					continue
				
		var path = NodePath("%GeneralSkeleton:" + target_name)
		
		var has_position = false
		var has_rotation = false
		for ch in node.channels:
			if ch.ends_with("position"): has_position = true
			if ch.ends_with("rotation"): has_rotation = true
			
		if has_position:
			var pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pos_track, path)
			anim.track_set_interpolation_type(pos_track, Animation.INTERPOLATION_LINEAR)
			
			for f in range(bvh_data.num_frames):
				var frame_data = bvh_data.motion_data[f]
				var pos = _extract_position(node, frame_data)
				anim.track_insert_key(pos_track, f * frame_time, pos * scale_factor)
				
		if has_rotation:
			var rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(rot_track, path)
			anim.track_set_interpolation_type(rot_track, Animation.INTERPOLATION_LINEAR)
			
			for f in range(bvh_data.num_frames):
				var frame_data = bvh_data.motion_data[f]
				var rot = _extract_rotation(node, frame_data)
				anim.track_insert_key(rot_track, f * frame_time, rot)
				
	print("BvhBuilder: Created animation 'Take 001' with ", anim.get_track_count(), " tracks.")
	library.add_animation("Take 001", anim)
	return library


static func _strip_prefix(n: String) -> String:
	var idx = n.find(":")
	if idx != -1:
		return n.substr(idx + 1)
	return n

static func _extract_position(node: BvhParser.BvhNode, frame_data: PackedFloat32Array) -> Vector3:
	var pos = node.offset # Base offset
	var idx = node.channel_start_index
	for ch in node.channels:
		var val = frame_data[idx]
		if ch == "Xposition": pos.x += val
		elif ch == "Yposition": pos.y += val
		elif ch == "Zposition": pos.z += val
		idx += 1
	return pos

static func _extract_rotation(node: BvhParser.BvhNode, frame_data: PackedFloat32Array) -> Quaternion:
	var rot = Quaternion.IDENTITY
	var idx = node.channel_start_index
	
	for ch in node.channels:
		var val = deg_to_rad(frame_data[idx])
		if ch == "Xrotation":
			rot = rot * Quaternion(Vector3.RIGHT, val)
		elif ch == "Yrotation":
			rot = rot * Quaternion(Vector3.UP, val)
		elif ch == "Zrotation":
			rot = rot * Quaternion(Vector3.BACK, val)
		idx += 1
		
	return rot
