@tool
extends Node3D

## Scene to load VRM Models at runtime for debugging purposes.
## Keeps track of the last 10 opened models and allows testing expressions.


const CONFIG_PATH: String = "user://vrm_recents.cfg"
const MAX_RECENTS: int = 10
const MTOON_SHADER_PATH := "res://addons/vrm/shaders/mtoon.gdshader"
const MTOON_OUTLINE_SHADER_PATH := "res://addons/vrm/shaders/mtoon_outline.gdshader"

const VRM1_TO_VRM0_EXPRESSIONS: Dictionary = {
	"happy": "joy",
	"sad": "sorrow",
	"relaxed": "fun",
	"aa": "a",
	"ih": "i",
	"ou": "u",
	"ee": "e",
	"oh": "o"
}

var _recents: Array[String] = []
var _current_model: Node = null
var _expression_controller: Node = null
## Maps each body ShaderMaterial to its generated outline ShaderMaterial.
var _mtoon_outline_materials: Dictionary[ShaderMaterial, ShaderMaterial] = {}

@onready var _ui: VrmRuntimeUI = $UI
@onready var _model_anchor: Node3D = $ModelAnchor
@onready var _world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Connect signals
	_ui.open_button.pressed.connect(_on_open_vrm_pressed)
	_ui.file_dialog.file_selected.connect(_on_file_dialog_file_selected)

	# Setup UI
	_ui.setup_tabs()
	_update_animations_ui()

	# Register extensions for runtime loading
	_register_vrm_extensions()

	_load_recents()
	_update_recents_ui()
	_ui.status_label.text = "Select a VRM model to load."


func _process(_delta: float) -> void:
	# Reserved for future per-frame GI / outline updates.
	pass


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
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	
	var err: Error = gltf.append_from_file(path, state)
	if err != OK:
		_ui.status_label.text = "Error: Failed to append GLTF from file. Error code: " + str(err)
		return
		
	var generated_scene: Node = gltf.generate_scene(state)
	if not generated_scene:
		_ui.status_label.text = "Error: Failed to generate scene."
		return
		
	_current_model = generated_scene
	_model_anchor.add_child(_current_model)

	# Apply MToon outline pass to every qualifying mesh surface.
	_setup_mtoon_outlines(_current_model)

	# Find expression controller
	_expression_controller = _find_expression_controller(_current_model)
	_update_expressions_ui()
	_ui.set_model_loaded(true)

	_add_to_recents(path)
	_ui.status_label.text = "Successfully loaded: " + path.get_file()


func _register_vrm_extensions() -> void:
	var vrm0_ext_path := "res://addons/vrm/vrm0/vrm0_extension.gd"
	var vrm1_ext_path := "res://addons/vrm/vrm1/vrm1_extension.gd"

	if not FileAccess.file_exists(vrm0_ext_path) or not FileAccess.file_exists(vrm1_ext_path):
		return

	var vrm0_ext = load(vrm0_ext_path).new()
	var vrm1_ext = load(vrm1_ext_path).new()

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
	var sm := mat as ShaderMaterial
	return sm.shader != null and sm.shader.resource_path == MTOON_SHADER_PATH


func _build_outline_from(body: ShaderMaterial) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
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


func _find_expression_controller(root: Node) -> Node:
	for child in root.get_children():
		if child.get_class() == "Vrm0ExpressionController" or child is Vrm0ExpressionController:
			return child
		if child.get_class() == "Vrm1ExpressionController" or child is Vrm1ExpressionController:
			return child
	return null


func _update_expressions_ui() -> void:
	for child in _ui.expression_list.get_children():
		child.queue_free()
		
	if not _expression_controller:
		_ui.set_model_loaded(false)
		return
		
	_ui.set_model_loaded(true)
	
	var expression_names: Array = []
	if _expression_controller is Vrm0ExpressionController:
		expression_names = _expression_controller.expressions
	elif _expression_controller is Vrm1ExpressionController:
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
		var standard_props = ["happy", "angry", "sad", "relaxed", "surprised", "aa", "ih", "ou", "ee", "oh", "blink", "blink_left", "blink_right", "look_up", "look_down", "look_left", "look_right", "neutral"]
		var prop_name = exp_name.to_snake_case()
		if prop_name in standard_props:
			_expression_controller.set(prop_name, value)
		else:
			_expression_controller.set_custom_expression(exp_name, value)


