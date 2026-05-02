@tool
class_name VmdDebugSkeleton
extends Node3D

## Visualizes raw VMD motion data as an animated wire-frame stick figure.
## No retargeting is applied — what you see is exactly what is in the VMD file
## after coordinate conversion (Z-flip) and scale (* 0.1).
## Useful for debugging bone rotations and positions before applying to a VRM skeleton.

const VmdParser = preload("res://addons/vrm/vmd/vmd_parser.gd")
const VmdAnimationLibraryBuilder = preload("res://addons/vrm/vmd/vmd_animation_library_builder.gd")

# MMD humanoid hierarchy: bone_name -> parent_bone_name (empty string = root)
static var HIERARCHY: Dictionary = {
	"hips": "",
	"spine": "hips",
	"chest": "spine",
	"upperChest": "chest",
	"neck": "upperChest",
	"head": "neck",
	"leftShoulder": "upperChest",
	"leftUpperArm": "leftShoulder",
	"leftLowerArm": "leftUpperArm",
	"leftHand": "leftLowerArm",
	"rightShoulder": "upperChest",
	"rightUpperArm": "rightShoulder",
	"rightLowerArm": "rightUpperArm",
	"rightHand": "rightLowerArm",
	"leftUpperLeg": "hips",
	"leftLowerLeg": "leftUpperLeg",
	"leftFoot": "leftLowerLeg",
	"leftToes": "leftFoot",
	"rightUpperLeg": "hips",
	"rightLowerLeg": "rightUpperLeg",
	"rightFoot": "rightLowerLeg",
	"rightToes": "rightFoot",
}

# Approximate bone lengths (metres) for drawing the stick figure.
static var BONE_LENGTHS: Dictionary = {
	"hips": 0.12,
	"spine": 0.18,
	"chest": 0.18,
	"upperChest": 0.12,
	"neck": 0.08,
	"head": 0.12,
	"leftShoulder": 0.08,
	"leftUpperArm": 0.28,
	"leftLowerArm": 0.24,
	"leftHand": 0.10,
	"rightShoulder": 0.08,
	"rightUpperArm": 0.28,
	"rightLowerArm": 0.24,
	"rightHand": 0.10,
	"leftUpperLeg": 0.42,
	"leftLowerLeg": 0.38,
	"leftFoot": 0.12,
	"leftToes": 0.08,
	"rightUpperLeg": 0.42,
	"rightLowerLeg": 0.38,
	"rightFoot": 0.12,
	"rightToes": 0.08,
}

# Bone colors: left side = blue, right side = green, centre = white.
static var BONE_COLORS: Dictionary = {
	"hips": Color(1.0, 1.0, 0.0),
	"spine": Color(1.0, 1.0, 1.0),
	"chest": Color(1.0, 1.0, 1.0),
	"upperChest": Color(1.0, 1.0, 1.0),
	"neck": Color(1.0, 1.0, 1.0),
	"head": Color(1.0, 1.0, 1.0),
}

# Local position of each bone's pivot relative to its parent's pivot in T-pose.
# These offsets define the humanoid shape — no animation applied yet.
static var BONE_REST_OFFSETS: Dictionary = {
	"hips":         Vector3(0.0,   0.90,  0.0),   # hips world height
	"spine":        Vector3(0.0,   0.12,  0.0),
	"chest":        Vector3(0.0,   0.18,  0.0),
	"upperChest":   Vector3(0.0,   0.18,  0.0),
	"neck":         Vector3(0.0,   0.12,  0.0),
	"head":         Vector3(0.0,   0.08,  0.0),
	"leftShoulder": Vector3(-0.05, 0.10,  0.0),
	"leftUpperArm": Vector3(-0.08, 0.0,   0.0),
	"leftLowerArm": Vector3(-0.28, 0.0,   0.0),
	"leftHand":     Vector3(-0.24, 0.0,   0.0),
	"rightShoulder":Vector3( 0.05, 0.10,  0.0),
	"rightUpperArm":Vector3( 0.08, 0.0,   0.0),
	"rightLowerArm":Vector3( 0.28, 0.0,   0.0),
	"rightHand":    Vector3( 0.24, 0.0,   0.0),
	"leftUpperLeg": Vector3(-0.10, -0.04, 0.0),
	"leftLowerLeg": Vector3( 0.0,  -0.42, 0.0),
	"leftFoot":     Vector3( 0.0,  -0.38, 0.0),
	"leftToes":     Vector3( 0.0,  -0.10, 0.10),
	"rightUpperLeg":Vector3( 0.10, -0.04, 0.0),
	"rightLowerLeg":Vector3( 0.0,  -0.42, 0.0),
	"rightFoot":    Vector3( 0.0,  -0.38, 0.0),
	"rightToes":    Vector3( 0.0,  -0.10, 0.10),
}


