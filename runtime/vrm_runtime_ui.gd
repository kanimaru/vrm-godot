@tool
extends CanvasLayer
class_name VrmRuntimeUI

## Specialized UI for the VRM Runtime Loader.
## Exposes internal nodes and handles tabbed layout setup.

@onready var open_button: Button = $LeftPanel/MarginContainer/VBoxContainer/OpenButton
@onready var file_dialog: FileDialog = $FileDialog
@onready var recents_list: VBoxContainer = $LeftPanel/MarginContainer/VBoxContainer/ScrollContainer/RecentsList
@onready var status_label: Label = $LeftPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var no_model_label: Label = $RightPanel/MarginContainer/VBoxContainer/NoModelLabel
@onready var exp_scroll: ScrollContainer = $RightPanel/MarginContainer/VBoxContainer/ExpScroll
@onready var expression_list: VBoxContainer = $RightPanel/MarginContainer/VBoxContainer/ExpScroll/ExpressionList
@onready var right_vbox: VBoxContainer = $RightPanel/MarginContainer/VBoxContainer

var tab_container: TabContainer
var anim_list: VBoxContainer


func setup_tabs() -> void:
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.visible = false
	right_vbox.add_child(tab_container)
	
	# Reparent Expression Scroll
	exp_scroll.get_parent().remove_child(exp_scroll)
	tab_container.add_child(exp_scroll)
	exp_scroll.name = "Expressions"
	
	# Create Animations Scroll
	var anim_scroll := ScrollContainer.new()
	anim_scroll.name = "Animations"
	anim_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	anim_list = VBoxContainer.new()
	anim_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anim_list.add_theme_constant_override("separation", 4)
	anim_scroll.add_child(anim_list)
	tab_container.add_child(anim_scroll)


func set_model_loaded(is_loaded: bool) -> void:
	no_model_label.visible = not is_loaded
	if tab_container:
		tab_container.visible = is_loaded
