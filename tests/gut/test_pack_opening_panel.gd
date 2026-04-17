## Tests PackOpeningPanel: staged reveal flow, rarity hold, and commit behavior.
extends GutTest


class FakePackOpeningSystem extends PackOpeningSystem:
	var commit_calls: int = 0
	var last_revealed_cards: Array[Dictionary] = []
	var commit_result: bool = true

	func commit_pack_results(revealed_cards: Array[Dictionary]) -> bool:
		commit_calls += 1
		last_revealed_cards = revealed_cards.duplicate(true)
		return commit_result


var _panel: PackOpeningPanel
var _sample_cards: Array[Dictionary]
var _fake_system: FakePackOpeningSystem


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/pack_opening_panel.tscn"
	).instantiate()
	add_child_autofree(_panel)

	_fake_system = FakePackOpeningSystem.new()
	_panel.pack_opening_system = _fake_system

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
			"rarity": "ultra_rare",
			"value": 12.00,
		},
		{
			"id": "card_006",
			"name": "Bonus Bat",
			"rarity": "common",
			"value": 0.20,
		},
	]


func _get_card_button(index: int) -> Button:
	return _panel._card_row.get_child(index) as Button


func _reveal_card(index: int) -> void:
	_panel._on_card_clicked(_get_card_button(index))


func _await_flip(duration: float = PackOpeningPanel.FLIP_DURATION) -> void:
	await get_tree().create_timer(duration + 0.05).timeout


func _reveal_all_cards() -> void:
	for i: int in range(_panel._card_row.get_child_count()):
		_reveal_card(i)
		await _await_flip()
		if _sample_cards[i]["rarity"] in PackOpeningPanel.RARE_RARITIES:
			await get_tree().create_timer(
				PackOpeningPanel.RARE_HOLD_DURATION + 0.05
			).timeout


func test_panel_starts_closed() -> void:
	assert_false(_panel.is_open(), "Panel should start closed")


func test_pack_opening_started_shows_five_face_down_cards() -> void:
	var cards_typed: Array[Dictionary] = []
	for card: Dictionary in _sample_cards:
		cards_typed.append(card)
	EventBus.pack_opening_started.emit("pack_sig", cards_typed)
	await get_tree().process_frame

	assert_true(_panel.is_open(), "Signal should open the panel")
	assert_eq(
		_panel._card_row.get_child_count(),
		PackOpeningPanel.CARDS_PER_PACK,
		"Panel should only show five face-down cards",
	)
	for i: int in range(_panel._card_row.get_child_count()):
		var button: Button = _get_card_button(i)
		assert_false(
			button.get_meta("revealed", false),
			"Preview card %d should start hidden" % i,
		)


func test_card_flip_uses_tween_instead_of_instant_reveal() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame

	var button: Button = _get_card_button(0)
	var name_label: Label = (
		button.get_node("CardContent/NameLabel") as Label
	)

	_reveal_card(0)
	await get_tree().create_timer(
		PackOpeningPanel.FLIP_DURATION * 0.25
	).timeout
	assert_eq(name_label.text, "?", "Card should stay hidden mid-flip")

	await _await_flip()
	assert_eq(
		name_label.text,
		_sample_cards[0]["name"],
		"Card should reveal after the flip tween completes",
	)


func test_rare_card_blocks_next_reveal_during_hold() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame

	_reveal_card(3)
	await _await_flip()
	assert_true(
		_panel._is_flipping,
		"Rare reveal should keep the panel locked during the fanfare hold",
	)

	await get_tree().create_timer(
		PackOpeningPanel.RARE_HOLD_DURATION + 0.05
	).timeout
	assert_false(
		_panel._is_flipping,
		"Rare reveal lock should clear after the hold duration",
	)


func test_revealed_card_populates_rarity_pip_and_label() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame

	_reveal_card(4)
	await _await_flip()
	await get_tree().create_timer(
		PackOpeningPanel.RARE_HOLD_DURATION + 0.05
	).timeout

	var button: Button = _get_card_button(4)
	var pip: Label = (
		button.get_node("CardContent/RarityRow/RarityPip") as Label
	)
	var rarity_label: Label = (
		button.get_node("CardContent/RarityRow/RarityLabel") as Label
	)
	assert_eq(pip.text, "**", "Ultra-rare cards should show a pip")
	assert_eq(
		rarity_label.text,
		"Ultra Rare",
		"Rarity label should use the preview tier text",
	)


func test_add_button_appears_only_after_all_five_preview_cards_are_revealed() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame

	for i: int in range(PackOpeningPanel.CARDS_PER_PACK - 1):
		_reveal_card(i)
		await _await_flip()
		if _sample_cards[i]["rarity"] in PackOpeningPanel.RARE_RARITIES:
			await get_tree().create_timer(
				PackOpeningPanel.RARE_HOLD_DURATION + 0.05
			).timeout
	assert_false(
		_panel._add_button.visible,
		"Add button must stay hidden until every preview card is revealed",
	)

	_reveal_card(PackOpeningPanel.CARDS_PER_PACK - 1)
	await _await_flip()
	await get_tree().create_timer(
		PackOpeningPanel.RARE_HOLD_DURATION + 0.05
	).timeout
	assert_true(
		_panel._add_button.visible,
		"Add button should appear after the fifth reveal",
	)


func test_total_value_uses_only_revealed_preview_cards() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	await _reveal_all_cards()

	assert_eq(
		_panel._total_value_label.text,
		"Total Value: $23.75",
		"Total value should ignore card data beyond the five-card preview",
	)


func test_add_to_inventory_commits_revealed_cards_and_closes() -> void:
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	await _reveal_all_cards()

	_panel._on_add_to_inventory()
	await get_tree().create_timer(0.3).timeout

	assert_eq(
		_fake_system.commit_calls,
		1,
		"Add to Inventory should commit exactly once",
	)
	assert_eq(
		_fake_system.last_revealed_cards.size(),
		PackOpeningPanel.CARDS_PER_PACK,
		"Panel should pass the five revealed preview cards to the system",
	)
	assert_false(_panel.is_open(), "Panel should close after a successful commit")


func test_failed_commit_keeps_panel_open() -> void:
	_fake_system.commit_result = false
	_panel.open("pack_123", _sample_cards)
	await get_tree().process_frame
	await _reveal_all_cards()

	_panel._on_add_to_inventory()

	assert_true(_panel.is_open(), "Failed commits should keep the panel open")
	assert_false(
		_panel._add_button.disabled,
		"Failed commits should re-enable the confirmation button",
	)


func test_escape_input_is_consumed_without_closing_panel() -> void:
	_panel.open("pack_123", _sample_cards)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true

	_panel._unhandled_input(event)

	assert_true(
		_panel.is_open(),
		"Escape should not dismiss the panel mid-reveal",
	)


func test_rare_rarities_match_issue_tiers() -> void:
	assert_eq(
		PackOpeningPanel.RARE_RARITIES,
		["rare", "ultra_rare"],
		"Rare fanfare should only trigger for Rare and Ultra Rare preview tiers",
	)
