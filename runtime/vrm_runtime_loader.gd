@tool
extends Node3D

## Scene to load VRM Models at runtime for debugging purposes.
## Keeps track of the last 10 opened models and allows testing expressions.


const CONFIG_PATH: String = "user://vrm_recents.cfg"
const MAX_RECENTS: int = 10
const MTOON_SHADER_PATH: String = "res://addons/vrm/shaders/mtoon.gdshader"
const MTOON_OUTLINE_SHADER_PATH: String = "res://addons/vrm/shaders/mtoon_outline.gdshader"
const VRMUtil = preload("res://addons/vrm/common/vrm_util.gd")
const MODEL_ROOT_VRM_NAME: String = "ModelRoot"

const VRM1_TO_VRM0_EXPRESSIONS: Dictionary[String, String] = {
	"happy": "joy",
	"sad": "sorrow",
	"relaxed": "fun",
	"aa": "a",
	"ih": "i",
	"ou": "u",
	"ee": "e",
	"oh": "o",
}

var _recents: Array[String] = []
var _current_model: Node = null
var _expression_controller: Node = null
## Maps each body ShaderMaterial to its generated outline ShaderMaterial.
var _mtoon_outline_materials: Dictionary[ShaderMaterial, ShaderMaterial] = {}

@onready var _ui: VrmRuntimeUI = $UI
@onready var _model_anchor: Node3D = $ModelAnchor
@onready var _world_env: WorldEnvironment = $WorldEnvironment

var _is_animation_paused: bool = false

var _vmd_motion_path: String = ""
var _vmd_camera_path: String = ""
var _vmd_audio_path: String = ""
var _file_dialog_mode: String = "vrm"

## Set to true while a VMD dance with root motion is playing.
var _vmd_root_motion_active: bool = false
## The AnimationPlayer driving the current VMD animation (for root motion polling).
var _vmd_player: AnimationPlayer = null
## Active debug skeleton visualizer (raw VMD motion, no retargeting).
var _debug_skeleton: Node3D = null
## Whether the currently loaded model is VRM 0.0.
var _is_vrm0: bool = false
var _initial_anchor_transform: Transform3D = Transform3D.IDENTITY

@onready var _vmd_camera: Camera3D = Camera3D.new()
@onready var _audio_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Store the initial position of the model anchor (e.g. for grounding offsets)
	_initial_anchor_transform = _model_anchor.transform

	# Setup Nodes
	_vmd_camera.name = "VmdCamera"
	_vmd_camera.unique_name_in_owner = true
	add_child(_vmd_camera)
	_vmd_camera.owner = self
	_vmd_camera.transform.origin = Vector3(0, 1.5, 4) # Default position

	_audio_player.name = "VmdAudioPlayer"
	add_child(_audio_player)

	# Connect signals
	_ui.open_button.pressed.connect(_on_open_vrm_pressed)
	_ui.file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	_ui.stop_button.pressed.connect(_on_stop_animation_pressed)
	_ui.pause_button.pressed.connect(_on_pause_animation_pressed)

	# Connect modular VMD tab
	_ui.setup_tabs()
	_ui.vmd_tab.get_motion_btn().pressed.connect(_on_vmd_slot_pressed.bind("motion"))
	_ui.vmd_tab.get_camera_btn().pressed.connect(_on_vmd_slot_pressed.bind("camera"))
	_ui.vmd_tab.get_audio_btn().pressed.connect(_on_vmd_slot_pressed.bind("audio"))
	_ui.vmd_tab.play_pressed.connect(_on_play_dance_pressed)
	_ui.vmd_tab.dance_folder_selected.connect(_on_dance_folder_selected)
	_ui.vmd_tab.debug_skeleton_pressed.connect(_on_debug_skeleton_pressed)

	_update_animations_ui()

	# Register extensions for runtime loading
	_register_vrm_extensions()

	_load_recents()
	_update_recents_ui()
	_ui.status_label.text = "Select a VRM model to load."


func _physics_process(_delta: float) -> void:
	if not _vmd_root_motion_active or not _vmd_player:
		return
	if not _vmd_player.is_playing():
		return
	# Accumulate root motion delta onto the model anchor each physics tick.
	var motion: Vector3 = _vmd_player.get_root_motion_position()
	var rot: Quaternion = _vmd_player.get_root_motion_rotation()
	_model_anchor.global_transform.basis = (
		Basis(rot) * _model_anchor.global_transform.basis
	)
	_model_anchor.global_transform.origin += (
		_model_anchor.global_transform.basis * motion
	)


