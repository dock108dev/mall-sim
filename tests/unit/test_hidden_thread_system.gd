## Unit tests for HiddenThreadSystem — tier triggers, day-boundary artifact
## unlocks, per-day pattern accumulation, and save/load round-trip.
##
## Tests run against the project autoload (HiddenThreadSystemSingleton) and
## reset its state between cases — instantiating a second HiddenThreadSystem
## would cause every EventBus emission to be handled twice (autoload + fresh
## instance) and corrupt assertion counts.
class_name TestHiddenThreadSystem
extends GutTest


var _sys: HiddenThreadSystem


func before_each() -> void:
	_sys = (
		Engine.get_main_loop().root.get_node("HiddenThreadSystemSingleton")
		as HiddenThreadSystem
	)
	_sys.reset()


# ── Initial state ─────────────────────────────────────────────────────────────


func test_fresh_system_initializes_all_stats_to_zero() -> void:
	assert_eq(_sys.hidden_thread_interactions, 0)
	assert_eq(_sys.paper_trail_score, 0.0)
	assert_eq(_sys.scapegoat_risk, 0.0)
	assert_eq(_sys.awareness_score, 0.0)
	assert_eq(_sys.discovered_artifacts.size(), 0)


# ── Tier 1 ────────────────────────────────────────────────────────────────────


func test_tier1_delivery_manifest_increments_awareness_by_5() -> void:
	EventBus.delivery_manifest_examined.emit(&"retro_games", 1)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)


func test_tier1_hold_shady_request_increments_awareness_by_5() -> void:
	EventBus.hold_shady_request_received.emit(
		&"retro_games", "HOLD-0001", &"vecforce_hd", 2
	)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)


func test_tier1_inventory_variance_increments_awareness_by_5() -> void:
	EventBus.inventory_variance_noted.emit(&"retro_games", &"sku_001", 5, 4)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)


func test_tier1_display_exposes_weird_inventory_increments_by_5() -> void:
	EventBus.display_exposes_weird_inventory.emit(&"retro_games")
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)


func test_tier1_emits_hidden_thread_interaction_fired_with_tier_1() -> void:
	watch_signals(EventBus)
	EventBus.delivery_manifest_examined.emit(&"retro_games", 1)
	assert_signal_emit_count(EventBus, "hidden_thread_interaction_fired", 1)
	var params: Array = get_signal_parameters(
		EventBus, "hidden_thread_interaction_fired", 0
	)
	assert_eq(int(params[0]), 1, "tier should be 1")


func test_tier1_emits_hidden_thread_interacted_signal() -> void:
	watch_signals(EventBus)
	EventBus.delivery_manifest_examined.emit(&"retro_games", 1)
	assert_signal_emit_count(EventBus, "hidden_thread_interacted", 1)


# ── Hidden-Thread Interactables (Tier 1) ─────────────────────────────────────


func test_hold_shelf_inspected_increments_awareness_by_5() -> void:
	EventBus.hold_shelf_inspected.emit(&"retro_games", 2)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)


func test_warranty_binder_increments_paper_trail_by_2() -> void:
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.paper_trail_score, 2.0)


func test_employee_schedule_increments_paper_trail_by_1() -> void:
	EventBus.employee_schedule_examined.emit(&"retro_games", 1)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.paper_trail_score, 1.0)


func test_other_hidden_thread_interactables_do_not_touch_paper_trail() -> void:
	EventBus.hold_shelf_inspected.emit(&"retro_games", 0)
	EventBus.backordered_item_examined.emit(&"retro_games", &"sku_a", 3)
	EventBus.register_note_examined.emit(&"retro_games", 1)
	EventBus.security_flyer_examined.emit(&"retro_games")
	EventBus.returned_item_examined.emit(&"retro_games", &"sku_b")
	assert_eq(_sys.paper_trail_score, 0.0)


func test_backordered_item_examined_increments_awareness_by_5() -> void:
	EventBus.backordered_item_examined.emit(&"retro_games", &"sku_x", 4)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)


func test_register_note_examined_increments_awareness_by_5() -> void:
	EventBus.register_note_examined.emit(&"retro_games", 1)
	assert_eq(_sys.awareness_score, 5.0)


func test_security_flyer_examined_increments_awareness_by_5() -> void:
	EventBus.security_flyer_examined.emit(&"retro_games")
	assert_eq(_sys.awareness_score, 5.0)


func test_returned_item_examined_increments_awareness_by_5() -> void:
	EventBus.returned_item_examined.emit(&"retro_games", &"sku_x")
	assert_eq(_sys.awareness_score, 5.0)


func test_hidden_thread_inspection_is_idempotent_per_day() -> void:
	# Three E-presses on the same prop in one day → exactly one credit.
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	assert_eq(_sys.awareness_score, 5.0)
	assert_eq(_sys.hidden_thread_interactions, 1)
	assert_eq(_sys.paper_trail_score, 2.0)