func _update_animations_ui() -> void:
	if not _ui.anim_list:
		return
		
	for child in _ui.anim_list.get_children():
		child.queue_free()
	
	var stop_btn := Button.new()
	stop_btn.text = "⏹ Stop Animation"
	stop_btn.pressed.connect(_on_stop_animation_pressed)
	_ui.anim_list.add_child(stop_btn)
	_ui.anim_list.add_child(HSeparator.new())
	
	var anim_dir := "res://assets/vrma/"
	if not DirAccess.dir_exists_absolute(anim_dir):
		var lbl := Label.new()
		lbl.text = "No animations found in " + anim_dir
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ui.anim_list.add_child(lbl)
		return
		
	var dir := DirAccess.open(anim_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".vrma") or file_name.ends_with(".bvh")):
				var btn := Button.new()
				btn.text = "▶ " + file_name.get_basename()
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.pressed.connect(_on_animation_selected.bind(anim_dir + file_name))
				_ui.anim_list.add_child(btn)
			file_name = dir.get_next()


func _on_animation_selected(path: String) -> void:
	if not _current_model:
		return
	_ui.status_label.text = "Loading Animation: " + path.get_file() + "..."
	var library: AnimationLibrary = VrmaLoader.load_animation_library(path) if path.ends_with(".vrma") else BvhLoader.load_animation_library(path)
	if not library:
		_ui.status_label.text = "Error: Failed to load VRMA at " + path
		return
	
	# Create a unique copy so retargeting doesn't corrupt the cached resource or compound rotations.
	var local_library: AnimationLibrary = library.duplicate(true)
	
	var player := _find_animation_player(_current_model)
	if not player:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		_current_model.add_child(player)
		player.owner = _current_model
	
	if player.has_animation_library(&"VRMA"):
		player.remove_animation_library(&"VRMA")
	player.add_animation_library(&"VRMA", local_library)
	
	# Retarget bone paths in the local copy to match this specific avatar's skeleton.
	_retarget_library_for_model(local_library, _current_model)
	
	var anims := local_library.get_animation_list()
	if not anims.is_empty():
		player.play("VRMA/" + str(anims[0]))
		_ui.status_label.text = "Playing: " + path.get_file()


