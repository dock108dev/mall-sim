## ISSUE-002: Tests for HUD visibility gating on GameManager state.
extends GutTest

const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _hud: CanvasLayer
var _saved_state: GameManager.State


func before_all() -> void:
	_saved_state = GameManager.current_state
	_hud = _HudScene.instantiate()
	add_child(_hud)


func after_all() -> void:
	GameManager.current_state = _saved_state
	if is_instance_valid(_hud):
		_hud.free()
	_hud = null


func before_each() -> void:
	_hud._reset_for_tests()


func after_each() -> void:
	GameManager.current_state = _saved_state


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


func test_hidden_in_main_menu() -> void:
	_emit_state(GameManager.State.MAIN_MENU)
	assert_false(_hud.visible, "HUD must be invisible in MAIN_MENU")


func test_hidden_in_day_summary() -> void:
	_emit_state(GameManager.State.DAY_SUMMARY)
	assert_false(_hud.visible, "HUD must be invisible in DAY_SUMMARY")


func test_visible_in_mall_overview() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	assert_true(_hud.visible, "HUD must be visible in MALL_OVERVIEW")


func test_mall_overview_hides_close_day_button() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_not_null(btn, "CloseDayButton must exist")
	assert_false(btn.visible, "Close Day must be hidden in MALL_OVERVIEW")


func test_mall_overview_hides_hub_back_button() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/HubBackButton")
	assert_not_null(btn, "HubBackButton must exist")
	assert_false(btn.visible, "Hub Back must be hidden in MALL_OVERVIEW")


func test_mall_overview_hides_store_label() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	assert_false(
		_hud.get_node("StoreLabel").visible,
		"StoreLabel must be hidden in MALL_OVERVIEW"
	)


func test_mall_overview_hides_objective_label() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	assert_false(
		_hud.get_node("ObjectiveLabel").visible,
		"ObjectiveLabel must be hidden in MALL_OVERVIEW"
	)


func test_mall_overview_shows_cash_label() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	assert_true(
		_hud.get_node("TopBar/CashLabel").visible,
		"CashLabel must be visible in MALL_OVERVIEW"
	)


func test_mall_overview_shows_time_label() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	assert_true(
		_hud.get_node("TopBar/TimeLabel").visible,
		"TimeLabel (day label) must be visible in MALL_OVERVIEW"
	)


func test_mall_overview_shows_milestones_button() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	assert_true(
		_hud.get_node("TopBar/MilestonesButton").visible,
		"MilestonesButton must be visible in MALL_OVERVIEW"
	)


func test_store_view_shows_close_day_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_not_null(btn, "CloseDayButton must exist")
	assert_true(btn.visible, "Close Day must be visible in STORE_VIEW")


func test_store_view_shows_items_placed_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/ItemsPlacedLabel").visible,
		"ItemsPlacedLabel must be visible in STORE_VIEW"
	)


func test_store_view_shows_customers_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/CustomersLabel").visible,
		"CustomersLabel must be visible in STORE_VIEW"
	)


func test_store_view_shows_sales_today_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/SalesTodayLabel").visible,
		"SalesTodayLabel must be visible in STORE_VIEW"
	)


func test_store_view_hides_seasonal_event_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_false(
		_hud.get_node("SeasonalEventLabel").visible,
		"SeasonalEventLabel must be hidden in STORE_VIEW"
	)


func test_store_view_hides_telegraph_card() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_false(
		_hud.get_node("TelegraphCard").visible,
		"TelegraphCard must be hidden in STORE_VIEW"
	)


func test_hub_back_not_shown_when_store_entered_in_mall_overview() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	EventBus.store_entered.emit(&"retro_games")
	var btn: Button = _hud.get_node_or_null("TopBar/HubBackButton")
	assert_not_null(btn, "HubBackButton must exist")
	assert_false(
		btn.visible,
		"Hub Back must stay hidden when store_entered fires in MALL_OVERVIEW"
	)


