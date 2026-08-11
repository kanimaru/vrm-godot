@tool
extends Resource
class_name Vrm0Meta

@export var title: String = ""
@export var version: String = ""
@export var author: String = ""
@export var contact_information: String = ""
@export var reference: String = ""
@export var texture: int = -1
## Resolved by Vrm0Extension._import_post_parse (needs GLTFState, unavailable at parse
## time) - not part of the VRM0 JSON itself.
var thumbnail_texture: Texture2D = null
@export var allowed_user_name: String = ""
@export var violent_ussage_name: String = ""
@export var sexual_ussage_name: String = ""
@export var commercial_ussage_name: String = ""
@export var other_permission_url: String = ""
@export var license_name: String = ""
@export var other_license_url: String = ""