func _retarget_library_for_model(library: AnimationLibrary, model: Node) -> void:
	var skeleton: Skeleton3D = _find_skeleton(model)
	if skeleton == null:
		push_warning("VrmRuntimeLoader: No Skeleton3D found for retargeting.")
		return

	# Build lookup tables
	var role_to_bone: Dictionary = model.get_meta("vrm_humanoid_bones", {})
	var bone_names_lower: Dictionary = {}
	for i in range(skeleton.get_bone_count()):
		var b: String = skeleton.get_bone_name(i)
		bone_names_lower[b.to_lower()] = b

	# Pre-compute skeleton base rotation (from parents like the GLTF root node).
	var is_vrm0: bool = model.has_meta("vrm0_data")
	var skeleton_rot := Quaternion.IDENTITY
	
	var root_node: Node = skeleton.get_parent()
	while root_node != null and root_node is Node3D:
		skeleton_rot = root_node.transform.basis.orthonormalized().get_rotation_quaternion() * skeleton_rot
		root_node = root_node.get_parent()

	# Pre-compute world rest rotations for all bones.
	# This captures Godot's SkeletonProfileHumanoid reorientations (vital for VRM1)
	# AND the physical world direction of the mesh (vital for VRM0).
	var world_rests: Array[Quaternion] = []
	world_rests.resize(skeleton.get_bone_count())
	for i in range(skeleton.get_bone_count()):
		world_rests[i] = _compute_bone_world_rest(skeleton, i, skeleton_rot)

	for anim_name in library.get_animation_list():
		var anim: Animation = library.get_animation(anim_name)
		var fixed := 0
		var failed: Array[String] = []

		for i in range(anim.get_track_count()):
			var path_str: String = str(anim.track_get_path(i))
			if not "%GeneralSkeleton:" in path_str:
				continue
			var parts := path_str.split(":")
			if parts.size() < 2:
				continue
			var bone_name: String = parts[1]

			# --- Step A: Resolve the bone name ---
			var resolved_name := ""
			if skeleton.find_bone(bone_name) != -1:
				resolved_name = bone_name
			else:
				# Try case-insensitive humanoid role metadata lookup
				var bone_name_lower := bone_name.to_lower()
				if role_to_bone.has(bone_name_lower):
					resolved_name = role_to_bone[bone_name_lower]
				
				if resolved_name.is_empty():
					# Try case-insensitive match against skeleton bone names
					if bone_names_lower.has(bone_name_lower):
						resolved_name = bone_names_lower[bone_name_lower]

			if resolved_name.is_empty():
				failed.append(bone_name)
				continue

			if resolved_name != bone_name:
				parts[1] = resolved_name
				anim.track_set_path(i, NodePath(":".join(parts)))
				fixed += 1

			# --- Step B: Apply target rest pose (spec Step 2) ---
			# Rotations: B.LocalRotation = L_dst * W_dst⁻¹ * NLR * W_dst
			# Positions: B.LocalPosition = L_dst_pos + (W_dst_inv * NLR_pos)
			var bone_idx := skeleton.find_bone(resolved_name)
			if bone_idx >= 0:
				if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
					var L_dst: Quaternion = skeleton.get_bone_rest(bone_idx).basis.orthonormalized().get_rotation_quaternion()
					var W_dst: Quaternion = world_rests[bone_idx]
					var W_dst_inv: Quaternion = W_dst.inverse()
					if not (L_dst.is_equal_approx(Quaternion.IDENTITY) and W_dst.is_equal_approx(Quaternion.IDENTITY)):
						for k in range(anim.track_get_key_count(i)):
							var nlr: Quaternion = anim.track_get_key_value(i, k)
							anim.track_set_key_value(i, k, L_dst * W_dst_inv * nlr * W_dst)
							
				elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
					var W_dst_inv: Quaternion = world_rests[bone_idx].inverse()
					if not W_dst_inv.is_equal_approx(Quaternion.IDENTITY):
						for k in range(anim.track_get_key_count(i)):
							var pos: Vector3 = anim.track_get_key_value(i, k)
							anim.track_set_key_value(i, k, W_dst_inv * pos)

		# --- Step C: Expression Controller Retargeting (VRM 0.0 vs 1.0) ---
		for i in range(anim.get_track_count()):
			var path_str: String = str(anim.track_get_path(i))
			if "Vrm1ExpressionController:" in path_str and is_vrm0:
				var prop_name := path_str.split(":")[1]
				var target_prop: String = VRM1_TO_VRM0_EXPRESSIONS.get(prop_name, prop_name)
				var new_path := "%Vrm0ExpressionController:" + target_prop
				anim.track_set_path(i, NodePath(new_path))

		print("VrmRuntimeLoader: '", anim_name, "' fixed=", fixed, " unresolved=", failed)


func _compute_bone_world_rest(skeleton: Skeleton3D, bone_idx: int, skeleton_rot: Quaternion) -> Quaternion:
	var rot: Quaternion = skeleton.get_bone_rest(bone_idx).basis.orthonormalized().get_rotation_quaternion()
	var parent: int = skeleton.get_bone_parent(bone_idx)
	while parent >= 0:
		rot = skeleton.get_bone_rest(parent).basis.orthonormalized().get_rotation_quaternion() * rot
		parent = skeleton.get_bone_parent(parent)
	return skeleton_rot * rot


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children(true):
		var res := _find_skeleton(child)
		if res:
			return res
	return null


func _on_stop_animation_pressed() -> void:
	if not _current_model:
		return
	var player := _find_animation_player(_current_model)
	if player:
		player.stop()
		_ui.status_label.text = "Animation stopped."


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var res := _find_animation_player(child)
		if res:
			return res
	return null


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
	if config.load(CONFIG_PATH) == OK:
		_recents = config.get_value("general", "recents", [])


func _update_recents_ui() -> void:
	for child in _ui.recents_list.get_children():
		child.queue_free()
	for path in _recents:
		var btn := Button.new()
		btn.text = path.get_file()
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(load_vrm.bind(path))
		_ui.recents_list.add_child(btn)


func _on_open_vrm_pressed() -> void:
	_ui.file_dialog.popup_centered_ratio(0.8)


func _on_file_dialog_file_selected(path: String) -> void:
	load_vrm(path)
