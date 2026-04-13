@tool
extends Resource
class_name Vrm1LookAt


class RangeMap extends Resource:
	@export var input_max_value: float = 90.0
	@export var output_scale: float = 10.0


@export var offset_from_head_bone: Vector3 = Vector3(0.0, 0.06, 0.0)
@export var type: String = "bone"
@export var range_map_horizontal_inner: RangeMap
@export var range_map_horizontal_outer: RangeMap
@export var range_map_vertical_down: RangeMap
@export var range_map_vertical_up: RangeMap
