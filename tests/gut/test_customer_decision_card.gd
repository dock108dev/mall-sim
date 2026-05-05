## Tests CheckoutPanel customer-decision-card augmentation: archetype label
## derivation, six-element population, two-line consequence preview, bundle
## gating, post-selection result state, and absence of regressions when no
## customer card is provided.
extends GutTest


var _panel: CheckoutPanel
var _haggle_panel: HagglePanel


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/checkout_panel.tscn"
	).instantiate() as CheckoutPanel
	add_child_autofree(_panel)
	_haggle_panel = preload(
		"res://game/scenes/ui/haggle_panel.tscn"
	).instantiate() as HagglePanel
	add_child_autofree(_haggle_panel)


func _make_profile(
	archetype_id: StringName = &"",
	patience: float = 0.5,
	price_sensitivity: float = 0.5,
) -> CustomerTypeDefinition:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.customer_name = "Test"
	profile.archetype_id = archetype_id
	profile.patience = patience
	profile.price_sensitivity = price_sensitivity
	profile.budget_range = [10.0, 50.0]
	profile.mood_tags = PackedStringArray(["wistful"])
	return profile


func _basic_card(
	overrides: Dictionary = {}
) -> Dictionary:
	var data: Dictionary = {
		"archetype_id": &"collector",
		"archetype_label": "Collector",
		"want": "She wants the cartridge.",
		"context": "Mood: focused — budget around $40–$80.",
		"reasoning": "Knows the market. Price honestly.",
		"offer_price": 24.99,
		"sticker_price": 24.99,
		"rep_delta": "+1 Rep",
		"decline_label": "Customer leaves, −Rep",
	}
	for key in overrides:
		data[key] = overrides[key]
	return data


# --- Archetype derivation ---


func test_archetype_uses_explicit_id_when_set() -> void:
	var profile: CustomerTypeDefinition = _make_profile(&"collector")
	var info: Dictionary = CheckoutPanel.derive_archetype_label(profile)
	assert_eq(
		StringName(info.get("archetype_id", &"")), &"collector",
		"Explicit archetype_id should be returned"
	)
	assert_eq(
		info.get("conflict", -1),
		DecisionCardStyle.ConflictLevel.NEUTRAL,
		"Collector is a neutral archetype"
	)


func test_archetype_id_humanized_label() -> void:
	var profile: CustomerTypeDefinition = _make_profile(&"angry_return_customer")
	var info: Dictionary = CheckoutPanel.derive_archetype_label(profile)
	assert_string_contains(
		String(info.get("label", "")), "Angry"
	)


func test_archetype_derived_from_traits_when_id_empty() -> void:
	# High price sensitivity, low patience → bargain hunter (tension)
	var profile: CustomerTypeDefinition = _make_profile(&"", 0.3, 0.9)
	var info: Dictionary = CheckoutPanel.derive_archetype_label(profile)
	assert_eq(
		StringName(info.get("archetype_id", &"")), &"bargain_hunter",
		"High price sensitivity should derive bargain_hunter"
	)
	assert_eq(
		info.get("conflict", -1),
		DecisionCardStyle.ConflictLevel.TENSION,
		"Bargain hunter is a tension archetype"
	)


func test_archetype_derived_collector_when_low_sensitivity_high_patience() -> void:
	var profile: CustomerTypeDefinition = _make_profile(&"", 0.9, 0.2)
	var info: Dictionary = CheckoutPanel.derive_archetype_label(profile)
	assert_eq(
		StringName(info.get("archetype_id", &"")), &"collector",
		"Low sensitivity + high patience should derive collector"
	)


func test_null_profile_returns_neutral_default() -> void:
	var info: Dictionary = CheckoutPanel.derive_archetype_label(null)
	assert_eq(info.get("label", "x"), "")
	assert_eq(
		info.get("conflict", -1),
		DecisionCardStyle.ConflictLevel.NEUTRAL,
		"Null profile must default to neutral"
	)


# --- Conflict-color encoding ---


func test_low_conflict_archetype_returns_green_color() -> void:
	var color: Color = DecisionCardStyle.archetype_color(&"confused_parent")
	assert_eq(
		color, DecisionCardStyle.ARCHETYPE_COLOR_LOW,
		"Confused parent must use the low-conflict color"
	)


func test_neutral_archetype_returns_amber_color() -> void:
	var color: Color = DecisionCardStyle.archetype_color(&"collector")
	assert_eq(
		color, DecisionCardStyle.ARCHETYPE_COLOR_NEUTRAL,
		"Collector must use the neutral-conflict color"
	)


