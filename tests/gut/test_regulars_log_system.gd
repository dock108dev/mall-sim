## Tests for RegularsLogSystem: trigger conditions, phase transitions,
## signal emission, and save/load round-trip.
extends GutTest


var _system: RegularsLogSystem

const _THREAD_DEFS: Array[Dictionary] = []

const _FAMILIAR_FACE_DEF: Dictionary = {
	"id": "the_familiar_face",
	"display_name": "The Familiar Face",
	"phases": [
		{
			"phase": 1,
			"trigger": {"type": "visit_count", "threshold": 5},
			"narrative_text": "She's here every day.",
			"payoff_text": "",
		},
		{
			"phase": 2,
			"trigger": {"type": "day_range", "min_day": 15, "max_day": 999},
			"narrative_text": "She lingered near the display.",
			"payoff_text": "",
		},
		{
			"phase": 3,
			"trigger": {"type": "visit_count", "threshold": 20},
			"narrative_text": "",
			"payoff_text": "Thank you for keeping it open.",
		},
	],
}

const _CRITIC_DEF: Dictionary = {
	"id": "the_notebook_critic",
	"display_name": "The Notebook Critic",
	"phases": [
		{
			"phase": 1,
			"trigger": {"type": "visit_count", "threshold": 3},
			"narrative_text": "A visitor with a notebook.",
			"payoff_text": "",
		},
		{
			"phase": 2,
			"trigger": {"type": "purchase_type", "category": "singles"},
			"narrative_text": "He bought something.",
			"payoff_text": "",
		},
		{
			"phase": 3,
			"trigger": {"type": "visit_count", "threshold": 12},
			"narrative_text": "",
			"payoff_text": "Four stars.",
		},
	],
}

const _VACANT_UNIT_DEF: Dictionary = {
	"id": "the_vacant_unit",
	"display_name": "The Vacant Unit",
	"phases": [
		{
			"phase": 1,
			"trigger": {"type": "day_range", "min_day": 10, "max_day": 999},
			"narrative_text": "Minor utility draw in 7B.",
			"payoff_text": "",
		},
		{
			"phase": 2,
			"trigger": {"type": "visit_count", "threshold": 5},
			"narrative_text": "Figure seen at dawn.",
			"payoff_text": "",
		},
		{
			"phase": 3,
			"trigger": {"type": "day_range", "min_day": 25, "max_day": 999},
			"narrative_text": "",
			"payoff_text": "Thank you for not making it worse.",
		},
	],
}

const _LEGEND_DEF: Dictionary = {
	"id": "the_legend",
	"display_name": "The Legend",
	"phases": [
		{
			"phase": 1,
			"trigger": {"type": "day_range", "min_day": 14, "max_day": 999},
			"narrative_text": "Community rumor.",
			"payoff_text": "",
		},
		{
			"phase": 2,
			"trigger": {"type": "visit_count", "threshold": 3},
			"narrative_text": "Old inscription found.",
			"payoff_text": "",
		},
		{
			"phase": 3,
			"trigger": {"type": "day_range", "min_day": 50, "max_day": 999},
			"narrative_text": "",
			"payoff_text": "It's real.",
		},
	],
}


func before_each() -> void:
	_system = RegularsLogSystem.new()
	add_child_autofree(_system)
	_system._current_day = 1


func _setup_with_defs(defs: Array[Dictionary]) -> void:
	_system._thread_defs = defs.duplicate(true)


func _simulate_visits(customer_id: String, count: int) -> void:
	for _i: int in range(count):
		_system._record_visit(customer_id, "Test Customer")


func _simulate_purchase(customer_id: String, category: String) -> void:
	_system._record_purchase(customer_id, "item_001", category)


# ── JSON file integrity ────────────────────────────────────────────────────────


func test_json_file_loads_four_threads() -> void:
	var parsed: Array = DataLoader.load_catalog_entries(
		"res://game/content/meta/regulars_threads.json"
	)
	assert_eq(parsed.size(), 4, "Must have exactly four thread entries")