func _process(_delta: float) -> void:
	if not _current_model: return
	var player: AnimationPlayer = VRMUtil.find_animation_player(_current_model)
	if not player: return

	if (player.is_playing() or _is_animation_paused) and player.current_animation != "":
		var current_time: float = player.current_animation_position
		var frame: int = int(current_time * 30.0)
		_ui.frame_label.text = "Frame: %d" % frame

		# Sync debug skeleton
		if _debug_skeleton and _debug_skeleton.has_node("DebugPlayer"):
			var debug_player: AnimationPlayer = _debug_skeleton.get_node("DebugPlayer")
			if debug_player.current_animation == "vmd_debug":
				if player.is_playing() and not debug_player.is_playing():
					debug_player.play()
				elif not player.is_playing() and debug_player.is_playing():
					debug_player.pause()

				if abs(debug_player.current_animation_position - current_time) > 0.05:
					debug_player.seek(current_time, true)


func _on_vmd_slot_pressed(mode: String) -> void:
	_file_dialog_mode = mode
	_ui.file_dialog.filters = ["*.vmd ; VMD Motion"] if mode != "audio" else ["*.wav, *.mp3, *.ogg ; Audio"]
	_ui.file_dialog.popup_centered_ratio(0.8)


func _on_open_vrm_pressed() -> void:
	_file_dialog_mode = "vrm"
	_ui.file_dialog.filters = ["*.vrm ; VRM Avatar"]
	_ui.file_dialog.popup_centered_ratio(0.8)


func _on_file_dialog_file_selected(path: String) -> void:
	match _file_dialog_mode:
		"vrm":
			load_vrm(path)
		"motion":
			_vmd_motion_path = path
			_ui.vmd_tab.update_slot("motion", path)
		"camera":
			_vmd_camera_path = path
			_ui.vmd_tab.update_slot("camera", path)
		"audio":
			_vmd_audio_path = path
			_ui.vmd_tab.update_slot("audio", path)


func _on_dance_folder_selected(folder_path: String) -> void:
	if not folder_path.ends_with("/"): folder_path += "/"

	_ui.status_label.text = "Scanning dance folder..."

	var dir: DirAccess = DirAccess.open(folder_path)
	if not dir: return

	var vmd_files: Array[String] = []
	var audio_file: String = ""

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".vmd"):
				vmd_files.append(folder_path + file_name)
			elif file_name.ends_with(".wav") or file_name.ends_with(".mp3") or file_name.ends_with(".ogg"):
				if audio_file.is_empty():
					audio_file = folder_path + file_name
		file_name = dir.get_next()

	# Identify VMD contents
	var motion_vmd: String = ""
	var camera_vmd: String = ""

	for vmd_path: String in vmd_files:
		var data: VmdParser.VmdData = VmdParser.parse_file(vmd_path)
		if data:
			if data.camera_frames.size() > 0:
				camera_vmd = vmd_path
			elif data.bone_frames.size() > 0:
				motion_vmd = vmd_path

	if motion_vmd.is_empty() and not vmd_files.is_empty():
		motion_vmd = vmd_files[0] # Fallback

	# Update slots and paths
	_vmd_motion_path = motion_vmd
	_vmd_camera_path = camera_vmd
	_vmd_audio_path = audio_file

	_ui.vmd_tab.update_slot("motion", motion_vmd)
	_ui.vmd_tab.update_slot("camera", camera_vmd)
	_ui.vmd_tab.update_slot("audio", audio_file)

	_on_play_dance_pressed()


