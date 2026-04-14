@tool
extends Node3D

## Scene to load VRM Models at runtime for debugging purposes.
## Keeps track of the last 10 opened models and allows testing expressions.


const CONFIG_PATH: String = "user://vrm_recents.cfg"
const MAX_RECENTS: int = 10

var _recents: Array[String] = []
var _current_model: Node = null
var _expression_controller: Node = null

@onready var _open_button: Button = $UI/LeftPanel/MarginContainer/VBoxContainer/OpenButton
@onready var _file_dialog: FileDialog = $UI/FileDialog
@onready var _recents_list: VBoxContainer = $UI/LeftPanel/MarginContainer/VBoxContainer/ScrollContainer/RecentsList
@onready var _status_label: Label = $UI/LeftPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var _model_anchor: Node3D = $ModelAnchor

@onready var _no_model_label: Label = $UI/RightPanel/MarginContainer/VBoxContainer/NoModelLabel
@onready var _exp_scroll: ScrollContainer = $UI/RightPanel/MarginContainer/VBoxContainer/ExpScroll
@onready var _expression_list: VBoxContainer = $UI/RightPanel/MarginContainer/VBoxContainer/ExpScroll/ExpressionList


func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	# Connect signals
	_open_button.pressed.connect(_on_open_vrm_pressed)
	_file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	
	# Register extensions for runtime loading
	_register_vrm_extensions()
	
	_load_recents()
	_update_recents_ui()
	_status_label.text = "Select a VRM model to load."


func load_vrm(path: String) -> void:
	if not FileAccess.file_exists(path):
		_status_label.text = "Error: File does not exist at " + path
		return
		
	_status_label.text = "Loading: " + path.get_file() + "..."
	
	# Clear current model
	if _current_model:
		_current_model.queue_free()
		_current_model = null
		_expression_controller = null
		
	# Setup GLTF document and state
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	
	var err: Error = gltf.append_from_file(path, state)
	if err != OK:
		_status_label.text = "Error: Failed to append GLTF from file. Error code: " + str(err)
		return
		
	var generated_scene: Node = gltf.generate_scene(state)
	if not generated_scene:
		_status_label.text = "Error: Failed to generate scene."
		return
		
	_current_model = generated_scene
	_model_anchor.add_child(_current_model)
	
	# Find expression controller
	_expression_controller = _find_expression_controller(_current_model)
	_update_expressions_ui()
	
	_add_to_recents(path)
	_status_label.text = "Successfully loaded: " + path.get_file()


func _register_vrm_extensions() -> void:
	var vrm0_ext_path := "res://addons/vrm/vrm0/vrm0_extension.gd"
	var vrm1_ext_path := "res://addons/vrm/vrm1/vrm1_extension.gd"
	
	if not FileAccess.file_exists(vrm0_ext_path) or not FileAccess.file_exists(vrm1_ext_path):
		return
		
	var vrm0_ext = load(vrm0_ext_path).new()
	var vrm1_ext = load(vrm1_ext_path).new()
	
	GLTFDocument.register_gltf_document_extension(vrm0_ext, true)
	GLTFDocument.register_gltf_document_extension(vrm1_ext, true)


func _find_expression_controller(root: Node) -> Node:
	# VRM controllers are typically direct children of the scene root
	for child in root.get_children():
		if child.get_class() == "Vrm0ExpressionController" or child is Vrm0ExpressionController:
			return child
		if child.get_class() == "Vrm1ExpressionController" or child is Vrm1ExpressionController:
			return child
	return null


func _update_expressions_ui() -> void:
	# Clear old sliders
	for child in _expression_list.get_children():
		child.queue_free()
		
	if not _expression_controller:
		_no_model_label.visible = true
		_exp_scroll.visible = false
		return
		
	_no_model_label.visible = false
	_exp_scroll.visible = true
	
	var expression_names: Array = []
	
	if _expression_controller is Vrm0ExpressionController:
		expression_names = _expression_controller.expression_binds.keys()
	elif _expression_controller is Vrm1ExpressionController:
		# Accessing the internal _binds dictionary
		var binds = _expression_controller.get("_binds")
		if binds:
			expression_names = binds.keys()
			
	expression_names.sort()
	
	for exp_name in expression_names:
		_add_expression_slider(exp_name)


func _add_expression_slider(exp_name: String) -> void:
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	label.text = exp_name.capitalize()
	label.custom_minimum_size.x = 100
	label.clip_text = true
	hbox.add_child(label)
	
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Initial value
	if _expression_controller is Vrm0ExpressionController:
		# Some expressions match property names
		if exp_name in _expression_controller:
			slider.value = _expression_controller.get(exp_name)
	elif _expression_controller is Vrm1ExpressionController:
		slider.value = _expression_controller.get_expression(exp_name)
		
	slider.value_changed.connect(_on_expression_value_changed.bind(exp_name))
	hbox.add_child(slider)
	
	_expression_list.add_child(hbox)


func _on_expression_value_changed(value: float, exp_name: String) -> void:
	if not _expression_controller:
		return
		
	if _expression_controller is Vrm0ExpressionController:
		# Vrm0ExpressionController has set_expression
		_expression_controller.set_expression(exp_name, value)
		# Also update the property if it exists so the slider matches state if property is changed elsewhere
		if exp_name in _expression_controller:
			_expression_controller.set(exp_name, value)
	elif _expression_controller is Vrm1ExpressionController:
		# Vrm1ExpressionController handles both standard and custom via properties or set_custom_expression
		var standard_props = ["happy", "angry", "sad", "relaxed", "surprised", "aa", "ih", "ou", "ee", "oh", "blink", "blink_left", "blink_right", "look_up", "look_down", "look_left", "look_right", "neutral"]
		var prop_name = exp_name.to_snake_case()
		if prop_name in standard_props:
			_expression_controller.set(prop_name, value)
		else:
			_expression_controller.set_custom_expression(exp_name, value)


func _add_to_recents(path: String) -> void:
	if _recents.has(path):
		_recents.erase(path)
	
	_recents.push_front(path)
	
	if _recents.size() > MAX_RECENTS:
		_recents.pop_back()
		
	_save_recents()
	_update_recents_ui()


func _save_recents() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "recents", _recents)
	config.save(CONFIG_PATH)


func _load_recents() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(CONFIG_PATH)
	if err == OK:
		_recents = config.get_value("general", "recents", [])


func _update_recents_ui() -> void:
	for child in _recents_list.get_children():
		child.queue_free()
		
	for path in _recents:
		var btn := Button.new()
		btn.text = path.get_file()
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = path
		btn.pressed.connect(load_vrm.bind(path))
		_recents_list.add_child(btn)


func _on_open_vrm_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.8)


func _on_file_dialog_file_selected(path: String) -> void:
	load_vrm(path)
