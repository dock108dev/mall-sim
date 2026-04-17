## Tests for EndingScreen UI — signal wiring, catalog binding, and guarded actions.
extends GutTest


const _SAVE_PATH: String = "user://save_slot_0.json"

const _ENDING_IDS: Array[String] = [
	"render_test_01",
	"render_test_02",
	"render_test_03",
	"render_test_04",
	"render_test_05",
	"render_test_06",
	"render_test_07",
	"render_test_08",
	"render_test_09",
	"render_test_10",
	"render_test_11",
	"render_test_12",
	"render_test_13",
]

var _screen: EndingScreen
var _save_backup_exists: bool = false
var _save_backup_text: String = ""


func before_each() -> void:
	_backup_user_file(_SAVE_PATH, "_save_backup_exists", "_save_backup_text")

	_screen = preload(
		"res://game/scenes/ui/ending_screen.tscn"
	).instantiate() as EndingScreen
	add_child_autofree(_screen)


func after_each() -> void:
	_restore_user_file(_SAVE_PATH, _save_backup_exists, _save_backup_text)


func _make_test_stats() -> Dictionary:
	return {
		"days_survived": 30.0,
		"cumulative_revenue": 5000.0,
		"owned_store_count_final": 3.0,
		"satisfied_customer_count": 50.0,
		"max_reputation_tier": 2.0,
		"rare_items_sold": 7.0,
		"secret_threads_completed": 1.0,
	}


func _register_test_ending(
	id: String, category: String, tone: String = "positive"
) -> void:
	var entry: Dictionary = {
		"id": id,
		"name": "Ending %s" % id,
		"title": "Title %s" % id,
		"text": "Narrative text for %s." % id,
		"category": category,
		"tone": tone,
	}
	ContentRegistry.register_entry(entry, "ending")


func _trigger_ending(id: StringName, stats: Dictionary) -> void:
	EventBus.ending_triggered.emit(id, stats)


func _write_current_slot_metadata(used_downgrade: bool) -> void:
	DirAccess.make_dir_recursive_absolute("user://")
	var file: FileAccess = FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(
			JSON.stringify(
				{
					"save_version": 1,
					"save_metadata": {
						"day": 1,
						"cash": 0.0,
						"owned_stores": [],
						"saved_at": "2026-01-01T00:00:00",
						"used_difficulty_downgrade": used_downgrade,
					},
				}
			)
		)
		file.close()


func _backup_user_file(
	path: String, exists_property: String, text_property: String
) -> void:
	set(exists_property, FileAccess.file_exists(path))
	if not get(exists_property):
		set(text_property, "")
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	set(text_property, file.get_as_text() if file else "")
	if file:
		file.close()


func _restore_user_file(path: String, existed: bool, text: String) -> void:
	if existed:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(text)
			file.close()
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_screen_starts_hidden() -> void:
	assert_false(_screen.visible, "EndingScreen should be hidden on ready")


func test_screen_connects_to_ending_triggered() -> void:
	assert_true(
		EventBus.ending_triggered.is_connected(_screen._on_ending_triggered),
		"EndingScreen should connect to ending_triggered"
	)


func test_show_ending_uses_content_registry_title_category_and_text() -> void:
	_register_test_ending("test_binding", "bankruptcy", "negative")
	_screen._show_ending(&"test_binding", _make_test_stats())

	assert_true(_screen.visible, "EndingScreen should become visible when shown")
	assert_eq(_screen._title_label.text, "Title test_binding")
	assert_eq(_screen._category_label.text, "Bankruptcy")
	assert_eq(_screen._flavor_label.text, "Narrative text for test_binding.")
	assert_true(_screen._flavor_label.visible, "Narrative text should be visible")
	assert_false(_screen._body_label.visible, "Legacy body label should stay hidden")


func test_missing_ending_uses_fallback_without_crashing() -> void:
	_screen._show_ending(&"missing_ending", _make_test_stats())

	assert_eq(
		_screen._title_label.text, EndingScreen.FALLBACK_TITLE,
		"Missing ending should show fallback title"
	)
	assert_eq(_screen._flavor_label.text, "", "Fallback ending text should be empty")
	assert_false(_screen._flavor_label.visible, "Empty fallback text should stay hidden")


func test_stats_display_all_visible_metrics() -> void:
	_register_test_ending("test_stats", "success")
	_trigger_ending(&"test_stats", _make_test_stats())

	assert_eq(_screen._days_label.text, "Days Survived: 30")
	assert_eq(_screen._revenue_label.text, "Total Revenue: $5000.00")
	assert_eq(_screen._stores_label.text, "Stores Owned: 3")
	assert_eq(_screen._customers_label.text, "Satisfied Customers: 50")
	assert_eq(_screen._reputation_label.text, "Peak Reputation Tier: Reputable")
	assert_eq(_screen._rare_items_label.text, "Rare Items Sold: 7")
	assert_eq(_screen._threads_label.text, "Secret Threads Completed: 1")
	assert_false(_screen._cash_label.visible, "Final cash should not be shown in the stats block")


func test_assisted_label_hidden_without_current_slot_metadata() -> void:
	_register_test_ending("test_no_assist", "success")
	_trigger_ending(&"test_no_assist", _make_test_stats())

	assert_false(
		_screen._assisted_label.visible,
		"Assisted label should stay hidden when slot metadata is absent"
	)


func test_assisted_label_shown_from_save_manager_metadata() -> void:
	_register_test_ending("test_assist", "success")
	_write_current_slot_metadata(true)
	_trigger_ending(&"test_assist", _make_test_stats())

	assert_true(
		_screen._assisted_label.visible,
		"Assisted label should read from SaveManager slot metadata"
	)
	assert_eq(_screen._assisted_label.text, "Assisted Run")


func test_all_13_ending_ids_render_without_errors() -> void:
	for ending_id: String in _ENDING_IDS:
		_register_test_ending(ending_id, "success")

	for ending_id: String in _ENDING_IDS:
		_screen._show_ending(StringName(ending_id), _make_test_stats())
		assert_true(
			_screen.visible,
			"EndingScreen should render '%s'" % ending_id
		)


func test_positive_tone_applies_warm_palette() -> void:
	_register_test_ending("test_positive", "success", "positive")
	_trigger_ending(&"test_positive", _make_test_stats())

	var category_color: Color = _screen._category_label.get_theme_color("font_color")
	assert_gt(
		category_color.r, category_color.b,
		"Positive endings should bias the palette warm"
	)


func test_negative_tone_applies_desaturated_palette() -> void:
	_register_test_ending("test_negative", "bankruptcy", "negative")
	_trigger_ending(&"test_negative", _make_test_stats())

	var background_color: Color = _screen._background.color
	assert_lt(
		background_color.r, 0.2,
		"Negative endings should use a muted, cool overlay"
	)
	assert_gt(
		background_color.b, background_color.r,
		"Negative endings should bias the palette toward cooler tones"
	)


func test_view_credits_opens_overlay_without_crashing() -> void:
	_register_test_ending("test_credits", "success")
	_trigger_ending(&"test_credits", _make_test_stats())

	_screen._on_credits_pressed()

	assert_not_null(_screen._credits_overlay, "Credits overlay should be instantiated")
	assert_true(_screen._credits_overlay.visible, "Credits overlay should become visible")


func test_escape_input_is_consumed_without_dismissing_screen() -> void:
	_register_test_ending("test_escape", "success")
	_trigger_ending(&"test_escape", _make_test_stats())

	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true
	_screen._unhandled_input(escape_event)

	assert_true(
		_screen.visible,
		"Escape should not dismiss the ending screen"
	)
