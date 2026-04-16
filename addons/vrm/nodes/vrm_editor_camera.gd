@tool
class_name VrmEditorCamera
extends Camera3D

## A camera controller that replicates Godot's editor navigation.
## Orbit: Middle Mouse Button (MMB)
## Pan: Shift + Middle Mouse Button (MMB)
## Zoom: Mouse Wheel or Ctrl + Middle Mouse Button (MMB)
## Freelook: Hold Right Mouse Button (RMB) + WASDQE keys

@export_group("Sensitivity")
@export var mouse_sensitivity: float = 0.002
@export var orbit_speed: float = 1.0
@export var zoom_speed: float = 1.0

@export_group("Fly Mode")
@export var fly_speed: float = 5.0
@export var fly_acceleration: float = 10.0

@export_group("Smoothing")
@export var smooth_time: float = 0.1

var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 5.0
var _target_pos: Vector3 = Vector3.ZERO

var _current_yaw: float = 0.0
var _current_pitch: float = 0.0
var _current_distance: float = 5.0
var _current_target_pos: Vector3 = Vector3.ZERO

var _is_orbiting: bool = false
var _is_panning: bool = false
var _is_freelooking: bool = false

var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	if not is_inside_tree():
		return
	
	# Initialize values from current transform
	var forward: Vector3 = -global_transform.basis.z
	_target_pos = global_position + forward * _distance
	
	var angles: Vector3 = global_transform.basis.get_euler()
	_yaw = angles.y
	_pitch = angles.x
	
	_current_yaw = _yaw
	_current_pitch = _pitch
	_current_distance = _distance
	_current_target_pos = _target_pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		
		# Middle Mouse: Orbit/Pan
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				if mb.shift_pressed:
					_is_panning = true
					_is_orbiting = false
				else:
					_is_orbiting = true
					_is_panning = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_is_orbiting = false
				_is_panning = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Right Mouse: Freelook
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_is_freelooking = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_is_freelooking = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Scroll Wheel: Zoom
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_speed)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_speed)

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		
		if _is_orbiting:
			_yaw -= mm.relative.x * mouse_sensitivity * orbit_speed
			_pitch -= mm.relative.y * mouse_sensitivity * orbit_speed
			_pitch = clampf(_pitch, -PI/2 + 0.01, PI/2 - 0.01)
		
		elif _is_panning:
			var side: Vector3 = global_transform.basis.x
			var up: Vector3 = global_transform.basis.y
			var offset: Vector3 = (side * -mm.relative.x + up * mm.relative.y) * mouse_sensitivity * _distance * 0.5
			_target_pos += offset
			
		elif _is_freelooking:
			_yaw -= mm.relative.x * mouse_sensitivity
			_pitch -= mm.relative.y * mouse_sensitivity
			_pitch = clampf(_pitch, -PI/2 + 0.01, PI/2 - 0.01)


func _process(delta: float) -> void:
	if _is_freelooking:
		var input_dir: Vector3 = Vector3.ZERO
		if Input.is_key_pressed(KEY_W): input_dir.z -= 1
		if Input.is_key_pressed(KEY_S): input_dir.z += 1
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1
		if Input.is_key_pressed(KEY_D): input_dir.x += 1
		if Input.is_key_pressed(KEY_Q): input_dir.y -= 1
		if Input.is_key_pressed(KEY_E): input_dir.y += 1
		
		var move_dir: Vector3 = global_transform.basis * input_dir
		_velocity = _velocity.lerp(move_dir * fly_speed, fly_acceleration * delta)
		global_position += _velocity * delta
		
		# Sync target pos for when we switch back to orbit
		_target_pos = global_position - global_transform.basis.z * _distance
		_current_target_pos = _target_pos
	else:
		_velocity = Vector3.ZERO
		
	# Apply smoothing
	var weight: float = 1.0
	if smooth_time > 0.01:
		weight = 1.0 - exp(-delta / smooth_time)
	
	_current_yaw = lerp_angle(_current_yaw, _yaw, weight)
	_current_pitch = lerp(_current_pitch, _pitch, weight)
	_current_distance = lerp(_current_distance, _distance, weight)
	_current_target_pos = _current_target_pos.lerp(_target_pos, weight)
	
	_update_transform()


func _zoom(amount: float) -> void:
	_distance = maxf(0.1, _distance + amount * zoom_speed)


func _update_transform() -> void:
	var basis: Basis = Basis.from_euler(Vector3(_current_pitch, _current_yaw, 0))
	global_transform.basis = basis
	global_position = _current_target_pos + basis.z * _current_distance
