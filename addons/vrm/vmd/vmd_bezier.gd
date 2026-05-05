class_name VmdBezier
extends RefCounted

## Evaluates a VMD Bezier curve.
## VMD curves define a mapping from normalized time (x) to interpolation factor (y).

var x1: float
var y1: float
var x2: float
var y2: float


func _init(p_x1: int, p_y1: int, p_x2: int, p_y2: int) -> void:
	# Normalize from 0-127 to 0-1
	x1 = p_x1 / 127.0
	y1 = p_y1 / 127.0
	x2 = p_x2 / 127.0
	y2 = p_y2 / 127.0


## Finds the interpolation factor (y) for a given normalized time (x).
func evaluate(x: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0
	
	# If the curve is linear
	if abs(x1 - y1) < 0.001 and abs(x2 - y2) < 0.001:
		return x
		
	# Find 't' such that bezier_x(t) = x using Newton's method
	var t := x
	for i in range(8):
		var x_t = _get_x(t)
		var slope = _get_slope_x(t)
		if abs(slope) < 0.0001: break
		t -= (x_t - x) / slope
		t = clampf(t, 0.0, 1.0)
		
	return _get_y(t)


func _get_x(t: float) -> float:
	var it := 1.0 - t
	return 3 * it * it * t * x1 + 3 * it * t * t * x2 + t * t * t


func _get_y(t: float) -> float:
	var it := 1.0 - t
	return 3 * it * it * t * y1 + 3 * it * t * t * y2 + t * t * t


func _get_slope_x(t: float) -> float:
	var it := 1.0 - t
	return 3 * it * it * x1 + 6 * it * t * (x2 - x1) + 3 * t * t * (1.0 - x2)
