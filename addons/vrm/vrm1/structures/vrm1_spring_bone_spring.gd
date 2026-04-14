@tool
extends Resource
class_name Vrm1SpringBoneSpring

@export var name: String = ""
@export var joints: Array[Vrm1SpringBoneJoint] = []
@export var collider_groups: PackedInt32Array = PackedInt32Array()
@export var center: int = -1
