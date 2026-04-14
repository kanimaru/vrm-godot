@tool
extends Resource
class_name Vrm0FirstPerson


class MeshAnnotation extends Resource:
	@export var mesh: int = -1
	@export var first_person_flag: String = "Auto"


class DegreeMap extends Resource:
	@export var curve: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 1, 1, 1, 1, 0])
	@export var x_range: float = 90.0
	@export var y_range: float = 10.0


@export var first_person_bone: int = -1
@export var first_person_bone_offset: Vector3
@export var mesh_annotations: Array[Resource] = []
@export var look_at_type_name: String = "Bone"
@export var look_at_horizontal_inner: DegreeMap
@export var look_at_horizontal_outer: DegreeMap
@export var look_at_vertical_down: DegreeMap
@export var look_at_vertical_up: DegreeMap
