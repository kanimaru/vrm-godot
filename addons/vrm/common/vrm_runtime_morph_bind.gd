@tool
extends Resource
class_name RuntimeMorphBind

## Path is relative to the expression controller ("../Body"), so it resolves the
## same way in the importer's tree, in a scene instantiated from the .scn, and
## in a duplicate. See RuntimeExpression for why this is a Resource.

@export var path: NodePath
@export var index: int
@export var weight: float