## GUT unit tests for MomentCard: character name display, dismiss button,
## countdown progress, and display-style helpers.
extends GutTest


func _make_card() -> MomentCard:
	var scene: PackedScene = load("res://game/scenes/ui/moment_card.tscn")
	assert_not_null(scene, "moment_card.tscn must be loadable")
	var card: MomentCard = scene.instantiate() as MomentCard
	add_child_autofree(card)
	return card


# ── setup ────────────────────────────────────────────────────────────────────


func test_setup_stores_moment_id() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"test_moment", "Some text.", 5.0)
	assert_eq(card.get_moment_id(), &"test_moment")


func test_setup_stores_duration() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"dur_test", "Text.", 8.0)
	assert_eq(card.get_duration(), 8.0)


func test_setup_clamps_below_minimum_duration() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"clamp_test", "Text.", 0.0)
	assert_gte(card.get_duration(), 0.5, "Duration should be at least 0.5 s")


func test_setup_stores_time_remaining_equal_to_duration() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"time_test", "Text.", 6.0)
	assert_almost_eq(card.get_time_remaining(), 6.0, 0.001)


# ── character name ───────────────────────────────────────────────────────────


func test_character_name_label_exists() -> void:
	var card: MomentCard = _make_card()
	var label: Label = card.get_node_or_null("Margin/VBox/Header/CharacterName")
	assert_not_null(label, "CharacterName label node must exist")


func test_character_name_hidden_when_empty() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"no_name", "Flavor text.", 5.0, "")
	var label: Label = card.get_node_or_null("Margin/VBox/Header/CharacterName") as Label
	if label:
		assert_false(label.visible, "CharacterName should be hidden when name is empty")


func test_character_name_visible_when_provided() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"named", "Flavor text.", 5.0, "Odalys")
	var label: Label = card.get_node_or_null("Margin/VBox/Header/CharacterName") as Label
	if label:
		assert_true(label.visible, "CharacterName should be visible when provided")
		assert_eq(label.text, "Odalys")


# ── dismiss button ────────────────────────────────────────────────────────────


func test_dismiss_button_exists() -> void:
	var card: MomentCard = _make_card()
	var btn: Button = card.get_node_or_null("Margin/VBox/Header/DismissButton") as Button
	assert_not_null(btn, "DismissButton must exist in the scene")


func test_dismiss_signal_emitted_on_button_press() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"dismiss_test", "Text.", 10.0)
	var received: Array[StringName] = []
	card.dismissed.connect(func(mid: StringName) -> void: received.append(mid))
	var btn: Button = card.get_node_or_null("Margin/VBox/Header/DismissButton") as Button
	if btn:
		btn.pressed.emit()
	assert_eq(received.size(), 1, "dismissed should emit once on button press")
	if received.size() > 0:
		assert_eq(received[0], &"dismiss_test")


func test_dismiss_does_not_double_fire() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"double_test", "Text.", 10.0)
	var count: Array = [0]
	card.dismissed.connect(func(_mid: StringName) -> void: count[0] += 1)
	var btn: Button = card.get_node_or_null("Margin/VBox/Header/DismissButton") as Button
	if btn:
		btn.pressed.emit()
		btn.pressed.emit()
	assert_eq(count[0], 1, "dismissed must not fire twice on double press")


# ── pause / resume ────────────────────────────────────────────────────────────


func test_paused_flag_defaults_false() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"pause_default", "Text.", 5.0)
	assert_false(card.is_paused())


func test_pause_sets_flag() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"pause_set", "Text.", 5.0)
	card.pause_countdown()
	assert_true(card.is_paused())


func test_resume_clears_flag() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"resume_clear", "Text.", 5.0)
	card.pause_countdown()
	card.resume_countdown()
	assert_false(card.is_paused())


# ── extend_duration ───────────────────────────────────────────────────────────


func test_extend_duration_increases_remaining_time() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"extend_test", "Text.", 5.0)
	card.extend_duration(3.0)
	assert_almost_eq(card.get_time_remaining(), 8.0, 0.001)


func test_extend_duration_ignores_negative_values() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"extend_neg", "Text.", 5.0)
	card.extend_duration(-10.0)
	assert_almost_eq(card.get_time_remaining(), 5.0, 0.001)


# ── display style ─────────────────────────────────────────────────────────────


func test_default_display_style_is_toast() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"style_default", "Text.", 5.0)
	assert_eq(card.get_display_style_name(), "toast")


func test_thought_bubble_style_recognised() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"style_thought", "Text.", 5.0, "", "thought_bubble")
	assert_eq(card.get_display_style_name(), "thought_bubble")


func test_log_entry_style_recognised() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"style_log", "Text.", 5.0, "", "log_entry")
	assert_eq(card.get_display_style_name(), "log_entry")


func test_audio_only_style_recognised() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"style_audio", "Text.", 5.0, "", "audio_only")
	assert_eq(card.get_display_style_name(), "audio_only")


func test_unknown_display_type_falls_back_to_toast() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"style_unk", "Text.", 5.0, "", "banana")
	assert_eq(card.get_display_style_name(), "toast")


# ── progress bar ──────────────────────────────────────────────────────────────


func test_progress_bar_node_exists() -> void:
	var card: MomentCard = _make_card()
	var bar: ProgressBar = card.get_node_or_null("Margin/VBox/Progress") as ProgressBar
	assert_not_null(bar, "Progress bar node must exist")


func test_progress_bar_max_value_equals_duration() -> void:
	var card: MomentCard = _make_card()
	card.setup(&"prog_max", "Text.", 7.0)
	var bar: ProgressBar = card.get_node_or_null("Margin/VBox/Progress") as ProgressBar
	if bar:
		assert_almost_eq(bar.max_value, 7.0, 0.001)
