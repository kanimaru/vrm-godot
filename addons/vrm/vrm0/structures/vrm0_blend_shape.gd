@tool
extends Resource
class_name Vrm0BlendShape


class Bind extends Resource:
	@export var mesh: int = -1
	@export var index: int = -1
	@export var weight: float = 0.0


class MaterialBind extends Resource:
	@export var material_name: String = ""
	@export var property_name: String = ""
	@export var target_value: PackedFloat32Array = PackedFloat32Array()


class BlendShapeGroup extends Resource:
	@export var name: String = ""
	@export var preset_name: String = ""
	@export var binds: Array[Bind] = []
	@export var material_values: Array[MaterialBind] = []
	@export var is_binary: bool = false


@export var blend_shape_groups: Array[BlendShapeGroup] = []
