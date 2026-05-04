## Tests for HUD signal-driven updates, cash animation, and speed cycling.
extends GutTest


var _hud: CanvasLayer
const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)


func before_each() -> void:
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)


func test_cash_updates_on_money_changed() -> void:
	EventBus.money_changed.emit(0.0, 1234.56)
	await get_tree().create_timer(_hud._CASH_COUNT_DURATION + 0.05).timeout
	var label: Label = _hud.get_node("TopBar/CashLabel")
	assert_string_contains(label.text, "1,234.56")


func test_cash_count_animation_target() -> void:
	EventBus.money_changed.emit(0.0, 500.0)
	assert_eq(_hud._target_cash, 500.0)


func test_cash_flash_green_on_income() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	assert_not_null(
		_hud._cash_color_tween,
		"Should create a color flash tween for income"
	)


func test_cash_flash_red_on_expense() -> void:
	EventBus.money_changed.emit(200.0, 100.0)
	assert_not_null(
		_hud._cash_color_tween,
		"Should create a color flash tween for expense"
	)


func test_day_updates_on_day_started() -> void:
	EventBus.day_started.emit(5)
	assert_eq(_hud._current_day, 5)


func test_hour_updates_on_hour_changed() -> void:
	EventBus.hour_changed.emit(14)
	assert_eq(_hud._current_hour, 14)


func test_phase_updates_on_day_phase_changed() -> void:
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_eq(_hud._current_phase, TimeSystem.DayPhase.MIDDAY_RUSH)


func test_speed_display_updates_on_speed_changed() -> void:
	EventBus.speed_changed.emit(3.0)
	var btn: Button = _hud.get_node("TopBar/SpeedButton")
	assert_eq(btn.text, "Fast")


func test_speed_paused_display() -> void:
	EventBus.speed_changed.emit(0.0)
	var btn: Button = _hud.get_node("TopBar/SpeedButton")
	assert_eq(btn.text, "Paused")


func test_speed_cycle_emits_time_speed_requested() -> void:
	var received: Array[int] = []
	EventBus.time_speed_requested.connect(
		func(tier: int) -> void: received.append(tier)
	)
	_hud._current_speed = 1.0
	GameManager.current_state = GameManager.State.GAMEPLAY
	_hud._on_speed_button_pressed()
	assert_eq(received.size(), 1)
	assert_eq(
		received[0], TimeSystem.SpeedTier.FAST,
		"Normal -> Fast in speed cycle"
	)


func test_speed_cycle_wraps_around() -> void:
	var received: Array[int] = []
	EventBus.time_speed_requested.connect(
		func(tier: int) -> void: received.append(tier)
	)
	_hud._current_speed = 6.0
	GameManager.current_state = GameManager.State.GAMEPLAY
	_hud._on_speed_button_pressed()
	assert_eq(
		received[0], TimeSystem.SpeedTier.PAUSED,
		"Ultra -> Paused wraps around"
	)


func test_reputation_updates_on_signal() -> void:
	EventBus.reputation_changed.emit("test_store", 0.0, 80.0)
	assert_eq(_hud._last_reputation, 80.0)


func test_reputation_tier_color_applied_by_display_update() -> void:
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	_hud._update_reputation_display(80.0)
	var expected: Color = Color(1.0, 0.84, 0.0)
	assert_true(
		label.has_theme_color_override("font_color"),
		"Should have font_color override for tier"
	)
	var actual: Color = label.get_theme_color("font_color")
	assert_eq(actual, expected, "Legendary tier should use gold color")


func test_no_direct_system_references() -> void:
	var script: GDScript = _hud.get_script()
	var source: String = script.source_code
	assert_false(
		source.contains("_find_time_system"),
		"HUD should not reference TimeSystem directly"
	)
	assert_false(
		source.contains("_find_economy_system"),
		"HUD should not reference EconomySystem directly"
	)
	assert_false(
		source.contains("_find_reputation_system"),
		"HUD should not reference ReputationSystem directly"
	)
	assert_false(
		source.contains("time_sys.set_speed"),
		"HUD should not call TimeSystem.set_speed directly"
	)