func _on_debug_skeleton_pressed() -> void:
	# Toggle: if already showing, remove it.
	if _debug_skeleton != null:
		_debug_skeleton.queue_free()
		_debug_skeleton = null
		_ui.status_label.text = "Debug skeleton hidden."
		return

	if _vmd_motion_path.is_empty():
		_ui.status_label.text = "Error: Select a motion VMD first."
		return

	_ui.status_label.text = "Parsing VMD for debug skeleton..."

	const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
	const VmdDebugSkeleton = preload("res://addons/vrm/vmd/vmd_debug_skeleton.gd")

	var vmd_data: VmdParser.VmdData = VmdParser.parse_file(_vmd_motion_path)
	if vmd_data == null:
		_ui.status_label.text = "Error: Failed to parse VMD."
		return

	_debug_skeleton = VmdDebugSkeleton.new()
	_debug_skeleton.name = "VmdDebugSkeleton"
	# Place the debug skeleton slightly to the side of the model so both are visible.
	_debug_skeleton.position = Vector3(1.5, 0.0, 0.0)
	add_child(_debug_skeleton)
	(_debug_skeleton as VmdDebugSkeleton).setup(vmd_data)

	_ui.status_label.text = "Debug skeleton active. Press again to hide."


func _on_play_dance_pressed() -> void:
	if not _current_model:
		_ui.status_label.text = "Error: Load a VRM model first."
		return

	if _vmd_motion_path.is_empty():
		_ui.status_label.text = "Error: Select a motion VMD first."
		return

	_ui.status_label.text = "Loading Dance Package..."
	var y_offset: float = _ui.vmd_tab.camera_y_offset
	var a_pose: bool = _ui.vmd_tab.a_pose_vmd_mode
	var debug_ik: bool = _ui.vmd_tab.debug_ik

	# 1. Load Motion
	var position_scale: float = 0.08
	var skeleton: Skeleton3D = VRMUtil.find_skeleton(_current_model)
	if skeleton:
		var head_name: String = VRMUtil.find_bone(skeleton, _current_model, "head")
		var head_idx: int = skeleton.find_bone(head_name)
		if head_idx != -1:
			var head_height: float = skeleton.get_bone_global_rest(head_idx).origin.y
			# Heuristic: MMD models are roughly 1.58m tall, mapping to ~15.8 units.
			# Scale factor = ModelHeight / 15.8.
			position_scale = head_height / 15.8

	var motion_lib: AnimationLibrary = VmdLoader.load_animation_library(_vmd_motion_path, 30.0, y_offset, a_pose, position_scale)
	if not motion_lib: return

	var main_anim: Animation = motion_lib.get_animation("default").duplicate()

	# 2. Load Camera
	if not _vmd_camera_path.is_empty():
		var cam_lib: AnimationLibrary = VmdLoader.load_animation_library(_vmd_camera_path, 30.0, y_offset, a_pose)
		if cam_lib:
			var cam_anim: Animation = cam_lib.get_animation("default")
			for i: int in range(cam_anim.get_track_count()):
				cam_anim.copy_track(i, main_anim)

	# 3. Load Audio
	if not _vmd_audio_path.is_empty():
		var stream: AudioStream = load(_vmd_audio_path)
		if stream:
			_audio_player.stream = stream

	# 4. Setup AnimationPlayer and enable root motion
	var player: AnimationPlayer = VRMUtil.find_animation_player(_current_model)
	if not player:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		_current_model.add_child(player)
	player.owner = self

	var final_lib: AnimationLibrary = AnimationLibrary.new()
	final_lib.add_animation("dance", main_anim)

	if player.has_animation_library(&"VMD"):
		player.remove_animation_library(&"VMD")
	player.add_animation_library(&"VMD", final_lib)

	_retarget_library_for_model(final_lib, _current_model, true)

	# Enable root motion: the %ModelRoot track (from 全ての親) drives world locomotion.
	var has_root_motion: bool = false
	for i: int in range(main_anim.get_track_count()):
		if "%ModelRoot" in str(main_anim.track_get_path(i)):
			has_root_motion = true
			break
	if has_root_motion:
		player.root_motion_track = player.get_path_to(%ModelRoot)
		_vmd_root_motion_active = true
	else:
		player.root_motion_track = NodePath("")
		_vmd_root_motion_active = false
	_vmd_player = player

	# Enable IK if needed
	var ik_controller: Node = _current_model.get_node_or_null("VrmIkController")
	if ik_controller:
		var has_ik: bool = false
		for i: int in range(main_anim.get_track_count()):
			var path: String = str(main_anim.track_get_path(i))
			if "leftLegIk" in path or "rightLegIk" in path or "leftToeIk" in path or "rightToeIk" in path:
				has_ik = true
				break
		ik_controller.enabled = has_ik
		ik_controller.debug = debug_ik

	_vmd_camera.transform.origin = Vector3(0, 1.5, 4) # Default position

	_is_animation_paused = false
	player.play("VMD/dance")
	if _audio_player.stream:
		_audio_player.stream_paused = false
		_audio_player.play()

	_sync_pause_buttons(false)

	_vmd_camera.make_current()
	_ui.status_label.text = "Dancing!"


