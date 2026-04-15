## Tween-based animation utilities for UI panel transitions.
class_name PanelAnimator


const SLIDE_DURATION: float = 0.2
const MODAL_DURATION: float = 0.15
const FULLSCREEN_FADE_DURATION: float = 0.25
const TOOLTIP_FADE_DURATION: float = 0.15
const TOOLTIP_HOVER_DELAY: float = 0.3
const MODAL_SCALE_START: float = 0.85
const FEEDBACK_FLOAT_DURATION: float = 0.8
const FEEDBACK_PULSE_DURATION: float = 0.3
const FEEDBACK_SHAKE_DURATION: float = 0.2
const BANNER_SLIDE_DURATION: float = 0.3
const BANNER_HOLD_DURATION: float = 3.0
const BUILD_MODE_TRANSITION: float = 0.25


static func kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()


static func slide_in(
	panel: Control,
	direction: Vector2,
	duration: float = SLIDE_DURATION,
) -> Tween:
	var viewport_size: Vector2 = panel.get_viewport_rect().size
	var target_pos: Vector2 = panel.position
	if direction == Vector2.LEFT:
		panel.position.x = -panel.size.x
	elif direction == Vector2.RIGHT:
		panel.position.x = viewport_size.x
	elif direction == Vector2.UP:
		panel.position.y = -panel.size.y
	elif direction == Vector2.DOWN:
		panel.position.y = viewport_size.y
	panel.visible = true
	panel.modulate = Color.WHITE
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "position", target_pos, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


static func slide_out(
	panel: Control,
	direction: Vector2,
	duration: float = SLIDE_DURATION,
) -> Tween:
	var viewport_size: Vector2 = panel.get_viewport_rect().size
	var target_pos: Vector2 = panel.position
	if direction == Vector2.LEFT:
		target_pos.x = -panel.size.x
	elif direction == Vector2.RIGHT:
		target_pos.x = viewport_size.x
	elif direction == Vector2.UP:
		target_pos.y = -panel.size.y
	elif direction == Vector2.DOWN:
		target_pos.y = viewport_size.y
	var rest_pos: Vector2 = panel.position
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "position", target_pos, duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(
		func() -> void:
			panel.visible = false
			panel.position = rest_pos
	)
	return tween


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


static func fullscreen_fade_in(
	panel: Control,
	duration: float = FULLSCREEN_FADE_DURATION,
) -> Tween:
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	panel.visible = true
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "modulate", Color.WHITE, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


static func fullscreen_fade_out(
	panel: Control,
	duration: float = FULLSCREEN_FADE_DURATION,
) -> Tween:
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "modulate",
		Color(1.0, 1.0, 1.0, 0.0), duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(
		func() -> void:
			panel.visible = false
			panel.modulate = Color.WHITE
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


static func fade_out(
	panel: Control,
	duration: float = TOOLTIP_FADE_DURATION,
) -> Tween:
	var tween: Tween = panel.create_tween()
	tween.tween_property(
		panel, "modulate",
		Color(1.0, 1.0, 1.0, 0.0), duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(
		func() -> void:
			panel.visible = false
			panel.modulate = Color.WHITE
	)
	return tween


static func shake(
	node: Control,
	magnitude: float = 6.0,
	duration: float = FEEDBACK_SHAKE_DURATION,
) -> Tween:
	var original_x: float = node.position.x
	var tween: Tween = node.create_tween()
	var step: float = duration / 7.0
	for i: int in range(3):
		tween.tween_property(
			node, "position:x", original_x + magnitude, step
		)
		tween.tween_property(
			node, "position:x", original_x - magnitude, step
		)
	tween.tween_property(node, "position:x", original_x, step)
	return tween


static func pulse_scale(
	node: Control,
	peak: float = 1.15,
	duration: float = FEEDBACK_PULSE_DURATION,
) -> Tween:
	node.pivot_offset = node.size / 2.0
	var tween: Tween = node.create_tween()
	tween.tween_property(
		node, "scale",
		Vector2(peak, peak),
		duration * 0.4,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(
		node, "scale", Vector2.ONE, duration * 0.6
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween


static func flash_color(
	node: Control,
	color: Color,
	duration: float = FEEDBACK_PULSE_DURATION,
) -> Tween:
	var tween: Tween = node.create_tween()
	tween.tween_property(
		node, "modulate", color, duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(
		node, "modulate", Color.WHITE, duration * 0.7
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	return tween


static func stagger_fade_in(
	nodes: Array[Control],
	delay_step: float = 0.05,
	fade_duration: float = 0.15,
) -> Tween:
	if nodes.is_empty():
		return null
	for node: Control in nodes:
		node.modulate = Color.TRANSPARENT
	var tween: Tween = nodes[0].create_tween()
	for i: int in range(nodes.size()):
		var node: Control = nodes[i]
		if i > 0:
			tween.tween_interval(delay_step)
		tween.tween_property(
			node, "modulate", Color.WHITE, fade_duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tween