func test_hub_back_shown_when_store_entered_in_store_view() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	EventBus.store_entered.emit(&"retro_games")
	var btn: Button = _hud.get_node_or_null("TopBar/HubBackButton")
	assert_not_null(btn, "HubBackButton must exist")
	assert_true(
		btn.visible,
		"Hub Back must be visible after store_entered in STORE_VIEW"
	)


func test_paused_does_not_change_close_day_from_store_view() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_true(btn.visible, "Close Day visible in STORE_VIEW")
	_emit_state(GameManager.State.PAUSED)
	assert_true(
		btn.visible,
		"PAUSED must not hide Close Day button set by STORE_VIEW"
	)


func test_switching_state_takes_effect_immediately() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(_hud.visible)
	_emit_state(GameManager.State.MAIN_MENU)
	assert_false(
		_hud.visible,
		"State switch must apply within the same frame"
	)


func test_initial_ready_hides_hud_when_game_is_at_main_menu() -> void:
	# GameManager starts at MAIN_MENU; _ready must apply that state.
	var fresh_hud: CanvasLayer = _HudScene.instantiate()
	GameManager.current_state = GameManager.State.MAIN_MENU
	add_child_autofree(fresh_hud)
	assert_false(
		fresh_hud.visible,
		"HUD must be hidden on _ready when GameManager is at MAIN_MENU"
	)


func test_top_bar_labels_have_clip_text() -> void:
	var label_names: Array[String] = [
		"CashLabel", "TimeLabel", "ItemsPlacedLabel",
		"CustomersLabel", "SalesTodayLabel", "ReputationLabel",
	]
	for label_name: String in label_names:
		var label: Label = _hud.get_node("TopBar/" + label_name)
		assert_true(
			label.clip_text,
			"%s must have clip_text = true to prevent overflow" % label_name
		)


func test_close_day_button_has_min_width() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_not_null(btn, "CloseDayButton must exist")
	assert_gte(
		btn.custom_minimum_size.x, 80.0,
		"CloseDayButton must have custom_minimum_size.x >= 80 to prevent wrapping"
	)


func test_hub_back_button_has_min_width() -> void:
	var btn: Button = _hud.get_node_or_null("TopBar/HubBackButton")
	assert_not_null(btn, "HubBackButton must exist")
	assert_gte(
		btn.custom_minimum_size.x, 80.0,
		"HubBackButton must have custom_minimum_size.x >= 80 to prevent wrapping"
	)


func test_tutorial_step_suppresses_telegraph_card() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	# Trigger a telegraphed event so the card would normally appear.
	EventBus.event_telegraphed.emit("summer_sale", 2)
	var card: Label = _hud.get_node("TelegraphCard")
	assert_true(card.visible, "TelegraphCard should appear before tutorial starts")

	EventBus.tutorial_step_changed.emit("click_store")
	assert_false(
		card.visible,
		"TelegraphCard must be hidden when tutorial hint is active"
	)


func test_tutorial_step_suppresses_new_telegraph_events() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	EventBus.tutorial_step_changed.emit("click_store")
	# Event fires while tutorial is active — card must stay hidden.
	EventBus.event_telegraphed.emit("winter_sale", 3)
	var card: Label = _hud.get_node("TelegraphCard")
	assert_false(
		card.visible,
		"TelegraphCard must not appear while tutorial hint is active"
	)


func test_tutorial_hint_ended_restores_telegraph_card() -> void:
	_emit_state(GameManager.State.MALL_OVERVIEW)
	EventBus.event_telegraphed.emit("summer_sale", 2)
	EventBus.tutorial_step_changed.emit("click_store")
	var card: Label = _hud.get_node("TelegraphCard")
	assert_false(card.visible, "Card must be hidden during tutorial")

	EventBus.tutorial_completed.emit()
	assert_true(
		card.visible,
		"TelegraphCard must re-appear after tutorial_completed restores ticker"
	)