func test_hidden_thread_inspection_credits_again_after_day_rollover() -> void:
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.day_started.emit(2)
	EventBus.warranty_binder_examined.emit(&"retro_games", 2)
	assert_eq(_sys.hidden_thread_interactions, 2)
	assert_eq(_sys.paper_trail_score, 4.0)


func test_distinct_props_each_credit_independently() -> void:
	EventBus.hold_shelf_inspected.emit(&"retro_games", 0)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.backordered_item_examined.emit(&"retro_games", &"a", 0)
	assert_eq(_sys.awareness_score, 15.0)
	assert_eq(_sys.hidden_thread_interactions, 3)
	assert_eq(_sys.get_inspections_today(), 3)


# ── finalize_day / hidden_thread_consequence_triggered ───────────────────────


func test_finalize_day_with_zero_inspections_emits_empty_string() -> void:
	watch_signals(EventBus)
	_sys.finalize_day(1)
	assert_signal_emit_count(
		EventBus, "hidden_thread_consequence_triggered", 1
	)
	var params: Array = get_signal_parameters(
		EventBus, "hidden_thread_consequence_triggered", 0
	)
	assert_eq(String(params[0]), "")


func test_finalize_day_with_one_inspection_emits_minor_irregularity() -> void:
	watch_signals(EventBus)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	_sys.finalize_day(1)
	var params: Array = get_signal_parameters(
		EventBus, "hidden_thread_consequence_triggered", 0
	)
	assert_eq(
		String(params[0]),
		HiddenThreadSystem.CONSEQUENCE_TEXT_ONE,
	)


func test_finalize_day_with_two_to_five_inspections_emits_several_items() -> void:
	watch_signals(EventBus)
	EventBus.hold_shelf_inspected.emit(&"retro_games", 0)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	_sys.finalize_day(1)
	var params: Array = get_signal_parameters(
		EventBus, "hidden_thread_consequence_triggered", 0
	)
	assert_eq(
		String(params[0]),
		HiddenThreadSystem.CONSEQUENCE_TEXT_MULTIPLE,
	)


func test_finalize_day_is_idempotent_per_day() -> void:
	watch_signals(EventBus)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	_sys.finalize_day(3)
	_sys.finalize_day(3)
	_sys.finalize_day(3)
	assert_signal_emit_count(
		EventBus, "hidden_thread_consequence_triggered", 1
	)


func test_day_ended_emits_consequence_text_via_finalize_day() -> void:
	watch_signals(EventBus)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.day_ended.emit(2)
	assert_signal_emit_count(
		EventBus, "hidden_thread_consequence_triggered", 1
	)


func test_inspections_today_resets_at_day_started() -> void:
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.hold_shelf_inspected.emit(&"retro_games", 0)
	assert_eq(_sys.get_inspections_today(), 2)
	EventBus.day_started.emit(2)
	assert_eq(_sys.get_inspections_today(), 0)


# ── Defective return passive accumulator (Tier 2) ───────────────────────────


func test_defective_item_received_accumulates_tier2_at_threshold() -> void:
	EventBus.defective_item_received.emit("sku_a")
	assert_eq(_sys.awareness_score, 0.0)
	EventBus.defective_item_received.emit("sku_b")
	# Two defective items in one day → Tier 2 cluster fires (+10 awareness).
	assert_eq(_sys.awareness_score, 10.0)


func test_defective_item_below_threshold_does_not_fire() -> void:
	EventBus.defective_item_received.emit("sku_a")
	assert_eq(_sys.awareness_score, 0.0)


func test_defective_returns_counter_resets_at_day_started() -> void:
	EventBus.defective_item_received.emit("sku_a")
	EventBus.day_started.emit(2)
	EventBus.defective_item_received.emit("sku_b")
	# Without reset, two would have crossed threshold; after reset, only one
	# accumulated on day 2 — no Tier 2 cluster.
	assert_eq(_sys.awareness_score, 0.0)


# ── Tier 2 ────────────────────────────────────────────────────────────────────


func test_tier2_unsatisfied_streak_fires_after_three_unsatisfied() -> void:
	for i: int in range(3):
		EventBus.customer_left.emit({"satisfied": false})
	assert_eq(_sys.awareness_score, 10.0)


func test_tier2_unsatisfied_streak_fires_only_once_per_day() -> void:
	for i: int in range(5):
		EventBus.customer_left.emit({"satisfied": false})
	assert_eq(_sys.awareness_score, 10.0)


func test_tier2_unsatisfied_streak_resets_at_day_started() -> void:
	for i: int in range(3):
		EventBus.customer_left.emit({"satisfied": false})
	EventBus.day_started.emit(2)
	for i: int in range(3):
		EventBus.customer_left.emit({"satisfied": false})
	assert_eq(_sys.awareness_score, 20.0)