static func _init_hierarchy_and_offsets() -> void:
	var sides = ["left", "right"]
	var fingers = ["Thumb", "Index", "Middle", "Ring", "Little"]
	var joints = ["Proximal", "Intermediate", "Distal"]
	var thumb_joints = ["Metacarpal", "Proximal", "Distal"]
	
	for s in range(2):
		var side = sides[s]
		var side_sign = -1.0 if s == 0 else 1.0
		var hand = side + "Hand"
		
		for f in range(5):
			var finger = fingers[f]
			var parent = hand
			for j in range(3):
				var joint = joints[j]
				if finger == "Thumb": joint = thumb_joints[j]
				var bone = side + finger + joint
				
				HIERARCHY[bone] = parent
				BONE_LENGTHS[bone] = 0.03 if finger == "Thumb" else 0.04
				
				# Offset
				if j == 0:
					# Hand to Proximal
					var spread_y = (f - 2) * 0.01
					var spread_z = (f - 2) * 0.005 # Reversed spread for forward -Z
					var length = side_sign * -0.04
					if finger == "Thumb":
						BONE_REST_OFFSETS[bone] = Vector3(side_sign * -0.02, -0.01, -0.02)
					else:
						BONE_REST_OFFSETS[bone] = Vector3(length, spread_y, spread_z)
				else:
					# Chain offsets
					var length = side_sign * -0.035
					if finger == "Thumb":
						BONE_REST_OFFSETS[bone] = Vector3(side_sign * -0.03, -0.01, -0.01)
					else:
						BONE_REST_OFFSETS[bone] = Vector3(length, 0, 0)
				
				parent = bone

static var _initialized := false
func _init():
	if not _initialized:
		_initialized = true
		_init_hierarchy_and_offsets()


var _bone_nodes: Dictionary = {}  # bone_name -> Node3D pivot
var _player: AnimationPlayer = null


func setup(vmd_data: VmdParser.VmdData) -> void:
	_clear()
	_build_stick_figure()
	_build_animation(vmd_data)
	_player.play("vmd_debug")


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_bone_nodes.clear()
	_player = null


# --- Stick figure construction ---

func _build_stick_figure() -> void:
	for bone_name in HIERARCHY:
		var pivot: Node3D = Node3D.new()
		pivot.name = bone_name
		# Apply T-pose rest offset so bones form a recognisable humanoid shape.
		pivot.position = BONE_REST_OFFSETS.get(bone_name, Vector3.ZERO)
		_bone_nodes[bone_name] = pivot

	# Parent each pivot to its parent pivot (or self for roots).
	for bone_name in HIERARCHY:
		var parent_name: String = HIERARCHY[bone_name]
		var pivot: Node3D = _bone_nodes[bone_name]
		if parent_name == "":
			add_child(pivot)
		else:
			var parent: Node3D = _bone_nodes[parent_name]
			parent.add_child(pivot)
		
		# Set rest position.
		pivot.position = BONE_REST_OFFSETS.get(bone_name, Vector3.ZERO)

	# Build visual meshes (spheres and sticks).
	for bone_name in _bone_nodes:
		var pivot: Node3D = _bone_nodes[bone_name]
		_add_bone_sphere(pivot, bone_name)

	# Setup AnimationPlayer.
	_player = AnimationPlayer.new()
	_player.name = "VmdPlayer"
	_player.root_node = _player.get_path_to(self)
	add_child(_player)


func _get_bone_color(bone_name: String) -> Color:
	if BONE_COLORS.has(bone_name):
		return BONE_COLORS[bone_name]
	if bone_name.to_lower().contains("left"):
		return Color(0.3, 0.6, 1.0)
	if bone_name.to_lower().contains("right"):
		return Color(0.3, 1.0, 0.4)
	return Color(1.0, 1.0, 1.0)


