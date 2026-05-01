## Verifies HUD TopBar metric labels (Day 1 readability + live updates):
##   * StoreLabel lives inside the TopBar between TimeLabel and ItemsPlacedLabel.
##   * StoreLabel becomes visible during STORE_VIEW after store_opened fires
##     and shows the active store's display name.
##   * ItemsPlacedLabel and SalesTodayLabel use unambiguous wording so a
##     first-time player can read them without context.
##   * TimeLabel updates on `EventBus.hour_changed`.
##   * CashLabel reflects new cash after the count-up tween settles.
extends GutTest


const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")
const _CASH_TWEEN_SETTLE: float = 0.45


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


func test_store_label_lives_in_top_bar() -> void:
	var label: Label = _hud.get_node_or_null("TopBar/StoreLabel")
	assert_not_null(label, "StoreLabel must exist as a child of TopBar")


func test_store_label_positioned_between_time_and_items_placed() -> void:
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	var time_idx: int = _hud.get_node("TopBar/TimeLabel").get_index()
	var store_idx: int = _hud.get_node("TopBar/StoreLabel").get_index()
	var items_idx: int = _hud.get_node("TopBar/ItemsPlacedLabel").get_index()
	assert_lt(
		time_idx, store_idx,
		"StoreLabel must come after TimeLabel in TopBar order"
	)
	assert_lt(
		store_idx, items_idx,
		"StoreLabel must come before ItemsPlacedLabel in TopBar order"
	)
	assert_eq(
		top_bar, _hud.get_node("TopBar/StoreLabel").get_parent(),
		"StoreLabel parent must be TopBar"
	)


func test_store_label_visible_in_store_view_after_store_opened() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	EventBus.store_opened.emit("retro_games")
	var label: Label = _hud.get_node("TopBar/StoreLabel")
	assert_true(
		label.visible,
		"StoreLabel must be visible in STORE_VIEW after store_opened"
	)
	assert_false(
		label.text.strip_edges().is_empty(),
		"StoreLabel text must not be empty after store_opened"
	)


func test_items_placed_label_text_is_unambiguous() -> void:
	_hud._update_items_placed_display(0)
	var label: Label = _hud.get_node("TopBar/ItemsPlacedLabel")
	# "Placed: 0" was ambiguous — could mean placed-today or placed-total. The
	# replacement must clearly identify the count as items currently on shelves.
	var text_lower: String = label.text.to_lower()
	assert_true(
		text_lower.contains("shel") or text_lower.contains("stock"),
		"ItemsPlacedLabel must reference shelves or stock, got: '%s'" % label.text
	)
	assert_false(
		label.text.begins_with("Placed:"),
		"ItemsPlacedLabel must no longer use the ambiguous 'Placed:' wording"
	)


func test_sales_today_label_text_is_unambiguous() -> void:
	_hud._update_sales_today_display(0)
	var label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	# "Sold: 0" was ambiguous — could mean sold-today or sold-all-time. The
	# replacement must scope the count to the current day.
	assert_true(
		label.text.to_lower().contains("today"),
		"SalesTodayLabel must scope the count to 'today', got: '%s'" % label.text
	)


func test_time_label_advances_on_hour_changed() -> void:
	EventBus.day_started.emit(1)
	EventBus.hour_changed.emit(11)
	var label: Label = _hud.get_node("TopBar/TimeLabel")
	assert_string_contains(
		label.text, "11",
		"TimeLabel must reflect the new hour after hour_changed"
	)


func test_cash_label_updates_on_money_changed() -> void:
	var label: Label = _hud.get_node("TopBar/CashLabel")
	EventBus.money_changed.emit(0.0, 25.50)
	# CashLabel uses a count-up tween (~0.3s) — wait for it to settle.
	await get_tree().create_timer(_CASH_TWEEN_SETTLE).timeout
	assert_string_contains(
		label.text, "25.50",
		"CashLabel must show new cash amount after money_changed settles"
	)


func test_top_bar_labels_have_no_truncation_at_1920x1080() -> void:
	# At 1920x1080 (project default), the unambiguous metric labels must
	# render at their natural size without forcing clip_text to actually
	# elide. This verifies the custom_minimum_size is wide enough for the
	# default text content.
	await get_tree().process_frame
	var label_names: Array[String] = [
		"ItemsPlacedLabel", "SalesTodayLabel",
	]
	for label_name: String in label_names:
		var label: Label = _hud.get_node("TopBar/" + label_name)
		var text_min: Vector2 = label.get_minimum_size()
		assert_gte(
			label.custom_minimum_size.x, text_min.x - 1.0,
			"%s custom_minimum_size.x must accommodate text width (got %d, need %d)" % [
				label_name, int(label.custom_minimum_size.x), int(text_min.x)
			]
		)
