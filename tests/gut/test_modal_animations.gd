## Tests that modal animation panels use PanelAnimator correctly:
## _anim_tween variable exists, kill_tween called before animations,
## and slide/modal open/close are wired up.
extends GutTest


const HAGGLE_PANEL_SCENE := preload("res://game/scenes/ui/haggle_panel.tscn")
const TRADE_PANEL_SCENE := preload("res://game/scenes/ui/trade_panel.tscn")

var _haggle: HagglePanel
var _trade: TradePanel


func before_each() -> void:
	_haggle = HAGGLE_PANEL_SCENE.instantiate() as HagglePanel
	add_child_autofree(_haggle)

	_trade = TRADE_PANEL_SCENE.instantiate() as TradePanel
	add_child_autofree(_trade)


func test_haggle_panel_has_anim_tween() -> void:
	assert_has(_haggle, "_anim_tween", "HagglePanel should have _anim_tween")


func test_trade_panel_has_anim_tween() -> void:
	assert_has(_trade, "_anim_tween", "TradePanel should have _anim_tween")


func test_haggle_panel_starts_hidden() -> void:
	assert_false(_haggle.visible, "HagglePanel should start hidden")
	assert_false(_haggle.is_open(), "HagglePanel should not be open")


func test_trade_panel_starts_hidden() -> void:
	assert_false(_trade.visible, "TradePanel should start hidden")
	assert_false(_trade.is_open(), "TradePanel should not be open")


func test_haggle_open_sets_is_open() -> void:
	_haggle.show_negotiation("Test Item", "good", 10.0, 8.0, 3)
	assert_true(_haggle.is_open(), "HagglePanel should be open after show")


func test_haggle_close_clears_is_open() -> void:
	_haggle.show_negotiation("Test Item", "good", 10.0, 8.0, 3)
	_haggle.hide_negotiation()
	assert_false(_haggle.is_open(), "HagglePanel should not be open after hide")


func test_trade_open_sets_is_open() -> void:
	_trade.show_trade("Card A", "mint", 50.0, "Card B", "good", 30.0)
	assert_true(_trade.is_open(), "TradePanel should be open after show")


func test_trade_close_clears_is_open() -> void:
	_trade.show_trade("Card A", "mint", 50.0, "Card B", "good", 30.0)
	_trade.hide_trade()
	assert_false(_trade.is_open(), "TradePanel should not be open after hide")


func test_haggle_rapid_open_close_no_crash() -> void:
	for i: int in range(5):
		_haggle.show_negotiation("Item", "good", 10.0, 8.0, 3)
		_haggle.hide_negotiation()
	assert_false(
		_haggle.is_open(),
		"HagglePanel should survive rapid open/close"
	)


func test_trade_rapid_open_close_no_crash() -> void:
	for i: int in range(5):
		_trade.show_trade("A", "mint", 50.0, "B", "good", 30.0)
		_trade.hide_trade()
	assert_false(
		_trade.is_open(),
		"TradePanel should survive rapid open/close"
	)


func test_haggle_panel_has_feedback_tween() -> void:
	assert_has(
		_haggle, "_feedback_tween",
		"HagglePanel should have _feedback_tween for result animations"
	)


func test_trade_panel_has_feedback_tween() -> void:
	assert_has(
		_trade, "_feedback_tween",
		"TradePanel should have _feedback_tween for result animations"
	)


func test_haggle_accept_emits_signal() -> void:
	_haggle.show_negotiation("Test Item", "good", 10.0, 8.0, 3)
	watch_signals(_haggle)
	_haggle._on_accept_pressed()
	assert_signal_emitted(
		_haggle, "offer_accepted",
		"Accept should emit offer_accepted signal"
	)


func test_haggle_decline_emits_signal() -> void:
	_haggle.show_negotiation("Test Item", "good", 10.0, 8.0, 3)
	watch_signals(_haggle)
	_haggle._on_reject_pressed()
	assert_signal_emitted(
		_haggle, "offer_declined",
		"Reject should emit offer_declined signal"
	)


func test_trade_accept_emits_signal() -> void:
	_trade.show_trade("Card A", "mint", 50.0, "Card B", "good", 30.0)
	watch_signals(_trade)
	_trade._on_accept_pressed()
	assert_signal_emitted(
		_trade, "trade_accepted",
		"Accept should emit trade_accepted signal"
	)


func test_trade_decline_emits_signal() -> void:
	_trade.show_trade("Card A", "mint", 50.0, "Card B", "good", 30.0)
	watch_signals(_trade)
	_trade._on_decline_pressed()
	assert_signal_emitted(
		_trade, "trade_declined",
		"Decline should emit trade_declined signal"
	)
