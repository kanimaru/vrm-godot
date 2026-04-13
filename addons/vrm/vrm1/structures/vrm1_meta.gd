@tool
extends Resource
class_name Vrm1Meta

@export var name: String = ""
@export var version: String = ""
@export var authors: PackedStringArray = PackedStringArray()
@export var copyright_information: String = ""
@export var contact_information: String = ""
@export var references: PackedStringArray = PackedStringArray()
@export var third_party_licenses: String = ""
@export var thumbnail_image: int = -1
@export var license_url: String = "https://vrm.dev/licenses/1.0/"
@export var avatar_permission: String = "onlyAuthor"
@export var allow_excessively_violent_usage: bool = false
@export var allow_excessively_sexual_usage: bool = false
@export var commercial_usage: String = "personalNonProfit"
@export var allow_political_or_religious_usage: bool = false
@export var allow_antisocial_or_hate_usage: bool = false
@export var credit_notation: String = "required"
@export var allow_redistribution: bool = false
@export var modification: String = "prohibited"
