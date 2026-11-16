@tool
extends Resource
class_name Vrm1LookAt


## Kept so Vrm1LookAt.RangeMap still names the range map type; see Vrm1LookAtRangeMap.
const RangeMap = preload("vrm1_look_at_range_map.gd")


@export var offset_from_head_bone: Vector3 = Vector3(0.0, 0.06, 0.0)
@export var type: String = "bone"
@export var range_map_horizontal_inner: Vrm1LookAtRangeMap
@export var range_map_horizontal_outer: Vrm1LookAtRangeMap
@export var range_map_vertical_down: Vrm1LookAtRangeMap
@export var range_map_vertical_up: Vrm1LookAtRangeMap
