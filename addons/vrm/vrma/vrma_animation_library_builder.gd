@tool
class_name VrmaAnimationLibraryBuilder
extends RefCounted
const VRMUtil = preload("../common/vrm_util.gd")

## Converts a raw VRMA GLTFState + generated scene into a retargeted AnimationLibrary.
## Bone rotations are normalized from the VRMA's own T-pose rest rotations so they can
## be applied to any VRM avatar with zero or near-zero rest rotations.

# No longer using a hardcoded map. We use the VRM role names (camelCase) directly.

# VRM expression preset (camelCase) -> Vrm1ExpressionController property (snake_case)
const EXPRESSION_NAME_MAP: Dictionary = {
	"happy": "happy",
	"angry": "angry",
	"sad": "sad",
	"relaxed": "relaxed",
	"surprised": "surprised",
	"aa": "aa",
	"ih": "ih",
	"ou": "ou",
	"ee": "ee",
	"oh": "oh",
	"blink": "blink",
	"blinkLeft": "blink_left",
	"blinkRight": "blink_right",
	"neutral": "neutral",
}

# These bones are excluded from animation per spec — handled by LookAt instead.
const EXCLUDED_BONES: PackedStringArray = ["leftEye", "rightEye"]

# These expressions are excluded per spec — handled by LookAt instead.
const EXCLUDED_EXPRESSIONS: PackedStringArray = [
	"lookUp", "lookDown", "lookLeft", "lookRight",
]


static func build(state: GLTFState, scene: Node) -> AnimationLibrary:
	var vrma: VrmaTopLevel = state.get_additional_data("vrma") as VrmaTopLevel
	if vrma == null:
		push_error("VrmaAnimationLibraryBuilder: No VRMA data in GLTFState.")
		return AnimationLibrary.new()

	var role_map: Dictionary = _build_role_map(vrma)
	var name_to_idx: Dictionary = _build_name_to_idx(state)
	var world_rests: Dictionary = _compute_world_rest_rotations(state)
	var local_rests: Dictionary = _get_local_rest_rotations(state)

	var anim_player: AnimationPlayer = VRMUtil.find_animation_player(scene)
	if anim_player == null:
		push_warning("VrmaAnimationLibraryBuilder: No AnimationPlayer in VRMA scene.")
		return AnimationLibrary.new()

	var library: AnimationLibrary = AnimationLibrary.new()

	var source_lib: AnimationLibrary = anim_player.get_animation_library("") \
		if anim_player.has_animation_library("") else null
	if source_lib == null:
		return library

	for anim_name: StringName in source_lib.get_animation_list():
		var source_anim: Animation = source_lib.get_animation(anim_name)
		var retargeted: Animation = _retarget_animation(
			source_anim, role_map, name_to_idx, world_rests, local_rests
		)
		library.add_animation(anim_name, retargeted)

	return library


# ---------------------------------------------------------------------------
# Role map helpers
# ---------------------------------------------------------------------------

static func _build_role_map(vrma: VrmaTopLevel) -> Dictionary:
	var map: Dictionary = {}

	if vrma.humanoid:
		for bone_name: String in vrma.humanoid.human_bones:
			if bone_name in EXCLUDED_BONES:
				continue
			var node_idx: int = vrma.humanoid.human_bones[bone_name]
			if node_idx < 0:
				continue
			map[node_idx] = {
				"type": "bone",
				"vrm_name": bone_name,
				"is_hips": bone_name == "hips",
			}

	if vrma.expressions:
		for expr_name: String in vrma.expressions.preset:
			if expr_name in EXCLUDED_EXPRESSIONS:
				continue
			var node_idx: int = vrma.expressions.preset[expr_name]
			if node_idx < 0:
				continue
			map[node_idx] = {
				"type": "expression",
				"vrm_name": expr_name,
				"prop": EXPRESSION_NAME_MAP.get(expr_name, expr_name),
			}

		for expr_name: String in vrma.expressions.custom:
			var node_idx: int = vrma.expressions.custom[expr_name]
			if node_idx < 0:
				continue
			map[node_idx] = {
				"type": "expression",
				"vrm_name": expr_name,
				"prop": expr_name,
			}

	if vrma.look_at and vrma.look_at.node >= 0:
		map[vrma.look_at.node] = { "type": "lookat" }

	return map


