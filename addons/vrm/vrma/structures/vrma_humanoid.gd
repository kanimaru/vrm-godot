@tool
class_name VrmaHumanoid
extends Resource

## Maps Humanoid bone name (e.g. "hips") to GLTF node index
@export var human_bones: Dictionary[String, int] = {}
