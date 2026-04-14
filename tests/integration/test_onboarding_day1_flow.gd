## Integration test: Day 1 onboarding hint flow through OnboardingSystem and HintOverlayUI.
extends GutTest


const EXPECTED_DAY_START_HINT_ID: StringName = &"hint_day_start"
const EXPECTED_DAY_START_MESSAGE: String = (
	"A new day begins — check your inventory and set your "
	+ "prices before shoppers arrive."
)
const EXPECTED_DAY_START_POSITION: String = "bottom_left"

var _onboarding: OnboardingSystem
var _hint_overlay: HintOverlayUI
var _received_hint_id: StringName = &""
var _received_message: String = ""
var _received_position: String = ""
var _hint_emit_count: int = 0


func before_each() -> void:
	_received_hint_id = &""
	_received_message = ""
	_received_position = ""
	_hint_emit_count = 0

	_onboarding = OnboardingSystem.new()
	add_child_autofree(_onboarding)

	_hint_overlay = HintOverlayUI.new()
	var label: Label = Label.new()
	label.name = "MessageLabel"
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_child(label)
	_hint_overlay.add_child(margin)
	add_child_autofree(_hint_overlay)

	EventBus.onboarding_hint_shown.connect(_on_hint_shown)


func after_each() -> void:
	if EventBus.onboarding_hint_shown.is_connected(_on_hint_shown):
		EventBus.onboarding_hint_shown.disconnect(_on_hint_shown)


func _on_hint_shown(
	hint_id: StringName, message: String, position: String
) -> void:
	_received_hint_id = hint_id
	_received_message = message
	_received_position = position
	_hint_emit_count += 1


func test_day1_start_triggers_hint_signal() -> void:
	EventBus.day_started.emit(1)
	_onboarding.maybe_show_hint(&"day_start")

	assert_eq(
		_hint_emit_count, 1,
		"onboarding_hint_shown should emit exactly once"
	)
	assert_eq(
		_received_hint_id, EXPECTED_DAY_START_HINT_ID,
		"Hint ID should match onboarding_config.json Day 1 entry"
	)
	assert_eq(
		_received_message, EXPECTED_DAY_START_MESSAGE,
		"Message should match onboarding_config.json Day 1 entry"
	)
	assert_eq(
		_received_position, EXPECTED_DAY_START_POSITION,
		"Position hint should match onboarding_config.json Day 1 entry"
	)


func test_day1_hint_makes_overlay_visible() -> void:
	EventBus.day_started.emit(1)
	_onboarding.maybe_show_hint(&"day_start")

	assert_true(
		_hint_overlay.visible,
		"HintOverlayUI should be visible after hint fires"
	)


func test_day1_hint_sets_overlay_label_text() -> void:
	EventBus.day_started.emit(1)
	_onboarding.maybe_show_hint(&"day_start")

	var label: Label = _hint_overlay.get_node("Margin/MessageLabel")
	assert_eq(
		label.text, EXPECTED_DAY_START_MESSAGE,
		"HintOverlayUI label text should match hint message"
	)


func test_day2_does_not_re_emit_day_start_hint() -> void:
	EventBus.day_started.emit(1)
	_onboarding.maybe_show_hint(&"day_start")
	assert_eq(_hint_emit_count, 1, "Day 1 should emit once")

	_hint_emit_count = 0
	_received_hint_id = &""

	EventBus.day_started.emit(2)
	_onboarding.maybe_show_hint(&"day_start")

	assert_eq(
		_hint_emit_count, 0,
		"onboarding_hint_shown should NOT emit on Day 2"
	)
	assert_eq(
		_received_hint_id, &"",
		"No hint_id should be received on Day 2"
	)


func test_day2_overlay_retains_previous_message() -> void:
	EventBus.day_started.emit(1)
	_onboarding.maybe_show_hint(&"day_start")

	var label: Label = _hint_overlay.get_node("Margin/MessageLabel")
	var day1_text: String = label.text

	EventBus.day_started.emit(2)
	_onboarding.maybe_show_hint(&"day_start")

	assert_eq(
		label.text, day1_text,
		"HintOverlayUI should still show previous message after Day 2"
	)
	assert_eq(
		label.text, EXPECTED_DAY_START_MESSAGE,
		"Label text should remain the Day 1 hint message"
	)