func test_cash_format_with_commas() -> void:
	var formatted: String = _hud._format_cash(1234567.89)
	assert_eq(formatted, "1,234,567.89")


func test_cash_format_zero() -> void:
	var formatted: String = _hud._format_cash(0.0)
	assert_eq(formatted, "0.00")


func test_cash_format_small() -> void:
	var formatted: String = _hud._format_cash(42.50)
	assert_eq(formatted, "42.50")


func test_cash_pulse_scale_income() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	assert_not_null(
		_hud._cash_scale_tween,
		"Should create a scale pulse tween for income"
	)


func test_cash_pulse_scale_expense() -> void:
	EventBus.money_changed.emit(200.0, 100.0)
	assert_not_null(
		_hud._cash_scale_tween,
		"Should create a scale pulse tween for expense"
	)


func test_expense_scale_is_smaller_than_income_scale() -> void:
	assert_gt(
		_hud._CASH_EXPENSE_SCALE, 1.0,
		"Expense scale should still pulse above 1.0"
	)
	assert_lt(
		_hud._CASH_EXPENSE_SCALE, _hud._CASH_INCOME_SCALE,
		"Expense pulse should be smaller than income pulse"
	)


func test_income_scale_grows() -> void:
	assert_gt(
		_hud._CASH_INCOME_SCALE, 1.0,
		"Income scale should grow above 1.0"
	)


func test_reputation_arrow_tween_on_increase() -> void:
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 70.0)
	assert_not_null(
		_hud._rep_arrow_tween,
		"Should create arrow tween on reputation increase"
	)


func test_reputation_arrow_tween_on_decrease() -> void:
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	assert_not_null(
		_hud._rep_arrow_tween,
		"Should create arrow tween on reputation decrease"
	)


func test_reputation_arrow_up_text() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_string_contains(
		label.text, "\u25B2",
		"Should show up arrow on increase"
	)


func test_reputation_arrow_down_text() -> void:
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_string_contains(
		label.text, "\u25BC",
		"Should show down arrow on decrease"
	)


func test_reputation_flash_uses_issue_025_timing() -> void:
	assert_eq(_hud._REP_ARROW_FADE_IN, 0.1)
	assert_eq(_hud._REP_ARROW_HOLD, 1.0)
	assert_eq(_hud._REP_ARROW_FADE_OUT, 0.4)


func test_reputation_increase_flashes_positive_color() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	await get_tree().create_timer(_hud._REP_ARROW_FADE_IN + 0.05).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	var actual: Color = label.get_theme_color("font_color")
	var expected: Color = UIThemeConstants.get_positive_color()
	assert_almost_eq(actual.r, expected.r, 0.005, "Increase should flash positive color (R)")
	assert_almost_eq(actual.g, expected.g, 0.005, "Increase should flash positive color (G)")
	assert_almost_eq(actual.b, expected.b, 0.005, "Increase should flash positive color (B)")


func test_reputation_decrease_flashes_negative_color() -> void:
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	await get_tree().create_timer(_hud._REP_ARROW_FADE_IN + 0.05).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	var actual: Color = label.get_theme_color("font_color")
	var expected: Color = UIThemeConstants.get_negative_color()
	assert_almost_eq(actual.r, expected.r, 0.005, "Decrease should flash negative color (R)")
	assert_almost_eq(actual.g, expected.g, 0.005, "Decrease should flash negative color (G)")
	assert_almost_eq(actual.b, expected.b, 0.005, "Decrease should flash negative color (B)")


func test_reputation_arrow_removed_after_hold() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	await get_tree().create_timer(
		_hud._REP_ARROW_FADE_IN + _hud._REP_ARROW_HOLD + 0.05
	).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_false(
		label.text.contains("\u25B2") or label.text.contains("\u25BC"),
		"Arrow should be removed after the hold"
	)


