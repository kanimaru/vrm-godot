@tool
extends EditorInspectorPlugin
class_name Vrm1InspectorPlugin

## EditorInspectorPlugin for VRM 1.0 models.
## Injects a read-only Vrm1InspectorPanel at the top of the Inspector
## when the selected node has vrm1_data metadata (set during GLTF import).


func _can_handle(object: Object) -> bool:
	return object is Node and (object as Node).has_meta("vrm1_data")


func _parse_begin(object: Object) -> void:
	var node := object as Node
	var data := node.get_meta("vrm1_data") as Vrm1TopLevel
	if data == null:
		return
	
	var panel := preload("res://addons/vrm/vrm1/vrm1_inspector_panel.gd").new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.build(data)
	add_custom_control(panel)
