@tool
extends Resource
class_name Vrm1Expressions


class MorphTargetBind extends Resource:
	@export var node: int = -1
	@export var index: int = -1
	@export var weight: float = 1.0


class MaterialColorBind extends Resource:
	@export var material: int = -1
	@export var type: String = "color"
	@export var target_value: PackedFloat32Array = PackedFloat32Array()


class TextureTransformBind extends Resource:
	@export var material: int = -1
	@export var scale: Vector2 = Vector2(1.0, 1.0)
	@export var offset: Vector2 = Vector2(0.0, 0.0)


class ExpressionData extends Resource:
	@export var morph_target_binds: Array[MorphTargetBind] = []
	@export var material_color_binds: Array[MaterialColorBind] = []
	@export var texture_transform_binds: Array[TextureTransformBind] = []
	@export var is_binary: bool = false
	@export var override_blink: String = "none"
	@export var override_look_at: String = "none"
	@export var override_mouth: String = "none"


@export var preset: Dictionary = {}
@export var custom: Dictionary = {}
