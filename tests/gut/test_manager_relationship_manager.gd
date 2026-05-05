# gdlint:disable=max-public-methods
## Tests for the ManagerRelationshipManager autoload — covers trust clamping
## and tier mapping, event-driven trust deltas, override-day note selection
## (Day 1, 10, 20, unlock-after), tier × category note selection on regular
## days, and signal emissions for manager_note_shown / manager_trust_changed /
## manager_confrontation_triggered.
extends GutTest


const _SAMPLE_NOTES: Dictionary = {
	"tier_notes": {
		"cold": {
			"operational": [{"id": "cold_op", "body": "cold op body"}],
			"sales": [{"id": "cold_sales", "body": "cold sales body"}],
			"staff": [{"id": "cold_staff", "body": "cold staff body"}],
		},
		"neutral": {
			"operational": [{"id": "neutral_op", "body": "neutral op body"}],
			"sales": [{"id": "neutral_sales", "body": "neutral sales body"}],
			"staff": [{"id": "neutral_staff", "body": "neutral staff body"}],
		},
		"warm": {
			"operational": [{"id": "warm_op", "body": "warm op body"}],
			"sales": [{"id": "warm_sales", "body": "warm sales body"}],
			"staff": [{"id": "warm_staff", "body": "warm staff body"}],
		},
		"trusted": {
			"operational": [{"id": "trusted_op", "body": "trusted op body"}],
			"sales": [{"id": "trusted_sales", "body": "trusted sales body"}],
			"staff": [{"id": "trusted_staff", "body": "trusted staff body"}],
		},
	},
	"date_overrides": {
		"day_1": {"id": "note_override_day_1", "body": "day 1 orientation"},
		"day_10": {"id": "note_override_day_10", "body": "day 10 milestone"},
		"day_20": {"id": "note_override_day_20", "body": "day 20 stretch"},
	},
	"unlock_overrides": {
		"trade_in_intake": {
			"id": "note_override_unlock_trade_in",
			"body": "trade-in unlocked",
		},
	},
	"fallback": {"id": "note_fallback_default", "body": "fallback body"},
}


func before_each() -> void:
	ManagerRelationshipManager.reset_for_testing()
	ManagerRelationshipManager._set_notes_for_testing(_SAMPLE_NOTES)


# ── Initialization & tier mapping ────────────────────────────────────────────

func test_initial_trust_matches_default() -> void:
	assert_almost_eq(
		ManagerRelationshipManager.manager_trust,
		ManagerRelationshipManager.DEFAULT_TRUST, 0.0001,
		"manager_trust must default to 0.5"
	)
	assert_eq(
		ManagerRelationshipManager.get_tier(),
		ManagerRelationshipManager.TIER_WARM,
		"trust=0.5 sits in warm tier per the [0.50,0.75) range"
	)


func test_tier_cold_at_low_trust() -> void:
	ManagerRelationshipManager.apply_trust_delta(-0.4, "test")
	assert_eq(
		ManagerRelationshipManager.get_tier(),
		ManagerRelationshipManager.TIER_COLD,
	)


func test_tier_warm_at_mid_high_trust() -> void:
	ManagerRelationshipManager.apply_trust_delta(0.1, "test")
	assert_eq(
		ManagerRelationshipManager.get_tier(),
		ManagerRelationshipManager.TIER_WARM,
	)


func test_tier_trusted_at_high_trust() -> void:
	ManagerRelationshipManager.apply_trust_delta(0.4, "test")
	assert_eq(
		ManagerRelationshipManager.get_tier(),
		ManagerRelationshipManager.TIER_TRUSTED,
	)


# ── Trust deltas & clamping ──────────────────────────────────────────────────

func test_apply_trust_delta_clamps_at_max() -> void:
	ManagerRelationshipManager.apply_trust_delta(0.9, "saturate_high")
	assert_almost_eq(
		ManagerRelationshipManager.manager_trust, 1.0, 0.0001,
		"trust must clamp to 1.0"
	)


func test_apply_trust_delta_clamps_at_min() -> void:
	ManagerRelationshipManager.apply_trust_delta(-0.9, "saturate_low")
	assert_almost_eq(
		ManagerRelationshipManager.manager_trust, 0.0, 0.0001,
		"trust must clamp to 0.0"
	)