func load_vrm(path: String) -> void:
	if not FileAccess.file_exists(path):
		_ui.status_label.text = "Error: File does not exist at " + path
		return

	_ui.status_label.text = "Loading: " + path.get_file() + "..."

	# Clear current model
	if _current_model:
		_current_model.queue_free()
		_current_model = null
		_expression_controller = null
		_mtoon_outline_materials.clear()

	# Setup GLTF document and state
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	var err: Error = gltf.append_from_file(path, state)
	if err != OK:
		_ui.status_label.text = "Error: Failed to append GLTF from file. Error code: " + str(err)
		return

	var generated_scene: Node = gltf.generate_scene(state)
	if not generated_scene:
		_ui.status_label.text = "Error: Failed to generate scene."
		return

	_current_model = generated_scene
	# Wrap the loaded model in a ModelRoot node so the %ModelRoot unique name resolves.
	# This is the target for the 全ての親 root-motion track.
	var model_root: Node3D = Node3D.new()
	model_root.name = "ModelRoot"
	model_root.unique_name_in_owner = true
	_model_anchor.add_child(model_root)
	model_root.owner = self

	model_root.add_child(_current_model)
	_current_model.owner = self

	_setup_mtoon_outlines(_current_model)
	_expression_controller = VRMUtil.find_expression_controller(_current_model)
	_is_vrm0 = VRMUtil.is_vrm0(_current_model)

	# Setup IK
	var skeleton: Skeleton3D = VRMUtil.find_skeleton(_current_model)
	if skeleton:
		var ik_controller: Node = load("res://addons/vrm/vmd/vrm_ik_controller.gd").new()
		ik_controller.name = "VrmIkController"
		_current_model.add_child(ik_controller)
		var m_root: Node = get_node("%ModelRoot")
		ik_controller.setup(skeleton, m_root, _is_vrm0)
		# Explicitly set owner to self for unique name resolution in AnimationPlayer
		ik_controller.left_target.owner = self
		ik_controller.right_target.owner = self
		ik_controller.left_toe_target.owner = self
		ik_controller.right_toe_target.owner = self

	_update_expressions_ui()
	_ui.set_model_loaded(true)

	_add_to_recents(path)
	_ui.status_label.text = "Successfully loaded: " + path.get_file()


func _register_vrm_extensions() -> void:
	var vrm0_ext_path: String = "res://addons/vrm/vrm0/vrm0_extension.gd"
	var vrm1_ext_path: String = "res://addons/vrm/vrm1/vrm1_extension.gd"
	if not FileAccess.file_exists(vrm0_ext_path) or not FileAccess.file_exists(vrm1_ext_path):
		return
	var vrm0_ext: GLTFDocumentExtension = load(vrm0_ext_path).new()
	var vrm1_ext: GLTFDocumentExtension = load(vrm1_ext_path).new()
	GLTFDocument.register_gltf_document_extension(vrm0_ext, true)
	GLTFDocument.register_gltf_document_extension(vrm1_ext, true)


func _setup_mtoon_outlines(root: Node) -> void:
	_mtoon_outline_materials.clear()
	_crawl_for_mtoon(root)