func test_json_threads_have_required_fields() -> void:
	var parsed: Array = DataLoader.load_catalog_entries(
		"res://game/content/meta/regulars_threads.json"
	)
	if parsed.is_empty():
		return
	for entry: Variant in parsed:
		assert_true(entry is Dictionary, "Each entry must be a Dictionary")
		if entry is not Dictionary:
			continue
		var d: Dictionary = entry as Dictionary
		assert_true(d.has("id"), "Thread must have 'id'")
		assert_true(d.has("phases"), "Thread must have 'phases'")
		var phases: Variant = d.get("phases")
		assert_true(phases is Array, "'phases' must be an Array")
		if phases is not Array:
			continue
		for phase: Variant in (phases as Array):
			assert_true(phase is Dictionary, "Phase must be a Dictionary")
			if phase is not Dictionary:
				continue
			var p: Dictionary = phase as Dictionary
			assert_true(p.has("trigger"), "Phase must have 'trigger'")
			assert_true(p.has("payoff_text"), "Phase must have 'payoff_text'")


# ── regular_recognized signal ─────────────────────────────────────────────────


func test_regular_recognized_fires_at_recognition_threshold() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	watch_signals(EventBus)
	_simulate_visits(
		"cust_01",
		RegularsLogSystem.RECOGNITION_THRESHOLD - 1
	)
	assert_signal_not_emitted(
		EventBus, "regular_recognized",
		"Should not fire before threshold"
	)
	_system._record_visit("cust_01", "Diane")
	assert_signal_emitted(
		EventBus, "regular_recognized",
		"Should fire exactly at RECOGNITION_THRESHOLD"
	)


func test_regular_recognized_not_fired_again_after_threshold() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	watch_signals(EventBus)
	_simulate_visits("cust_02", RegularsLogSystem.RECOGNITION_THRESHOLD + 5)
	assert_signal_emit_count(
		EventBus, "regular_recognized", 1,
		"regular_recognized fires exactly once"
	)


# ── visit_count trigger ────────────────────────────────────────────────────────


func test_visit_count_trigger_below_threshold_does_not_advance() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	_simulate_visits("cust_03", 4)
	assert_eq(
		_system.get_thread_phase("cust_03", "the_familiar_face"), 0,
		"Phase must stay 0 below visit_count threshold of 5"
	)


func test_visit_count_trigger_at_threshold_advances_phase() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	_simulate_visits("cust_04", 5)
	assert_eq(
		_system.get_thread_phase("cust_04", "the_familiar_face"), 1,
		"Phase must advance to 1 when visit_count == 5"
	)


func test_visit_count_trigger_above_threshold_advances_phase() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	_simulate_visits("cust_05", 7)
	assert_eq(
		_system.get_thread_phase("cust_05", "the_familiar_face"), 1,
		"Phase must be 1 when visit_count > 5 (phase 2 needs day_range)"
	)


func test_visit_count_one_below_threshold_boundary() -> void:
	_setup_with_defs([_CRITIC_DEF])
	_simulate_visits("cust_critic_01", 2)
	assert_eq(
		_system.get_thread_phase("cust_critic_01", "the_notebook_critic"), 0,
		"At visit 2 (threshold=3), phase must still be 0"
	)


# ── purchase_type trigger ──────────────────────────────────────────────────────


func test_purchase_type_matching_category_advances_phase() -> void:
	_setup_with_defs([_CRITIC_DEF])
	# Advance past phase 0 (visit_count >= 3) first
	_simulate_visits("cust_c2", 3)
	assert_eq(_system.get_thread_phase("cust_c2", "the_notebook_critic"), 1)
	# Now trigger purchase_type phase
	_simulate_purchase("cust_c2", "singles")
	assert_eq(
		_system.get_thread_phase("cust_c2", "the_notebook_critic"), 2,
		"Purchase of 'singles' category must advance to phase 2"
	)


