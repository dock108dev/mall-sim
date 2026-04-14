## Tests for tournament event scheduling and demand effects in SeasonalEventSystem.
extends GutTest

var _seasonal: SeasonalEventSystem


func _tournament_def(o: Dictionary = {}) -> TournamentEventDefinition:
	var t := TournamentEventDefinition.new()
	t.id = o.get("id", "test_tournament")
	t.name = o.get("name", "Test Tournament")
	t.description = o.get("description", "A test tournament")
	t.card_category = o.get("card_category", "singles")
	t.start_day = o.get("start_day", 10)
	t.duration_days = o.get("duration_days", 3)
	t.demand_multiplier = o.get("demand_multiplier", 1.5)
	t.announcement_text = o.get("announce", "Tournament incoming!")
	t.active_text = o.get("active", "Tournament active!")
	return t


func _mock_item(
	category: String = "singles",
	store_type: String = "pocket_creatures"
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_item"
	def.category = category
	def.store_type = store_type
	def.base_price = 10.0
	var inst := ItemInstance.new()
	inst.definition = def
	return inst


func before_each() -> void:
	_seasonal = SeasonalEventSystem.new()
	add_child_autofree(_seasonal)


# --- Tournament announcement on day before start ---

func test_tournament_announced_day_before_start() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10,
	})
	_seasonal._tournament_definitions = [def]
	var fired: bool = false
	var got_id: String = ""
	var cb: Callable = func(id: String) -> void:
		fired = true
		got_id = id
	EventBus.tournament_event_announced.connect(cb)
	_seasonal._on_day_started(9)
	assert_true(fired, "Announced signal should fire on day 9")
	assert_eq(got_id, "test_tournament")
	assert_eq(_seasonal._announced_tournaments.size(), 1)
	assert_eq(_seasonal._active_tournaments.size(), 0)
	EventBus.tournament_event_announced.disconnect(cb)


func test_tournament_not_announced_too_early() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._on_day_started(7)
	assert_eq(_seasonal._announced_tournaments.size(), 0)


# --- Tournament activation on start day ---

func test_tournament_activates_on_start_day() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10, "duration_days": 3,
	})
	_seasonal._tournament_definitions = [def]
	var got_id: String = ""
	var cb: Callable = func(id: String) -> void:
		got_id = id
	EventBus.tournament_event_started.connect(cb)
	_seasonal._on_day_started(9)
	_seasonal._on_day_started(10)
	assert_eq(got_id, "test_tournament")
	assert_eq(_seasonal._active_tournaments.size(), 1)
	assert_eq(_seasonal._announced_tournaments.size(), 0)
	EventBus.tournament_event_started.disconnect(cb)


# --- Tournament expiry after duration ---

func test_tournament_expires_after_duration() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10, "duration_days": 3,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 10,
	})
	var got_id: String = ""
	var cb: Callable = func(id: String) -> void:
		got_id = id
	EventBus.tournament_event_ended.connect(cb)
	_seasonal._on_day_started(12)
	assert_eq(
		_seasonal._active_tournaments.size(), 1,
		"Still active on day 12"
	)
	_seasonal._on_day_started(13)
	assert_eq(
		_seasonal._active_tournaments.size(), 0,
		"Expired on day 13"
	)
	assert_eq(got_id, "test_tournament")
	EventBus.tournament_event_ended.disconnect(cb)


# --- Tournament demand multiplier ---

func test_tournament_demand_multiplier_during_active() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"card_category": "singles", "demand_multiplier": 1.5,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 10,
	})
	var item: ItemInstance = _mock_item("singles")
	assert_almost_eq(
		_seasonal.get_tournament_demand_multiplier(item),
		1.5, 0.001
	)


func test_tournament_demand_no_effect_wrong_category() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"card_category": "singles", "demand_multiplier": 1.5,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 10,
	})
	var item: ItemInstance = _mock_item("booster_packs")
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(item), 1.0
	)


func test_tournament_demand_no_effect_wrong_store() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"card_category": "singles", "demand_multiplier": 1.5,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 10,
	})
	var item: ItemInstance = _mock_item("singles", "sports")
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(item), 1.0
	)


func test_tournament_demand_no_active() -> void:
	var item: ItemInstance = _mock_item("singles")
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(item), 1.0
	)


func test_tournament_demand_null_item() -> void:
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(null), 1.0
	)


# --- Full lifecycle: announce -> activate -> expire ---