static func _build_name_to_idx(state: GLTFState) -> Dictionary:
	var map: Dictionary = {}
	var gltf_nodes: Array[GLTFNode] = state.get_nodes()
	for i: int in range(gltf_nodes.size()):
		var scene_node: Node = state.get_scene_node(i)
		if scene_node != null:
			map[scene_node.name] = i
		else:
			var n: GLTFNode = gltf_nodes[i]
			var name: String = n.original_name
			if name.is_empty():
				name = n.resource_name
			if not name.is_empty():
				map[name] = i
				map[name.replace(".", "_")] = i
	return map


# ---------------------------------------------------------------------------
# T-pose rest rotation helpers
# ---------------------------------------------------------------------------

static func _get_local_rest_rotations(state: GLTFState) -> Dictionary:
	var map: Dictionary = {}
	var gltf_nodes: Array[GLTFNode] = state.get_nodes()
	for i: int in range(gltf_nodes.size()):
		map[i] = gltf_nodes[i].rotation
	return map


static func _compute_world_rest_rotations(state: GLTFState) -> Dictionary:
	var map: Dictionary = {}
	var gltf_nodes: Array[GLTFNode] = state.get_nodes()
	for i: int in range(gltf_nodes.size()):
		var local_rot: Quaternion = gltf_nodes[i].rotation
		var parent: int = gltf_nodes[i].parent
		if parent >= 0 and map.has(parent):
			map[i] = (map[parent] as Quaternion) * local_rot
		else:
			map[i] = local_rot
	return map


# ---------------------------------------------------------------------------
# Scene helpers
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# Animation retargeting
# ---------------------------------------------------------------------------

static func _retarget_animation(
	source: Animation,
	role_map: Dictionary,
	name_to_idx: Dictionary,
	world_rests: Dictionary,
	local_rests: Dictionary,
) -> Animation:
	var out: Animation = Animation.new()
	out.length = source.length
	out.loop_mode = source.loop_mode

	for t: int in range(source.get_track_count()):
		var path: NodePath = source.track_get_path(t)
		var track_type: int = source.track_get_type(t)
		var node_name: String = _node_name_from_path(path)

		if not name_to_idx.has(node_name):
			continue
		var node_idx: int = name_to_idx[node_name]

		if not role_map.has(node_idx):
			continue
		var role: Dictionary = role_map[node_idx]

		match role["type"]:
			"bone":
				_add_bone_tracks(source, t, track_type, node_idx, role, out, world_rests, local_rests)
			"expression":
				if track_type == Animation.TYPE_POSITION_3D:
					_add_expression_track(source, t, role, out)
			"lookat":
				if track_type == Animation.TYPE_ROTATION_3D:
					_add_lookat_tracks(source, t, out)

	return out


static func _node_name_from_path(path: NodePath) -> String:
	var count: int = path.get_name_count()
	if count == 0:
		return ""
	return path.get_name(count - 1)


