## ISSUE-016: Return/refund consumes warranty record and branches outcome.
## Covers declined (no warranty on record), basic tier, and premium tier paths.
## Also verifies tier_id persists on sale record and in save data.
extends GutTest


var _manager: WarrantyManager


func before_each() -> void:
	_manager = WarrantyManager.new()


# ── Persistence of tier on the sale record ───────────────────────────────────

func test_add_warranty_records_tier_id_on_sale_record() -> void:
	var record: Dictionary = _manager.add_warranty(
		"elec_001", 120.0, 18.0, 60.0, 1, "basic"
	)
	assert_eq(record.get("tier_id", ""), "basic")


func test_add_warranty_tier_id_defaults_to_empty_for_legacy_callers() -> void:
	var record: Dictionary = _manager.add_warranty(
		"elec_legacy", 120.0, 18.0, 60.0, 1
	)
	assert_eq(record.get("tier_id", "missing"), "")


func test_save_data_round_trip_preserves_tier_id() -> void:
	_manager.add_warranty("elec_save", 200.0, 50.0, 100.0, 1, "premium")
	var data: Dictionary = _manager.get_save_data()
	var restored := WarrantyManager.new()
	restored.load_save_data(data)
	var active: Array = restored.get_save_data().get("active_warranties", [])
	assert_eq(active.size(), 1)
	assert_eq((active[0] as Dictionary).get("tier_id", ""), "premium")


# ── find_active_warranty ─────────────────────────────────────────────────────

func test_find_active_warranty_returns_empty_when_none() -> void:
	var w: Dictionary = _manager.find_active_warranty("nope", 5)
	assert_true(w.is_empty())


func test_find_active_warranty_ignores_expired() -> void:
	_manager.add_warranty("elec_exp", 100.0, 20.0, 50.0, 1, "basic")
	var past_expiry: int = 1 + WarrantyManager.WARRANTY_DURATION_DAYS + 1
	var w: Dictionary = _manager.find_active_warranty("elec_exp", past_expiry)
	assert_true(w.is_empty())


# ── process_return: declined path (no warranty) ──────────────────────────────

func test_process_return_declined_path_partial_refund() -> void:
	var outcome: Dictionary = _manager.process_return("unsold_item", 100.0, 5, 0.5)
	assert_false(outcome.get("warranty_consumed", true))
	assert_eq(outcome.get("reason", ""), "no_warranty")
	assert_almost_eq(float(outcome.get("refund_amount", -1.0)), 50.0, 0.001)
	assert_eq(outcome.get("tier_id", "x"), "")


func test_process_return_declined_clamps_refund_percent() -> void:
	var outcome: Dictionary = _manager.process_return("x", 100.0, 5, 1.5)
	assert_almost_eq(float(outcome.get("refund_amount", -1.0)), 100.0, 0.001)


# ── process_return: basic tier ───────────────────────────────────────────────

func test_process_return_basic_tier_full_refund_and_consumes_warranty() -> void:
	_manager.add_warranty("elec_basic", 120.0, 18.0, 60.0, 1, "basic")
	var outcome: Dictionary = _manager.process_return("elec_basic", 120.0, 5, 0.5)
	assert_true(outcome.get("warranty_consumed", false))
	assert_eq(outcome.get("reason", ""), "warranty_covered")
	assert_eq(outcome.get("tier_id", ""), "basic")
	assert_almost_eq(float(outcome.get("refund_amount", -1.0)), 120.0, 0.001)
	# Warranty is consumed — second return finds no active warranty.
	var again: Dictionary = _manager.process_return("elec_basic", 120.0, 6, 0.5)
	assert_false(again.get("warranty_consumed", true))
	assert_eq(again.get("reason", ""), "no_warranty")


func test_process_return_basic_tier_records_claim_history() -> void:
	_manager.add_warranty("elec_basic_ch", 120.0, 18.0, 60.0, 1, "basic")
	_manager.process_return("elec_basic_ch", 120.0, 5, 0.5)
	var data: Dictionary = _manager.get_save_data()
	var history: Array = data.get("claim_history", [])
	assert_eq(history.size(), 1)
	var claim: Dictionary = history[0]
	assert_eq(claim.get("tier_id", ""), "basic")
	assert_eq(claim.get("reason", ""), "return")


# ── process_return: premium tier ─────────────────────────────────────────────

func test_process_return_premium_tier_full_refund_and_tier_preserved() -> void:
	_manager.add_warranty("elec_prem", 300.0, 75.0, 150.0, 2, "premium")
	var outcome: Dictionary = _manager.process_return("elec_prem", 300.0, 10, 0.5)
	assert_true(outcome.get("warranty_consumed", false))
	assert_eq(outcome.get("tier_id", ""), "premium")
	assert_almost_eq(float(outcome.get("refund_amount", -1.0)), 300.0, 0.001)


func test_process_return_expired_warranty_falls_back_to_partial_refund() -> void:
	_manager.add_warranty("elec_expired", 200.0, 40.0, 100.0, 1, "premium")
	var past: int = 1 + WarrantyManager.WARRANTY_DURATION_DAYS + 1
	var outcome: Dictionary = _manager.process_return("elec_expired", 200.0, past, 0.5)
	assert_false(outcome.get("warranty_consumed", true))
	assert_eq(outcome.get("reason", ""), "no_warranty")
	assert_almost_eq(float(outcome.get("refund_amount", -1.0)), 100.0, 0.001)
