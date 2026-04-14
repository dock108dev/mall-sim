## Integration test: day_started → RandomEventSystem event rolls → random_event_triggered + toast_requested chain.
extends GutTest

const STORE_ID: StringName = &"retro_games"
const STARTING_CASH: float = 500.0

var _random_event_system: RandomEventSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem

var _saved_store_id: StringName
var _saved_data_loader: DataLoader

var _triggered_events: Array[Dictionary] = []
var _toast_requests: Array[Dictionary] = []
var _emit_order: Array[String] = []


func _make_event_def(overrides: Dictionary = {}) -> RandomEventDefinition:
	var d := RandomEventDefinition.new()
	d.id = overrides.get("id", "test_celebrity")
	d.name = overrides.get("name", "Test Celebrity Event")
	d.description = "Integration test deterministic event"
	d.effect_type = overrides.get("effect_type", "celebrity_visit")
	d.duration_days = overrides.get("duration_days", 1)
	d.severity = "high"
	d.cooldown_days = overrides.get("cooldown_days", 0)
	d.probability_weight = overrides.get("probability_weight", 100.0)
	d.notification_text = "Test celebrity is at the food court!"
	d.resolution_text = "The celebrity left via the service entrance."
	d.toast_message = overrides.get(
		"toast_message", "Test toast: crowds are flooding the mall!"
	)
	d.time_window_start = -1
	d.time_window_end = -1
	return d


func _seed_single_event(def: RandomEventDefinition) -> void:
	_random_event_system._event_definitions = [def]
	_random_event_system._active_event = {}
	_random_event_system._cooldowns = {}
	_random_event_system._daily_rolled = false


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	GameManager.current_store_id = STORE_ID

	var data_loader := DataLoader.new()
	add_child_autofree(data_loader)
	data_loader.load_all_content()
	GameManager.data_loader = data_loader

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_reputation_system = ReputationSystem.new()
	add_child_autofree(_reputation_system)
	_reputation_system.initialize_store(String(STORE_ID))

	_random_event_system = RandomEventSystem.new()
	add_child_autofree(_random_event_system)
	_random_event_system.initialize(
		data_loader, _inventory_system, _reputation_system, _economy_system
	)

	_triggered_events = []
	_toast_requests = []
	_emit_order = []

	EventBus.random_event_triggered.connect(_on_random_event_triggered)
	EventBus.toast_requested.connect(_on_toast_requested)


func after_each() -> void:
	if EventBus.random_event_triggered.is_connected(_on_random_event_triggered):
		EventBus.random_event_triggered.disconnect(_on_random_event_triggered)
	if EventBus.toast_requested.is_connected(_on_toast_requested):
		EventBus.toast_requested.disconnect(_on_toast_requested)
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


func _on_random_event_triggered(
	event_id: StringName, store_id: StringName, effect: Dictionary
) -> void:
	_triggered_events.append({
		"event_id": event_id,
		"store_id": store_id,
		"effect": effect,
	})
	_emit_order.append("triggered")


func _on_toast_requested(
	message: String, category: StringName, duration: float
) -> void:
	_toast_requests.append({
		"message": message,
		"category": category,
		"duration": duration,
	})
	_emit_order.append("toast")


# ── Scenario A: day_started triggers event and toast ─────────────────────────


func test_day_started_triggers_random_event_triggered() -> void:
	_seed_single_event(_make_event_def())

	EventBus.day_started.emit(1)

	assert_eq(
		_triggered_events.size(), 1,
		"random_event_triggered fires once after day_started"
	)
	assert_eq(
		_triggered_events[0]["event_id"],
		StringName("test_celebrity"),
		"event_id matches the seeded event"
	)


func test_day_started_emits_toast_requested() -> void:
	_seed_single_event(_make_event_def())

	EventBus.day_started.emit(1)

	assert_eq(
		_toast_requests.size(), 1,
		"toast_requested fires once when an event is triggered"
	)


# ── Scenario B: toast payload correctness ────────────────────────────────────


func test_toast_category_is_random_event() -> void:
	_seed_single_event(_make_event_def())

	EventBus.day_started.emit(1)

	assert_eq(_toast_requests.size(), 1, "toast fires")
	assert_eq(
		_toast_requests[0]["category"],
		&"random_event",
		"toast category is StringName random_event"
	)


func test_toast_duration_is_four_seconds() -> void:
	_seed_single_event(_make_event_def())

	EventBus.day_started.emit(1)

	assert_eq(_toast_requests.size(), 1, "toast fires")
	assert_almost_eq(
		_toast_requests[0]["duration"],
		4.0,
		0.001,
		"toast duration is 4.0 seconds"
	)


func test_toast_message_matches_event_definition() -> void:
	const EXPECTED_MSG: String = "Crowds are gathering — something huge just happened!"
	_seed_single_event(_make_event_def({"toast_message": EXPECTED_MSG}))

	EventBus.day_started.emit(1)

	assert_eq(_toast_requests.size(), 1, "toast fires")
	assert_eq(
		_toast_requests[0]["message"],
		EXPECTED_MSG,
		"toast message matches event definition toast_message field"
	)


# ── Scenario C: toast message sourced from random_events.json ─────────────────


func test_toast_message_matches_json_definition() -> void:
	var json_def: RandomEventDefinition = null
	for ev: RandomEventDefinition in _random_event_system._event_definitions:
		if ev.id == "d_list_celebrity_sighting":
			json_def = ev
			break
	if not json_def:
		pending("d_list_celebrity_sighting not found in random_events.json")
		return
	json_def.probability_weight = 100.0
	_seed_single_event(json_def)

	EventBus.day_started.emit(1)

	assert_eq(_toast_requests.size(), 1, "toast fires")
	assert_eq(
		_toast_requests[0]["message"],
		json_def.toast_message,
		"toast message matches the toast_message field from random_events.json"
	)


# ── Scenario D: signal order — triggered fires before toast ──────────────────


func test_random_event_triggered_fires_before_toast_requested() -> void:
	_seed_single_event(_make_event_def())

	EventBus.day_started.emit(1)

	assert_eq(_emit_order.size(), 2, "both signals fired")
	assert_eq(
		_emit_order[0],
		"triggered",
		"random_event_triggered fires first"
	)
	assert_eq(
		_emit_order[1],
		"toast",
		"toast_requested fires after random_event_triggered"
	)


# ── Scenario E: no event triggered → no toast ────────────────────────────────


func test_no_toast_when_definitions_empty() -> void:
	_seed_single_event(_make_event_def())
	_random_event_system._event_definitions = []

	EventBus.day_started.emit(1)

	assert_eq(
		_triggered_events.size(), 0,
		"no event triggered when definitions list is empty"
	)
	assert_eq(
		_toast_requests.size(), 0,
		"no toast fires when no events are defined"
	)


func test_no_toast_when_all_events_on_cooldown() -> void:
	var def := _make_event_def({"cooldown_days": 5})
	_seed_single_event(def)
	_random_event_system._cooldowns = {def.id: 3}

	EventBus.day_started.emit(1)

	assert_eq(
		_triggered_events.size(), 0,
		"no event triggered when the only event is on cooldown"
	)
	assert_eq(
		_toast_requests.size(), 0,
		"no toast fires when all events are on cooldown"
	)