func _add_bone_sphere(parent: Node3D, bone_name: String) -> void:
	var color: Color = _get_bone_color(bone_name)

	# Sphere at joint origin.
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "BoneMesh"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.02
	sphere.height = 0.04
	mi.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	parent.add_child(mi)

	# Determine direction toward child bone so the stick points the right way.
	# Find first child of this bone in HIERARCHY.
	var child_offset: Vector3 = Vector3.ZERO
	for candidate in HIERARCHY:
		if HIERARCHY[candidate] == bone_name and BONE_REST_OFFSETS.has(candidate):
			child_offset = BONE_REST_OFFSETS[candidate]
			break

	var length: float = child_offset.length()
	if length < 0.001:
		# No child or zero-length: fall back to a default length.
		length = BONE_LENGTHS.get(bone_name, 0.05)
		child_offset = Vector3(0, length, 0)

	# Capsule is along its local +Y by default. Rotate to align with child_offset.
	var stick: MeshInstance3D = MeshInstance3D.new()
	stick.name = "BoneStick"
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.008
	cap.height = length
	stick.mesh = cap
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.albedo_color = color
	smat.albedo_color.a = 0.5
	smat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stick.material_override = smat
	# Centre the capsule midway along the child direction.
	stick.position = child_offset * 0.5
	# Align capsule +Y to dir.
	var dir: Vector3 = child_offset.normalized()
	if dir.length() > 0.9:
		if abs(dir.dot(Vector3.UP)) > 0.99:
			if dir.dot(Vector3.UP) < 0:
				stick.rotation.x = PI
		else:
			stick.look_at(parent.global_position + child_offset, Vector3.UP)
			stick.rotate_object_local(Vector3.RIGHT, PI/2)
	
	parent.add_child(stick)


# --- Animation construction ---

func _build_animation(vmd_data: VmdParser.VmdData) -> void:
	var anim: Animation = Animation.new()
	var time_scale: float = 1.0 / 30.0
	var max_frame: int = 0

	# Group raw bone frames by VRM bone name.
	var bone_map: Dictionary = VmdAnimationLibraryBuilder.BONE_MAP.duplicate()
	VmdAnimationLibraryBuilder._setup_finger_map(bone_map)
	
	var raw_frames: Dictionary = {}  # VRM_name -> Array[VmdBoneFrame]

	for f: VmdParser.VmdBoneFrame in vmd_data.bone_frames:
		var vrm_name: String = bone_map.get(f.name, "")
		if vrm_name == "" or not HIERARCHY.has(vrm_name):
			continue
		if not raw_frames.has(vrm_name):
			raw_frames[vrm_name] = []
		raw_frames[vrm_name].append(f)
		max_frame = max(max_frame, f.frame)

	for vrm_name in raw_frames:
		var frames = raw_frames[vrm_name]
		# 3D Rotation track — raw converted VMD rotation.
		var node_path: NodePath = _build_node_path(vrm_name)
		var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, node_path)
		
		# Position track — only for hips (center provides translation).
		var pos_track: int = -1
		if vrm_name == "hips":
			pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pos_track, node_path)

		for f: VmdParser.VmdBoneFrame in frames:
			var t: float = f.frame * time_scale
			# Rotation is already converted to Godot space in the parser (-X, -Y, Z, W).
			anim.track_insert_key(rot_track, t, f.rotation)
			if pos_track != -1:
				# VMD position is delta from rest.
				# For the debug skeleton, rest position is already set in _build_stick_figure.
				# So we just add the animated delta.
				anim.track_insert_key(pos_track, t, BONE_REST_OFFSETS["hips"] + (f.position * 0.1))

	anim.length = max_frame * time_scale

	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("vmd_debug", anim)

	_player = AnimationPlayer.new()
	_player.name = "DebugPlayer"
	add_child(_player)
	_player.add_animation_library(&"", library)


func _build_node_path(bone_name: String) -> NodePath:
	# Build slash-separated path from self → bone pivot by walking HIERARCHY.
	var parts: Array[String] = []
	var current: String = bone_name
	while current != "":
		parts.push_front(current)
		current = HIERARCHY.get(current, "")
	# parts is now [root_bone, ..., bone_name] — the path from self to the pivot.
	return NodePath("/".join(parts))
