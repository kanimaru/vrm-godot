@tool
extends Resource
class_name RuntimeExpression

## One compiled expression: what to drive, by how much, on which node/material.
##
## A Resource with exported fields on purpose. These are compiled once, at import
## time, from glTF node indices that only GLTFState can resolve - and then have
## to live inside the PackedScene the importer writes, or every instantiated
## avatar comes up with an empty controller (sliders present, nothing bound,
## `expressions == []`). As plain RefCounted values they were dropped on
## serialization; as Resources they are stored as sub-resources and survive
## both `PackedScene.pack()` and `Node.duplicate()`.

@export var is_binary: bool = false
@export var override_blink: String = "none"
@export var override_look_at: String = "none"
@export var override_mouth: String = "none"

@export var morph_binds: Array[RuntimeMorphBind] = []
@export var color_binds: Array[RuntimeMaterialColorBind] = []
@export var uv_binds: Array[RuntimeTextureTransformBind] = []