func _crawl_for_mtoon(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_outlines_to_mesh(node as MeshInstance3D)
	for child: Node in node.get_children():
		_crawl_for_mtoon(child)


func _apply_outlines_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for i: int in range(mesh_instance.mesh.get_surface_count()):
		var body_mat: Material = mesh_instance.get_surface_override_material(i)
		if body_mat == null:
			body_mat = mesh_instance.mesh.surface_get_material(i)
		if not _is_mtoon(body_mat):
			continue
		var shader_body: ShaderMaterial = body_mat as ShaderMaterial
		if mesh_instance.get_surface_override_material(i) == null:
			shader_body = shader_body.duplicate() as ShaderMaterial
			mesh_instance.set_surface_override_material(i, shader_body)
		var outline: ShaderMaterial = _build_outline_from(shader_body)
		shader_body.next_pass = outline
		_mtoon_outline_materials[shader_body] = outline


func _is_mtoon(mat: Material) -> bool:
	if not (mat is ShaderMaterial):
		return false
	var sm: ShaderMaterial = mat as ShaderMaterial
	return sm.shader != null and sm.shader.resource_path == MTOON_SHADER_PATH


func _build_outline_from(body: ShaderMaterial) -> ShaderMaterial:
	var outline: ShaderMaterial = ShaderMaterial.new()
	outline.shader = load(MTOON_OUTLINE_SHADER_PATH)
	const SHARED_PARAMS: Array[StringName] = [
		&"alpha_mode", &"alpha_cutoff", &"base_color", &"base_color_texture",
		&"shading_shift_factor", &"shading_shift_texture", &"shading_toony_factor",
		&"uv_animation_mask_texture", &"uv_animation_scroll_x_speed",
		&"uv_animation_scroll_y_speed", &"uv_animation_rotation_speed",
	]
	for param: StringName in SHARED_PARAMS:
		var value: Variant = body.get_shader_parameter(param)
		if value != null:
			outline.set_shader_parameter(param, value)
	return outline


func _update_expressions_ui() -> void:
	for child: Node in _ui.expression_list.get_children():
		child.queue_free()
	if not _expression_controller:
		_ui.set_model_loaded(false)
		return
	_ui.set_model_loaded(true)
	var expression_names: Array = []
	if _expression_controller is Vrm0ExpressionController:
		expression_names = _expression_controller.expressions
	elif _expression_controller is Vrm1ExpressionController:
		var binds: Dictionary = _expression_controller.get("_binds")
		if binds:
			expression_names = binds.keys()
	expression_names.sort()
	for exp_name: String in expression_names:
		_add_expression_slider(exp_name)


func _add_expression_slider(exp_name: String) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = exp_name.capitalize()
	label.custom_minimum_size.x = 100
	label.clip_text = true
	hbox.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _expression_controller is Vrm0ExpressionController:
		if exp_name in _expression_controller:
			slider.value = _expression_controller.get(exp_name)
	elif _expression_controller is Vrm1ExpressionController:
		slider.value = _expression_controller.get_expression(exp_name)
	slider.value_changed.connect(_on_expression_value_changed.bind(exp_name))
	hbox.add_child(slider)
	_ui.expression_list.add_child(hbox)


func _on_expression_value_changed(value: float, exp_name: String) -> void:
	if not _expression_controller:
		return
	if _expression_controller is Vrm0ExpressionController:
		_expression_controller.set_expression(exp_name, value)
		if exp_name in _expression_controller:
			_expression_controller.set(exp_name, value)
	elif _expression_controller is Vrm1ExpressionController:
		var standard_props: Array[String] = ["happy", "angry", "sad", "relaxed", "surprised", "aa", "ih", "ou", "ee", "oh", "blink", "blink_left", "blink_right", "look_up", "look_down", "look_left", "look_right", "neutral"]
		var prop_name: String = exp_name.to_snake_case()
		if prop_name in standard_props:
			_expression_controller.set(prop_name, value)
		else:
			_expression_controller.set_custom_expression(exp_name, value)


func _update_animations_ui() -> void:
	if not _ui.anim_list:
		return
	for child: Node in _ui.anim_list.get_children():
		child.queue_free()

	var anim_dir: String = "res://assets/vrma/"
	if not DirAccess.dir_exists_absolute(anim_dir):
		return
	var dir: DirAccess = DirAccess.open(anim_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".vrma") or file_name.ends_with(".bvh")):
				var btn: Button = Button.new()
				btn.text = "▶ " + file_name.get_basename()
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.clip_text = true
				btn.pressed.connect(_on_animation_selected.bind(anim_dir + file_name))
				_ui.anim_list.add_child(btn)
			file_name = dir.get_next()


