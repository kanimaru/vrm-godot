@tool
extends Node
class_name MtoonController

## Synchronizes Godot's WorldEnvironment ambient light color with the _GIAmbientColor
## uniform on an array of Mtoon ShaderMaterials. This ensures that the toon shading
## respects the local ambient room light in the scene.

@export var mtoon_materials: Array[Material] = []
@export var update_interval: float = 0.1

var _timer: float = 0.0
var _current_ambient: Color = Color.WHITE

func _process(delta: float) -> void:
	if mtoon_materials.is_empty():
		return
		
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0

	var env: Environment = _get_environment()
	if env == null:
		return

	# Calculate ambient color approx from environment
	var ambient: Color = Color.BLACK
	if env.background_mode == Environment.BG_COLOR:
		ambient = env.background_color * env.background_energy
	elif env.background_mode == Environment.BG_CLEAR_COLOR:
		ambient = RenderingServer.get_default_clear_color() * env.background_energy
	else:
		ambient = env.ambient_light_color * env.ambient_light_energy

	# MToon spec assumes uniformedGi is an average of up and down.
	# The up vector tends to be fully lit, while down is dimmed.
	var ambient_average: Color = ambient * 0.75 

	if _current_ambient != ambient_average:
		_current_ambient = ambient_average
		var ambient_vec = Vector3(ambient_average.r, ambient_average.g, ambient_average.b)
		for mat: Material in mtoon_materials:
			if mat is ShaderMaterial:
				mat.set_shader_parameter("_GIAmbientColor", ambient_vec)


func _get_environment() -> Environment:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	var world: World3D = vp.find_world_3d()
	if world == null:
		return null
	if world.environment != null:
		return world.environment
	return world.fallback_environment
