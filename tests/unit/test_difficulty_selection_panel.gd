## Tests for DifficultySelectionPanel — card rendering, tier selection, signal emission, and guards.
extends GutTest

const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/difficulty_selection_panel.tscn"
)

var _panel: DifficultySelectionPanel


func before_each() -> void:
	_panel = _SCENE.instantiate() as DifficultySelectionPanel
	add_child_autofree(_panel)
	DifficultySystem.set_tier(&"normal")
	_panel.open()


func test_panel_shows_three_tier_cards() -> void:
	var row: HBoxContainer = _panel.get_node("Panel/Margin/VBox/CardsRow")
	assert_eq(row.get_child_count(), 3, "Panel should display exactly three tier cards")


func test_cards_have_expected_names() -> void:
	var row: HBoxContainer = _panel.get_node("Panel/Margin/VBox/CardsRow")
	assert_not_null(row.get_node_or_null("Card_easy"), "Easy card should exist")
	assert_not_null(row.get_node_or_null("Card_normal"), "Normal card should exist")
	assert_not_null(row.get_node_or_null("Card_hard"), "Hard card should exist")


func test_default_selection_highlights_current_tier() -> void:
	var row: HBoxContainer = _panel.get_node("Panel/Margin/VBox/CardsRow")
	var normal_card: PanelContainer = row.get_node("Card_normal") as PanelContainer
	var easy_card: PanelContainer = row.get_node("Card_easy") as PanelContainer
	assert_eq(
		normal_card.modulate,
		DifficultySelectionPanel._SELECTED_MODULATE,
		"Current tier card should be fully highlighted"
	)
	assert_eq(
		easy_card.modulate,
		DifficultySelectionPanel._DESELECTED_MODULATE,
		"Non-current tier cards should be dimmed"
	)


func test_select_easy_emits_difficulty_confirmed() -> void:
	watch_signals(_panel)
	_panel._on_select_pressed(&"easy")
	assert_signal_emitted(_panel, "difficulty_confirmed", "difficulty_confirmed should fire on selection")
	var params: Array = get_signal_parameters(_panel, "difficulty_confirmed")
	assert_eq(params[0] as StringName, &"easy", "Signal should carry the selected tier_id")


func test_select_calls_difficulty_system_set_tier() -> void:
	_panel._on_select_pressed(&"hard")
	assert_eq(
		DifficultySystem.get_current_tier_id(),
		&"hard",
		"DifficultySystem tier should update to selected tier"
	)


func test_select_hides_panel_after_confirm() -> void:
	_panel._on_select_pressed(&"easy")
	assert_false(_panel.visible, "Panel should hide after confirming a selection")


func test_is_lower_tier_returns_true_for_easier_selection() -> void:
	DifficultySystem.set_tier(&"hard")
	_panel.open()
	assert_true(
		_panel._is_lower_tier(&"easy"),
		"easy should be considered lower than hard"
	)
	assert_true(
		_panel._is_lower_tier(&"normal"),
		"normal should be considered lower than hard"
	)


func test_is_lower_tier_returns_false_for_same_or_harder() -> void:
	DifficultySystem.set_tier(&"normal")
	_panel.open()
	assert_false(
		_panel._is_lower_tier(&"normal"),
		"Same tier should not be lower"
	)
	assert_false(
		_panel._is_lower_tier(&"hard"),
		"Harder tier should not be lower"
	)


func test_no_assisted_warning_when_not_from_pause() -> void:
	DifficultySystem.set_tier(&"hard")
	_panel.open(false)
	var dialog: ConfirmationDialog = _panel.get_node("AssistedWarningDialog")
	_panel._on_select_pressed(&"easy")
	assert_false(
		dialog.visible,
		"Assisted warning should not appear when not opened from pause menu"
	)


func test_assisted_warning_requires_day_greater_than_one() -> void:
	# When day == 1 and from_pause == true, no warning should appear.
	DifficultySystem.set_tier(&"hard")
	_panel._from_pause = true
	var dialog: ConfirmationDialog = _panel.get_node("AssistedWarningDialog")
	# GameManager.current_day defaults to 1 on a fresh session.
	if GameManager.current_day <= 1:
		_panel._on_select_pressed(&"easy")
		assert_false(
			dialog.visible,
			"Assisted warning should not appear on day 1 even from pause"
		)


func test_assisted_canceled_reverts_highlight() -> void:
	DifficultySystem.set_tier(&"hard")
	_panel.open(true)
	_panel._pending_tier_id = &"easy"
	_panel._on_assisted_canceled()
	var row: HBoxContainer = _panel.get_node("Panel/Margin/VBox/CardsRow")
	var hard_card: PanelContainer = row.get_node("Card_hard") as PanelContainer
	assert_eq(
		hard_card.modulate,
		DifficultySelectionPanel._SELECTED_MODULATE,
		"Canceling assisted dialog should revert highlight to current tier"
	)
	assert_eq(
		_panel._pending_tier_id,
		&"",
		"Pending tier should be cleared on cancel"
	)


func test_difficulty_not_changed_when_assisted_dialog_canceled() -> void:
	DifficultySystem.set_tier(&"hard")
	_panel.open(true)
	_panel._pending_tier_id = &"easy"
	_panel._on_assisted_canceled()
	assert_eq(
		DifficultySystem.get_current_tier_id(),
		&"hard",
		"Difficulty should remain unchanged after canceling the assisted dialog"
	)
