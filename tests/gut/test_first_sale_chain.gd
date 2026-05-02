## Verifies the Day 1 scripted first-customer → first-sale → HUD update chain.
##
## Three layers are exercised:
##   1. `CustomerSystem._on_item_stocked` — the scripted Day 1 trigger guarded by
##      `_day1_customer_spawned`, independent of clock-driven HOUR_DENSITY.
##   2. HUD label handlers — `CashLabel`, `CustomersLabel`, `SalesTodayLabel`
##      update synchronously from `money_changed` / `customer_entered` /
##      `item_sold`.
##   3. Close Day gate — `_is_day1_gate_active()` flips off after
##      `first_sale_complete` is set, and the button-press path emits the
##      correct EventBus signal in each gate state.
##
## Chain wiring further upstream (`item_sold → ObjectiveDirector →
## first_sale_completed → DayManager → flag`) is covered by
## `test_day1_core_loop.gd`; cash/items_sold accounting by
## `test_economy_customer_purchased.gd`. This file fills the remaining gaps.
extends GutTest


const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)
const _STORE_ID: String = "test_store_first_sale"

var _saved_current_day: int
var _saved_state: GameManager.State
var _saved_store_id: StringName


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func before_each() -> void:
	_saved_current_day = GameManager.get_current_day()
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	GameState.reset_new_game()
	GameManager.set_current_day(1)


func after_each() -> void:
	GameManager.set_current_day(_saved_current_day)
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameState.reset_new_game()


# ── CustomerSystem._on_item_stocked: scripted Day 1 spawn ─────────────────────


func test_on_item_stocked_spawns_one_customer_on_day_1() -> void:
	var system: CustomerSystem = _make_customer_system()
	GameManager.set_current_day(1)
	system._on_item_stocked("item_x", "slot_a")
	assert_true(
		system._day1_customer_spawned,
		"Day 1 first item_stocked must flip _day1_customer_spawned to true"
	)
	assert_eq(
		system.get_active_customer_count(),
		1,
		"Day 1 first item_stocked must spawn exactly one active customer"
	)


func test_on_item_stocked_skipped_after_day_1() -> void:
	var system: CustomerSystem = _make_customer_system()
	GameManager.set_current_day(2)
	system._on_item_stocked("item_x", "slot_a")
	assert_false(
		system._day1_customer_spawned,
		"Scripted spawn must not fire on Day 2"
	)
	assert_eq(
		system.get_active_customer_count(),
		0,
		"No customer should spawn from item_stocked outside Day 1"
	)


func test_on_item_stocked_one_shot_within_day_1() -> void:
	var system: CustomerSystem = _make_customer_system()
	GameManager.set_current_day(1)
	system._on_item_stocked("item_a", "slot_a")
	# Despawn the spawned customer so the `_active_customers.is_empty()`
	# guard does not mask the second-call check.
	for c: Customer in system.get_active_customers().duplicate():
		system.despawn_customer(c)
	system._on_item_stocked("item_b", "slot_b")
	assert_eq(
		system.get_active_customer_count(),
		0,
		"Second item_stocked on the same Day 1 must not spawn a second customer"
	)


func test_day_started_resets_day1_spawn_flag() -> void:
	var system: CustomerSystem = _make_customer_system()
	system._day1_customer_spawned = true
	system._on_day_started(1)
	assert_false(
		system._day1_customer_spawned,
		"day_started must clear _day1_customer_spawned so the next day re-arms"
	)


func test_on_item_stocked_signal_wired_through_initialize() -> void:
	# Direct signal-emission path: verify `initialize()` connects the handler so
	# the scripted spawn is reachable from EventBus.item_stocked, not just from
	# direct method calls. Uses a synchronous emit; spawn runs in the same frame.
	var system: CustomerSystem = CustomerSystem.new()
	add_child_autofree(system)
	system._customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	system._connect_signals()
	GameManager.set_current_day(1)
	EventBus.item_stocked.emit("item_x", "slot_a")
	assert_true(
		system._day1_customer_spawned,
		"item_stocked signal must reach _on_item_stocked via _connect_signals()"
	)


# ── HUD: signal-driven label updates ──────────────────────────────────────────


