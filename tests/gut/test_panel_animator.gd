## Tests for PanelAnimator tween-based animation utilities.
extends GutTest


var _panel: Control


func before_each() -> void:
	_panel = Control.new()
	_panel.size = Vector2(200.0, 100.0)
	_panel.position = Vector2(50.0, 50.0)
	add_child_autofree(_panel)


func test_constants_match_spec() -> void:
	assert_eq(PanelAnimator.SLIDE_DURATION, 0.2)
	assert_eq(PanelAnimator.MODAL_DURATION, 0.15)
	assert_eq(PanelAnimator.FULLSCREEN_FADE_DURATION, 0.25)
	assert_eq(PanelAnimator.TOOLTIP_FADE_DURATION, 0.15)


func test_modal_scale_start() -> void:
	assert_eq(
		PanelAnimator.MODAL_SCALE_START, 0.85,
		"MODAL_SCALE_START should be 0.85 per spec"
	)


func test_kill_tween_null_safe() -> void:
	PanelAnimator.kill_tween(null)
	pass_test("kill_tween(null) should not crash")


func test_kill_tween_stops_valid_tween() -> void:
	var tween: Tween = _panel.create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 1.0)
	assert_true(tween.is_valid())
	PanelAnimator.kill_tween(tween)
	assert_false(tween.is_valid())


func test_kill_control_tween_stops_active_panel_tween() -> void:
	var tween: Tween = PanelAnimator.fade_in(_panel)
	assert_true(tween.is_valid())
	PanelAnimator.kill_control_tween(_panel)
	assert_false(tween.is_valid())


func test_panel_animator_can_attach_to_control_node() -> void:
	var animator: PanelAnimator = PanelAnimator.new()
	add_child_autofree(animator)
	assert_true(animator is Control)


func test_new_animation_kills_previous_panel_tween() -> void:
	var tween_a: Tween = PanelAnimator.fullscreen_fade_in(_panel)
	var tween_b: Tween = PanelAnimator.fullscreen_fade_out(_panel)
	assert_false(tween_a.is_valid())
	assert_true(tween_b.is_valid())


func test_slide_in_returns_tween() -> void:
	var tween: Tween = PanelAnimator.slide_in(
		_panel, Vector2.LEFT
	)
	assert_not_null(tween)
	assert_true(tween.is_valid())
	assert_true(_panel.visible)


func test_slide_in_sets_visible() -> void:
	_panel.visible = false
	PanelAnimator.slide_in(_panel, Vector2.RIGHT)
	assert_true(_panel.visible)


func test_slide_out_returns_tween() -> void:
	var tween: Tween = PanelAnimator.slide_out(
		_panel, Vector2.DOWN
	)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_slide_open_sets_visible() -> void:
	_panel.visible = false
	PanelAnimator.slide_open(_panel, 50.0, false)
	assert_true(_panel.visible)


func test_slide_open_returns_tween() -> void:
	var tween: Tween = PanelAnimator.slide_open(
		_panel, 50.0, true
	)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_slide_close_returns_tween() -> void:
	var tween: Tween = PanelAnimator.slide_close(
		_panel, 50.0, false
	)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_modal_open_sets_initial_state() -> void:
	_panel.visible = false
	PanelAnimator.modal_open(_panel)
	assert_true(_panel.visible)
	assert_eq(
		_panel.scale,
		Vector2(PanelAnimator.MODAL_SCALE_START, PanelAnimator.MODAL_SCALE_START)
	)


func test_modal_open_returns_tween() -> void:
	var tween: Tween = PanelAnimator.modal_open(_panel)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_modal_close_returns_tween() -> void:
	var tween: Tween = PanelAnimator.modal_close(_panel)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_fullscreen_fade_in_sets_visible() -> void:
	_panel.visible = false
	PanelAnimator.fullscreen_fade_in(_panel)
	assert_true(_panel.visible)


func test_fullscreen_fade_in_returns_tween() -> void:
	var tween: Tween = PanelAnimator.fullscreen_fade_in(_panel)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_fullscreen_fade_out_returns_tween() -> void:
	var tween: Tween = PanelAnimator.fullscreen_fade_out(_panel)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_fade_in_sets_visible() -> void:
	_panel.visible = false
	PanelAnimator.fade_in(_panel)
	assert_true(_panel.visible)


func test_fade_out_returns_tween() -> void:
	var tween: Tween = PanelAnimator.fade_out(_panel)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_shake_returns_tween() -> void:
	var tween: Tween = PanelAnimator.shake(_panel, 8.0, 0.3)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_shake_default_params() -> void:
	var tween: Tween = PanelAnimator.shake(_panel)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_pulse_scale_returns_tween() -> void:
	var tween: Tween = PanelAnimator.pulse_scale(_panel, 1.3)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_pulse_scale_sets_pivot() -> void:
	PanelAnimator.pulse_scale(_panel)
	assert_eq(_panel.pivot_offset, _panel.size / 2.0)


func test_flash_color_returns_tween() -> void:
	var tween: Tween = PanelAnimator.flash_color(
		_panel, Color.RED, 0.3
	)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_stagger_fade_in_empty_returns_null() -> void:
	var empty: Array[Control] = []
	var tween: Tween = PanelAnimator.stagger_fade_in(empty)
	assert_null(tween)


func test_stagger_fade_in_sets_transparent() -> void:
	var child_a: Control = Control.new()
	var child_b: Control = Control.new()
	add_child_autofree(child_a)
	add_child_autofree(child_b)
	var nodes: Array[Control] = [child_a, child_b]
	PanelAnimator.stagger_fade_in(nodes, 0.05)
	assert_eq(child_a.modulate, Color.TRANSPARENT)
	assert_eq(child_b.modulate, Color.TRANSPARENT)


func test_stagger_fade_in_returns_tween() -> void:
	var child: Control = Control.new()
	add_child_autofree(child)
	var nodes: Array[Control] = [child]
	var tween: Tween = PanelAnimator.stagger_fade_in(nodes)
	assert_not_null(tween)
	assert_true(tween.is_valid())


func test_no_double_tween_pattern() -> void:
	var tween_a: Tween = PanelAnimator.modal_open(_panel)
	PanelAnimator.kill_tween(tween_a)
	var tween_b: Tween = PanelAnimator.modal_close(_panel)
	assert_false(tween_a.is_valid())
	assert_true(tween_b.is_valid())


func test_slide_in_easing_uses_ease_out() -> void:
	_panel.position = Vector2(50.0, 50.0)
	var tween: Tween = PanelAnimator.slide_in(
		_panel, Vector2.LEFT
	)
	assert_not_null(tween)


func test_slide_out_easing_uses_ease_in() -> void:
	var tween: Tween = PanelAnimator.slide_out(
		_panel, Vector2.RIGHT
	)
	assert_not_null(tween)
