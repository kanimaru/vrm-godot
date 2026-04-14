@tool
extends Resource
class_name Vrm1ExpressionData

@export var is_binary: bool = false
@export var override_blink: String = "none"
@export var override_look_at: String = "none"
@export var override_mouth: String = "none"
@export var morph_binds: Array[Vrm1ExpressionMorphBind] = []
@export var material_color_binds: Array[Vrm1ExpressionMaterialColorBind] = []
@export var texture_transform_binds: Array[Vrm1ExpressionTextureTransformBind] = []
