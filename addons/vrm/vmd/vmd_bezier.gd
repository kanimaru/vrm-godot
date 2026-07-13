class_name VmdBezier
extends RefCounted

## Evaluates a VMD cubic Bezier interpolation curve.
##
## VMD curves define a mapping from normalised input time (x-axis) to an
## interpolated output value (y-axis). Control points are stored as integers
## in [0, 127] and normalised to [0.0, 1.0] on construction.
##
## The curve is evaluated with Newton's method to find the parametric value
## [code]t[/code] that satisfies [code]bezier_x(t) == x[/code], then the
## corresponding [code]bezier_y(t)[/code] is returned.

## First control point X coordinate, normalised to [0.0, 1.0].
var x1: float
## First control point Y coordinate, normalised to [0.0, 1.0].
var y1: float
## Second control point X coordinate, normalised to [0.0, 1.0].
var x2: float
## Second control point Y coordinate, normalised to [0.0, 1.0].
var y2: float


## Constructs the curve from raw VMD integer control-point values.
## Each integer is in the range [0, 127] and is normalised to [0.0, 1.0].
func _init(p_x1: int, p_y1: int, p_x2: int, p_y2: int) -> void:
	# Normalize from 0-127 to 0-1
	x1 = p_x1 / 127.0
	y1 = p_y1 / 127.0
	x2 = p_x2 / 127.0
	y2 = p_y2 / 127.0


## Returns the interpolated output value (y) for a given normalised time (x).
##
## Uses Newton's method to invert the Bezier X component and find the
## parametric [code]t[/code], then evaluates the Y component at that [code]t[/code].
func evaluate(x: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0

	# Fast-path: the curve is effectively linear (control points on diagonal).
	if abs(x1 - y1) < 0.001 and abs(x2 - y2) < 0.001:
		return x

	# Find 't' such that bezier_x(t) == x using Newton's method.
	var param_t := x
	for _iter: int in range(8):
		var x_at_t: float = _get_x(param_t)
		var slope: float = _get_slope_x(param_t)
		if abs(slope) < 0.0001: break
		param_t -= (x_at_t - x) / slope
		param_t = clampf(param_t, 0.0, 1.0)

	return _get_y(param_t)


## Evaluates the X component of the cubic Bezier at parametric value [param param_t].
func _get_x(param_t: float) -> float:
	var one_minus_t := 1.0 - param_t
	return (
		3.0 * one_minus_t * one_minus_t * param_t * x1
		+ 3.0 * one_minus_t * param_t * param_t * x2
		+ param_t * param_t * param_t
	)


## Evaluates the Y component of the cubic Bezier at parametric value [param param_t].
func _get_y(param_t: float) -> float:
	var one_minus_t := 1.0 - param_t
	return (
		3.0 * one_minus_t * one_minus_t * param_t * y1
		+ 3.0 * one_minus_t * param_t * param_t * y2
		+ param_t * param_t * param_t
	)


## Returns the derivative of the X component with respect to [param param_t].
## Used by Newton's method in [method evaluate] to converge quickly.
func _get_slope_x(param_t: float) -> float:
	var one_minus_t := 1.0 - param_t
	return (
		3.0 * one_minus_t * one_minus_t * x1
		+ 6.0 * one_minus_t * param_t * (x2 - x1)
		+ 3.0 * param_t * param_t * (1.0 - x2)
	)
