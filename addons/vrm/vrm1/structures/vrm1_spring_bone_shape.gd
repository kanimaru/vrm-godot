@tool
extends Resource
class_name Vrm1SpringBoneShape

## Represents the shape of a VRM 1.0 spring bone collider.
## type is one of: "sphere", "capsule", "plane"
## For sphere/capsule the extended collider `inside` flag is also stored here.

@export var type: String = "sphere"
@export var offset: Vector3 = Vector3.ZERO
@export var radius: float = 0.0
@export var tail: Vector3 = Vector3.ZERO   # capsule tail endpoint (local space)
@export var normal: Vector3 = Vector3.FORWARD  # plane normal (local space)
@export var inside: bool = false  # extended collider inside mode
