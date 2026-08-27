@tool
extends EditorPlugin
const inspector_plugin_class = preload("./inspector_mtoon.gd")
const mtoon_controller_class = preload("./mtoon_controller.gd")

var inspector_plugin: Object = null


func _enter_tree() -> void:
	inspector_plugin = inspector_plugin_class.new()
	add_inspector_plugin(inspector_plugin)
	# Safely register MtoonController - icon can be null
	var icon: Texture2D = null
	if get_editor_interface() and get_editor_interface().get_base_control():
		icon = get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
	add_custom_type("MtoonController", "Node", mtoon_controller_class, icon)


func _exit_tree() -> void:
	remove_custom_type("MtoonController")
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
