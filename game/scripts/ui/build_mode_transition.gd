## World tint overlay for build mode entry/exit transitions.
class_name BuildModeTransition
extends CanvasLayer

const _TINT_COLOR: Color = Color(0.85, 0.88, 0.95, 1.0)
const _TINT_LAYER: int = 1

var _tint_rect: ColorRect
var _tint_tween: Tween


func _ready() -> void:
	layer = _TINT_LAYER
	_create_tint_overlay()
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)


func _on_build_mode_entered() -> void:
	PanelAnimator.kill_tween(_tint_tween)
	_tint_rect.color = Color.WHITE
	_tint_rect.visible = true
	_tint_tween = _tint_rect.create_tween()
	_tint_tween.tween_property(
		_tint_rect, "color", _TINT_COLOR,
		PanelAnimator.BUILD_MODE_TRANSITION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_build_mode_exited() -> void:
	PanelAnimator.kill_tween(_tint_tween)
	_tint_tween = _tint_rect.create_tween()
	_tint_tween.tween_property(
		_tint_rect, "color", Color.WHITE,
		PanelAnimator.BUILD_MODE_TRANSITION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tint_tween.tween_callback(_hide_tint)


func _create_tint_overlay() -> void:
	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.color = Color.WHITE
	_tint_rect.visible = false
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint_rect.material = mat
	add_child(_tint_rect)


func _hide_tint() -> void:
	_tint_rect.visible = false
