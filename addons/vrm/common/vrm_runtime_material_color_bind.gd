@tool
extends Resource
class_name RuntimeMaterialColorBind

## `material` is the live MToon ShaderMaterial the mesh renders with. It is a
## sub-resource of the same scene, so serializing this bind stores a reference to
## that sub-resource and an instantiated scene hands back the very material its
## mesh uses - the bind and the mesh cannot drift apart. See RuntimeExpression.

@export var material: Material
@export var prop: String
@export var color: Color