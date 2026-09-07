@tool
extends Resource
class_name RuntimeTextureTransformBind

## See RuntimeMaterialColorBind for the material reference, RuntimeExpression
## for why this is a Resource.

@export var material: Material
@export var scale: Vector2
@export var offset: Vector2