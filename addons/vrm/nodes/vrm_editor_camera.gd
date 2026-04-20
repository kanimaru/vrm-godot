@tool
class_name VrmEditorCamera
extends Camera3D

## A camera controller that replicates Godot's editor navigation with modern improvements.
## Orbit: Middle Mouse Button (MMB)
## Pan: Shift + Middle Mouse Button (MMB)
## Zoom: Mouse Wheel (Zoom to Cursor)
## Focus: F key (Focus on scene/model)
## Look: Right Mouse Button (RMB) - Rotate camera directly (First-person)
## Fly: Hold RMB + WASDQE keys

@export_group("Sensitivity")
@export var mouse_sensitivity: float = 0.002
@export var orbit_speed: float = 1.0
@export var zoom_speed: float = 1.0

@export_group("Fly Mode")
@export var fly_speed: float = 5.0
@export var fly_acceleration: float = 20.0

@export_group("Smoothing")
@export var smooth_time: float = 0.05

var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 5.0
var _target_pos: Vector3 = Vector3.ZERO
var _camera_pos: Vector3 = Vector3.ZERO

var _current_yaw: float = 0.0
var _current_pitch: float = 0.0
var _current_distance: float = 5.0
var _current_target_pos: Vector3 = Vector3.ZERO
var _current_camera_pos: Vector3 = Vector3.ZERO

var _is_orbiting: bool = false
var _is_panning: bool = false
var _is_freelooking: bool = false

var _velocity: Vector3 = Vector3.ZERO
var _pivot_visualizer: Node3D


func _ready() -> void:
	if not is_inside_tree():
		return
	
	# Initialize values from current transform
	var forward: Vector3 = -global_transform.basis.z
	_camera_pos = global_position
	_target_pos = _camera_pos + forward * _distance
	
	var angles: Vector3 = global_transform.basis.get_euler()
	_yaw = angles.y
	_pitch = angles.x
	
	_current_yaw = _yaw
	_current_pitch = _pitch
	_current_distance = _distance
	_current_target_pos = _target_pos
	_current_camera_pos = _camera_pos
	
	_setup_pivot_visualizer()


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
		
		# Right Mouse: Freelook (Look Directly)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_is_freelooking = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_is_freelooking = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Scroll Wheel: Zoom to Mouse
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_to_mouse(-1.0, get_viewport().get_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to_mouse(1.0, get_viewport().get_mouse_position())

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		
		if _is_orbiting or _is_freelooking:
			_yaw -= mm.relative.x * mouse_sensitivity * orbit_speed
			_pitch -= mm.relative.y * mouse_sensitivity * orbit_speed
			_pitch = clampf(_pitch, -PI/2 + 0.01, PI/2 - 0.01)
		
		elif _is_panning:
			var side: Vector3 = global_transform.basis.x
			var up: Vector3 = global_transform.basis.y
			# Panning scales with distance so dragging feels consistent
			var viewport_size = get_viewport().get_visible_rect().size
			var projection_factor = 2.0 * _distance * tan(deg_to_rad(fov) / 2.0) / viewport_size.y
			var offset: Vector3 = (side * -mm.relative.x + up * mm.relative.y) * projection_factor
			_target_pos += offset
			_camera_pos += offset

	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and k.keycode == KEY_F:
			_focus_on_scene()


func _process(delta: float) -> void:
	# Update logic based on mode
	if _is_freelooking:
		# Calculate movement
		var input_dir: Vector3 = Vector3.ZERO
		if Input.is_key_pressed(KEY_W): input_dir.z -= 1
		if Input.is_key_pressed(KEY_S): input_dir.z += 1
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1
		if Input.is_key_pressed(KEY_D): input_dir.x += 1
		if Input.is_key_pressed(KEY_Q): input_dir.y -= 1
		if Input.is_key_pressed(KEY_E): input_dir.y += 1
		
		var move_dir: Vector3 = global_transform.basis * input_dir
		_velocity = _velocity.lerp(move_dir * fly_speed, fly_acceleration * delta)
		_camera_pos += _velocity * delta
		
		# In Look-mode, target_pos moves relative to current look
		var forward = -Basis.from_euler(Vector3(_pitch, _yaw, 0)).z
		_target_pos = _camera_pos + forward * _distance
	else:
		_velocity = Vector3.ZERO
		
		if _is_orbiting:
			# In Orbit-mode, camera_pos moves around target
			var back = Basis.from_euler(Vector3(_pitch, _yaw, 0)).z
			_camera_pos = _target_pos + back * _distance
	
	# Apply smoothing
	var weight: float = 1.0
	if smooth_time > 0.01:
		weight = 1.0 - exp(-delta / smooth_time)
	
	_current_yaw = lerp_angle(_current_yaw, _yaw, weight)
	_current_pitch = lerp(_current_pitch, _pitch, weight)
	_current_distance = lerp(_current_distance, _distance, weight)
	_current_target_pos = _current_target_pos.lerp(_target_pos, weight)
	_current_camera_pos = _current_camera_pos.lerp(_camera_pos, weight)
	
	_update_transform()
	_update_visualizer()


func _zoom_to_mouse(amount: float, mouse_pos: Vector2) -> void:
	var factor: float = 1.1 if amount > 0 else 0.9
	
	# Raycast to find the 3D point under the mouse at target depth
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_dir = project_ray_normal(mouse_pos)
	var plane = Plane(-global_transform.basis.z, _target_pos)
	var intersection = plane.intersects_ray(ray_origin, ray_dir)
	
	if intersection:
		var old_cam_pos = _camera_pos
		var to_intersection = intersection - old_cam_pos
		
		_distance = maxf(0.1, _distance * factor)
		
		# Shift position so the intersection point stays at the same screen coordinate
		var new_cam_pos = intersection - to_intersection * factor
		var new_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0))
		_camera_pos = new_cam_pos
		_target_pos = _camera_pos - new_basis.z * _distance
	else:
		# Fallback to simple centered zoom
		_distance = maxf(0.1, _distance * factor)
		var back = Basis.from_euler(Vector3(_pitch, _yaw, 0)).z
		_camera_pos = _target_pos + back * _distance


