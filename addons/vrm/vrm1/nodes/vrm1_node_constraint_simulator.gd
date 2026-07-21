@tool
extends SkeletonModifier3D
class_name Vrm1NodeConstraintSimulator

## Evaluates VRMC_node_constraint (roll/aim/rotation) constraints each frame.
## See docs/VRMC_node_constraint-1.0/README.md for the spec this implements.
##
## Scope: constraint sources and destinations must resolve to Skeleton3D bones (matches
## every example in the spec itself — twist bones, cloth-aim helpers, sub-arm rotation
## copying are all bone-hierarchy based). A constraint referencing a non-bone node is
## dropped at setup time with a push_warning rather than attempted.

const ROLL_AXES: Dictionary[String, Vector3] = {
	"X": Vector3(1, 0, 0),
	"Y": Vector3(0, 1, 0),
	"Z": Vector3(0, 0, 1),
}

const AIM_AXES: Dictionary[String, Vector3] = {
	"PositiveX": Vector3(1, 0, 0),
	"NegativeX": Vector3(-1, 0, 0),
	"PositiveY": Vector3(0, 1, 0),
	"NegativeY": Vector3(0, -1, 0),
	"PositiveZ": Vector3(0, 0, 1),
	"NegativeZ": Vector3(0, 0, -1),
}

## Parsed node constraints, keyed by the glTF node index they were declared on.
@export var node_constraints: Dictionary[int, Vrm1NodeConstraint] = {}

## glTF node index -> Godot bone/node name, same map VrmSceneComposer.resolve_all_node_names
## builds for spring bones.
@export var gltf_node_names: Dictionary[int, String] = {}

## Resolved constraints keyed by destination bone index. Each value:
## {"src_bone": int, "type": String, "weight": float, "roll_axis": Vector3, "aim_axis": Vector3}
var _by_dst: Dictionary[int, Dictionary] = {}

## Destination bone indices in dependency-safe evaluation order.
var _eval_order: Array[int] = []


func _ready() -> void:
	_resolve_constraints()


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return

	for dst_bone: int in _eval_order:
		var r: Dictionary = _by_dst[dst_bone]
		var target_q: Quaternion
		match r.type:
			"roll":
				target_q = _compute_roll(skeleton, dst_bone, r)
			"aim":
				target_q = _compute_aim(skeleton, dst_bone, r)
			"rotation":
				target_q = _compute_rotation(skeleton, dst_bone, r)
			_:
				continue
		skeleton.set_bone_pose_rotation(dst_bone, target_q)
		# Chained constraints (a constraint whose source is itself another constraint's
		# destination) must see the just-written pose, not the stale pre-constraint one.
		skeleton.force_update_all_bone_transforms()


## Resolves each parsed constraint's node/source glTF indices to skeleton bone indices,
## drops anything that doesn't resolve to a bone, and builds the dependency-safe eval order.
func _resolve_constraints() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return

	_by_dst.clear()
	for node_idx: int in node_constraints:
		var nc: Vrm1NodeConstraint = node_constraints[node_idx]
		var dst_name: String = gltf_node_names.get(nc.node, "")
		var src_name: String = gltf_node_names.get(nc.source, "")
		var dst_bone: int = skeleton.find_bone(dst_name) if not dst_name.is_empty() else -1
		var src_bone: int = skeleton.find_bone(src_name) if not src_name.is_empty() else -1

		if dst_bone == -1 or src_bone == -1:
			push_warning(
				"Vrm1NodeConstraintSimulator: constraint on node %d (source %d) does not resolve to skeleton bones, skipping" % [nc.node, nc.source]
			)
			continue

		_by_dst[dst_bone] = {
			"src_bone": src_bone,
			"type": nc.type,
			"weight": clampf(nc.weight, 0.0, 1.0),
			"roll_axis": ROLL_AXES.get(nc.roll_axis, Vector3(1, 0, 0)),
			"aim_axis": AIM_AXES.get(nc.aim_axis, Vector3(1, 0, 0)),
		}

	_build_eval_order()


## DFS topological sort of _by_dst, mirroring the spec's own dependency-resolution
## pseudocode. A constraint depends on another iff its source bone is itself someone
## else's constrained destination. On a circular dependency, the offending destination
## (and anything transitively depending on it) is left out of _eval_order and warned
## about — the rest of the avatar's constraints still evaluate normally.
func _build_eval_order() -> void:
	_eval_order.clear()
	var visiting: Dictionary[int, bool] = {}
	var done: Dictionary[int, bool] = {}
	for dst_bone: int in _by_dst:
		_visit(dst_bone, visiting, done)