func test_store_view_shows_milestones_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/MilestonesButton").visible,
		"MilestonesButton must be visible in STORE_VIEW"
	)


func test_store_view_hides_store_label_before_store_opened() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_false(
		_hud.get_node("StoreLabel").visible,
		"StoreLabel must be hidden in STORE_VIEW until store_opened fires"
	)


func test_store_view_hides_objective_label_before_objective_text() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_false(
		_hud.get_node("ObjectiveLabel").visible,
		"ObjectiveLabel must be hidden in STORE_VIEW until objective text is set"
	)


func test_store_view_shows_cash_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/CashLabel").visible,
		"CashLabel must be visible in STORE_VIEW"
	)


func test_store_view_shows_time_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/TimeLabel").visible,
		"TimeLabel must be visible in STORE_VIEW"
	)


func test_store_view_shows_reputation_label() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		_hud.get_node("TopBar/ReputationLabel").visible,
		"ReputationLabel must be visible in STORE_VIEW"
	)


func test_store_view_hides_speed_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	assert_false(
		_hud.get_node("TopBar/SpeedButton").visible,
		"SpeedButton must be hidden in STORE_VIEW — it is non-functional outside GAMEPLAY"
	)


func test_reputation_label_has_no_placeholder_text_in_store_view() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_false(
		label.text == "Unknown" and label.visible,
		"ReputationLabel must not display bare 'Unknown' placeholder text in STORE_VIEW"
	)


func test_notification_suppressed_during_tutorial_step() -> void:
	EventBus.tutorial_step_changed.emit("click_store")
	EventBus.notification_requested.emit("Some flavor message")
	var prompt: Label = _hud.get_node("PromptLabel")
	assert_false(
		prompt.visible,
		"PromptLabel must stay hidden when notification_requested fires during an active tutorial step"
	)


func test_critical_notification_shows_during_tutorial_step() -> void:
	EventBus.tutorial_step_changed.emit("click_store")
	EventBus.critical_notification_requested.emit("Make your first sale before closing Day 1.")
	var prompt: Label = _hud.get_node("PromptLabel")
	assert_true(
		prompt.visible,
		"PromptLabel must show for critical_notification_requested even during an active tutorial step"
	)
	assert_eq(
		prompt.text,
		"Make your first sale before closing Day 1.",
		"Prompt text must match the critical message"
	)


func test_notification_shows_after_tutorial_completed() -> void:
	EventBus.tutorial_step_changed.emit("click_store")
	EventBus.tutorial_completed.emit()
	EventBus.notification_requested.emit("Order delivered.")
	var prompt: Label = _hud.get_node("PromptLabel")
	assert_true(
		prompt.visible,
		"PromptLabel must show notification_requested messages after tutorial_completed"
	)


func test_notification_shows_after_tutorial_skipped() -> void:
	EventBus.tutorial_step_changed.emit("click_store")
	EventBus.tutorial_skipped.emit()
	EventBus.notification_requested.emit("Order delivered.")
	var prompt: Label = _hud.get_node("PromptLabel")
	assert_true(
		prompt.visible,
		"PromptLabel must show notification_requested messages after tutorial_skipped"
	)


func test_notification_shows_with_no_tutorial_active() -> void:
	EventBus.notification_requested.emit("Game saved.")
	var prompt: Label = _hud.get_node("PromptLabel")
	assert_true(
		prompt.visible,
		"PromptLabel must show notification_requested when no tutorial step is active"
	)


func test_critical_notification_shows_with_no_tutorial_active() -> void:
	EventBus.critical_notification_requested.emit("Make your first sale before closing Day 1.")
	var prompt: Label = _hud.get_node("PromptLabel")
	assert_true(
		prompt.visible,
		"PromptLabel must show critical_notification_requested when no tutorial step is active"
	)