func test_purchase_type_wrong_category_does_not_advance() -> void:
	_setup_with_defs([_CRITIC_DEF])
	_simulate_visits("cust_c3", 3)
	_simulate_purchase("cust_c3", "gadgets")
	assert_eq(
		_system.get_thread_phase("cust_c3", "the_notebook_critic"), 1,
		"Wrong category must not advance phase"
	)


func test_purchase_type_no_purchase_does_not_advance() -> void:
	_setup_with_defs([_CRITIC_DEF])
	_simulate_visits("cust_c4", 3)
	assert_eq(
		_system.get_thread_phase("cust_c4", "the_notebook_critic"), 1,
		"No purchases must not advance past purchase_type phase"
	)


# ── day_range trigger ─────────────────────────────────────────────────────────


func test_day_range_before_min_day_does_not_advance() -> void:
	_setup_with_defs([_VACANT_UNIT_DEF])
	_system._current_day = 9
	_simulate_visits("cust_v1", 1)
	assert_eq(
		_system.get_thread_phase("cust_v1", "the_vacant_unit"), 0,
		"Day 9 is before min_day=10; phase must stay 0"
	)


func test_day_range_at_min_day_advances_phase() -> void:
	_setup_with_defs([_VACANT_UNIT_DEF])
	_system._current_day = 10
	_simulate_visits("cust_v2", 1)
	assert_eq(
		_system.get_thread_phase("cust_v2", "the_vacant_unit"), 1,
		"Day 10 == min_day=10; phase must advance to 1"
	)


func test_day_range_well_past_min_day_advances_phase() -> void:
	_setup_with_defs([_VACANT_UNIT_DEF])
	_system._current_day = 30
	_simulate_visits("cust_v3", 1)
	assert_eq(
		_system.get_thread_phase("cust_v3", "the_vacant_unit"), 1,
		"Day 30 > min_day=10; phase must advance to 1"
	)


func test_day_range_boundary_one_before_min_day() -> void:
	_setup_with_defs([_LEGEND_DEF])
	_system._current_day = 13
	_simulate_visits("cust_l1", 1)
	assert_eq(
		_system.get_thread_phase("cust_l1", "the_legend"), 0,
		"Day 13 is one before min_day=14; phase must stay 0"
	)


func test_day_range_boundary_at_min_day() -> void:
	_setup_with_defs([_LEGEND_DEF])
	_system._current_day = 14
	_simulate_visits("cust_l2", 1)
	assert_eq(
		_system.get_thread_phase("cust_l2", "the_legend"), 1,
		"Day 14 == min_day=14; phase must advance to 1"
	)


# ── thread_advanced and thread_resolved signals ────────────────────────────────


func test_thread_advanced_emitted_on_non_final_phase() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	watch_signals(EventBus)
	_system._current_day = 1
	_simulate_visits("cust_adv1", 5)
	assert_signal_emitted(
		EventBus, "thread_advanced",
		"thread_advanced must emit on phase 0→1 transition"
	)


func test_thread_resolved_emitted_on_final_phase() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	watch_signals(EventBus)
	_system._current_day = 20
	_simulate_visits("cust_res1", 5)   # phase 0→1 (visit_count>=5)
	# Phase 1→2: day_range min_day=15 satisfied (day=20) — advances on next visit
	# Phase 2→3: visit_count>=20
	_simulate_visits("cust_res1", 15)  # bring total to 20
	assert_signal_emitted(
		EventBus, "thread_resolved",
		"thread_resolved must emit when final phase triggers"
	)


func test_thread_resolved_not_emitted_before_final_phase() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	watch_signals(EventBus)
	_system._current_day = 1
	_simulate_visits("cust_res2", 5)  # only phase 0→1, day_range not met
	assert_signal_not_emitted(
		EventBus, "thread_resolved",
		"thread_resolved must not fire on non-final phases"
	)


# ── full thread progression for all four threads ───────────────────────────────