func test_satisfied_customers_do_not_count() -> void:
	for i: int in range(5):
		EventBus.customer_left.emit({"satisfied": true})
	assert_eq(_sys.awareness_score, 0.0)


func test_tier2_backroom_reentry_fires_after_three_opens() -> void:
	for i: int in range(3):
		EventBus.panel_opened.emit("back_room_inventory")
	assert_eq(_sys.awareness_score, 10.0)


func test_tier2_backroom_reentry_ignores_unrelated_panels() -> void:
	for i: int in range(5):
		EventBus.panel_opened.emit("inventory")
	assert_eq(_sys.awareness_score, 0.0)


func test_tier2_discrepancy_cluster_fires_on_two_variance_notes() -> void:
	EventBus.inventory_variance_noted.emit(&"retro_games", &"sku_a", 5, 4)
	EventBus.inventory_variance_noted.emit(&"retro_games", &"sku_b", 3, 1)
	# Two Tier 1 (5+5=10) plus one Tier 2 cluster (+10) → 20 total.
	assert_eq(_sys.awareness_score, 20.0)


func test_tier2_hold_conflict_bypassed_increments_awareness_by_10() -> void:
	EventBus.hold_conflict_bypassed.emit(
		&"retro_games", &"vecforce_hd", ["HOLD-0001", "HOLD-0002"]
	)
	assert_eq(_sys.awareness_score, 10.0)


func test_tier2_emits_hidden_thread_interaction_fired_with_tier_2() -> void:
	watch_signals(EventBus)
	for i: int in range(3):
		EventBus.customer_left.emit({"satisfied": false})
	# customer_left does not itself emit hidden_thread_interaction_fired
	# until the threshold is crossed. Expect exactly one tier-2 emission.
	assert_signal_emit_count(EventBus, "hidden_thread_interaction_fired", 1)
	var params: Array = get_signal_parameters(
		EventBus, "hidden_thread_interaction_fired", 0
	)
	assert_eq(int(params[0]), 2, "tier should be 2")


# ── Tier 3 ────────────────────────────────────────────────────────────────────


func test_tier3_artifact_spawns_when_threshold_met_at_day_5() -> void:
	_sys.awareness_score = 15.0
	EventBus.day_ended.emit(5)
	assert_true(_sys.has_artifact(&"delivery_manifest_carbon"))
	assert_eq(_sys.discovered_artifacts.size(), 1)
	assert_eq(_sys.awareness_score, 35.0, "+20 for Tier 3 unlock")


func test_tier3_artifact_does_not_spawn_below_day_5_threshold() -> void:
	_sys.awareness_score = 14.0
	EventBus.day_ended.emit(5)
	assert_eq(_sys.discovered_artifacts.size(), 0)
	assert_eq(_sys.awareness_score, 14.0)


func test_tier3_missed_artifact_is_permanent_no_catchup() -> void:
	_sys.awareness_score = 10.0
	EventBus.day_ended.emit(5)
	assert_eq(_sys.discovered_artifacts.size(), 0)
	# Crossing the threshold AFTER day 5 must not retroactively grant the
	# artifact — the spawn check is one-shot per scheduled day.
	_sys.awareness_score = 100.0
	EventBus.day_ended.emit(6)
	EventBus.day_ended.emit(7)
	assert_false(_sys.has_artifact(&"delivery_manifest_carbon"))


func test_tier3_artifact_thresholds_per_day() -> void:
	var schedule: Array = [
		[10, 30.0, &"vacant_unit_manifesto"],
		[15, 50.0, &"directory_ghost_entry"],
		[20, 75.0, &"escalator_loop_token"],
		[25, 100.0, &"wax_reflection_shard"],
	]
	for entry: Array in schedule:
		_sys.reset()
		_sys.awareness_score = float(entry[1])
		EventBus.day_ended.emit(int(entry[0]))
		assert_true(
			_sys.has_artifact(entry[2] as StringName),
			"day %d should unlock %s at threshold %s" % [entry[0], entry[2], entry[1]]
		)


func test_tier3_emits_hidden_artifact_spawned() -> void:
	watch_signals(EventBus)
	_sys.awareness_score = 15.0
	EventBus.day_ended.emit(5)
	assert_signal_emit_count(EventBus, "hidden_artifact_spawned", 1)


func test_tier3_emits_hidden_thread_interacted_with_artifact_id() -> void:
	watch_signals(EventBus)
	_sys.awareness_score = 15.0
	EventBus.day_ended.emit(5)
	var emit_count: int = get_signal_emit_count(
		EventBus, "hidden_thread_interacted"
	)
	var last_params: Array = get_signal_parameters(
		EventBus, "hidden_thread_interacted", emit_count - 1
	)
	assert_eq(StringName(last_params[0]), &"delivery_manifest_carbon")