func test_reputation_color_fades_to_body_font_color() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	await get_tree().create_timer(
		_hud._REP_ARROW_FADE_IN
		+ _hud._REP_ARROW_HOLD
		+ _hud._REP_ARROW_FADE_OUT
		+ 0.05
	).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_eq(
		label.get_theme_color("font_color"),
		UIThemeConstants.BODY_FONT_COLOR,
		"Reputation label should fade back to body font color"
	)


func test_no_arrow_on_same_reputation() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	assert_null(
		_hud._rep_arrow_tween,
		"No arrow tween when reputation unchanged"
	)


func test_simultaneous_cash_and_reputation_effects() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	assert_not_null(_hud._cash_scale_tween, "Cash tween active")
	assert_not_null(_hud._rep_arrow_tween, "Rep tween active")


# Day 1 starting-cash seed: EconomySystem.initialize() writes player_cash
# via _apply_state and does not emit money_changed, so a HUD that only
# listens on money_changed would show $0.00 until the first transaction.
# day_started must seed the display from EconomySystem.get_cash().


func test_day_started_seeds_cash_from_economy_system() -> void:
	var economy: EconomySystem = EconomySystem.new()
	economy.name = "EconomySystem"
	add_child_autofree(economy)
	economy.initialize(500.0)
	# Pre-condition: HUD has not seen money_changed yet.
	assert_eq(_hud._displayed_cash, 0.0, "HUD starts with displayed cash $0")
	assert_eq(_hud._target_cash, 0.0, "HUD starts with target cash $0")
	EventBus.day_started.emit(1)
	var label: Label = _hud.get_node("TopBar/CashLabel")
	assert_string_contains(
		label.text, "500",
		"CashLabel must reflect EconomySystem.get_cash() after day_started"
	)
	assert_eq(
		_hud._target_cash, 500.0,
		"day_started must seed _target_cash from EconomySystem"
	)
	assert_eq(
		_hud._displayed_cash, 500.0,
		"day_started must snap _displayed_cash so no 0 → 500 tween shows"
	)


func test_day_started_seed_does_not_break_subsequent_money_changed() -> void:
	var economy: EconomySystem = EconomySystem.new()
	economy.name = "EconomySystem"
	add_child_autofree(economy)
	economy.initialize(500.0)
	EventBus.day_started.emit(1)
	# Live update path must keep working after the seed.
	EventBus.money_changed.emit(500.0, 525.50)
	assert_eq(
		_hud._target_cash, 525.50,
		"money_changed must still set _target_cash after a day_started seed"
	)


func test_day_started_seed_silent_when_economy_system_missing() -> void:
	# In unit-test scope without an EconomySystem in the tree, day_started
	# must not crash and the cash display must remain untouched.
	_hud._displayed_cash = 0.0
	_hud._target_cash = 0.0
	EventBus.day_started.emit(1)
	assert_eq(_hud._displayed_cash, 0.0)
	assert_eq(_hud._target_cash, 0.0)


# ── Day-1 counter accuracy (On Shelves / Cust / Sold Today) ────────────────
# These assertions cover the three throughput readouts the in-store HUD shows
# during Day 1: increments fire on the right signals, the On Shelves count
# decrements when stock leaves inventory (sale path), and all three counters
# zero out when day_started fires for Day 2.


