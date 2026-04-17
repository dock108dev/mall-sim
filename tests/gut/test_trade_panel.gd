## GUT coverage for the decomposed trade panel scene wiring and flow.
extends GutTest


const TRADE_PANEL_SCENE := preload("res://game/scenes/ui/trade_panel.tscn")

var _panel: TradePanel


func before_each() -> void:
	_panel = TRADE_PANEL_SCENE.instantiate() as TradePanel
	add_child_autofree(_panel)


func test_show_trade_updates_offer_and_valuation_displays() -> void:
	_panel.show_trade("Wanted Card", "Near Mint", 100.0, "Offer Card", "Good", 95.0)

	var wanted_name: Label = _panel.get_node(
		"Margin/VBox/OfferDisplay/WantedSection/WantedNameLabel"
	) as Label
	var wanted_condition: Label = _panel.get_node(
		"Margin/VBox/OfferDisplay/WantedSection/WantedConditionLabel"
	) as Label
	var offered_value: Label = _panel.get_node(
		"Margin/VBox/OfferDisplay/OfferedSection/OfferedValueLabel"
	) as Label
	var valuation: Label = _panel.get_node(
		"Margin/VBox/FairTradeIndicator"
	) as Label

	assert_eq(wanted_name.text, "Wanted Card", "Wanted name should match the offer")
	assert_eq(
		wanted_condition.text,
		"Condition: Near Mint",
		"Wanted condition should include the condition label"
	)
	assert_eq(
		offered_value.text,
		"Value: $95.00",
		"Offered value should use the currency format"
	)
	assert_eq(valuation.text, "Fair Trade", "Close values should be marked fair")


func test_accept_button_press_emits_trade_accepted_and_disables_actions() -> void:
	_panel.show_trade("Wanted Card", "Good", 50.0, "Offer Card", "Good", 50.0)
	watch_signals(_panel)

	var accept_button: Button = _panel.get_node(
		"Margin/VBox/ButtonRow/AcceptButton"
	) as Button
	var decline_button: Button = _panel.get_node(
		"Margin/VBox/ButtonRow/DeclineButton"
	) as Button
	accept_button.emit_signal("pressed")

	assert_signal_emitted(
		_panel,
		"trade_accepted",
		"Accepting should emit trade_accepted"
	)
	assert_true(accept_button.disabled, "Accept should disable while pending")
	assert_true(decline_button.disabled, "Decline should disable while pending")


func test_decline_button_press_emits_trade_declined() -> void:
	_panel.show_trade("Wanted Card", "Good", 50.0, "Offer Card", "Fair", 30.0)
	watch_signals(_panel)

	var decline_button: Button = _panel.get_node(
		"Margin/VBox/ButtonRow/DeclineButton"
	) as Button
	decline_button.emit_signal("pressed")

	assert_signal_emitted(
		_panel,
		"trade_declined",
		"Declining should emit trade_declined"
	)
