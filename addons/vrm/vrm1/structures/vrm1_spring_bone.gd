@tool
extends Resource
class_name Vrm1SpringBone


class Shape extends Resource:
	@export var sphere_radius: float = 0.0
	@export var capsule_radius: float = 0.0
	@export var capsule_offset: Vector3 = Vector3()


class Collider extends Resource:
	@export var node: int = -1
	@export var shape: Shape


class ColliderGroup extends Resource:
	@export var name: String = ""
	@export var colliders: PackedInt32Array = PackedInt32Array()


class Joint extends Resource:
	@export var node: int = -1
	@export var hit_radius: float = 0.0
	@export var stiffness: float = 1.0
	@export var gravity_power: float = 0.0
	@export var gravity_dir: Vector3 = Vector3(0.0, -1.0, 0.0)
	@export var drag_force: float = 0.5


class Spring extends Resource:
	@export var name: String = ""
	@export var joints: Array[Joint] = []
	@export var collider_groups: PackedInt32Array = PackedInt32Array()
	@export var center: int = -1


@export var colliders: Array[Collider] = []
@export var collider_groups: Array[ColliderGroup] = []
@export var springs: Array[Spring] = []
