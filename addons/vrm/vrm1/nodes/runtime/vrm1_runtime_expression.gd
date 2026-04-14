@tool
extends RefCounted
class_name RuntimeExpression

var is_binary: bool = false
var override_blink: String = "none"
var override_look_at: String = "none"
var override_mouth: String = "none"

var morph_binds: Array[RuntimeMorphBind] = []
var color_binds: Array[RuntimeMaterialColorBind] = []
var uv_binds: Array[RuntimeTextureTransformBind] = []