func test_tension_archetype_returns_red_color() -> void:
	var color: Color = DecisionCardStyle.archetype_color(&"bargain_hunter")
	assert_eq(
		color, DecisionCardStyle.ARCHETYPE_COLOR_TENSION,
		"Bargain hunter must use the tension color"
	)


func test_unknown_archetype_falls_back_to_neutral() -> void:
	var color: Color = DecisionCardStyle.archetype_color(&"made_up_id")
	assert_eq(
		color, DecisionCardStyle.ARCHETYPE_COLOR_NEUTRAL,
		"Unknown archetype must default to neutral instead of crashing"
	)


# --- Card population: six elements ---


func test_populate_shows_archetype_badge() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	await get_tree().process_frame
	assert_true(
		_panel._archetype_badge.visible,
		"Archetype badge should be visible after populate"
	)
	assert_string_contains(
		_panel._archetype_label.text, "COLLECTOR"
	)


func test_populate_shows_want_text() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	await get_tree().process_frame
	assert_eq(_panel._want_label.text, "She wants the cartridge.")
	assert_true(_panel._want_label.visible)


func test_populate_shows_context_text() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	await get_tree().process_frame
	assert_string_contains(
		_panel._context_label.text, "focused"
	)


func test_populate_shows_reasoning_with_italic_bbcode() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	await get_tree().process_frame
	assert_true(
		_panel._reasoning_label.visible,
		"Reasoning label should be visible"
	)
	assert_string_contains(
		_panel._reasoning_label.text, "[i]"
	)
	assert_string_contains(
		_panel._reasoning_label.text, "[/i]"
	)


func test_populate_renders_two_line_confirm_button() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card({"offer_price": 24.99, "sticker_price": 24.99}))
	await get_tree().process_frame
	assert_string_contains(_panel._confirm_button.text, "24.99")
	var consequence: Node = _panel._confirm_button.get_node_or_null("ConsequenceLabel")
	assert_not_null(
		consequence,
		"Confirm button should have a ConsequenceLabel child"
	)
	assert_string_contains(
		(consequence as Label).text, "Rep"
	)


func test_populate_renders_two_line_cancel_button() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	await get_tree().process_frame
	assert_eq(_panel._cancel_button.text, "Pass")
	var consequence: Node = _panel._cancel_button.get_node_or_null("ConsequenceLabel")
	assert_not_null(
		consequence,
		"Cancel button should have a ConsequenceLabel child"
	)


# --- Result state ---


func test_show_result_displays_resolution_text() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	_panel.show_result("Sold for $24.99. They smiled.")
	await get_tree().process_frame
	assert_true(_panel.is_showing_result())
	assert_true(_panel._result_label.visible)
	assert_string_contains(_panel._result_label.text, "Sold")


func test_result_state_hides_buttons() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	_panel.show_result("Sold for $24.99.")
	await get_tree().process_frame
	assert_false(_panel._confirm_button.visible)
	assert_false(_panel._cancel_button.visible)


func test_result_empty_text_is_no_op() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	_panel.show_result("")
	await get_tree().process_frame
	assert_false(
		_panel.is_showing_result(),
		"Empty resolution text should not enter result state"
	)


func test_cancel_with_card_enters_result_state() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	watch_signals(_panel)
	_panel._on_cancel_pressed()
	await get_tree().process_frame
	assert_signal_emitted(_panel, "sale_declined")
	assert_true(
		_panel.is_showing_result(),
		"Cancel with populated card should transition to result state"
	)


func test_success_with_card_enters_result_state() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	_panel._on_confirm_pressed()
	_panel._on_transaction_completed(24.99, true, "")
	await get_tree().process_frame
	assert_true(
		_panel.is_showing_result(),
		"Successful sale with card should show result state instead of receipt"
	)
	assert_false(
		_panel.is_showing_receipt(),
		"Receipt path should be skipped when card was populated"
	)


# --- Bundle suggestion gating ---


func test_bundle_button_hidden_by_default() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	await get_tree().process_frame
	assert_false(
		_panel._bundle_button.visible,
		"Bundle button must stay hidden when no bundle data is supplied"
	)


func test_bundle_button_shown_when_bundle_data_provided() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 75.0}])
	var data: Dictionary = _basic_card({
		"bundle": {
			"id": "accessory_1",
			"label": "Suggest Bundle: Memory Card",
			"consequence": "+$9.99 if accepted | −0.5 Rep if declined",
			"price": 9.99,
		}
	})
	_panel.populate_customer_card(data)
	await get_tree().process_frame
	assert_true(_panel._bundle_button.visible)
	assert_string_contains(
		_panel._bundle_button.text, "Bundle"
	)


