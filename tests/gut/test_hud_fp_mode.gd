## Tests for HUD.set_fp_mode — first-person corner overlay layout used while a
## StorePlayerBody owns the camera. Verifies that TopBar disappears, the four
## core readouts (cash, time, on-shelves, customers, sold-today) are reparented
## to the HUD CanvasLayer with anchored offsets, that toggling back restores
## the original TopBar layout, and that EventBus signal handlers still drive
## the detached labels after the reparent.
extends GutTest

const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _hud: CanvasLayer
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)


func after_each() -> void:
	GameManager.current_state = _saved_state


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


func test_set_fp_mode_hides_top_bar() -> void:
	_hud.set_fp_mode(true)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_false(
		top_bar.visible,
		"TopBar HBoxContainer must be hidden when FP mode is enabled"
	)


func test_set_fp_mode_reparents_cash_label_under_hud() -> void:
	_hud.set_fp_mode(true)
	var cash_label: Label = _hud._cash_label
	assert_eq(
		cash_label.get_parent(), _hud,
		"CashLabel must be reparented directly under the HUD CanvasLayer in FP mode"
	)


func test_set_fp_mode_reparents_time_label_under_hud() -> void:
	_hud.set_fp_mode(true)
	var time_label: Label = _hud._time_label
	assert_eq(
		time_label.get_parent(), _hud,
		"TimeLabel must be reparented directly under the HUD CanvasLayer in FP mode"
	)


func test_set_fp_mode_reparents_items_placed_label_under_hud() -> void:
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._items_placed_label.get_parent(), _hud,
		"ItemsPlacedLabel must be reparented under HUD in FP mode"
	)


func test_set_fp_mode_reparents_customers_label_under_hud() -> void:
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._customers_label.get_parent(), _hud,
		"CustomersLabel must be reparented under HUD in FP mode"
	)


func test_set_fp_mode_reparents_sales_today_label_under_hud() -> void:
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._sales_today_label.get_parent(), _hud,
		"SalesTodayLabel must be reparented under HUD in FP mode"
	)


func test_fp_mode_cash_label_anchored_top_left() -> void:
	_hud.set_fp_mode(true)
	var cash_label: Label = _hud._cash_label
	assert_eq(cash_label.anchor_left, 0.0, "CashLabel anchored top-left in FP mode")
	assert_eq(cash_label.anchor_right, 0.0, "CashLabel anchor_right is 0 in FP mode")
	assert_eq(cash_label.offset_left, 8.0, "CashLabel offset_left = 8 in FP mode")
	assert_eq(cash_label.offset_top, 8.0, "CashLabel offset_top = 8 in FP mode")


func test_fp_mode_time_label_anchored_top_center() -> void:
	_hud.set_fp_mode(true)
	var time_label: Label = _hud._time_label
	assert_eq(time_label.anchor_left, 0.5, "TimeLabel anchored to horizontal center")
	assert_eq(time_label.anchor_right, 0.5, "TimeLabel anchor_right at center")


func test_fp_mode_time_label_grows_symmetrically() -> void:
	# Ultrawide guard: a centered label must grow in both directions when its
	# minimum size exceeds the explicit offset width, otherwise a long localized
	# string would push the visible center off the right edge of the viewport.
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._time_label.grow_horizontal, Control.GROW_DIRECTION_BOTH,
		"TimeLabel must grow symmetrically (GROW_DIRECTION_BOTH) when centered in FP mode"
	)


func test_fp_mode_cash_label_grows_rightward() -> void:
	_hud.set_fp_mode(true)
	assert_eq(
		_hud._cash_label.grow_horizontal, Control.GROW_DIRECTION_END,
		"Left-anchored CashLabel must grow rightward so it stays inside the viewport"
	)


func test_fp_mode_right_cluster_grows_leftward() -> void:
	# Right-anchored corner labels must grow toward the screen interior so a
	# long localized string never pushes the rect off the right edge on
	# ultrawide displays.
	_hud.set_fp_mode(true)
	for lbl: Label in [
		_hud._items_placed_label,
		_hud._customers_label,
		_hud._sales_today_label,
	]:
		assert_eq(
			lbl.grow_horizontal, Control.GROW_DIRECTION_BEGIN,
			"%s must grow leftward (GROW_DIRECTION_BEGIN) when right-anchored" % lbl.name
		)


func test_fp_mode_items_placed_anchored_top_right() -> void:
	_hud.set_fp_mode(true)
	var lbl: Label = _hud._items_placed_label
	assert_eq(lbl.anchor_left, 1.0, "ItemsPlacedLabel anchored top-right")
	assert_eq(lbl.anchor_right, 1.0, "ItemsPlacedLabel anchor_right at right edge")


func test_fp_mode_customers_below_items_placed() -> void:
	_hud.set_fp_mode(true)
	assert_gt(
		_hud._customers_label.offset_top, _hud._items_placed_label.offset_top,
		"CustomersLabel must sit below ItemsPlacedLabel in the top-right cluster"
	)


func test_fp_mode_sales_today_below_customers() -> void:
	_hud.set_fp_mode(true)
	assert_gt(
		_hud._sales_today_label.offset_top, _hud._customers_label.offset_top,
		"SalesTodayLabel must sit below CustomersLabel in the top-right cluster"
	)


func test_fp_mode_hides_milestones_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	assert_false(
		_hud._milestones_button.visible,
		"MilestonesButton must not be visible in FP mode"
	)


func test_fp_mode_hides_reputation_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	assert_false(
		_hud._reputation_label.visible,
		"ReputationLabel must not be visible in FP mode"
	)


