## GUT tests for hub store card status string, urgency indicator, and KPI strip
## value updates on day-close. Exercises the EventBus-driven binding only —
## no game world or save system needed.
extends GutTest


const _STORE_ID: StringName = &"retro_games"
const _STORE_NAME: String = "Retro Games"


func _make_card() -> StorefrontCard:
	var card: StorefrontCard = preload(
		"res://game/scenes/mall/storefront_card.tscn"
	).instantiate() as StorefrontCard
	card.store_id = _STORE_ID
	card.display_name = _STORE_NAME
	add_child_autofree(card)
	return card


func _make_kpi() -> PanelContainer:
	var kpi: PanelContainer = preload(
		"res://game/scenes/ui/kpi_strip.tscn"
	).instantiate() as PanelContainer
	add_child_autofree(kpi)
	return kpi


# ── StorefrontCard status string ──────────────────────────────────────────────

func test_card_status_is_day_active_initially() -> void:
	var card := _make_card()
	assert_eq(card._status_label.text, "Day active")


func test_card_status_updates_to_day_closed_on_day_closed_signal() -> void:
	var card := _make_card()
	EventBus.day_closed.emit(1, {"store_revenue": {_STORE_ID: 0.0}})
	assert_eq(card._status_label.text, "Day closed")


func test_card_status_resets_to_day_active_on_day_started() -> void:
	var card := _make_card()
	EventBus.day_closed.emit(1, {"store_revenue": {}})
	EventBus.day_started.emit(2)
	assert_eq(card._status_label.text, "Day active")


func test_card_status_shows_revenue_when_nonzero() -> void:
	var card := _make_card()
	EventBus.day_closed.emit(1, {"store_revenue": {_STORE_ID: 250.0}})
	assert_true(
		card._status_label.text.begins_with("Day closed"),
		"Status must begin with 'Day closed' when revenue > 0"
	)
	assert_true(
		"250" in card._status_label.text,
		"Status must include the revenue amount"
	)


func test_card_revenue_label_updates_from_day_closed_summary() -> void:
	var card := _make_card()
	EventBus.day_closed.emit(1, {"store_revenue": {_STORE_ID: 99.0}})
	assert_true(
		"99" in card._preview_revenue_label.text,
		"Preview revenue label must show the day's revenue"
	)


func test_card_revenue_label_shows_placeholder_before_any_day_close() -> void:
	var card := _make_card()
	assert_eq(card._preview_revenue_label.text, "Last day: --")


# ── StorefrontCard urgency indicator ─────────────────────────────────────────

func test_urgency_dot_is_visible() -> void:
	var card := _make_card()
	assert_true(card._urgency_dot.visible)


func test_urgency_dot_turns_green_when_day_closed() -> void:
	var card := _make_card()
	EventBus.day_closed.emit(1, {"store_revenue": {}})
	assert_almost_eq(
		card._urgency_dot.color.g,
		UIThemeConstants.POSITIVE_COLOR.g,
		0.05,
		"Urgency dot must be positive (green) after day close"
	)


# ── StorefrontCard preview panel ─────────────────────────────────────────────

func test_preview_panel_hidden_by_default() -> void:
	var card := _make_card()
	assert_false(card._preview_panel.visible)


# ── StorefrontCard highlight via hub_store_highlighted ───────────────────────

func test_hub_store_highlighted_triggers_frame_color_change() -> void:
	var card := _make_card()
	var original_color: Color = card._frame.color
	EventBus.hub_store_highlighted.emit(_STORE_ID)
	assert_ne(
		card._frame.color,
		original_color,
		"Frame color must change immediately when hub_store_highlighted fires"
	)


func test_hub_store_highlighted_ignores_other_store_ids() -> void:
	var card := _make_card()
	var original_color: Color = card._frame.color
	EventBus.hub_store_highlighted.emit(&"sports")
	assert_eq(
		card._frame.color,
		original_color,
		"Card must not react to hub_store_highlighted for a different store"
	)


# ── KPI strip label updates ───────────────────────────────────────────────────

func test_kpi_day_label_updates_on_day_started() -> void:
	var kpi := _make_kpi()
	EventBus.day_started.emit(7)
	assert_eq(kpi._day_label.text, "Day 7")


func test_kpi_cash_label_updates_on_money_changed() -> void:
	var kpi := _make_kpi()
	EventBus.money_changed.emit(0.0, 1500.0)
	assert_true(
		"1500" in kpi._cash_label.text,
		"Cash label must display the new amount"
	)


func test_kpi_rep_label_updates_on_reputation_changed() -> void:
	var kpi := _make_kpi()
	EventBus.reputation_changed.emit("retro_games", 0.0, 55.0)
	assert_eq(kpi._rep_label.text, "Reputable")


func test_kpi_rep_label_shows_unknown_at_zero() -> void:
	var kpi := _make_kpi()
	assert_eq(kpi._rep_label.text, "Unknown")


func test_kpi_milestone_bar_increments_on_milestone_reached() -> void:
	var kpi := _make_kpi()
	var initial: float = kpi._milestone_bar.value
	EventBus.milestone_reached.emit(&"first_sale")
	assert_gt(
		kpi._milestone_bar.value,
		initial,
		"Milestone bar value must increase after milestone_reached"
	)


func test_kpi_day_label_refreshes_on_day_closed() -> void:
	var kpi := _make_kpi()
	EventBus.day_started.emit(3)
	EventBus.day_closed.emit(3, {})
	assert_eq(kpi._day_label.text, "Day 3")


# ── Day-close integration: both card and KPI strip update together ────────────

func test_card_and_kpi_both_update_on_day_close() -> void:
	var card := _make_card()
	var kpi := _make_kpi()
	EventBus.day_started.emit(4)
	EventBus.money_changed.emit(0.0, 800.0)
	EventBus.day_closed.emit(4, {"store_revenue": {_STORE_ID: 200.0}})

	assert_eq(card._status_label.text.substr(0, 10), "Day closed")
	assert_eq(kpi._day_label.text, "Day 4")
	assert_true("800" in kpi._cash_label.text)
