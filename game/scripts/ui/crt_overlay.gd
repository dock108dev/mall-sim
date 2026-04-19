## CRT scanline post-process overlay.
## Sits on CanvasLayer 100 and reads SCREEN_TEXTURE.
## Auto-disables when Settings.render_quality is LOW.
extends CanvasLayer

@export var intensity: float = 0.25 : set = _set_intensity

@onready var _rect: ColorRect = $CRTRect


func _ready() -> void:
	if Engine.is_editor_hint():
		visible = false
		return
	_apply_quality()
	Settings.preference_changed.connect(_on_preference_changed)


func _set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if is_node_ready() and _rect and _rect.material:
		(_rect.material as ShaderMaterial).set_shader_parameter(
			"scanline_intensity", intensity
		)


func _apply_quality() -> void:
	visible = (Settings.render_quality != Settings.RenderQuality.LOW)
	if visible and _rect and _rect.material:
		(_rect.material as ShaderMaterial).set_shader_parameter(
			"scanline_intensity", intensity
		)


func _on_preference_changed(key: StringName, _value: Variant) -> void:
	if key == &"render_quality":
		_apply_quality()
