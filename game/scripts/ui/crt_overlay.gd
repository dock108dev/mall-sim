## CRT scanline post-process overlay.
## Sits on CanvasLayer 100 and reads SCREEN_TEXTURE.
## Only visible when the Retro Games drawer is open and render quality is not LOW.
extends CanvasLayer

@export var intensity: float = 0.25 : set = _set_intensity

@onready var _rect: ColorRect = $CRTRect

var _retro_drawer_active: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		visible = false
		return
	visible = false
	Settings.preference_changed.connect(_on_preference_changed)
	EventBus.drawer_opened.connect(_on_drawer_opened)
	EventBus.drawer_closed.connect(_on_drawer_closed)


func _set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if is_node_ready() and _rect and _rect.material:
		(_rect.material as ShaderMaterial).set_shader_parameter(
			"scanline_intensity", intensity
		)


func _apply_quality() -> void:
	visible = _retro_drawer_active \
		and Settings.render_quality != Settings.RenderQuality.LOW
	if visible and _rect and _rect.material:
		(_rect.material as ShaderMaterial).set_shader_parameter(
			"scanline_intensity", intensity
		)


func _on_drawer_opened(store_id: StringName) -> void:
	_retro_drawer_active = (store_id == &"retro_games")
	_apply_quality()


func _on_drawer_closed(_store_id: StringName) -> void:
	_retro_drawer_active = false
	visible = false


func _on_preference_changed(key: StringName, _value: Variant) -> void:
	if key == &"render_quality":
		_apply_quality()
