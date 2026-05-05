## Tests the metric-driven end-of-day comment surface on
## ManagerRelationshipManager: priority order across condition branches,
## graceful fallback when shift_summary lacks the stockout / queue fields,
## and that day_closed emits manager_end_of_day_comment with the resolved
## tier × condition entry.
extends GutTest


const _SAMPLE_NOTES: Dictionary = {
	"tier_notes": {
		"warm": {
			"operational": [{"id": "warm_op", "body": "warm op body"}],
		},
	},
	"end_of_day_comments": {
		"cold": {
			"zero_sales": [{"id": "eod_cold_zero", "body": "cold zero body"}],
			"normal": [{"id": "eod_cold_normal", "body": "cold normal body"}],
		},
		"warm": {
			"zero_sales": [{"id": "eod_warm_zero", "body": "warm zero body"}],
			"empty_shelves": [
				{"id": "eod_warm_empty", "body": "warm empty body"}
			],
			"stockout_walkouts": [
				{"id": "eod_warm_stockout", "body": "warm stockout body"}
			],
			"queue_timeout": [
				{"id": "eod_warm_queue", "body": "warm queue body"}
			],
			"normal": [{"id": "eod_warm_normal", "body": "warm normal body"}],
		},
	},
	"fallback": {"id": "note_fallback_default", "body": "fallback body"},
}


func before_each() -> void:
	ManagerRelationshipManager.reset_for_testing()
	ManagerRelationshipManager._set_notes_for_testing(_SAMPLE_NOTES)


# Default trust 0.5 sits at the warm boundary (≥ NEUTRAL_MAX). All tests below
# operate in warm tier unless they explicitly drop trust into cold.

func test_zero_sales_takes_priority_over_normal() -> void:
	var payload: Dictionary = {"items_sold": 0, "inventory_remaining": 5}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(1, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_zero")


func test_zero_sales_wins_over_empty_shelves() -> void:
	# Stockout + zero inventory would normally drive empty_shelves, but
	# items_sold == 0 takes the highest priority.
	var payload: Dictionary = {
		"items_sold": 0,
		"inventory_remaining": 0,
		"shift_summary": {"customers_no_stock": 4},
	}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(1, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_zero")


func test_empty_shelves_when_stockouts_and_zero_inventory() -> void:
	var payload: Dictionary = {
		"items_sold": 4,
		"inventory_remaining": 0,
		"shift_summary": {"customers_no_stock": 1},
	}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(2, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_empty")


func test_stockout_walkouts_when_threshold_exceeded() -> void:
	# customers_no_stock > 2 with non-zero inventory selects the
	# stockout_walkouts branch over queue_timeout / normal.
	var payload: Dictionary = {
		"items_sold": 4,
		"inventory_remaining": 2,
		"shift_summary": {
			"customers_no_stock": 3, "customers_timeout": 10
		},
	}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(2, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_stockout")


func test_queue_timeout_when_threshold_exceeded() -> void:
	var payload: Dictionary = {
		"items_sold": 4,
		"inventory_remaining": 2,
		"shift_summary": {"customers_timeout": 4},
	}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(2, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_queue")


func test_normal_when_thresholds_not_met() -> void:
	var payload: Dictionary = {
		"items_sold": 4,
		"inventory_remaining": 5,
		"shift_summary": {
			"customers_no_stock": 1, "customers_timeout": 2
		},
	}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(2, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_normal")


func test_missing_shift_summary_degrades_to_normal_without_warning() -> void:
	# Acceptance criterion: when shift_summary lacks stockout/timeout fields,
	# selection degrades gracefully to `normal` without error or push_warning.
	var payload: Dictionary = {"items_sold": 4, "inventory_remaining": 5}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(2, payload)
	)
	assert_eq(comment.get("id"), "eod_warm_normal")


func test_missing_condition_falls_back_to_normal() -> void:
	# Cold tier in the fixture has no empty_shelves / stockout entries.
	# A stockout-driven condition must fall back to the cold normal entry.
	ManagerRelationshipManager.apply_trust_delta(-0.4, "cold_setup")
	var payload: Dictionary = {
		"items_sold": 5,
		"inventory_remaining": 0,
		"shift_summary": {"customers_no_stock": 5},
	}
	var comment: Dictionary = (
		ManagerRelationshipManager.select_end_of_day_comment(2, payload)
	)
	assert_eq(comment.get("id"), "eod_cold_normal")


# ── Signal emission ──────────────────────────────────────────────────────────

func test_day_closed_emits_manager_end_of_day_comment() -> void:
	watch_signals(EventBus)
	var payload: Dictionary = {"items_sold": 0, "inventory_remaining": 0}
	EventBus.day_closed.emit(1, payload)
	assert_signal_emitted(
		EventBus, "manager_end_of_day_comment",
		"day_closed must drive ManagerRelationshipManager to emit the comment"
	)
	var params: Array = (
		get_signal_parameters(EventBus, "manager_end_of_day_comment")
	)
	assert_eq(params[0], "eod_warm_zero")
	assert_eq(params[1], "warm zero body")


func test_day_closed_with_normal_metrics_emits_normal_comment() -> void:
	watch_signals(EventBus)
	var payload: Dictionary = {"items_sold": 5, "inventory_remaining": 5}
	EventBus.day_closed.emit(2, payload)
	assert_signal_emitted(EventBus, "manager_end_of_day_comment")
	var params: Array = (
		get_signal_parameters(EventBus, "manager_end_of_day_comment")
	)
	assert_eq(params[0], "eod_warm_normal")


func test_no_emission_when_eod_block_missing() -> void:
	# When the JSON lacks end_of_day_comments entirely (legacy test fixtures),
	# day_closed must not crash and must not emit a partial signal.
	ManagerRelationshipManager._set_notes_for_testing({
		"tier_notes": {},
		"fallback": {"id": "note_fallback_default", "body": ""},
	})
	watch_signals(EventBus)
	EventBus.day_closed.emit(1, {"items_sold": 0})
	assert_signal_not_emitted(EventBus, "manager_end_of_day_comment")
