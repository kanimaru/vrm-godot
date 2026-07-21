@tool
extends Resource
class_name Vrm1NodeConstraint

## Represents a VRMC_node_constraint attached to a single glTF node.
## type is one of: "roll", "aim", "rotation"
## roll_axis is only meaningful when type == "roll".
## aim_axis is only meaningful when type == "aim".

@export var type: String = ""
@export var node: int = -1
@export var source: int = -1
@export var weight: float = 1.0
@export var roll_axis: String = ""
@export var aim_axis: String = ""