func test_apply_trust_delta_emits_signal_with_actual_delta() -> void:
	watch_signals(EventBus)
	ManagerRelationshipManager.apply_trust_delta(0.1, "test_reason")
	assert_signal_emitted(EventBus, "manager_trust_changed")
	var params: Array = get_signal_parameters(EventBus, "manager_trust_changed")
	assert_almost_eq(float(params[0]), 0.1, 0.0001)
	assert_eq(params[1], "test_reason")


func test_apply_trust_delta_no_signal_at_saturation() -> void:
	ManagerRelationshipManager.manager_trust = 1.0
	watch_signals(EventBus)
	ManagerRelationshipManager.apply_trust_delta(0.1, "saturated")
	assert_signal_not_emitted(EventBus, "manager_trust_changed")


# ── Trust deltas via EventBus ────────────────────────────────────────────────

func test_task_completed_applies_documented_delta() -> void:
	var before: float = ManagerRelationshipManager.manager_trust
	EventBus.task_completed.emit(&"restock")
	var actual: float = ManagerRelationshipManager.manager_trust - before
	assert_almost_eq(
		actual, ManagerRelationshipManager.DELTA_TASK_COMPLETED, 0.0001,
		"task_completed must apply +0.06 trust"
	)


func test_staff_quit_applies_documented_delta() -> void:
	var before: float = ManagerRelationshipManager.manager_trust
	EventBus.staff_quit.emit("staff_a")
	var actual: float = ManagerRelationshipManager.manager_trust - before
	assert_almost_eq(
		actual, ManagerRelationshipManager.DELTA_STAFF_QUIT, 0.0001,
		"staff_quit must apply -0.05 trust"
	)


func test_missing_payroll_applies_documented_delta() -> void:
	var before: float = ManagerRelationshipManager.manager_trust
	EventBus.staff_not_paid.emit("staff_a")
	var actual: float = ManagerRelationshipManager.manager_trust - before
	assert_almost_eq(
		actual, ManagerRelationshipManager.DELTA_MISSING_PAYROLL, 0.0001,
		"staff_not_paid must apply -0.10 trust"
	)


# ── Confrontation trigger ────────────────────────────────────────────────────

func test_confrontation_emitted_when_trust_falls_into_floor() -> void:
	ManagerRelationshipManager.manager_trust = 0.20
	watch_signals(EventBus)
	ManagerRelationshipManager.apply_trust_delta(-0.1, "boundary_test")
	assert_signal_emitted(EventBus, "manager_confrontation_triggered")


func test_confrontation_not_emitted_for_positive_delta() -> void:
	ManagerRelationshipManager.manager_trust = 0.10
	watch_signals(EventBus)
	ManagerRelationshipManager.apply_trust_delta(0.05, "positive_test")
	assert_signal_not_emitted(EventBus, "manager_confrontation_triggered")


# ── Note selection — overrides ───────────────────────────────────────────────

func test_day_1_uses_override_and_blocks_auto_dismiss() -> void:
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(1)
	assert_eq(note.get("id"), "note_override_day_1")
	assert_false(
		bool(note.get("allow_auto_dismiss")),
		"Day 1 must require manual dismiss"
	)


func test_day_10_override_allows_auto_dismiss() -> void:
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(10)
	assert_eq(note.get("id"), "note_override_day_10")
	assert_true(
		bool(note.get("allow_auto_dismiss")),
		"Day 10 milestone allows auto-dismiss"
	)


func test_day_20_override_allows_auto_dismiss() -> void:
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(20)
	assert_eq(note.get("id"), "note_override_day_20")
	assert_true(bool(note.get("allow_auto_dismiss")))


func test_unlock_override_blocks_auto_dismiss() -> void:
	ManagerRelationshipManager._set_pending_unlock_for_testing("trade_in_intake")
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(5)
	assert_eq(note.get("id"), "note_override_unlock_trade_in")
	assert_false(
		bool(note.get("allow_auto_dismiss")),
		"unlock-override mornings must require manual dismiss"
	)


# ── Note selection — tier × category ─────────────────────────────────────────

