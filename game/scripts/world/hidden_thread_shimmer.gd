## Drives the saturation-shimmer shader for a hidden-thread interactable.
##
## Attach to a Node3D that owns (or is) a MeshInstance3D. The script tags the
## node with metadata "suspicious_flag = true" and adds it to the
## "hidden_thread" group, then per-frame computes whether the player camera is
## within 2 m AND within 30 deg of the object's center axis. When both
## conditions hold, the shader's `activation` uniform is lerped toward 1.0;
## otherwise it relaxes to 0.0. The shader does the saturation modulation —
## this script only gates visibility.
##
## Per ISSUE-015 spec: no UI badge, no tooltip, no particle, no outline, no
## icon. The shimmer is the only diegetic cue.
class_name HiddenThreadShimmer
extends Node3D


const SHIMMER_SHADER: Shader = preload(
	"res://game/assets/shaders/hidden_thread_shimmer.gdshader"
)
const PROXIMITY_RADIUS: float = 2.0
const LOOK_ANGLE_DEGREES: float = 30.0
const ACTIVATION_LERP_RATE: float = 6.0
const SHIMMER_GROUP: StringName = &"hidden_thread"

@export var hidden_thread_id: StringName = &""
@export var mesh_path: NodePath
@export var surface_color: Color = Color.WHITE

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _activation: float = 0.0
var _cos_half_angle: float = cos(deg_to_rad(LOOK_ANGLE_DEGREES))


func _ready() -> void:
	add_to_group(SHIMMER_GROUP)
	set_meta(&"suspicious_flag", true)
	if hidden_thread_id != &"":
		set_meta(&"hidden_thread_id", hidden_thread_id)
	_resolve_mesh()
	_install_material()


func _process(delta: float) -> void:
	var target: float = 1.0 if _player_in_focus() else 0.0
	_activation = lerpf(_activation, target, clampf(delta * ACTIVATION_LERP_RATE, 0.0, 1.0))
	if _material != null:
		_material.set_shader_parameter("activation", _activation)


func _resolve_mesh() -> void:
	# §F-140 — pure-visual fallback chain. The shimmer is a diegetic-only cue
	# (no UI badge / outline / icon per ISSUE-015); a host scene that wires
	# the script onto a node without a paired MeshInstance3D simply won't
	# render the shimmer. Pushing here would log on every static prop placed
	# in a store that has the script attached but isn't yet a hidden-thread
	# anchor — far more noise than signal.
	if not mesh_path.is_empty():
		_mesh = get_node_or_null(mesh_path) as MeshInstance3D
	if _mesh == null and self is MeshInstance3D:
		_mesh = self as MeshInstance3D
	if _mesh != null:
		return
	for child: Node in get_children():
		if child is MeshInstance3D:
			_mesh = child as MeshInstance3D
			return


func _install_material() -> void:
	# §F-140 — see _resolve_mesh. Material attach silently no-ops when no
	# mesh resolves; _process guards against null _material so the
	# per-frame activation lerp still runs without crashing.
	if _mesh == null:
		return
	_material = ShaderMaterial.new()
	_material.shader = SHIMMER_SHADER
	_material.set_shader_parameter("surface_color", surface_color)
	_material.set_shader_parameter("activation", 0.0)
	_mesh.material_override = _material


func _player_in_focus() -> bool:
	var camera: Camera3D = _resolve_camera()
	if camera == null:
		return false
	var origin: Vector3 = global_position
	var to_object: Vector3 = origin - camera.global_position
	var distance: float = to_object.length()
	if distance > PROXIMITY_RADIUS or distance <= 0.0:
		return false
	var look_dir: Vector3 = -camera.global_transform.basis.z
	var dot: float = look_dir.dot(to_object.normalized())
	return dot >= _cos_half_angle


func _resolve_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()
