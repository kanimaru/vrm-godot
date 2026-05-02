@tool
extends ScrollContainer

## UI Tab for VMD Studio playback management.
## Emits signals when files are selected or the play button is pressed.
class_name VrmRuntimeVmdTab

signal play_pressed()
signal dance_folder_selected(path: String)
signal debug_skeleton_pressed()

var motion_path: String = ""
var camera_path: String = ""
var audio_path: String = ""

var camera_y_offset: float = 0.0
var a_pose_vmd_mode: bool = true
var debug_ik: bool = false

@onready var _motion_btn: Button = %MotionBtn
@onready var _camera_btn: Button = %CameraBtn
@onready var _audio_btn: Button = %AudioBtn
@onready var _offset_spin: SpinBox = %OffsetSpin
@onready var _apose_check: CheckBox = %APoseCheck
@onready var _debug_check: CheckBox = %DebugCheck
@onready var _play_btn: Button = %PlayBtn
@onready var _dance_list: VBoxContainer = %DanceList

func _ready() -> void:
	# Signals
	_offset_spin.value_changed.connect(func(v): camera_y_offset = v)
	_apose_check.toggled.connect(func(v): a_pose_vmd_mode = v)
	_debug_check.toggled.connect(func(v): debug_ik = v)
	_play_btn.pressed.connect(func(): play_pressed.emit())
	
	var debug_skel_btn: Button = Button.new()
	debug_skel_btn.name = "DebugSkeletonBtn"
	debug_skel_btn.text = "🦴 Debug Skeleton"
	debug_skel_btn.tooltip_text = "Show raw VMD motion as a wire-frame stick figure (no retargeting)"
	debug_skel_btn.pressed.connect(func(): debug_skeleton_pressed.emit())
	# Insert before the play button's parent container
	_play_btn.get_parent().add_child(debug_skel_btn)
	_play_btn.get_parent().move_child(debug_skel_btn, _play_btn.get_index())
	
	# Initial Values
	camera_y_offset = _offset_spin.value
	a_pose_vmd_mode = _apose_check.button_pressed
	
	refresh_dances()


func refresh_dances() -> void:
	for child in _dance_list.get_children():
		child.queue_free()
		
	var path := "res://assets/vmd/"
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
		
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var folder_name := dir.get_next()
		while folder_name != "":
			if dir.current_is_dir() and not folder_name.begins_with("."):
				var btn := Button.new()
				btn.text = folder_name.capitalize()
				btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
				btn.pressed.connect(func(): dance_folder_selected.emit(path + folder_name))
				_dance_list.add_child(btn)
			folder_name = dir.get_next()



func update_slot(type: String, path: String) -> void:
	match type:
		"motion":
			motion_path = path
			_motion_btn.text = path.get_file()
		"camera":
			camera_path = path
			_camera_btn.text = path.get_file()
		"audio":
			audio_path = path
			_audio_btn.text = path.get_file()



func get_motion_btn() -> Button: return _motion_btn
func get_camera_btn() -> Button: return _camera_btn
func get_audio_btn() -> Button: return _audio_btn