func test_day_ended_outside_schedule_does_nothing() -> void:
	_sys.awareness_score = 100.0
	EventBus.day_ended.emit(7)
	assert_eq(_sys.discovered_artifacts.size(), 0)
	assert_eq(_sys.awareness_score, 100.0)


# ── Awareness tier crossing ──────────────────────────────────────────────────


func test_awareness_tier_changes_at_25_50_75() -> void:
	watch_signals(EventBus)
	_sys.awareness_score = 24.0
	# +5 → 29.0 crosses the 25.0 boundary.
	EventBus.delivery_manifest_examined.emit(&"retro_games", 1)
	assert_signal_emit_count(EventBus, "hidden_awareness_tier_changed", 1)


# ── Persistence ───────────────────────────────────────────────────────────────


func test_save_load_round_trip_preserves_all_stats() -> void:
	_sys.hidden_thread_interactions = 7
	_sys.paper_trail_score = 12.5
	_sys.scapegoat_risk = 0.3
	_sys.awareness_score = 42.0
	_sys.discovered_artifacts.append(&"delivery_manifest_carbon")
	_sys.discovered_artifacts.append(&"vacant_unit_manifesto")

	var data: Dictionary = _sys.get_save_data()

	_sys.reset()
	_sys.load_state(data)

	assert_eq(_sys.hidden_thread_interactions, 7)
	assert_eq(_sys.paper_trail_score, 12.5)
	assert_eq(_sys.scapegoat_risk, 0.3)
	assert_eq(_sys.awareness_score, 42.0)
	assert_eq(_sys.discovered_artifacts.size(), 2)
	assert_true(_sys.has_artifact(&"delivery_manifest_carbon"))
	assert_true(_sys.has_artifact(&"vacant_unit_manifesto"))


func test_load_state_with_missing_keys_defaults_to_zero_and_empty() -> void:
	_sys.load_state({})
	assert_eq(_sys.hidden_thread_interactions, 0)
	assert_eq(_sys.paper_trail_score, 0.0)
	assert_eq(_sys.scapegoat_risk, 0.0)
	assert_eq(_sys.awareness_score, 0.0)
	assert_eq(_sys.discovered_artifacts.size(), 0)


func test_day_started_does_not_reset_cumulative_stats() -> void:
	_sys.hidden_thread_interactions = 5
	_sys.awareness_score = 30.0
	_sys.discovered_artifacts.append(&"delivery_manifest_carbon")
	EventBus.day_started.emit(2)
	assert_eq(_sys.hidden_thread_interactions, 5)
	assert_eq(_sys.awareness_score, 30.0)
	assert_eq(_sys.discovered_artifacts.size(), 1)


func test_day_started_resets_per_day_counters() -> void:
	for i: int in range(2):
		EventBus.customer_left.emit({"satisfied": false})
	# One short of Tier 2.
	EventBus.day_started.emit(2)
	for i: int in range(3):
		EventBus.customer_left.emit({"satisfied": false})
	# Tier 2 should fire on day 2 (3 unsatisfied) → +10 awareness.
	assert_eq(_sys.awareness_score, 10.0)


# ── Public read API ──────────────────────────────────────────────────────────


func test_get_mystery_artifacts_count_matches_discovered_size() -> void:
	_sys.discovered_artifacts.append(&"delivery_manifest_carbon")
	_sys.discovered_artifacts.append(&"vacant_unit_manifesto")
	assert_eq(_sys.get_mystery_artifacts_count(), 2)
	assert_eq(
		_sys.get_mystery_artifacts_count(), _sys.discovered_artifacts.size()
	)


func test_reset_clears_all_stats() -> void:
	_sys.awareness_score = 75.0
	_sys.discovered_artifacts.append(&"delivery_manifest_carbon")
	_sys.reset()
	assert_eq(_sys.awareness_score, 0.0)
	assert_eq(_sys.discovered_artifacts.size(), 0)


# ── Integration with EndingEvaluator ─────────────────────────────────────────


func test_ending_evaluator_mystery_artifacts_collected_matches_count() -> void:
	var evaluator: EndingEvaluatorSystem = EndingEvaluatorSystem.new()
	add_child_autofree(evaluator)
	evaluator.initialize()

	_sys.awareness_score = 100.0
	EventBus.day_ended.emit(5)

	assert_eq(_sys.get_mystery_artifacts_count(), 1)
	assert_eq(
		evaluator.get_tracked_stat(&"mystery_artifacts_collected"),
		float(_sys.discovered_artifacts.size()),
		"EndingEvaluator's mystery_artifacts_collected must equal discovered_artifacts.size()"
	)
