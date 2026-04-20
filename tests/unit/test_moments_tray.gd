## GUT unit tests for MomentsTray: one-at-a-time queuing, priority queue,
## suspend/resume, clear, and stat tracking.
extends GutTest


func _make_tray() -> MomentsTray:
	var scene: PackedScene = load("res://game/scenes/ui/moments_tray.tscn")
	assert_not_null(scene, "moments_tray.tscn must be loadable")
	var tray: MomentsTray = scene.instantiate() as MomentsTray
	add_child_autofree(tray)
	return tray


# ── initial state ─────────────────────────────────────────────────────────────


func test_tray_starts_with_empty_queues() -> void:
	var tray: MomentsTray = _make_tray()
	assert_eq(tray.get_queue_depth(), 0)


func test_tray_starts_with_no_active_card() -> void:
	var tray: MomentsTray = _make_tray()
	assert_false(tray.has_active_card())


func test_tray_starts_unsuspended() -> void:
	var tray: MomentsTray = _make_tray()
	assert_false(tray.is_suspended())


func test_cards_shown_today_starts_at_zero() -> void:
	var tray: MomentsTray = _make_tray()
	assert_eq(tray.get_cards_shown_today(), 0)


func test_total_cards_shown_starts_at_zero() -> void:
	var tray: MomentsTray = _make_tray()
	assert_eq(tray.get_total_cards_shown(), 0)


# ── queue depth helpers ───────────────────────────────────────────────────────


func test_get_priority_queue_depth_starts_at_zero() -> void:
	var tray: MomentsTray = _make_tray()
	assert_eq(tray.get_priority_queue_depth(), 0)


func test_get_normal_queue_depth_starts_at_zero() -> void:
	var tray: MomentsTray = _make_tray()
	assert_eq(tray.get_normal_queue_depth(), 0)


# ── suspend / resume ──────────────────────────────────────────────────────────


func test_suspend_sets_flag() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	assert_true(tray.is_suspended())


func test_resume_clears_flag() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	tray.resume()
	assert_false(tray.is_suspended())


# ── clear_queue ───────────────────────────────────────────────────────────────


func test_clear_queue_empties_normal_queue() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	# Fill via internal method to avoid spawning cards
	for i: int in range(3):
		tray._normal_queue.append({
			"moment_id": "m%d" % i, "flavor_text": "t",
			"duration_seconds": 5.0, "character_name": "", "display_type": "toast",
		})
	tray.clear_queue()
	assert_eq(tray.get_normal_queue_depth(), 0)


func test_clear_queue_empties_priority_queue() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	tray._priority_queue.append({
		"moment_id": "p1", "flavor_text": "t",
		"duration_seconds": 5.0, "character_name": "", "display_type": "toast",
	})
	tray.clear_queue()
	assert_eq(tray.get_priority_queue_depth(), 0)


# ── peek_next_id ──────────────────────────────────────────────────────────────


func test_peek_next_id_returns_empty_when_queue_empty() -> void:
	var tray: MomentsTray = _make_tray()
	assert_eq(tray.peek_next_id(), &"")


func test_peek_next_id_returns_priority_before_normal() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	tray._normal_queue.append({
		"moment_id": "normal_1", "flavor_text": "t",
		"duration_seconds": 5.0, "character_name": "", "display_type": "toast",
	})
	tray._priority_queue.append({
		"moment_id": "priority_1", "flavor_text": "t",
		"duration_seconds": 5.0, "character_name": "", "display_type": "toast",
	})
	assert_eq(tray.peek_next_id(), &"priority_1",
		"Priority queue should be peeked before normal queue")


func test_peek_next_id_returns_normal_when_no_priority() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	tray._normal_queue.append({
		"moment_id": "norm_only", "flavor_text": "t",
		"duration_seconds": 5.0, "character_name": "", "display_type": "toast",
	})
	assert_eq(tray.peek_next_id(), &"norm_only")


# ── max queue depth ────────────────────────────────────────────────────────────


func test_normal_queue_caps_at_max_depth() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	for i: int in range(MomentsTray.MAX_QUEUE_DEPTH + 5):
		tray._on_moment_displayed(StringName("m%d" % i), "text", 5.0)
	assert_lte(tray.get_normal_queue_depth(), MomentsTray.MAX_QUEUE_DEPTH,
		"Normal queue must not exceed MAX_QUEUE_DEPTH")


func test_priority_queue_caps_at_max_depth() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	for i: int in range(MomentsTray.MAX_QUEUE_DEPTH + 5):
		tray.enqueue_priority(StringName("p%d" % i), "text", 5.0)
	assert_lte(tray.get_priority_queue_depth(), MomentsTray.MAX_QUEUE_DEPTH,
		"Priority queue must not exceed MAX_QUEUE_DEPTH")


# ── day_started resets today counter ─────────────────────────────────────────


func test_day_started_resets_cards_shown_today() -> void:
	var tray: MomentsTray = _make_tray()
	tray._cards_shown_today = 5
	tray._on_day_started(2)
	assert_eq(tray.get_cards_shown_today(), 0)


func test_day_started_resumes_tray() -> void:
	var tray: MomentsTray = _make_tray()
	tray.suspend()
	tray._on_day_started(2)
	assert_false(tray.is_suspended(), "day_started should resume the tray")


# ── day_ended suspends tray ────────────────────────────────────────────────────


func test_day_ended_suspends_tray() -> void:
	var tray: MomentsTray = _make_tray()
	tray._on_day_ended(1)
	assert_true(tray.is_suspended(), "day_ended should suspend the tray")