func test_fp_mode_hides_speed_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	_hud.set_fp_mode(true)
	assert_false(
		_hud._speed_button.visible,
		"SpeedButton must not be visible in FP mode"
	)


func test_fp_mode_hides_seasonal_event_label() -> void:
	_hud.set_fp_mode(true)
	assert_false(
		_hud.get_node("SeasonalEventLabel").visible,
		"SeasonalEventLabel must be hidden in FP mode"
	)


func test_fp_mode_hides_telegraph_card() -> void:
	_hud.set_fp_mode(true)
	assert_false(
		_hud.get_node("TelegraphCard").visible,
		"TelegraphCard must be hidden in FP mode"
	)


func test_fp_mode_keeps_crosshair_visible() -> void:
	_hud.set_fp_mode(true)
	var crosshair: Node = _hud.get_node_or_null("Crosshair")
	assert_not_null(crosshair, "Crosshair must remain a child of HUD in FP mode")
	if crosshair is CanvasItem:
		assert_true(
			(crosshair as CanvasItem).visible,
			"Crosshair must remain visible in FP mode"
		)


func test_fp_mode_creates_close_day_hint() -> void:
	_hud.set_fp_mode(true)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	assert_not_null(hint, "FP mode must add an F4 close-day hint label to HUD")
	if hint == null:
		return
	assert_true(hint.visible, "Close-day hint must be visible in FP mode")
	assert_string_contains(
		hint.text, "F4",
		"Close-day hint must surface the F4 keybinding"
	)


func test_fp_mode_hint_anchored_bottom_right() -> void:
	_hud.set_fp_mode(true)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	assert_not_null(hint)
	if hint == null:
		return
	assert_eq(hint.anchor_left, 1.0, "Close-day hint anchored to right edge")
	assert_eq(hint.anchor_top, 1.0, "Close-day hint anchored to bottom edge")


func test_fp_mode_cash_signal_still_updates_label() -> void:
	_hud.set_fp_mode(true)
	EventBus.money_changed.emit(0.0, 25.50)
	# Cash uses a count-up tween (~0.3s), wait for it to settle.
	await get_tree().create_timer(0.45).timeout
	assert_string_contains(
		_hud._cash_label.text, "25.50",
		"CashLabel must still receive money_changed updates after FP reparent"
	)


func test_fp_mode_time_signal_still_updates_label() -> void:
	_hud.set_fp_mode(true)
	EventBus.day_started.emit(1)
	EventBus.hour_changed.emit(11)
	assert_string_contains(
		_hud._time_label.text, "11",
		"TimeLabel must still receive hour_changed updates after FP reparent"
	)


func test_fp_mode_items_placed_signal_still_updates_label() -> void:
	_hud.set_fp_mode(true)
	_hud._update_items_placed_display(7)
	assert_string_contains(
		_hud._items_placed_label.text, "7",
		"ItemsPlacedLabel must still update via _update_items_placed_display after FP reparent"
	)


func test_fp_mode_customers_signal_still_updates_label() -> void:
	_hud.set_fp_mode(true)
	_hud._customers_active_count = 0
	EventBus.customer_entered.emit({"customer_id": "c1"})
	assert_string_contains(
		_hud._customers_label.text, "1",
		"CustomersLabel must still update via customer_entered after FP reparent"
	)


func test_fp_mode_sales_today_signal_still_updates_label() -> void:
	_hud.set_fp_mode(true)
	_hud._sales_today_count = 0
	EventBus.item_sold.emit("test_item", 9.99, "category")
	assert_string_contains(
		_hud._sales_today_label.text, "1",
		"SalesTodayLabel must still update via item_sold after FP reparent"
	)


func test_fp_mode_idempotent_when_called_twice() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(true)
	# No error, labels still parented to HUD root.
	assert_eq(
		_hud._cash_label.get_parent(), _hud,
		"Calling set_fp_mode(true) twice must remain a no-op"
	)


func test_disable_fp_mode_restores_top_bar() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(false)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_true(
		top_bar.visible,
		"TopBar must be visible again after set_fp_mode(false)"
	)


func test_disable_fp_mode_reparents_labels_back_to_top_bar() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(false)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_eq(
		_hud._cash_label.get_parent(), top_bar,
		"CashLabel must return to TopBar after FP mode is disabled"
	)
	assert_eq(
		_hud._time_label.get_parent(), top_bar,
		"TimeLabel must return to TopBar after FP mode is disabled"
	)
	assert_eq(
		_hud._items_placed_label.get_parent(), top_bar,
		"ItemsPlacedLabel must return to TopBar after FP mode is disabled"
	)
	assert_eq(
		_hud._customers_label.get_parent(), top_bar,
		"CustomersLabel must return to TopBar after FP mode is disabled"
	)
	assert_eq(
		_hud._sales_today_label.get_parent(), top_bar,
		"SalesTodayLabel must return to TopBar after FP mode is disabled"
	)


func test_disable_fp_mode_hides_close_day_hint() -> void:
	_hud.set_fp_mode(true)
	_hud.set_fp_mode(false)
	var hint: Label = _hud.get_node_or_null("FpCloseDayHint") as Label
	if hint == null:
		return
	assert_false(
		hint.visible,
		"FP close-day hint must be hidden after set_fp_mode(false)"
	)


func test_state_change_in_fp_mode_keeps_top_bar_hidden() -> void:
	# A STORE_VIEW transition normally shows TopBar children; FP mode must
	# re-assert overrides so the heavy bar does not leak back in.
	_hud.set_fp_mode(true)
	_emit_state(GameManager.State.STORE_VIEW)
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	assert_false(
		top_bar.visible,
		"TopBar must remain hidden after a STORE_VIEW transition while FP mode is on"
	)