func test_items_placed_decrements_when_inventory_changes() -> void:
	# Simulate an On-Shelves count that already reflects two items, then have
	# inventory drop to one (the sale path: CheckoutSystem._execute_sale calls
	# InventorySystem.remove_item, which emits inventory_changed).
	var inventory: InventorySystem = InventorySystem.new()
	inventory.name = "InventorySystem"
	add_child_autofree(inventory)
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "decrement_item_a"
	def.item_name = "Decrement Item A"
	def.category = "cartridges"
	def.base_price = 10.0
	def.store_type = "retro_games"
	var def_b: ItemDefinition = ItemDefinition.new()
	def_b.id = "decrement_item_b"
	def_b.item_name = "Decrement Item B"
	def_b.category = "cartridges"
	def_b.base_price = 10.0
	def_b.store_type = "retro_games"
	var item_a: ItemInstance = ItemInstance.create(def, "good", 0, def.base_price)
	item_a.current_location = "backroom"
	var item_b: ItemInstance = ItemInstance.create(def_b, "good", 0, def_b.base_price)
	item_b.current_location = "backroom"
	inventory.add_item(&"retro_games", item_a)
	inventory.add_item(&"retro_games", item_b)
	inventory.assign_to_shelf(
		&"retro_games", StringName(item_a.instance_id), &"slot_a"
	)
	inventory.assign_to_shelf(
		&"retro_games", StringName(item_b.instance_id), &"slot_b"
	)
	assert_eq(
		_hud._items_placed_count, 2,
		"On Shelves must reflect both stocked items after assign_to_shelf"
	)
	inventory.remove_item(item_a.instance_id)
	assert_eq(
		_hud._items_placed_count, 1,
		"On Shelves must decrement when inventory.remove_item is called"
	)


func test_day_started_resets_all_three_day_counters_to_zero() -> void:
	# Simulate end-of-day-1 state: counters hold yesterday's totals.
	_hud._items_placed_count = 4
	_hud._customers_served_today_count = 3
	_hud._sales_today_count = 5
	_hud._update_items_placed_display(4)
	_hud._update_customers_display(3)
	_hud._update_sales_today_display(5)
	# Day 2 start. The Cust and Sold Today counters reset unconditionally; the
	# On Shelves count re-reads inventory and reports zero when no inventory
	# system is in the tree (Tier-5 init silent return — the next
	# inventory_changed re-populates it).
	EventBus.day_started.emit(2)
	assert_eq(
		_hud._customers_served_today_count, 0,
		"Cust must reset to 0 at the start of Day 2"
	)
	assert_eq(
		_hud._sales_today_count, 0,
		"Sold Today must reset to 0 at the start of Day 2"
	)
	var customers_label: Label = _hud.get_node("TopBar/CustomersLabel")
	var sales_label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	assert_string_contains(
		customers_label.text, "0",
		"CustomersLabel text must show 0 after Day 2 reset"
	)
	assert_string_contains(
		sales_label.text, "0",
		"SalesTodayLabel text must show 0 after Day 2 reset"
	)


func test_items_placed_pulses_green_on_increment() -> void:
	var inventory: InventorySystem = InventorySystem.new()
	inventory.name = "InventorySystem"
	add_child_autofree(inventory)
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "pulse_item_inc"
	def.item_name = "Pulse Item Inc"
	def.category = "cartridges"
	def.base_price = 10.0
	def.store_type = "retro_games"
	var item: ItemInstance = ItemInstance.create(def, "good", 0, def.base_price)
	item.current_location = "backroom"
	inventory.add_item(&"retro_games", item)
	inventory.assign_to_shelf(
		&"retro_games", StringName(item.instance_id), &"slot_inc"
	)
	var label: Label = _hud.get_node("TopBar/ItemsPlacedLabel")
	assert_true(
		_hud._counter_scale_tweens.has(label),
		"On Shelves increment must create a scale-pulse tween"
	)


func test_customers_pulses_on_customer_purchased() -> void:
	_hud._customers_served_today_count = 0
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_a", 12.0, &"c_pulse"
	)
	var label: Label = _hud.get_node("TopBar/CustomersLabel")
	assert_true(
		_hud._counter_scale_tweens.has(label),
		"Cust increment must create a scale-pulse tween"
	)


func test_sales_today_pulses_on_item_sold() -> void:
	_hud._sales_today_count = 0
	EventBus.item_sold.emit("item_pulse", 25.0, "cartridges")
	var label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	assert_true(
		_hud._counter_scale_tweens.has(label),
		"Sold Today increment must create a scale-pulse tween"
	)
