## Day-1 onboarding zero-state hint: contextual copy on the in-store HUD
## that surfaces "stock the floor" or "waiting for customers" guidance when
## the player loop is idle.
extends GutTest


const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)
const _HINT_STOCK_FLOOR: String = "Stock shelves to open the lane."
const _HINT_AWAITING_CUSTOMER: String = "Waiting for the first customer…"

var _hud: CanvasLayer
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	InputFocus._reset_for_tests()
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)
	_hud._reset_for_tests()


func after_each() -> void:
	GameManager.current_state = _saved_state
	InputFocus._reset_for_tests()


func _hint() -> Label:
	return _hud.get_node("ZeroStateHint") as Label


func test_zero_state_hint_label_present() -> void:
	assert_not_null(_hint(), "ZeroStateHint must exist on hud.tscn")


func test_hint_shows_stock_copy_at_zero_items() -> void:
	_hud._items_placed_count = 0
	_hud._active_customer_count = 0
	_hud._refresh_zero_state_hint()
	assert_true(_hint().visible, "hint must show when shelves are empty")
	assert_eq(_hint().text, _HINT_STOCK_FLOOR)


func test_hint_transitions_to_waiting_after_first_stock() -> void:
	_hud._items_placed_count = 0
	_hud._active_customer_count = 0
	_hud._refresh_zero_state_hint()
	_hud._items_placed_count = 1
	_hud._refresh_zero_state_hint()
	assert_true(_hint().visible, "hint must remain visible while customers absent")
	assert_eq(_hint().text, _HINT_AWAITING_CUSTOMER)


func test_hint_hides_after_first_customer_spawn() -> void:
	_hud._items_placed_count = 1
	_hud._active_customer_count = 0
	_hud._refresh_zero_state_hint()
	assert_true(_hint().visible, "precondition: waiting copy visible")
	EventBus.customer_spawned.emit(_hud)
	assert_false(_hint().visible, "hint must hide once a customer is present")


func test_hint_reappears_when_all_customers_leave_with_stock() -> void:
	_hud._items_placed_count = 2
	EventBus.customer_spawned.emit(_hud)
	assert_false(_hint().visible, "precondition: hint hidden while customer in store")
	EventBus.customer_left.emit({})
	assert_true(_hint().visible, "hint must re-appear when active customers drop to 0")
	assert_eq(_hint().text, _HINT_AWAITING_CUSTOMER)


func test_stock_hint_takes_precedence_over_customer_hint() -> void:
	# Empty shelves win even if a customer is technically active.
	_hud._items_placed_count = 0
	_hud._active_customer_count = 3
	_hud._refresh_zero_state_hint()
	assert_true(_hint().visible)
	assert_eq(_hint().text, _HINT_STOCK_FLOOR)


func test_hint_hidden_during_modal_context() -> void:
	_hud._items_placed_count = 0
	_hud._refresh_zero_state_hint()
	assert_true(_hint().visible, "precondition: hint visible before modal opens")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(_hint().visible, "modal context must hide the hint")
	InputFocus.pop_context()
	assert_true(_hint().visible, "hint must restore when modal closes")


func test_hint_hidden_in_day_summary_state() -> void:
	_hud._items_placed_count = 0
	_hud._refresh_zero_state_hint()
	assert_true(_hint().visible, "precondition: hint visible in STORE_VIEW")
	GameManager.current_state = GameManager.State.DAY_SUMMARY
	EventBus.game_state_changed.emit(
		int(GameManager.State.STORE_VIEW),
		int(GameManager.State.DAY_SUMMARY),
	)
	assert_false(_hint().visible, "DAY_SUMMARY must hide the hint")


func test_hint_hidden_in_mall_overview_state() -> void:
	_hud._items_placed_count = 0
	_hud._refresh_zero_state_hint()
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	EventBus.game_state_changed.emit(
		int(GameManager.State.STORE_VIEW),
		int(GameManager.State.MALL_OVERVIEW),
	)
	assert_false(_hint().visible, "MALL_OVERVIEW must hide the in-store hint")


func test_day_started_resets_active_customer_count() -> void:
	EventBus.customer_spawned.emit(_hud)
	EventBus.customer_spawned.emit(_hud)
	assert_eq(_hud._active_customer_count, 2)
	EventBus.day_started.emit(2)
	assert_eq(
		_hud._active_customer_count, 0,
		"day_started must reset the active-customer gauge"
	)


func test_active_customer_count_clamps_at_zero() -> void:
	# Stray customer_left without a matching spawn must not push the gauge negative.
	_hud._active_customer_count = 0
	EventBus.customer_left.emit({})
	assert_eq(_hud._active_customer_count, 0)


func test_hint_position_below_top_bar() -> void:
	# Hint must sit below the TopBar (~48px tall) and not in the bottom-center
	# zone owned by the InteractionPrompt or the centered crosshair.
	var hint: Label = _hint()
	assert_almost_eq(
		hint.offset_top, 52.0, 1.0,
		"ZeroStateHint must anchor below the TopBar"
	)
	assert_almost_eq(
		hint.anchor_left, 0.5, 0.001, "ZeroStateHint must be top-center"
	)
	assert_almost_eq(
		hint.anchor_right, 0.5, 0.001, "ZeroStateHint must be top-center"
	)
	assert_eq(
		hint.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
		"hint text must be horizontally centered"
	)
