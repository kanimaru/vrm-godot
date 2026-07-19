@tool
extends RefCounted
class_name RuntimeNodeMorphState

# index (int) -> weight (float)
var blend_shapes: Dictionary[int, float] = {}
