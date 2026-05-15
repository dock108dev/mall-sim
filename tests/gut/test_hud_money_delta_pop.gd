## Tests for the HUD money-delta pop: a transient floating label that appears
## adjacent to the active cash readout on each money_changed event. Verifies
## color polarity, FP-vs-management anchor placement, session-start
## suppression, transience (no permanent hidden Label), independence of rapid
## successive pops, and modal-focus suppression.
extends GutTest

const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _hud: CanvasLayer


func before_each() -> void:
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)
	# Treat HUD as already seeded so the first money_changed under test is
	# not consumed by the session-start guard.
	_hud._cash_initialized = true
	_hud._prev_cash = 0.0


func after_each() -> void:
	# Drain InputFocus stack in case a test pushed CTX_MODAL.
	while InputFocus.depth() > 0:
		InputFocus.pop_context()


## Emits money_changed with `_prev_cash` primed so the pop's computed delta
## (`new_amount - _prev_cash`) matches the natural `(old_amount, new_amount)`
## intuition each test expresses.
func _emit_money_changed(old_amount: float, new_amount: float) -> void:
	_hud._prev_cash = old_amount
	_hud._cash_initialized = true
	EventBus.money_changed.emit(old_amount, new_amount)


func _find_pop_labels() -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in _hud.get_children():
		if (
			child is Label
			and child.is_in_group(_hud._MONEY_DELTA_GROUP)
			and not child.is_queued_for_deletion()
		):
			found.append(child as Label)
	return found


# ── Spawn polarity and color ────────────────────────────────────────────────


func test_positive_delta_spawns_green_pop() -> void:
	_emit_money_changed(100.0, 150.0)
	var pops: Array[Label] = _find_pop_labels()
	assert_eq(pops.size(), 1, "Income should spawn exactly one pop label")
	var actual: Color = pops[0].get_theme_color("font_color")
	var expected: Color = _hud._MONEY_DELTA_COLOR_POSITIVE
	assert_almost_eq(actual.r, expected.r, 0.005, "Positive pop uses green R")
	assert_almost_eq(actual.g, expected.g, 0.005, "Positive pop uses green G")
	assert_almost_eq(actual.b, expected.b, 0.005, "Positive pop uses green B")
	assert_string_contains(pops[0].text, "+", "Positive pop text has + sign")


func test_negative_delta_spawns_amber_pop() -> void:
	_emit_money_changed(100.0, 75.0)
	var pops: Array[Label] = _find_pop_labels()
	assert_eq(pops.size(), 1, "Expense should spawn exactly one pop label")
	var actual: Color = pops[0].get_theme_color("font_color")
	var expected: Color = _hud._MONEY_DELTA_COLOR_NEGATIVE
	assert_almost_eq(actual.r, expected.r, 0.005, "Negative pop uses amber R")
	assert_almost_eq(actual.g, expected.g, 0.005, "Negative pop uses amber G")
	assert_almost_eq(actual.b, expected.b, 0.005, "Negative pop uses amber B")
	assert_string_contains(pops[0].text, "-", "Negative pop text has - sign")


func test_zero_delta_does_not_spawn_pop() -> void:
	_emit_money_changed(100.0, 100.0)
	assert_eq(
		_find_pop_labels().size(), 0,
		"Zero-delta money_changed must not spawn a pop"
	)


# ── Session-start suppression ───────────────────────────────────────────────


func test_first_money_changed_after_ready_does_not_pop() -> void:
	# Override the before_each baseline so this test exercises the genuine
	# session-start path: a fresh HUD has _cash_initialized = false.
	_hud._cash_initialized = false
	_hud._prev_cash = 0.0
	EventBus.money_changed.emit(0.0, 500.0)
	assert_eq(
		_find_pop_labels().size(), 0,
		"First money_changed after _ready must not spawn a pop"
	)
	assert_true(
		_hud._cash_initialized,
		"First money_changed must flip _cash_initialized true"
	)


func test_second_money_changed_after_seed_pops() -> void:
	_hud._cash_initialized = false
	_hud._prev_cash = 0.0
	EventBus.money_changed.emit(0.0, 500.0)
	EventBus.money_changed.emit(500.0, 525.0)
	assert_eq(
		_find_pop_labels().size(), 1,
		"Second money_changed must spawn a pop"
	)


# ── Independence: rapid successive pops do not overwrite each other ────────


