## Integration test: difficulty change mid-game → OrderSystem recalculates pending delivery times.
extends GutTest

const STORE_ID: StringName = &"retro_games"
## Common-rarity item available at SPECIALTY tier catalog.
const ITEM_ID: StringName = &"retro_plumber_world_ss_loose"
const STARTING_CASH: float = 5000.0
const SPECIALTY_TIER: OrderSystem.SupplierTier = OrderSystem.SupplierTier.SPECIALTY
## Normal (1.0×): roundi(2 × 1.00) = 2 days.
const SPECIALTY_NORMAL_DAYS: int = 2
## Hard (1.30×): roundi(2 × 1.30) = roundi(2.60) = 3 days.
const SPECIALTY_HARD_DAYS: int = 3
## Easy (0.80×): roundi(2 × 0.80) = roundi(1.60) = 2 days.
const SPECIALTY_EASY_DAYS: int = 2
## Tier indices from difficulty_config.json array order: easy=0, normal=1, hard=2.
const TIER_INDEX_EASY: int = 0
const TIER_INDEX_NORMAL: int = 1
const TIER_INDEX_HARD: int = 2

var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _time_system: TimeSystem
var _data_loader: DataLoader

var _saved_store_id: StringName
var _saved_data_loader: DataLoader
var _saved_tier: StringName

var _difficulty_signals: Array[Dictionary] = []


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader
	_saved_tier = DifficultySystem.get_current_tier_id()
	_difficulty_signals = []

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = STORE_ID

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()
	## Sync to GameManager so delivery_day arithmetic matches current session day.
	_time_system.current_day = GameManager.current_day

	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory_system, null, null)

	## Start each test at Normal difficulty without emitting difficulty_changed.
	DifficultySystem.set_tier(&"normal")


func after_each() -> void:
	if EventBus.difficulty_changed.is_connected(_on_difficulty_changed):
		EventBus.difficulty_changed.disconnect(_on_difficulty_changed)
	DifficultySystem.set_tier(_saved_tier)
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader


func _on_difficulty_changed(old_tier: int, new_tier: int) -> void:
	_difficulty_signals.append({"old_tier": old_tier, "new_tier": new_tier})


## Returns the delivery_day of the first pending order, or -1 if none.
func _get_first_order_delivery_day() -> int:
	var orders: Array[Dictionary] = _order_system.get_pending_orders()
	if orders.is_empty():
		return -1
	return int(orders[0].get("delivery_day", -1))


# ── Scenario A: Normal → Hard recalculates in-flight delivery times ───────────


func test_scenario_a_initial_delivery_at_normal() -> void:
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	assert_eq(
		_get_first_order_delivery_day(),
		GameManager.current_day + SPECIALTY_NORMAL_DAYS,
		"At Normal, SPECIALTY order delivery = current_day + 2"
	)


func test_scenario_a_hard_upgrade_extends_delivery_to_three_days() -> void:
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	DifficultySystem.apply_difficulty_change(&"hard")
	assert_eq(
		_get_first_order_delivery_day(),
		GameManager.current_day + SPECIALTY_HARD_DAYS,
		"Switching to Hard recalculates in-flight SPECIALTY order from 2 to 3 days"
	)


func test_scenario_a_pending_order_count_preserved_after_upgrade() -> void:
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	DifficultySystem.apply_difficulty_change(&"hard")
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Recalculation must not add or remove pending orders"
	)


# ── Scenario B: Normal → Easy downgrade — minimum 1-day delivery guard ────────
# Easy multiplier = 0.80; roundi(2 × 0.80) = 2. The maxi(1, …) guard ensures
# the result never falls below 1 even if a future config lowers the multiplier.


func test_scenario_b_easy_downgrade_delivery_never_below_one_day() -> void:
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	DifficultySystem.apply_difficulty_change(&"easy")
	assert_gte(
		_get_first_order_delivery_day(),
		GameManager.current_day + 1,
		"Easy recalculation must yield at least current_day + 1 (minimum 1 delivery day)"
	)


func test_scenario_b_easy_downgrade_delivery_day_value() -> void:
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	DifficultySystem.apply_difficulty_change(&"easy")
	assert_eq(
		_get_first_order_delivery_day(),
		GameManager.current_day + SPECIALTY_EASY_DAYS,
		"Easy SPECIALTY: roundi(2 × 0.80) = 2 days"
	)


func test_scenario_b_easy_downgrade_preserves_pending_order_count() -> void:
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	DifficultySystem.apply_difficulty_change(&"easy")
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Easy downgrade must not remove pending orders"
	)


# ── Scenario C: EventBus.difficulty_changed signal payloads ───────────────────
# Tier order in difficulty_config.json: easy(0), normal(1), hard(2).


func test_scenario_c_signal_emitted_exactly_once_on_upgrade() -> void:
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	DifficultySystem.apply_difficulty_change(&"hard")
	assert_eq(
		_difficulty_signals.size(), 1,
		"difficulty_changed must be emitted exactly once on Normal→Hard"
	)


func test_scenario_c_signal_old_tier_is_normal_index() -> void:
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	DifficultySystem.apply_difficulty_change(&"hard")
	assert_eq(
		_difficulty_signals.size(), 1,
		"Signal must be emitted before checking payload"
	)
	assert_eq(
		_difficulty_signals[0]["old_tier"], TIER_INDEX_NORMAL,
		"old_tier must be 1 (normal) when upgrading from Normal"
	)


func test_scenario_c_signal_new_tier_is_hard_index() -> void:
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	DifficultySystem.apply_difficulty_change(&"hard")
	assert_eq(
		_difficulty_signals.size(), 1,
		"Signal must be emitted before checking payload"
	)
	assert_eq(
		_difficulty_signals[0]["new_tier"], TIER_INDEX_HARD,
		"new_tier must be 2 (hard) when upgrading to Hard"
	)


func test_scenario_c_signal_not_emitted_when_tier_unchanged() -> void:
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	DifficultySystem.apply_difficulty_change(&"normal")
	assert_eq(
		_difficulty_signals.size(), 0,
		"difficulty_changed must not emit when tier does not change"
	)


# ── Scenario D: Orders placed AFTER difficulty change use the new lead time ────


func test_scenario_d_new_order_after_hard_uses_hard_delivery_days() -> void:
	DifficultySystem.apply_difficulty_change(&"hard")
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	assert_eq(
		_get_first_order_delivery_day(),
		GameManager.current_day + SPECIALTY_HARD_DAYS,
		"Order placed after switching to Hard must use Hard effective delivery days (3)"
	)


func test_scenario_d_new_order_after_easy_uses_easy_delivery_days() -> void:
	DifficultySystem.apply_difficulty_change(&"easy")
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	assert_eq(
		_get_first_order_delivery_day(),
		GameManager.current_day + SPECIALTY_EASY_DAYS,
		"Order placed after switching to Easy must use Easy effective delivery days (2)"
	)


func test_scenario_d_new_order_after_hard_not_using_normal_days() -> void:
	DifficultySystem.apply_difficulty_change(&"hard")
	_order_system.place_order(STORE_ID, SPECIALTY_TIER, ITEM_ID, 1)
	assert_ne(
		_get_first_order_delivery_day(),
		GameManager.current_day + SPECIALTY_NORMAL_DAYS,
		"Hard delivery days (3) must differ from Normal (2)"
	)
