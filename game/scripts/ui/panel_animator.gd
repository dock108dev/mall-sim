## Tween-based animation utilities for UI panel transitions.
class_name PanelAnimator


const SLIDE_DURATION: float = 0.2
const MODAL_DURATION: float = 0.15
const TOOLTIP_FADE_DURATION: float = 0.15
const TOOLTIP_HOVER_DELAY: float = 0.3
const MODAL_SCALE_START: float = 0.95


static func kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


static func slide_open(
	panel: Control,
	rest_x: float,
	from_left: bool,
	duration: float = SLIDE_DURATION,
) -> Tween:
	var offset: float = panel.size.x
	if from_left:
		panel.position.x = rest_x - offset
	else:
		panel.position.x = rest_x + offset
	panel.modulate = Color.WHITE
	panel.visible = true
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "position:x", rest_x, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


static func slide_close(
	panel: Control,
	rest_x: float,
	from_left: bool,
	duration: float = SLIDE_DURATION,
) -> Tween:
	var offset: float = panel.size.x
	var target_x: float = panel.position.x
	if from_left:
		target_x -= offset
	else:
		target_x += offset
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "position:x", target_x, duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(
		func() -> void:
			panel.visible = false
			panel.position.x = rest_x
	)
	return tween


static func modal_open(
	panel: Control,
	duration: float = MODAL_DURATION,
) -> Tween:
	panel.pivot_offset = panel.size / 2.0
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.scale = Vector2(
		MODAL_SCALE_START, MODAL_SCALE_START
	)
	panel.visible = true
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "modulate", Color.WHITE, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(
		panel, "scale", Vector2.ONE, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


static func modal_close(
	panel: Control,
	duration: float = MODAL_DURATION,
) -> Tween:
	panel.pivot_offset = panel.size / 2.0
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "modulate",
		Color(1.0, 1.0, 1.0, 0.0), duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(
		panel, "scale",
		Vector2(MODAL_SCALE_START, MODAL_SCALE_START),
		duration,
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(
		func() -> void:
			panel.visible = false
			panel.modulate = Color.WHITE
			panel.scale = Vector2.ONE
	)
	return tween


static func fade_in(
	panel: Control,
	duration: float = TOOLTIP_FADE_DURATION,
) -> Tween:
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.visible = true
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "modulate", Color.WHITE, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween
