@tool
extends Resource
class_name Vrm0Humanoid


class Bone extends Resource:
	@export var bone: String = ""
	@export var node: int = -1
	@export var use_default_values: bool = true
	@export var min: Vector3
	@export var max: Vector3
	@export var center: Vector3
	@export var axis_length: float = 0.0


@export var human_bones: Array[Bone] = []
@export var arm_stretch: float = 0.05
@export var leg_stretch: float = 0.05
@export var upper_arm_twist: float = 0.5
@export var lower_arm_twist: float = 0.5
@export var upper_leg_twist: float = 0.5
@export var lower_leg_twist: float = 0.5
@export var feet_spacing: float = 0.0
@export var has_translation_dof: bool = false