func test_hud_cash_label_updates_on_money_changed() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	var label: Label = hud.get_node("TopBar/CashLabel")
	EventBus.money_changed.emit(100.0, 142.50)
	# CashLabel uses an animated count tween; assert the target updated.
	assert_almost_eq(
		hud._target_cash, 142.50, 0.001,
		"money_changed must update HUD _target_cash to the new amount"
	)
	assert_not_null(label, "CashLabel node must exist on the HUD")


func test_hud_customers_label_increments_on_customer_entered() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	var label: Label = hud.get_node("TopBar/CustomersLabel")
	hud._customers_active_count = 0
	EventBus.customer_entered.emit({"customer_id": 1})
	assert_eq(
		hud._customers_active_count, 1,
		"customer_entered must increment HUD active customer count"
	)
	assert_string_contains(
		label.text, "1",
		"CustomersLabel text must reflect the incremented count"
	)


func test_hud_sales_today_label_increments_on_item_sold() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	var label: Label = hud.get_node("TopBar/SalesTodayLabel")
	hud._sales_today_count = 0
	EventBus.item_sold.emit("item_x", 25.0, "cartridges")
	assert_eq(
		hud._sales_today_count, 1,
		"item_sold must increment HUD sales-today count"
	)
	assert_string_contains(
		label.text, "1",
		"SalesTodayLabel text must reflect the incremented count"
	)


# ── Close Day gate: state and button-press behavior ───────────────────────────


func test_close_day_gate_active_on_day_1_without_first_sale() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", false)
	assert_true(
		hud._is_day1_gate_active(),
		"Gate must be active on Day 1 with no first-sale flag"
	)


func test_close_day_gate_releases_after_first_sale_flag_set() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", true)
	assert_false(
		hud._is_day1_gate_active(),
		"Gate must release once first_sale_complete is set"
	)


func test_close_day_press_shows_soft_confirm_when_gate_active() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.current_state = GameManager.State.STORE_VIEW
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", false)

	var close_emits: Array[bool] = []
	var on_close: Callable = (func() -> void: close_emits.append(true))
	EventBus.day_close_requested.connect(on_close)
	hud._on_close_day_pressed()
	EventBus.day_close_requested.disconnect(on_close)

	var dialog: ConfirmationDialog = (
		hud.get_node("CloseDayConfirmDialog") as ConfirmationDialog
	)
	assert_true(
		dialog.visible,
		"Pressing Close Day with the gate active must surface the confirm dialog"
	)
	assert_eq(
		close_emits.size(), 0,
		"Pressing Close Day with the gate active must not yet request day close"
	)
	var preview: CanvasLayer = hud.get_node("CloseDayPreview") as CanvasLayer
	assert_false(
		preview.visible,
		"The dry-run preview must not open until the player confirms"
	)


func test_close_day_press_proceeds_when_gate_released() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.current_state = GameManager.State.STORE_VIEW
	GameManager.set_current_day(1)
	GameState.set_flag(&"first_sale_complete", true)

	var close_emits: Array[bool] = []
	var on_close: Callable = (func() -> void: close_emits.append(true))
	EventBus.day_close_requested.connect(on_close)
	hud._on_close_day_pressed()
	var preview: CanvasLayer = hud.get_node("CloseDayPreview") as CanvasLayer
	assert_not_null(
		preview, "HUD must instance the close-day preview modal"
	)
	assert_true(
		preview.visible,
		"Pressing Close Day after the gate releases must open the preview"
	)
	assert_eq(
		close_emits.size(), 0,
		"Press alone must not emit day_close_requested — confirm does"
	)
	preview._on_confirm_pressed()
	EventBus.day_close_requested.disconnect(on_close)
	assert_eq(
		close_emits.size(), 1,
		"Confirming the preview must emit day_close_requested exactly once"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_customer_system() -> CustomerSystem:
	# Constructs a CustomerSystem ready to exercise the Day 1 scripted spawn.
	# `initialize()` would call `_despawn_all_customers` which depends on full
	# scene-tree wiring; instead we load the Customer scene directly and hook
	# only what `_on_item_stocked` needs.
	var system: CustomerSystem = CustomerSystem.new()
	add_child_autofree(system)
	system._customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	system._store_id = _STORE_ID
	return system