func test_familiar_face_full_progression() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	_system._current_day = 1
	_simulate_visits("ff", 5)
	assert_eq(_system.get_thread_phase("ff", "the_familiar_face"), 1)
	_system._current_day = 20
	_simulate_visits("ff", 1)  # triggers day_range phase
	assert_eq(_system.get_thread_phase("ff", "the_familiar_face"), 2)
	_simulate_visits("ff", 14)  # total 20 visits
	assert_eq(_system.get_thread_phase("ff", "the_familiar_face"), 3)


func test_notebook_critic_full_progression() -> void:
	_setup_with_defs([_CRITIC_DEF])
	_simulate_visits("nc", 3)
	assert_eq(_system.get_thread_phase("nc", "the_notebook_critic"), 1)
	_simulate_purchase("nc", "singles")
	assert_eq(_system.get_thread_phase("nc", "the_notebook_critic"), 2)
	_simulate_visits("nc", 9)  # total 12
	assert_eq(_system.get_thread_phase("nc", "the_notebook_critic"), 3)


func test_vacant_unit_full_progression() -> void:
	_setup_with_defs([_VACANT_UNIT_DEF])
	_system._current_day = 10
	_simulate_visits("vu", 1)
	assert_eq(_system.get_thread_phase("vu", "the_vacant_unit"), 1)
	_simulate_visits("vu", 4)  # total 5
	assert_eq(_system.get_thread_phase("vu", "the_vacant_unit"), 2)
	_system._current_day = 25
	_simulate_visits("vu", 1)
	assert_eq(_system.get_thread_phase("vu", "the_vacant_unit"), 3)


func test_legend_full_progression() -> void:
	_setup_with_defs([_LEGEND_DEF])
	_system._current_day = 14
	_simulate_visits("leg", 1)
	assert_eq(_system.get_thread_phase("leg", "the_legend"), 1)
	_simulate_visits("leg", 2)  # total 3
	assert_eq(_system.get_thread_phase("leg", "the_legend"), 2)
	_system._current_day = 50
	_simulate_visits("leg", 1)
	assert_eq(_system.get_thread_phase("leg", "the_legend"), 3)


# ── save / load ────────────────────────────────────────────────────────────────


func test_save_data_round_trip() -> void:
	_setup_with_defs([_FAMILIAR_FACE_DEF])
	_system._current_day = 20
	_simulate_visits("persist_01", 5)

	var saved: Dictionary = _system.get_save_data()

	var restored: RegularsLogSystem = RegularsLogSystem.new()
	add_child_autofree(restored)
	restored._thread_defs = [_FAMILIAR_FACE_DEF]
	restored._current_day = 20
	restored.load_state(saved)

	assert_eq(
		restored.get_thread_phase("persist_01", "the_familiar_face"),
		_system.get_thread_phase("persist_01", "the_familiar_face"),
		"Restored phase must match original"
	)
	var orig: Dictionary = _system.get_regular("persist_01")
	var rest: Dictionary = restored.get_regular("persist_01")
	assert_eq(
		int(rest.get("visit_count", 0)),
		int(orig.get("visit_count", 0)),
		"Restored visit_count must match"
	)
	assert_eq(
		int(rest.get("last_seen_day", 0)),
		int(orig.get("last_seen_day", 0)),
		"Restored last_seen_day must match"
	)


func test_purchase_history_persists_across_save_load() -> void:
	_setup_with_defs([_CRITIC_DEF])
	_simulate_visits("persist_02", 1)
	_simulate_purchase("persist_02", "singles")

	var saved: Dictionary = _system.get_save_data()
	var restored: RegularsLogSystem = RegularsLogSystem.new()
	add_child_autofree(restored)
	restored._thread_defs = [_CRITIC_DEF]
	restored.load_state(saved)

	var entry: Dictionary = restored.get_regular("persist_02")
	var history: Array = entry.get("purchase_history", []) as Array
	assert_eq(history.size(), 1, "Restored purchase_history must have one entry")
	if not history.is_empty() and history[0] is Dictionary:
		assert_eq(
			str((history[0] as Dictionary).get("category", "")),
			"singles",
			"Restored purchase category must match"
		)