func test_rapid_pops_each_create_independent_label() -> void:
	_emit_money_changed(100.0, 110.0)
	# Subsequent emits advance from the previous new_amount — _prev_cash is
	# already that value because the prior _on_money_changed handler wrote it.
	EventBus.money_changed.emit(110.0, 120.0)
	EventBus.money_changed.emit(120.0, 130.0)
	assert_eq(
		_find_pop_labels().size(), 3,
		"Three rapid money_changed events must yield three concurrent pops"
	)


# ── Transience: no permanent hidden Label remains ──────────────────────────


func test_pop_label_queue_freed_after_tween_duration() -> void:
	_emit_money_changed(100.0, 150.0)
	assert_eq(_find_pop_labels().size(), 1)
	# Pop duration plus a small frame-budget margin.
	await get_tree().create_timer(
		_hud._MONEY_DELTA_DURATION + 0.1
	).timeout
	assert_eq(
		_find_pop_labels().size(), 0,
		"Pop label must queue_free itself once the tween completes"
	)


func test_no_permanent_money_delta_pop_in_packed_scene() -> void:
	# The hud.tscn packed scene must not author a permanent pop node;
	# pops are exclusively transient runtime children.
	for child: Node in _hud.get_children():
		if child is Label:
			assert_false(
				child.is_in_group(_hud._MONEY_DELTA_GROUP),
				"hud.tscn must not author a permanent money-delta pop label"
			)


# ── Modal-focus suppression ────────────────────────────────────────────────


func test_modal_focus_suppresses_pop() -> void:
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_emit_money_changed(100.0, 200.0)
	assert_eq(
		_find_pop_labels().size(), 0,
		"Pop must not spawn while CTX_MODAL owns InputFocus"
	)


# ── FP vs management anchor placement ──────────────────────────────────────


func test_management_mode_pop_uses_top_left_anchor() -> void:
	_hud.set_fp_mode(false)
	_emit_money_changed(100.0, 110.0)
	var pops: Array[Label] = _find_pop_labels()
	assert_eq(pops.size(), 1)
	var pop: Label = pops[0]
	# Non-FP layout uses default anchors (top-left) — anchor_left == 0.
	assert_eq(
		pop.anchor_left, 0.0,
		"Management-mode pop anchors to the left edge"
	)
	assert_gt(
		pop.offset_left, 0.0,
		"Management-mode pop offsets in from the left edge"
	)


func test_fp_mode_pop_uses_top_right_anchor() -> void:
	_hud.set_fp_mode(true)
	_emit_money_changed(100.0, 110.0)
	var pops: Array[Label] = _find_pop_labels()
	assert_eq(pops.size(), 1)
	var pop: Label = pops[0]
	assert_eq(
		pop.anchor_left, 1.0,
		"FP-mode pop anchors to the right edge (anchor_left = 1.0)"
	)
	assert_eq(
		pop.anchor_right, 1.0,
		"FP-mode pop anchors to the right edge (anchor_right = 1.0)"
	)
	assert_lt(
		pop.offset_right, 0.0,
		"FP-mode pop offsets in from the right edge with negative offset_right"
	)


# ── Tween-based animation (no AnimationPlayer) ──────────────────────────────


func test_pop_animation_uses_tween_not_animation_player() -> void:
	_emit_money_changed(100.0, 110.0)
	var pops: Array[Label] = _find_pop_labels()
	assert_eq(pops.size(), 1)
	var pop: Label = pops[0]
	for child: Node in pop.get_children():
		assert_false(
			child is AnimationPlayer,
			"Pop label must not host an AnimationPlayer node"
		)


# ── Tween animates the y-position upward ───────────────────────────────────


func test_pop_floats_upward_over_duration() -> void:
	_emit_money_changed(100.0, 110.0)
	var pops: Array[Label] = _find_pop_labels()
	assert_eq(pops.size(), 1)
	var pop: Label = pops[0]
	var start_top: float = pop.offset_top
	# Mid-duration: the tween should have progressed but not finished.
	await get_tree().create_timer(_hud._MONEY_DELTA_DURATION * 0.5).timeout
	if not is_instance_valid(pop):
		fail_test("Pop was freed before mid-duration; tween too short")
		return
	assert_lt(
		pop.offset_top, start_top,
		"Pop offset_top must decrease (label floats upward) during the tween"
	)
