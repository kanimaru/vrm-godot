extends MeshInstance3D

var call_count: int = 0
var last_idx: int = -1
var last_val: float = -1.0

@warning_ignore("native_method_override")
func set_blend_shape_value(idx: int, value: float) -> void:
	call_count += 1
	last_idx = idx
	last_val = value
	super.set_blend_shape_value(idx, value)
