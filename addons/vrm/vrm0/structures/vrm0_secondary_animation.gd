@tool
extends Resource
class_name Vrm0SecondaryAnimation


class Collider extends Resource:
	@export var offset: Vector3
	@export var radius: float = 0.0


class ColliderGroup extends Resource:
	@export var node: int = -1
	@export var colliders: Array[Collider] = []


class Spring extends Resource:
	@export var comment: String = ""
	@export var stiffness: float = 1.0
	@export var gravity_power: float = 0.0
	@export var gravity_dir: Vector3 = Vector3(0, -1, 0)
	@export var drag_force: float = 0.4
	@export var center: int = -1
	@export var hit_radius: float = 0.02
	@export var bones: PackedInt32Array = PackedInt32Array()
	@export var collider_groups: PackedInt32Array = PackedInt32Array()


@export var bone_groups: Array[Spring] = []
@export var collider_groups: Array[ColliderGroup] = []
