@tool
extends Resource
class_name Vrm1LookAtRangeMap

## One of VRMC_vrm lookAt's four range maps: a look of input_max_value degrees (or more)
## turns the eyes by output_scale degrees (bone type) or sets the look expression to
## output_scale (expression type). Its own script file, not an inner class of Vrm1LookAt,
## so the imported scene can save it: Godot cannot save a resource whose script is an inner
## class, and the look-at controller lost its data on every editor import.

@export var input_max_value: float = 90.0
@export var output_scale: float = 10.0