func _visit(dst_bone: int, visiting: Dictionary, done: Dictionary) -> bool:
	if done.get(dst_bone, false):
		return true
	if visiting.get(dst_bone, false):
		push_warning("Vrm1NodeConstraintSimulator: circular dependency detected at bone %d, skipping" % dst_bone)
		return false

	visiting[dst_bone] = true
	var r: Dictionary = _by_dst[dst_bone]
	if _by_dst.has(r.src_bone):
		if not _visit(r.src_bone, visiting, done):
			visiting.erase(dst_bone)
			return false

	visiting.erase(dst_bone)
	done[dst_bone] = true
	_eval_order.append(dst_bone)
	return true


## Rotation Constraint: local-to-local copy of the source's rotation delta from rest.
func _compute_rotation(skeleton: Skeleton3D, dst_bone: int, r: Dictionary) -> Quaternion:
	var dst_rest_q: Quaternion = skeleton.get_bone_rest(dst_bone).basis.get_rotation_quaternion()
	var src_rest_q: Quaternion = skeleton.get_bone_rest(r.src_bone).basis.get_rotation_quaternion()
	var src_pose_q: Quaternion = skeleton.get_bone_pose_rotation(r.src_bone)

	var src_delta_q: Quaternion = src_rest_q.inverse() * src_pose_q
	return dst_rest_q.slerp(dst_rest_q * src_delta_q, r.weight)


## Roll Constraint: twists the destination around a single local axis, isolating just the
## roll-axis component of the source's rotation delta so off-axis source rotation doesn't
## leak into the destination.
func _compute_roll(skeleton: Skeleton3D, dst_bone: int, r: Dictionary) -> Quaternion:
	var dst_rest_q: Quaternion = skeleton.get_bone_rest(dst_bone).basis.get_rotation_quaternion()
	var src_rest_q: Quaternion = skeleton.get_bone_rest(r.src_bone).basis.get_rotation_quaternion()
	var src_pose_q: Quaternion = skeleton.get_bone_pose_rotation(r.src_bone)

	var delta_src_q: Quaternion = src_rest_q.inverse() * src_pose_q
	var delta_src_q_in_parent: Quaternion = src_rest_q * delta_src_q * src_rest_q.inverse()
	var delta_src_q_in_dst: Quaternion = dst_rest_q.inverse() * delta_src_q_in_parent * dst_rest_q

	var roll_axis: Vector3 = r.roll_axis
	var to_vec: Vector3 = delta_src_q_in_dst * roll_axis
	var from_to_q: Quaternion = _from_to_rotation(roll_axis, to_vec)

	var full_q: Quaternion = dst_rest_q * from_to_q.inverse() * delta_src_q_in_dst
	return dst_rest_q.slerp(full_q, r.weight)


## Aim Constraint: rotates the destination so its aim axis points at the source, in world space.
func _compute_aim(skeleton: Skeleton3D, dst_bone: int, r: Dictionary) -> Quaternion:
	var dst_rest_q: Quaternion = skeleton.get_bone_rest(dst_bone).basis.get_rotation_quaternion()

	var skel_world_q: Quaternion = skeleton.global_transform.basis.orthonormalized().get_rotation_quaternion()
	var parent_idx: int = skeleton.get_bone_parent(dst_bone)
	var dst_parent_world_q: Quaternion = skel_world_q
	if parent_idx != -1:
		dst_parent_world_q = (
			skel_world_q * skeleton.get_bone_global_pose(parent_idx).basis.orthonormalized().get_rotation_quaternion()
		)

	var aim_axis: Vector3 = r.aim_axis
	var from_vec: Vector3 = ((dst_parent_world_q * dst_rest_q) * aim_axis).normalized()

	var src_world_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(r.src_bone).origin
	var dst_world_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(dst_bone).origin
	var to_vec: Vector3 = (src_world_pos - dst_world_pos).normalized()

	var from_to_q: Quaternion = _from_to_rotation(from_vec, to_vec)

	var full_q: Quaternion = dst_parent_world_q.inverse() * from_to_q * dst_parent_world_q * dst_rest_q
	return dst_rest_q.slerp(full_q, r.weight)


## Shortest-arc rotation from one normalized vector to another (spec pseudocode's
## Quaternion.fromToRotation). Falls back to identity for the degenerate case of exactly
## opposite vectors, which Godot's Quaternion(from, to) constructor cannot resolve to a
## unique axis — an extreme edge case unlikely in real VRM content.
func _from_to_rotation(from_vec: Vector3, to_vec: Vector3) -> Quaternion:
	var f: Vector3 = from_vec.normalized()
	var t: Vector3 = to_vec.normalized()
	if f.is_equal_approx(t) or f.is_equal_approx(-t):
		return Quaternion.IDENTITY
	return Quaternion(f, t)