func _on_animation_selected(path: String) -> void:
	if not _current_model:
		return
	_ui.status_label.text = "Loading Animation: " + path.get_file() + "..."
	var library: AnimationLibrary = VrmaLoader.load_animation_library(path) if path.ends_with(".vrma") else BvhLoader.load_animation_library(path)
	if not library:
		return
	var local_library: AnimationLibrary = library.duplicate(true)
	var player: AnimationPlayer = VRMUtil.find_animation_player(_current_model)
	if not player:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		_current_model.add_child(player)
		player.owner = _current_model
	if player.has_animation_library(&"VRMA"):
		player.remove_animation_library(&"VRMA")
	player.add_animation_library(&"VRMA", local_library)
	_retarget_library_for_model(local_library, _current_model)
	var anims: Array[StringName] = local_library.get_animation_list()
	if not anims.is_empty():
		_is_animation_paused = false
		player.play("VRMA/" + str(anims[0]))
		_sync_pause_buttons(false)


func _retarget_library_for_model(library: AnimationLibrary, model: Node, is_vmd: bool = false) -> void:
	var skeleton: Skeleton3D = VRMUtil.find_skeleton(model)
	if skeleton == null: return
	var is_vrm0: bool = VRMUtil.is_vrm0(model)
	var skeleton_rot: Quaternion = Quaternion.IDENTITY
	var root_node: Node = skeleton.get_parent()
	while root_node != null and root_node is Node3D:
		skeleton_rot = root_node.transform.basis.orthonormalized().get_rotation_quaternion() * skeleton_rot
		root_node = root_node.get_parent()
	var world_rests: Array[Transform3D] = []
	world_rests.resize(skeleton.get_bone_count())
	for i: int in range(skeleton.get_bone_count()):
		world_rests[i] = _compute_bone_world_rest(skeleton, i, skeleton_rot)
	for anim_name: StringName in library.get_animation_list():
		var anim: Animation = library.get_animation(anim_name)
		for i: int in range(anim.get_track_count()):
			var path_str: String = str(anim.track_get_path(i))
			if "Vrm1ExpressionController:" in path_str and is_vrm0:
				var prop_name: String = path_str.split(":")[1]
				var target_prop: String = VRM1_TO_VRM0_EXPRESSIONS.get(prop_name, prop_name)
				anim.track_set_path(i, NodePath("%Vrm0ExpressionController:"+ target_prop))

			var is_ik: bool = "leftLegIk" in path_str or "rightLegIk" in path_str
			var is_root: bool = "%ModelRoot" in path_str
			if not "%GeneralSkeleton:" in path_str and not is_ik and not is_root: continue

			var bone_name: String = ""
			if is_root:
				bone_name = "hips" # Use hips as proxy for root orientation
			elif is_ik:
				bone_name = "leftFoot" if "leftLegIk" in path_str else "rightFoot"
			else:
				bone_name = path_str.split(":")[1]

			var resolved_name: String = VRMUtil.find_bone(skeleton, model, bone_name)
			if resolved_name.is_empty() and not is_root: continue

			if not is_ik and not is_root and resolved_name != bone_name:
				var parts: PackedStringArray = path_str.split(":")
				if parts.size() > 1:
					parts[1] = resolved_name
					anim.track_set_path(i, NodePath(":".join(parts)))

			var bone_idx: int = skeleton.find_bone(resolved_name)
			if bone_idx >= 0 or is_root:
				# Use skeleton world rotation for root/IK, or bone-specific rest for pose
				var W_dst_node: Transform3D = world_rests[bone_idx] if bone_idx >= 0 else Transform3D(Basis(skeleton_rot), Vector3.ZERO)
				var W_dst_q: Quaternion = W_dst_node.basis.get_rotation_quaternion()
				var W_dst_q_inv: Quaternion = W_dst_q.inverse()
				var W_dst_inv_basis: Basis = W_dst_node.basis.inverse()

				if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
					var L_dst: Quaternion = Quaternion.IDENTITY
					if not is_ik:
						L_dst = skeleton.get_bone_rest(bone_idx).basis.orthonormalized().get_rotation_quaternion()

					for k: int in range(anim.track_get_key_count(i)):
						var nlr: Quaternion = anim.track_get_key_value(i, k)
						if is_vmd:
							if is_root or is_ik:
								# For Root and IK targets, raw VMD data is already Godot-forward.
								# Since they are children of %ModelRoot, they inherit the character's facing.
								if is_ik or is_root:
									anim.track_set_key_value(i, k, nlr)
							else:
								# For bones, use the standard world-rest conjugation
								anim.track_set_key_value(i, k, L_dst * W_dst_q_inv * nlr * W_dst_q)
						else:
							# VRMA rotations are absolute world-space orientations.
							anim.track_set_key_value(i, k, L_dst * W_dst_q_inv * nlr * W_dst_q)

				elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
					var local_rest: Vector3 = Vector3.ZERO
					if is_vmd:
						# VMD positions are deltas for bones, but absolute-local for Root/IK.
						if is_root:
							local_rest = Vector3.ZERO
						elif is_ik:
							local_rest = world_rests[bone_idx].origin
						else:
							local_rest = skeleton.get_bone_rest(bone_idx).origin
					else:
						# VRMA/BVH positions are usually deltas from rest or absolute.
						if not is_ik:
							local_rest = skeleton.get_bone_rest(bone_idx).origin
						else:
							local_rest = world_rests[bone_idx].origin

					for k: int in range(anim.track_get_key_count(i)):
						var pos: Vector3 = anim.track_get_key_value(i, k)
						# For Root, rotate by the skeleton overall orientation (to match Anchor)
						# For IK, apply raw (since it's a child of the already-rotated ModelRoot)
						# For Hips, rotate by the hips' rest basis
						var final_pos: Vector3 = local_rest
						if is_root or is_ik:
							final_pos += pos
						else:
							final_pos += W_dst_inv_basis * pos
						anim.track_set_key_value(i, k, final_pos)


