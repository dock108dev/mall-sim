## GUT tests for ISSUE-015: tournament event mechanic — telegraph, traffic,
## price-spike via PriceResolver, and result_summary on tournament_ended.
extends GutTest

var _seasonal: SeasonalEventSystem


func _make_def(overrides: Dictionary = {}) -> TournamentEventDefinition:
	var t := TournamentEventDefinition.new()
	t.id = overrides.get("id", "test_tourney")
	t.name = overrides.get("name", "Test Tournament")
	t.description = overrides.get("description", "")
	t.card_category = overrides.get("card_category", "singles")
	t.creature_type_focus = overrides.get("creature_type_focus", "fossil")
	t.start_day = overrides.get("start_day", 5)
	t.duration_days = overrides.get("duration_days", 2)
	t.telegraph_days = overrides.get("telegraph_days", 1)
	t.demand_multiplier = overrides.get("demand_multiplier", 1.5)
	t.price_spike_multiplier = overrides.get("price_spike_multiplier", 1.5)
	t.traffic_multiplier = overrides.get("traffic_multiplier", 1.3)
	t.announcement_text = overrides.get("announcement_text", "")
	t.active_text = overrides.get("active_text", "")
	return t


func _make_item(
	category: String = "singles",
	store_type: String = "pocket_creatures",
	tags: Array[StringName] = [],
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_card"
	def.category = category
	def.store_type = store_type
	def.base_price = 10.0
	def.tags = tags
	var inst := ItemInstance.new()
	inst.definition = def
	return inst


func before_each() -> void:
	_seasonal = SeasonalEventSystem.new()
	add_child_autofree(_seasonal)


# ── telegraph_days: fire telegraph N days before start ────────────────────────

func test_tournament_telegraphed_fires_telegraph_days_before_start() -> void:
	var def: TournamentEventDefinition = _make_def({
		"start_day": 10, "telegraph_days": 2,
	})
	_seasonal._tournament_definitions = [def]
	var telegraphed_ids: Array = []
	var cb: Callable = func(tid: String) -> void: telegraphed_ids.append(tid)
	EventBus.tournament_telegraphed.connect(cb)
	_seasonal._on_day_started(8)
	EventBus.tournament_telegraphed.disconnect(cb)
	assert_eq(telegraphed_ids.size(), 1, "Should telegraph on day 8")
	assert_eq(telegraphed_ids[0], "test_tourney")


func test_tournament_telegraphed_not_fired_too_early() -> void:
	var def: TournamentEventDefinition = _make_def({
		"start_day": 10, "telegraph_days": 2,
	})
	_seasonal._tournament_definitions = [def]
	var fired: Array = [false]
	var cb: Callable = func(_tid: String) -> void: fired[0] = true
	EventBus.tournament_telegraphed.connect(cb)
	_seasonal._on_day_started(7)
	EventBus.tournament_telegraphed.disconnect(cb)
	assert_false(fired[0], "Should not telegraph before telegraph window")


func test_tournament_telegraphed_default_one_day_lead() -> void:
	var def: TournamentEventDefinition = _make_def({
		"start_day": 10, "telegraph_days": 1,
	})
	_seasonal._tournament_definitions = [def]
	var fired: Array = [false]
	var cb: Callable = func(_tid: String) -> void: fired[0] = true
	EventBus.tournament_telegraphed.connect(cb)
	_seasonal._on_day_started(9)
	EventBus.tournament_telegraphed.disconnect(cb)
	assert_true(fired[0], "Default 1-day lead should telegraph on start_day - 1")


# ── traffic multiplier active during tournament ───────────────────────────────

func test_traffic_multiplier_active_during_tournament() -> void:
	var def: TournamentEventDefinition = _make_def({
		"start_day": 1, "duration_days": 2, "traffic_multiplier": 1.3,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 1,
	})
	assert_almost_eq(
		_seasonal.get_traffic_multiplier(), 1.3, 0.001,
		"Traffic multiplier should be 1.3 while tournament active"
	)


func test_traffic_multiplier_not_applied_when_no_tournament() -> void:
	assert_almost_eq(
		_seasonal.get_traffic_multiplier(), 1.0, 0.001,
		"No traffic boost when no tournament is active"
	)


func test_traffic_multiplier_inactive_after_tournament_expires() -> void:
	var def: TournamentEventDefinition = _make_def({
		"start_day": 1, "duration_days": 2, "traffic_multiplier": 1.3,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._on_day_started(0)
	_seasonal._on_day_started(1)
	_seasonal._on_day_started(2)
	_seasonal._on_day_started(3)
	assert_almost_eq(
		_seasonal.get_traffic_multiplier(), 1.0, 0.001,
		"Traffic multiplier back to 1.0 after tournament expires on day 3"
	)


# ── price_spike_multiplier via PriceResolver ──────────────────────────────────

func test_price_spike_multiplier_for_focused_creature_type() -> void:
	var def: TournamentEventDefinition = _make_def({
		"creature_type_focus": "fossil",
		"price_spike_multiplier": 1.5,
		"start_day": 1,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 1,
	})
	var item: ItemInstance = _make_item(
		"singles", "pocket_creatures",
		[&"fossil"]
	)
	assert_almost_eq(
		_seasonal.get_tournament_price_spike_multiplier(item),
		1.5, 0.001,
		"Price spike multiplier applies to item with matching creature_type_focus tag"
	)


func test_price_spike_no_effect_on_non_focused_type() -> void:
	var def: TournamentEventDefinition = _make_def({
		"creature_type_focus": "fossil",
		"price_spike_multiplier": 1.5,
		"start_day": 1,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 1,
	})
	var item: ItemInstance = _make_item(
		"singles", "pocket_creatures",
		[&"base_set"]
	)
	assert_almost_eq(
		_seasonal.get_tournament_price_spike_multiplier(item),
		1.0, 0.001,
		"Price spike should not apply to item without matching tag"
	)


func test_price_spike_falls_back_to_card_category() -> void:
	var def: TournamentEventDefinition = _make_def({
		"creature_type_focus": "",
		"card_category": "singles",
		"price_spike_multiplier": 1.4,
		"start_day": 1,
	})
	_seasonal._active_tournaments.append({
		"definition": def, "start_day": 1,
	})
	var item: ItemInstance = _make_item("singles", "pocket_creatures")
	assert_almost_eq(
		_seasonal.get_tournament_price_spike_multiplier(item),
		1.4, 0.001,
		"Price spike falls back to card_category match when creature_type_focus empty"
	)


# ── 2-day tournament golden path ──────────────────────────────────────────────
# tournament starts day 1, duration 2 → active days 1 & 2, expires day 3

func test_two_day_tournament_multiplier_active_day_1() -> void:
	var def: TournamentEventDefinition = _make_def({
		"id": "golden_tourney",
		"start_day": 1,
		"duration_days": 2,
		"telegraph_days": 1,
		"creature_type_focus": "fossil",
		"price_spike_multiplier": 1.5,
		"traffic_multiplier": 1.3,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._on_day_started(0)
	_seasonal._on_day_started(1)
	var item: ItemInstance = _make_item(
		"singles", "pocket_creatures", [&"fossil"]
	)
	assert_almost_eq(
		_seasonal.get_tournament_price_spike_multiplier(item),
		1.5, 0.001,
		"Price spike multiplier active on day 1"
	)
	assert_almost_eq(
		_seasonal.get_traffic_multiplier(), 1.3, 0.001,
		"Traffic multiplier active on day 1"
	)


func test_two_day_tournament_multiplier_inactive_day_3() -> void:
	var def: TournamentEventDefinition = _make_def({
		"id": "golden_tourney",
		"start_day": 1,
		"duration_days": 2,
		"telegraph_days": 1,
		"creature_type_focus": "fossil",
		"price_spike_multiplier": 1.5,
		"traffic_multiplier": 1.3,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._on_day_started(0)
	_seasonal._on_day_started(1)
	_seasonal._on_day_started(2)
	_seasonal._on_day_started(3)
	var item: ItemInstance = _make_item(
		"singles", "pocket_creatures", [&"fossil"]
	)
	assert_almost_eq(
		_seasonal.get_tournament_price_spike_multiplier(item),
		1.0, 0.001,
		"Price spike multiplier inactive on day 3"
	)
	assert_almost_eq(
		_seasonal.get_traffic_multiplier(), 1.0, 0.001,
		"Traffic multiplier inactive on day 3"
	)


func test_two_day_tournament_result_summary_emitted_after_day_2() -> void:
	var def: TournamentEventDefinition = _make_def({
		"id": "golden_tourney",
		"start_day": 1,
		"duration_days": 2,
		"telegraph_days": 1,
		"creature_type_focus": "fossil",
		"price_spike_multiplier": 1.5,
		"traffic_multiplier": 1.3,
	})
	_seasonal._tournament_definitions = [def]
	_seasonal._on_day_started(0)
	_seasonal._on_day_started(1)
	_seasonal._on_day_started(2)

	var got_id: Array = [""]
	var got_summary: Array = [{}]
	var cb: Callable = func(tid: String, rs: Dictionary) -> void:
		got_id[0] = tid
		got_summary[0] = rs
	EventBus.tournament_ended.connect(cb)
	# day_ended(2) fires tournament_ended for a 2-day tournament (start=1, dur=2)
	EventBus.day_ended.emit(2)
	EventBus.tournament_ended.disconnect(cb)

	assert_eq(got_id[0], "golden_tourney", "tournament_ended should fire after day 2")
	assert_false(
		got_summary[0].is_empty(), "result_summary should not be empty"
	)
	assert_eq(
		got_summary[0].get("tournament_id", ""),
		"golden_tourney"
	)
	assert_almost_eq(
		float(got_summary[0].get("price_spike_multiplier", 0.0)),
		1.5, 0.001
	)
	assert_almost_eq(
		float(got_summary[0].get("traffic_multiplier", 0.0)),
		1.3, 0.001
	)


# ── no stub methods ───────────────────────────────────────────────────────────

func test_get_tournament_price_spike_multiplier_returns_1_when_no_active() -> void:
	var item: ItemInstance = _make_item()
	assert_eq(
		_seasonal.get_tournament_price_spike_multiplier(item), 1.0
	)


func test_get_tournament_price_spike_multiplier_returns_1_for_null() -> void:
	assert_eq(
		_seasonal.get_tournament_price_spike_multiplier(null), 1.0
	)