func test_tournament_full_lifecycle() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10, "duration_days": 2,
		"card_category": "singles", "demand_multiplier": 1.8,
	})
	_seasonal._tournament_definitions = [def]
	var item: ItemInstance = _mock_item("singles")

	_seasonal._on_day_started(8)
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(item), 1.0,
		"No effect before announcement"
	)

	_seasonal._on_day_started(9)
	assert_eq(
		_seasonal._announced_tournaments.size(), 1,
		"Announced on day 9"
	)
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(item), 1.0,
		"No demand effect during announcement"
	)

	_seasonal._on_day_started(10)
	assert_eq(
		_seasonal._active_tournaments.size(), 1,
		"Active on day 10"
	)
	assert_almost_eq(
		_seasonal.get_tournament_demand_multiplier(item),
		1.8, 0.001,
		"Demand multiplied during tournament"
	)

	_seasonal._on_day_started(11)
	assert_almost_eq(
		_seasonal.get_tournament_demand_multiplier(item),
		1.8, 0.001,
		"Still active on day 11"
	)

	_seasonal._on_day_started(12)
	assert_eq(
		_seasonal._active_tournaments.size(), 0,
		"Expired on day 12"
	)
	assert_eq(
		_seasonal.get_tournament_demand_multiplier(item), 1.0,
		"Demand normalized after tournament"
	)


# --- No duplicate announcement ---

func test_tournament_no_duplicate_announcement() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._announced_tournaments.append({
		"definition": def, "announced_day": 9,
	})
	_seasonal._check_for_new_tournaments(9)
	assert_eq(_seasonal._announced_tournaments.size(), 1)


func test_tournament_no_announce_if_active() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 10,
	})
	_seasonal._check_for_new_tournaments(9)
	assert_eq(_seasonal._announced_tournaments.size(), 0)


# --- Overlap validation ---

func test_validate_no_overlap_different_categories() -> void:
	var a: TournamentEventDefinition = _tournament_def({
		"id": "a", "card_category": "singles",
		"start_day": 10, "duration_days": 5,
	})
	var b: TournamentEventDefinition = _tournament_def({
		"id": "b", "card_category": "booster_packs",
		"start_day": 12, "duration_days": 3,
	})
	_seasonal._tournament_definitions = [a, b]
	_seasonal._validate_tournament_schedule()


func test_validate_no_overlap_same_category_no_conflict() -> void:
	var a: TournamentEventDefinition = _tournament_def({
		"id": "a", "card_category": "singles",
		"start_day": 10, "duration_days": 3,
	})
	var b: TournamentEventDefinition = _tournament_def({
		"id": "b", "card_category": "singles",
		"start_day": 15, "duration_days": 3,
	})
	_seasonal._tournament_definitions = [a, b]
	_seasonal._validate_tournament_schedule()


# --- Save/load round-trip ---

func test_tournament_save_load_roundtrip() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"id": "tourney_a", "start_day": 15,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 15,
	})
	_seasonal._announced_tournaments.append({
		"definition": def, "announced_day": 14,
	})
	var save: Dictionary = _seasonal.get_save_data()
	var rest: SeasonalEventSystem = SeasonalEventSystem.new()
	add_child_autofree(rest)
	rest._tournament_definitions = [def]
	rest.load_save_data(save)
	assert_eq(rest._active_tournaments.size(), 1)
	assert_eq(rest._announced_tournaments.size(), 1)
	assert_eq(
		rest._active_tournaments[0].get("start_day", -1), 15
	)
	var rd: TournamentEventDefinition = (
		rest._active_tournaments[0].get("definition", null)
		as TournamentEventDefinition
	)
	assert_eq(rd.id, "tourney_a")


func test_tournament_load_skips_unknown() -> void:
	_seasonal._tournament_definitions = []
	_seasonal.load_save_data({
		"active_tournaments": [
			{"definition_id": "nonexistent", "start_day": 1},
		],
		"announced_tournaments": [],
	})
	assert_eq(_seasonal._active_tournaments.size(), 0)


# --- Notification text ---

func test_tournament_announcement_sends_notification() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10,
		"announce": "Tournament incoming: singles cards in demand tomorrow",
	})
	_seasonal._tournament_definitions = [def]
	var got_msg: String = ""
	var cb: Callable = func(msg: String) -> void:
		got_msg = msg
	EventBus.notification_requested.connect(cb)
	_seasonal._on_day_started(9)
	assert_eq(
		got_msg,
		"Tournament incoming: singles cards in demand tomorrow"
	)
	EventBus.notification_requested.disconnect(cb)


func test_tournament_active_sends_notification() -> void:
	var def: TournamentEventDefinition = _tournament_def({
		"start_day": 10,
		"active": "Tournament is live!",
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._on_day_started(9)
	var got_msg: String = ""
	var cb: Callable = func(msg: String) -> void:
		got_msg = msg
	EventBus.notification_requested.connect(cb)
	_seasonal._on_day_started(10)
	assert_eq(got_msg, "Tournament is live!")
	EventBus.notification_requested.disconnect(cb)