static func _add_bone_tracks(
	source: Animation,
	t: int,
	track_type: int,
	node_idx: int,
	role: Dictionary,
	out: Animation,
	world_rests: Dictionary,
	local_rests: Dictionary,
) -> void:
	# Use the VRM role name (camelCase) — this is the actual bone name in VRM models.
	var vrm_name: String = role.get("vrm_name", "")
	if vrm_name.is_empty():
		return

	var target_path: NodePath = NodePath("%GeneralSkeleton:" + vrm_name)
	var key_count: int = source.track_get_key_count(t)

	if track_type == Animation.TYPE_ROTATION_3D:
		var new_t: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(new_t, target_path)
		out.track_set_interpolation_type(new_t, source.track_get_interpolation_type(t))

		var w_src: Quaternion = world_rests.get(node_idx, Quaternion.IDENTITY)
		var l_src: Quaternion = local_rests.get(node_idx, Quaternion.IDENTITY)

		for k: int in range(key_count):
			var time: float = source.track_get_key_time(t, k)
			var raw: Quaternion = source.track_get_key_value(t, k)
			var normalized: Quaternion = _normalize_rotation(raw, w_src, l_src)
			out.track_insert_key(new_t, time, normalized)

	elif track_type == Animation.TYPE_POSITION_3D and role.get("is_hips", false):
		# Only hips can have a position track per the spec.
		var new_t: int = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(new_t, target_path)
		out.track_set_interpolation_type(new_t, source.track_get_interpolation_type(t))

		for k: int in range(key_count):
			var time: float = source.track_get_key_time(t, k)
			var pos: Vector3 = source.track_get_key_value(t, k)
			out.track_insert_key(new_t, time, pos)


static func _add_expression_track(
	source: Animation, t: int, role: Dictionary, out: Animation
) -> void:
	var prop: String = role.get("prop", "")
	if prop.is_empty():
		return

	var target_path: NodePath = NodePath("%Vrm1ExpressionController:" + prop)
	var new_t: int = out.add_track(Animation.TYPE_VALUE)
	out.track_set_path(new_t, target_path)
	out.track_set_interpolation_type(new_t, source.track_get_interpolation_type(t))

	for k: int in range(source.track_get_key_count(t)):
		var time: float = source.track_get_key_time(t, k)
		var pos: Vector3 = source.track_get_key_value(t, k)
		out.track_insert_key(new_t, time, clampf(pos.x, 0.0, 1.0))


static func _add_lookat_tracks(source: Animation, t: int, out: Animation) -> void:
	var yaw_path: NodePath = NodePath("%Vrm1LookAtController:target_yaw")
	var pitch_path: NodePath = NodePath("%Vrm1LookAtController:target_pitch")

	var yaw_t: int = out.add_track(Animation.TYPE_VALUE)
	out.track_set_path(yaw_t, yaw_path)
	out.track_set_interpolation_type(yaw_t, source.track_get_interpolation_type(t))

	var pitch_t: int = out.add_track(Animation.TYPE_VALUE)
	out.track_set_path(pitch_t, pitch_path)
	out.track_set_interpolation_type(pitch_t, source.track_get_interpolation_type(t))

	for k: int in range(source.track_get_key_count(t)):
		var time: float = source.track_get_key_time(t, k)
		var quat: Quaternion = source.track_get_key_value(t, k)
		var yaw_pitch: Vector2 = _quaternion_to_yaw_pitch(quat)
		out.track_insert_key(yaw_t, time, yaw_pitch.x)
		out.track_insert_key(pitch_t, time, yaw_pitch.y)


# ---------------------------------------------------------------------------
# Math helpers
# ---------------------------------------------------------------------------

## Normalize a bone rotation from source T-pose space into zero-rest-rotation space.
## Formula: W * L^-1 * local_rotation * W^-1
## This correctly transforms the local rotation into Global Space, resolving any 
## differences in the source bone's axes.
static func _normalize_rotation(
	local_rot: Quaternion, world_rest: Quaternion, local_rest: Quaternion
) -> Quaternion:
	return world_rest * local_rest.inverse() * local_rot * world_rest.inverse()


## Decompose a quaternion into yaw (Y) and pitch (X) using Extrinsic ZXY order.
## Extrinsic ZXY == Intrinsic YXZ in Godot's Euler decomposition.
static func _quaternion_to_yaw_pitch(q: Quaternion) -> Vector2:
	var euler: Vector3 = Basis(q).get_euler(EULER_ORDER_YXZ)
	return Vector2(rad_to_deg(euler.y), rad_to_deg(euler.x))