func test_silent_day_falls_back_to_operational() -> void:
	# No event recorded — top category resolves to operational and tier=neutral
	# (default trust 0.5 is at the warm boundary; verify exact tier first).
	# 0.50 maps to warm per the threshold contract (NEUTRAL_MAX = 0.50).
	ManagerRelationshipManager.manager_trust = 0.5
	# Force tier recalc by applying a no-op style delta that *does* move; we
	# apply a 0.0001 nudge to avoid the saturation guard.
	# Simpler: set manager_trust directly and call _recalculate_tier through
	# a benign delta sequence.
	ManagerRelationshipManager.apply_trust_delta(-0.01, "tier_setup")
	# trust now 0.49 → neutral. Verify selection lands on neutral_op.
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(2)
	assert_eq(
		note.get("id"), "neutral_op",
		"silent day must select tier × operational fallback"
	)
	assert_true(bool(note.get("allow_auto_dismiss")))


func test_top_category_staff_after_quit_event() -> void:
	# Two staff events lift staff above the operational fallback. The trust
	# setup keeps tier in neutral so the chosen note id is predictable.
	ManagerRelationshipManager.apply_trust_delta(-0.01, "tier_setup")
	ManagerRelationshipManager._record_event_for_testing(
		ManagerRelationshipManager.CATEGORY_STAFF
	)
	ManagerRelationshipManager._record_event_for_testing(
		ManagerRelationshipManager.CATEGORY_STAFF
	)
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(5)
	assert_eq(note.get("id"), "neutral_staff")


func test_top_category_sales_resolves_in_warm_tier() -> void:
	ManagerRelationshipManager.apply_trust_delta(0.15, "warm_setup")
	ManagerRelationshipManager._record_event_for_testing(
		ManagerRelationshipManager.CATEGORY_SALES
	)
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(5)
	assert_eq(
		note.get("id"), "warm_sales",
		"top sales category in warm tier must select warm_sales"
	)


# ── day_started flow ─────────────────────────────────────────────────────────

func test_day_started_emits_manager_note_shown_with_day1_payload() -> void:
	watch_signals(EventBus)
	EventBus.day_started.emit(1)
	assert_signal_emitted(EventBus, "manager_note_shown")
	var params: Array = get_signal_parameters(EventBus, "manager_note_shown")
	assert_eq(params[0], "note_override_day_1")
	assert_false(
		bool(params[2]),
		"Day 1 manager_note_shown must signal allow_auto_dismiss=false"
	)


func test_day_started_clears_category_tally() -> void:
	# Drop trust into neutral so the post-reset selection has a stable id.
	ManagerRelationshipManager.apply_trust_delta(-0.01, "tier_setup")
	ManagerRelationshipManager._record_event_for_testing(
		ManagerRelationshipManager.CATEGORY_STAFF
	)
	EventBus.day_started.emit(2)
	var second: Dictionary = ManagerRelationshipManager.select_note_for_day(3)
	assert_eq(
		second.get("id"), "neutral_op",
		"category counts must reset at day_started"
	)


func test_day_started_consumes_pending_unlock() -> void:
	ManagerRelationshipManager._set_pending_unlock_for_testing("trade_in_intake")
	EventBus.day_started.emit(5)  # Consumes the pending unlock.
	var second: Dictionary = ManagerRelationshipManager.select_note_for_day(6)
	assert_ne(
		second.get("id"), "note_override_unlock_trade_in",
		"unlock override fires exactly once on the morning after the unlock"
	)


# ── Acceptance: tally never crashes on unknown category ──────────────────────

func test_tier_category_lookup_falls_back_when_category_missing() -> void:
	# Custom note table without a "sales" key in the cold tier — should
	# silently fall back to operational rather than crash.
	var partial: Dictionary = {
		"tier_notes": {
			"cold": {
				"operational": [{"id": "cold_only_op", "body": "x"}],
			},
		},
		"date_overrides": {
			"day_1": {"id": "note_override_day_1", "body": "x"},
		},
		"fallback": {"id": "note_fallback_default", "body": "x"},
	}
	ManagerRelationshipManager._set_notes_for_testing(partial)
	ManagerRelationshipManager.apply_trust_delta(-0.4, "cold_setup")
	ManagerRelationshipManager._record_event_for_testing(
		ManagerRelationshipManager.CATEGORY_SALES
	)
	var note: Dictionary = ManagerRelationshipManager.select_note_for_day(5)
	assert_eq(
		note.get("id"), "cold_only_op",
		"missing category key must fall back to operational"
	)


# ── manager_name accessor ────────────────────────────────────────────────────

func test_manager_name_returns_vic_harlow() -> void:
	assert_eq(ManagerRelationshipManager.get_manager_name(), "Vic Harlow")
