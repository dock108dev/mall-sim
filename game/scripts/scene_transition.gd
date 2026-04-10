## Handles fade-to-black scene transitions with input blocking.
class_name SceneTransition
extends CanvasLayer

const FADE_DURATION: float = 0.3
const TRANSITION_LAYER: int = 128

var _is_transitioning: bool = false
var _overlay: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = TRANSITION_LAYER
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


func _unhandled_input(_event: InputEvent) -> void:
	if _is_transitioning:
		get_viewport().set_input_as_handled()


## Fades to black, swaps the scene, then fades back in.
func transition_to_scene(scene_path: String) -> void:
	if _is_transitioning:
		push_warning("SceneTransition: transition already in progress")
		return

	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade_out()
	get_tree().change_scene_to_file(scene_path)
	# Wait one frame for the new scene tree to settle
	await get_tree().process_frame
	await _fade_in()

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


## Fades to black, swaps to a packed scene, then fades back in.
func transition_to_packed(scene: PackedScene) -> void:
	if _is_transitioning:
		push_warning("SceneTransition: transition already in progress")
		return

	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade_out()
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await _fade_in()

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


## Returns true if a transition is currently in progress.
func is_transitioning() -> bool:
	return _is_transitioning


func _fade_out() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await _tween.finished


func _fade_in() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await _tween.finished


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
