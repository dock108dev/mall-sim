## Tests PackOpeningPanel: open/close lifecycle, card creation,
## click-to-flip reveal, rarity hold, and add-to-inventory flow.
extends GutTest

var _panel: PackOpeningPanel
var _sample_cards: Array[Dictionary]


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/pack_opening_panel.tscn"
	).instantiate()
	add_child_autofree(_panel)

	_sample_cards = [
		{
			"id": "card_001",
			"name": "Fire Lizard",
			"rarity": "common",
			"value": 0.50,
		},
		{
			"id": "card_002",
			"name": "Water Turtle",
			"rarity": "common",
			"value": 0.75,
		},
		{
			"id": "card_003",
			"name": "Vine Frog",
			"rarity": "uncommon",
			"value": 2.00,
		},
		{
			"id": "card_004",
			"name": "Thunder Mouse",
			"rarity": "rare",
			"value": 8.50,
		},
		{
			"id": "card_005",
			"name": "Psychic Cat",
			"rarity": "common",
			"value": 0.60,
		},
	]


# --- Open / Close ---


func test_panel_starts_closed() -> void:
	assert_false(
		_panel.is_open(),
		"Panel should start closed"
	)


func test_open_sets_is_open() -> void:
	_panel.open("pack_123", _sample_cards)
	assert_true(
		_panel.is_open(),
		"Panel should be open after open()"
	)


func test_close_sets_is_closed() -> void:
	_panel.open("pack_123", _sample_cards)
	_panel.close()
	assert_false(
		_panel.is_open(),
		"Panel should be closed after close()"
	)


func test_open_while_open_is_noop() -> void:
	_panel.open("pack_123", _sample_cards)
	_panel.open("pack_456", _sample_cards)
	assert_eq(
		_panel._pack_id, "pack_123",
		"Second open should be ignored while already open"
	)


func test_close_while_closed_is_noop() -> void:
	_panel.close()
	assert_false(
		_panel.is_open(),
		"close() on closed panel should be safe"
	)


# --- Card creation ---


func test_creates_five_card_buttons() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	assert_eq(
		_panel._card_row.get_child_count(), 5,
		"Should create 5 face-down card buttons"
	)


func test_cards_start_unrevealed() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	for i: int in range(_panel._card_row.get_child_count()):
		var btn: Button = (
			_panel._card_row.get_child(i) as Button
		)
		assert_false(
			btn.get_meta("revealed", false),
			"Card %d should start unrevealed" % i
		)


func test_card_has_name_label_with_question_mark() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	var btn: Button = (
		_panel._card_row.get_child(0) as Button
	)
	var vbox: VBoxContainer = (
		btn.get_node("CardContent") as VBoxContainer
	)
	var name_label: Label = (
		vbox.get_node("NameLabel") as Label
	)
	assert_eq(
		name_label.text, "?",
		"Unrevealed card should show '?'"
	)


# --- Reveal flow ---


func test_add_button_hidden_before_all_revealed() -> void:
	_panel.open("pack_123", _sample_cards)
	assert_false(
		_panel._add_button.visible,
		"Add button should be hidden before all cards revealed"
	)


func test_revealed_count_starts_at_zero() -> void:
	_panel.open("pack_123", _sample_cards)
	assert_eq(
		_panel._revealed_count, 0,
		"Revealed count should start at zero"
	)


# --- Total value ---


func test_total_value_empty_before_reveal() -> void:
	_panel.open("pack_123", _sample_cards)
	assert_eq(
		_panel._total_value_label.text, "",
		"Total value should be empty before all revealed"
	)


# --- EventBus integration ---


func test_open_emits_panel_opened() -> void:
	watch_signals(EventBus)
	_panel.open("pack_123", _sample_cards)
	assert_signal_emitted_with_parameters(
		EventBus,
		"panel_opened",
		[PackOpeningPanel.PANEL_NAME],
	)


func test_close_emits_panel_closed_after_anim() -> void:
	_panel.open("pack_123", _sample_cards)
	watch_signals(EventBus)
	_panel.close()
	await get_tree().create_timer(0.3).timeout
	assert_signal_emitted_with_parameters(
		EventBus,
		"panel_closed",
		[PackOpeningPanel.PANEL_NAME],
	)


func test_pack_opening_started_signal_opens_panel() -> void:
	var cards_typed: Array[Dictionary] = []
	for c: Dictionary in _sample_cards:
		cards_typed.append(c)
	EventBus.pack_opening_started.emit("pack_sig", cards_typed)
	assert_true(
		_panel.is_open(),
		"pack_opening_started signal should open the panel"
	)


# --- Card data ---


func test_card_index_meta_correct() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	for i: int in range(_panel._card_row.get_child_count()):
		var btn: Button = (
			_panel._card_row.get_child(i) as Button
		)
		assert_eq(
			btn.get_meta("card_index", -1), i,
			"Card %d should have correct index meta" % i
		)


func test_fewer_than_five_cards_handled() -> void:
	var small_pack: Array[Dictionary] = [
		{
			"id": "card_001",
			"name": "Solo Card",
			"rarity": "common",
			"value": 1.0,
		},
	]
	_panel.open("pack_small", small_pack)
	await get_tree().process_frame
	assert_eq(
		_panel._card_row.get_child_count(), 1,
		"Should handle fewer than 5 cards"
	)


# --- Background overlay ---


func test_background_visible_when_open() -> void:
	_panel.open("pack_123", _sample_cards)
	assert_true(
		_panel._background.visible,
		"Darkened background should be visible when open"
	)


func test_background_hidden_when_closed() -> void:
	_panel.open("pack_123", _sample_cards)
	_panel.close()
	assert_false(
		_panel._background.visible,
		"Background should be hidden after close"
	)


# --- Rarity constants ---


func test_rare_rarities_include_rare() -> void:
	assert_true(
		"rare" in PackOpeningPanel.RARE_RARITIES,
		"RARE_RARITIES should include 'rare'"
	)


func test_rare_rarities_include_very_rare() -> void:
	assert_true(
		"very_rare" in PackOpeningPanel.RARE_RARITIES,
		"RARE_RARITIES should include 'very_rare'"
	)


func test_rare_rarities_include_legendary() -> void:
	assert_true(
		"legendary" in PackOpeningPanel.RARE_RARITIES,
		"RARE_RARITIES should include 'legendary'"
	)


func test_rare_rarities_exclude_common() -> void:
	assert_false(
		"common" in PackOpeningPanel.RARE_RARITIES,
		"RARE_RARITIES should not include 'common'"
	)
