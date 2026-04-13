@tool
extends Resource
class_name Vrm1FirstPerson


class MeshAnnotation extends Resource:
	@export var node: int = -1
	@export var type: String = "auto"


@export var mesh_annotations: Array[MeshAnnotation] = []