func _focus_on_scene() -> void:
	var aabb: AABB = AABB()
	var found: bool = false
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().root
	if not root: return
	
	for child in root.find_children("", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst.visible:
			var world_aabb = mesh_inst.global_transform * mesh_inst.get_aabb()
			if not found:
				aabb = world_aabb
				found = true
			else:
				aabb = aabb.merge(world_aabb)
	
	if found:
		_target_pos = aabb.get_center()
		_distance = aabb.size.length() * 1.5
		var back = Basis.from_euler(Vector3(_pitch, _yaw, 0)).z
		_camera_pos = _target_pos + back * _distance
	else:
		_target_pos = Vector3.ZERO
		_distance = 5.0


func _update_transform() -> void:
	var basis: Basis = Basis.from_euler(Vector3(_current_pitch, _current_yaw, 0))
	global_transform.basis = basis
	
	if _is_freelooking:
		global_position = _current_camera_pos
	else:
		# Orbit mode needs to stay locked to target
		global_position = _current_target_pos + basis.z * _current_distance


func _setup_pivot_visualizer() -> void:
	if _pivot_visualizer:
		_pivot_visualizer.queue_free()
	
	_pivot_visualizer = Node3D.new()
	_pivot_visualizer.top_level = true
	_pivot_visualizer.visible = false
	add_child(_pivot_visualizer)
	
	var length = 0.2
	var thickness = 0.01
	
	for i in range(3):
		var mesh_inst = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(length if i == 0 else thickness, length if i == 1 else thickness, length if i == 2 else thickness)
		mesh_inst.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.RED if i == 0 else (Color.GREEN if i == 1 else Color.BLUE)
		mat.no_depth_test = true
		mesh_inst.material_override = mat
		_pivot_visualizer.add_child(mesh_inst)


func _update_visualizer() -> void:
	if not _pivot_visualizer: return
	var is_interacting = _is_orbiting or _is_panning
	_pivot_visualizer.visible = is_interacting
	if is_interacting:
		_pivot_visualizer.global_position = _current_target_pos
		var scale_factor = _current_distance * 0.1
		_pivot_visualizer.scale = Vector3(scale_factor, scale_factor, scale_factor)
