@tool
extends Resource
class_name Vrm1SpringBoneJoint

@export var node: int = -1
@export var hit_radius: float = 0.0
@export var stiffness: float = 1.0
@export var gravity_power: float = 0.0
@export var gravity_dir: Vector3 = Vector3(0.0, -1.0, 0.0)
@export var drag_force: float = 0.5
