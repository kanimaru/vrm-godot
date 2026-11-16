@tool
extends Resource
class_name Vrm1LookAtRangeMap

## One of VRMC_vrm lookAt's four range maps: a look of input_max_value degrees (or more)
## turns the eyes by output_scale degrees (bone type) or sets the look expression to
## output_scale (expression type). Its own script file, not an inner class of Vrm1LookAt,
## so the imported scene can save it: Godot cannot save a resource whose script is an inner
## class, and the look-at controller lost its data on every editor import.
##
## VRM 0.x's degree maps land here too (xRange -> input_max_value, yRange -> output_scale),
## with their curve: Unity AnimationCurve keys flattened as time, value, inTangent,
## outTangent per key, over 0..1 on both axes. VRM 1.0 has no curve (empty), which is linear.

const _KEY_STRIDE := 4

@export var input_max_value: float = 90.0
@export var output_scale: float = 10.0
@export var curve: PackedFloat32Array = PackedFloat32Array()


## Maps a signed look angle (degrees) to the signed output.
func map(value: float) -> float:
	var factor: float = clampf(absf(value) / maxf(input_max_value, 0.001), 0.0, 1.0)
	return evaluate_curve(factor) * output_scale * signf(value)


## The curve at x in 0..1: linear without keys, else Unity's cubic Hermite between the two
## keys around x, held flat outside the first and last key.
func evaluate_curve(x: float) -> float:
	var key_count: int = curve.size() / _KEY_STRIDE
	if key_count == 0:
		return x
	if key_count == 1 or x <= curve[0]:
		return curve[1]
	var last: int = (key_count - 1) * _KEY_STRIDE
	if x >= curve[last]:
		return curve[last + 1]
	for k: int in range(key_count - 1):
		var a: int = k * _KEY_STRIDE
		var b: int = a + _KEY_STRIDE
		if x > curve[b]:
			continue
		var dt: float = curve[b] - curve[a]
		if dt <= 0.0:
			return curve[b + 1]
		var s: float = (x - curve[a]) / dt
		var s2: float = s * s
		var s3: float = s2 * s
		return ((2.0 * s3 - 3.0 * s2 + 1.0) * curve[a + 1]
				+ (s3 - 2.0 * s2 + s) * dt * curve[a + 3]
				+ (-2.0 * s3 + 3.0 * s2) * curve[b + 1]
				+ (s3 - s2) * dt * curve[b + 2])
	return curve[last + 1]
