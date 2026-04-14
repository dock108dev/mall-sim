## Tests for HagglePanel UI: slider config, timer behavior, button states,
## outcome flash, and signal emission.
extends GutTest


var _panel: HagglePanel


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/haggle_panel.tscn"
	).instantiate() as HagglePanel
	add_child_autofree(_panel)


func test_starts_hidden() -> void:
	assert_false(_panel.visible, "Panel should start hidden")
	assert_false(_panel.is_open(), "Panel should not be open")


func test_show_negotiation_opens_panel() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	assert_true(_panel.is_open(), "Panel should be open after show")


func test_slider_step_is_025() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	var slider: HSlider = _panel._price_slider
	assert_eq(
		slider.step, 0.25,
		"Slider step should be 0.25"
	)


func test_slider_min_is_item_cost() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 12.0, 3)
	var slider: HSlider = _panel._price_slider
	assert_eq(
		slider.min_value, 12.0,
		"Slider min should equal customer offer (item cost floor)"
	)


func test_slider_max_is_sticker_times_15() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 12.0, 3)
	var slider: HSlider = _panel._price_slider
	assert_eq(
		slider.max_value, 30.0,
		"Slider max should be sticker_price * 1.5"
	)


func test_customer_name_displayed() -> void:
	_panel.show_negotiation(
		"Widget", "Good", 20.0, 15.0, 3, 10.0, "Bob"
	)
	assert_eq(
		_panel._customer_name_label.text, "Bob",
		"Customer name should display"
	)


func test_round_label_shows_round_1() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 4)
	assert_eq(
		_panel._round_label.text, "Round 1 / 4",
		"Round label should show initial round"
	)


func test_customer_counter_updates_offer_label() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 5)
	_panel.show_customer_counter(17.5, 2, 5)
	assert_eq(
		_panel._customer_offer_label.text, "$17.50",
		"Offer label should update on customer counter"
	)


func test_customer_counter_updates_round_label() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 5)
	_panel.show_customer_counter(17.5, 3, 5)
	assert_eq(
		_panel._round_label.text, "Round 3 / 5",
		"Round label should update on counter"
	)


func test_timer_bar_starts_full() -> void:
	_panel.show_negotiation(
		"Widget", "Good", 20.0, 15.0, 3, 8.0
	)
	assert_eq(
		_panel._timer_bar.value, 100.0,
		"Timer bar should start at 100%"
	)


func test_timer_depletes_on_process() -> void:
	_panel.show_negotiation(
		"Widget", "Good", 20.0, 15.0, 3, 10.0
	)
	_panel._process(5.0)
	assert_almost_eq(
		_panel._timer_bar.value, 50.0, 0.1,
		"Timer should deplete to ~50% after half the time"
	)


func test_timer_auto_submits_at_zero() -> void:
	_panel.show_negotiation(
		"Widget", "Good", 20.0, 15.0, 3, 5.0
	)
	watch_signals(_panel)
	_panel._process(6.0)
	assert_signal_emitted(
		_panel, "counter_submitted",
		"Timer expiry should auto-submit counter"
	)


func test_buttons_disabled_after_accept() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_panel._on_accept_pressed()
	assert_true(
		_panel._accept_button.disabled,
		"Accept button should be disabled after pressing"
	)
	assert_true(
		_panel._counter_button.disabled,
		"Counter button should be disabled after accept"
	)
	assert_true(
		_panel._reject_button.disabled,
		"Reject button should be disabled after accept"
	)


func test_buttons_disabled_after_counter() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_panel._on_counter_pressed()
	assert_true(
		_panel._counter_button.disabled,
		"Counter button should be disabled after counter"
	)


func test_buttons_disabled_after_reject() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_panel._on_reject_pressed()
	assert_true(
		_panel._reject_button.disabled,
		"Reject button should be disabled after reject"
	)


func test_buttons_reenabled_on_customer_counter() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 5)
	_panel._on_counter_pressed()
	assert_true(
		_panel._accept_button.disabled,
		"Buttons disabled after player counter"
	)
	_panel.show_customer_counter(17.0, 2, 5)
	assert_false(
		_panel._accept_button.disabled,
		"Buttons re-enabled on customer counter"
	)


func test_counter_submits_slider_value() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_panel._price_slider.value = 18.75
	watch_signals(_panel)
	_panel._on_counter_pressed()
	assert_signal_emitted_with_parameters(
		_panel, "counter_submitted", [18.75],
		"Counter should submit current slider value"
	)


func test_accept_emits_offer_accepted() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	watch_signals(_panel)
	_panel._on_accept_pressed()
	assert_signal_emitted(
		_panel, "offer_accepted",
		"Accept should emit offer_accepted"
	)


func test_reject_emits_offer_declined() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	watch_signals(_panel)
	_panel._on_reject_pressed()
	assert_signal_emitted(
		_panel, "offer_declined",
		"Reject should emit offer_declined"
	)


func test_hide_clears_is_open() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_panel.hide_negotiation()
	assert_false(_panel.is_open(), "Panel should not be open after hide")


func test_show_outcome_disables_buttons() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	_panel.show_outcome(true)
	assert_true(
		_panel._accept_button.disabled,
		"Buttons disabled during outcome"
	)


func test_timer_stops_on_accept() -> void:
	_panel.show_negotiation(
		"Widget", "Good", 20.0, 15.0, 3, 10.0
	)
	_panel._on_accept_pressed()
	assert_false(
		_panel._timer_active,
		"Timer should stop on accept"
	)


func test_timer_stops_on_reject() -> void:
	_panel.show_negotiation(
		"Widget", "Good", 20.0, 15.0, 3, 10.0
	)
	_panel._on_reject_pressed()
	assert_false(
		_panel._timer_active,
		"Timer should stop on reject"
	)


func test_portrait_hidden_when_no_texture() -> void:
	_panel.show_negotiation("Widget", "Good", 20.0, 15.0, 3)
	assert_false(
		_panel._customer_portrait.visible,
		"Portrait hidden when no texture provided"
	)
