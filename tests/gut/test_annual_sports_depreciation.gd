## Tests for the annual_sports decay profile in MarketValueSystem and the
## trade-in market_factor wiring on TradeInSystem.
##
## Acceptance targets (from the issue spec):
##   - 18% annual decay applies when no newer edition exists.
##   - 40% floor + 30% active rate when a newer edition exists in the catalog.
##   - $60 title aged 1yr with newer edition produces ~$42 face value.
##   - Trade-in offer for an annual_sports title carries the depreciation
##     through `market_factor` without changes to TradeInPanel.
##   - sports_regular gets a "new edition is out" dialogue line in that case.
extends GutTest


var _system: MarketValueSystem
var _inventory: InventorySystem
var _market_event: MarketEventSystem
var _seasonal_event: SeasonalEventSystem


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)

	_seasonal_event = SeasonalEventSystem.new()
	add_child_autofree(_seasonal_event)

	_system = MarketValueSystem.new()
	add_child_autofree(_system)
	_system.initialize(_inventory, _market_event, _seasonal_event)


func _make_sports_def(
	id: String, edition_year: int, series: StringName
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = id
	def.base_price = 60.0
	def.rarity = "common"
	def.category = &"cartridges"
	def.store_type = &"retro_games"
	def.decay_profile = &"annual_sports"
	def.edition_year = edition_year
	def.edition_series = series
	return def


# ── decay-profile dispatch ───────────────────────────────────────────────────


func test_unknown_profile_returns_one() -> void:
	var def := _make_sports_def("nostandard", 0, &"")
	def.decay_profile = &"collector_market"
	var mod: float = _system.get_time_modifier(def, 1)
	assert_almost_eq(mod, 1.0, 0.001)


func test_standard_profile_no_depreciation_when_flag_unset() -> void:
	var def := _make_sports_def("std", 0, &"")
	def.decay_profile = &"standard"
	def.depreciates = false
	var mod: float = _system.get_time_modifier(def, 30)
	assert_almost_eq(mod, 1.0, 0.001)


# ── annual_sports — no newer edition (standard yearly decay) ─────────────────


func test_annual_sports_current_edition_full_price() -> void:
	# age == 0 → no decay even on annual_sports profile.
	_system._current_year = 1994
	var def := _make_sports_def("gridiron_94", 1994, &"gridiron")
	_system.register_edition(def.edition_series, def.edition_year)
	var mod: float = _system.get_time_modifier(def, 1)
	assert_almost_eq(mod, 1.0, 0.001)


func test_annual_sports_one_year_old_no_newer_edition() -> void:
	# age == 1, no newer registered → standard 18% decay → 0.82.
	_system._current_year = 1995
	var def := _make_sports_def("gridiron_94", 1994, &"gridiron")
	_system.register_edition(def.edition_series, def.edition_year)
	var mod: float = _system.get_time_modifier(def, 365)
	assert_almost_eq(mod, 0.82, 0.001)


func test_annual_sports_three_years_old_no_newer_edition() -> void:
	# age == 3, no newer → 1 - 3*0.18 = 0.46 → $60 * 0.46 = $27.60.
	_system._current_year = 1997
	var def := _make_sports_def("gridiron_94", 1994, &"gridiron")
	_system.register_edition(def.edition_series, def.edition_year)
	var mod: float = _system.get_time_modifier(def, 365 * 3)
	assert_almost_eq(mod, 0.46, 0.001)
	assert_almost_eq(60.0 * mod, 27.60, 0.01)


# ── annual_sports — newer edition exists (step-function drop) ────────────────


func test_annual_sports_one_year_old_with_newer_edition_produces_42_dollars() -> void:
	# Canonical regression target from the issue spec:
	#   $60 base, 1 year old, newer edition in catalog → ~$42 (70% of base).
	_system._current_year = 1995
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	var newer := _make_sports_def("gridiron_95", 1995, &"gridiron")
	_system.register_edition(older.edition_series, older.edition_year)
	_system.register_edition(newer.edition_series, newer.edition_year)
	var mod: float = _system.get_time_modifier(older, 365)
	# 1 - 1*0.30 = 0.70; floor is 0.40 (not engaged at age 1).
	assert_almost_eq(mod, 0.70, 0.001)
	assert_almost_eq(older.base_price * mod, 42.0, 0.01)


func test_annual_sports_two_years_old_with_newer_edition_hits_floor() -> void:
	# age == 2, newer exists → 1 - 2*0.30 = 0.40, exactly at the fresh floor.
	_system._current_year = 1996
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	var newer := _make_sports_def("gridiron_96", 1996, &"gridiron")
	_system.register_edition(older.edition_series, older.edition_year)
	_system.register_edition(newer.edition_series, newer.edition_year)
	var mod: float = _system.get_time_modifier(older, 365 * 2)
	assert_almost_eq(mod, 0.40, 0.001)


func test_annual_sports_collectible_recovery_at_five_years() -> void:
	# age == 5, no newer → max(0.15, 1-5*0.18=0.10) = 0.15;
	# collectible bump * 1.35 → 0.2025.
	_system._current_year = 1999
	var def := _make_sports_def("gridiron_94", 1994, &"gridiron")
	_system.register_edition(def.edition_series, def.edition_year)
	var mod: float = _system.get_time_modifier(def, 365 * 5)
	assert_almost_eq(mod, 0.15 * 1.35, 0.001)


# ── register_edition idempotency ─────────────────────────────────────────────


func test_register_edition_keeps_max_year() -> void:
	_system.register_edition(&"gridiron", 1994)
	_system.register_edition(&"gridiron", 1992)
	_system.register_edition(&"gridiron", 1995)
	# Underlying registry should hold 1995, not 1992.
	_system._current_year = 1995
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	# 1995 > 1994 → newer exists → active rate applies.
	var mod: float = _system.get_time_modifier(older, 365)
	assert_almost_eq(mod, 0.70, 0.001)


func test_register_edition_empty_series_noop() -> void:
	_system.register_edition(&"", 1995)
	# No-op: an unset-series item with edition_year does not look up anything.
	var def := _make_sports_def("nope", 1994, &"")
	_system._current_year = 1995
	# Empty series → no newer edition possible → standard decay.
	var mod: float = _system.get_time_modifier(def, 365)
	assert_almost_eq(mod, 0.82, 0.001)


# ── calculate_item_value uses decay multiplier for annual_sports ─────────────


func test_calculate_item_value_includes_annual_sports_decay() -> void:
	_system._current_year = 1995
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	var newer := _make_sports_def("gridiron_95", 1995, &"gridiron")
	_system.register_edition(older.edition_series, older.edition_year)
	_system.register_edition(newer.edition_series, newer.edition_year)
	# Pretend the day rolled over a year so _current_year drives the formula.
	_system._current_day = 365
	var item: ItemInstance = ItemInstance.create_from_definition(older, "mint")
	var value: float = _system.calculate_item_value(item)
	# rarity=common (1.0) × condition=mint (1.0) × decay (0.70) on $60 = $42.
	# All other multipliers are inert in this fixture.
	assert_almost_eq(value, 42.0, 0.01)


# ── trade-in path picks up the depreciation ──────────────────────────────────


class _StubInventorySystem:
	extends Node
	func create_item(
		definition_id: String, condition: String, acquired_price: float
	) -> ItemInstance:
		var def: ItemDefinition = ItemDefinition.new()
		def.id = definition_id
		def.item_name = "Stub Item"
		def.base_price = 60.0
		return ItemInstance.create(def, condition, 0, acquired_price)


class _StubEconomySystem:
	extends Node
	func deduct_cash(_amount: float, _reason: String) -> bool:
		return true


class _StubReputationSystem:
	extends Node
	var score: float = 0.0
	func get_reputation(_store_id: String = "") -> float:
		return score


func test_trade_in_offer_reflects_annual_sports_depreciation() -> void:
	_system._current_year = 1995
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	var newer := _make_sports_def("gridiron_95", 1995, &"gridiron")
	_system.register_edition(older.edition_series, older.edition_year)
	_system.register_edition(newer.edition_series, newer.edition_year)

	var trade_in := TradeInSystem.new()
	add_child_autofree(trade_in)
	trade_in.inventory_system = _StubInventorySystem.new()
	trade_in.economy_system = _StubEconomySystem.new()
	trade_in.reputation_system = _StubReputationSystem.new()
	trade_in.market_value_system = _system
	trade_in.current_state = TradeInSystem.State.IDLE

	trade_in.begin_interaction(
		"cust_1", older.id, older, &"sports_regular"
	)
	trade_in.confirm_platform()
	trade_in.select_condition("good")
	trade_in.appraise()

	# compute_offer: 60.0 × (0.40 cond_mult + 0 trust) × 0.70 market_factor
	#              = 16.80; snapped to 0.25 step → 16.75.
	# Without the depreciation hook the same call would land at 24.00.
	var offer: float = trade_in.current_offer
	assert_almost_eq(offer, 16.75, 0.001)
	assert_lt(offer, 24.0,
		"annual_sports trade-in must not pay face-value with newer edition out")


func test_sports_regular_dialogue_line_when_newer_edition_out() -> void:
	_system._current_year = 1995
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	var newer := _make_sports_def("gridiron_95", 1995, &"gridiron")
	_system.register_edition(older.edition_series, older.edition_year)
	_system.register_edition(newer.edition_series, newer.edition_year)

	var trade_in := TradeInSystem.new()
	add_child_autofree(trade_in)
	trade_in.market_value_system = _system
	trade_in.current_state = TradeInSystem.State.IDLE
	trade_in.inventory_system = _StubInventorySystem.new()
	trade_in.economy_system = _StubEconomySystem.new()
	trade_in.reputation_system = _StubReputationSystem.new()

	trade_in.begin_interaction(
		"cust_1", older.id, older, &"sports_regular"
	)
	var line: String = trade_in.get_customer_dialogue_line()
	assert_ne(line, "",
		"sports_regular must surface a dialogue line for depreciated annual_sports")


func test_dialogue_line_silent_for_non_sports_archetype() -> void:
	_system._current_year = 1995
	var older := _make_sports_def("gridiron_94", 1994, &"gridiron")
	_system.register_edition(&"gridiron", 1995)

	var trade_in := TradeInSystem.new()
	add_child_autofree(trade_in)
	trade_in.market_value_system = _system
	trade_in.current_state = TradeInSystem.State.IDLE
	trade_in.inventory_system = _StubInventorySystem.new()
	trade_in.economy_system = _StubEconomySystem.new()
	trade_in.reputation_system = _StubReputationSystem.new()

	trade_in.begin_interaction(
		"cust_2", older.id, older, &"collector"
	)
	assert_eq(trade_in.get_customer_dialogue_line(), "")