func _compute_bone_world_rest(skeleton: Skeleton3D, bone_idx: int, skeleton_rot: Quaternion) -> Transform3D:
	var rest: Transform3D = skeleton.get_bone_rest(bone_idx)
	var parent: int = skeleton.get_bone_parent(bone_idx)
	while parent >= 0:
		rest = skeleton.get_bone_rest(parent) * rest
		parent = skeleton.get_bone_parent(parent)
	return Transform3D(Basis(skeleton_rot), Vector3.ZERO) * rest


func _on_stop_animation_pressed() -> void:
	if not _current_model: return
	var player: AnimationPlayer = VRMUtil.find_animation_player(_current_model)
	if player:
		player.stop()
		_is_animation_paused = false
		_sync_pause_buttons(false)
	if _audio_player.is_playing():
		_audio_player.stop()
	_ui.frame_label.text = "Frame: 0"
	# Reset root motion state and position
	_vmd_root_motion_active = false
	_vmd_player = null
	_model_anchor.transform = Transform3D.IDENTITY


func _on_pause_animation_pressed() -> void:
	if not _current_model: return
	var player: AnimationPlayer = VRMUtil.find_animation_player(_current_model)
	if not player: return

	if player.is_playing():
		if _is_animation_paused:
			# Resume
			player.play()
			if _audio_player.stream and _audio_player.stream_paused:
				_audio_player.stream_paused = false
			elif _audio_player.stream and not _audio_player.is_playing():
				_audio_player.play()
			_is_animation_paused = false
			_sync_pause_buttons(false)
		else:
			# Pause
			player.pause()
			if _audio_player.is_playing():
				_audio_player.stream_paused = true
			_is_animation_paused = true
			_sync_pause_buttons(true)
	else:
		# If stopped but we have an animation, try playing it
		if player.assigned_animation != "":
			player.play()
			_is_animation_paused = false
			_sync_pause_buttons(false)


func _sync_pause_buttons(is_paused: bool) -> void:
	var text: String = "▶ Resume Animation" if is_paused else "⏸ Pause Animation"
	_ui.pause_button.text = text


func _add_to_recents(path: String) -> void:
	if _recents.has(path): _recents.erase(path)
	_recents.push_front(path)
	if _recents.size() > MAX_RECENTS: _recents.pop_back()
	_save_recents()
	_update_recents_ui()


func _save_recents() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("general", "recents", _recents)
	config.save(CONFIG_PATH)


func _load_recents() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		_recents = config.get_value("general", "recents", [])


func _update_recents_ui() -> void:
	for child: Node in _ui.recents_list.get_children(): child.queue_free()
	for path: String in _recents:
		var btn: Button = Button.new()
		btn.text = path.get_file()
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.pressed.connect(load_vrm.bind(path))
		_ui.recents_list.add_child(btn)