func test_bundle_press_emits_signal_and_returns_payload() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 75.0}])
	var data: Dictionary = _basic_card({
		"bundle": {
			"id": "accessory_1",
			"label": "Suggest Bundle: Memory Card",
			"consequence": "+$9.99",
			"price": 9.99,
		}
	})
	_panel.populate_customer_card(data)
	watch_signals(_panel)
	_panel._on_bundle_pressed()
	assert_signal_emitted(_panel, "bundle_suggested")
	var payload: Dictionary = _panel.get_active_bundle()
	assert_eq(str(payload.get("id", "")), "accessory_1")


# --- Regression: no customer card → existing flow ---


func test_show_checkout_without_card_shows_receipt_path() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel._on_confirm_pressed()
	_panel._on_transaction_completed(25.0, true, "")
	assert_true(
		_panel.is_showing_receipt(),
		"Without a populated card, receipt should still appear"
	)
	assert_false(
		_panel.is_showing_result(),
		"Result state should not be entered when card is absent"
	)


func test_show_checkout_without_card_hides_archetype_badge() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	await get_tree().process_frame
	assert_false(
		_panel._archetype_badge.visible,
		"Archetype badge must be hidden when no customer is bound"
	)
	assert_false(_panel._customer_card.visible)
	assert_false(_panel._reasoning_label.visible)
	assert_false(_panel._bundle_button.visible)


# --- Card visual contract ---


func test_card_border_uses_shared_constant() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	await get_tree().process_frame
	var sb: StyleBox = _panel._panel.get_theme_stylebox("panel")
	assert_true(sb is StyleBoxFlat, "Panel stylebox should be StyleBoxFlat")
	if sb is StyleBoxFlat:
		var flat: StyleBoxFlat = sb as StyleBoxFlat
		assert_eq(
			flat.border_width_top,
			DecisionCardStyle.CARD_BORDER_WIDTH,
			"Top border width must match the shared constant"
		)
		assert_eq(
			flat.corner_radius_top_left,
			DecisionCardStyle.CARD_CORNER_RADIUS,
			"Corner radius must match the shared midday-card constant"
		)


func test_result_state_uses_desaturated_palette() -> void:
	_panel.show_checkout([{"item_name": "X", "condition": "Good", "price": 25.0}])
	_panel.populate_customer_card(_basic_card())
	var active_sb: StyleBox = _panel._panel.get_theme_stylebox("panel")
	var active_color: Color = (active_sb as StyleBoxFlat).bg_color
	_panel.show_result("Sold")
	await get_tree().process_frame
	var result_sb: StyleBox = _panel._panel.get_theme_stylebox("panel")
	var result_color: Color = (result_sb as StyleBoxFlat).bg_color
	assert_ne(
		active_color, result_color,
		"Active vs result palette must be visually distinct"
	)
	assert_eq(
		result_color, DecisionCardStyle.CARD_RESULT_BG_COLOR,
		"Result palette must use the desaturated background"
	)


# --- Haggle panel augmentation ---


func test_haggle_populate_shows_archetype_badge() -> void:
	_haggle_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_haggle_panel.populate_customer_card({
		"archetype_id": &"haggler",
		"archetype_label": "Haggler",
		"context": "She'll push for $2 off.",
		"reasoning": "Drop a few bucks and she'll close.",
		"accept_consequence": "Take $15.00 — done.",
		"counter_consequence": "Push back — they may walk.",
		"reject_consequence": "−2 Rep.",
	})
	await get_tree().process_frame
	assert_true(_haggle_panel._archetype_badge.visible)
	assert_string_contains(
		_haggle_panel._archetype_label.text, "HAGGLER"
	)
	assert_true(_haggle_panel._reasoning_label.visible)


func test_haggle_show_result_displays_text() -> void:
	_haggle_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_haggle_panel.populate_customer_card({
		"archetype_label": "Haggler",
		"context": "—",
	})
	_haggle_panel.show_result("Deal closed at $18.00.")
	await get_tree().process_frame
	assert_true(_haggle_panel.is_showing_result())
	assert_true(_haggle_panel._result_label.visible)
	assert_string_contains(
		_haggle_panel._result_label.text, "Deal"
	)


func test_haggle_panel_no_card_keeps_existing_flow() -> void:
	# Without populate, existing labels must remain functional and badge hidden.
	_haggle_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3, 10.0, "Bob")
	await get_tree().process_frame
	assert_eq(_haggle_panel._customer_name_label.text, "Bob")
	assert_false(_haggle_panel._archetype_badge.visible)
	assert_false(_haggle_panel._reasoning_label.visible)
	assert_false(_haggle_panel.is_card_populated())
