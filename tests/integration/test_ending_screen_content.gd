## Integration test — EndingScreen binds to the real endings catalog.
extends GutTest


const CATALOG_PATH := "res://game/content/endings/ending_config.json"
const SCENE_PATH := "res://game/scenes/ui/ending_screen.tscn"
const _SAVE_PATH: String = "user://save_slot_0.json"

const BANKRUPTCY_ENDING_ID: StringName = &"lights_out"
const SURVIVAL_ENDING_ID: StringName = &"broke_even"

var _screen: EndingScreen
var _catalog_entries: Array[Dictionary] = []
var _save_backup_exists: bool = false
var _save_backup_text: String = ""


func before_all() -> void:
	_catalog_entries = _load_catalog_entries()
	_ensure_endings_registered()


func before_each() -> void:
	_backup_user_file(_SAVE_PATH, "_save_backup_exists", "_save_backup_text")
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_screen = packed.instantiate() as EndingScreen
	add_child_autofree(_screen)


func after_each() -> void:
	_restore_user_file(_SAVE_PATH, _save_backup_exists, _save_backup_text)


func test_all_endings_title_matches_catalog_title_field() -> void:
	assert_true(
		_catalog_entries.size() >= 13,
		"Catalog must contain at least 13 endings; found %d" % _catalog_entries.size()
	)
	for entry: Dictionary in _catalog_entries:
		var ending_id: StringName = StringName(str(entry["id"]))
		_screen.initialize(ending_id)
		assert_eq(
			_screen._title_label.text,
			str(entry.get("title", EndingScreen.FALLBACK_TITLE)),
			"Title label for '%s' must equal catalog 'title' field" % ending_id
		)


func test_all_endings_body_text_matches_catalog_text_field() -> void:
	for entry: Dictionary in _catalog_entries:
		var ending_id: StringName = StringName(str(entry["id"]))
		_screen.initialize(ending_id)
		assert_eq(
			_screen._flavor_label.text,
			str(entry.get("text", "")),
			"Ending text for '%s' must match catalog 'text' field" % ending_id
		)


func test_stats_overlay_reflects_final_stats_values() -> void:
	var test_stats: Dictionary = {
		"days_survived": 28.0,
		"cumulative_revenue": 12500.50,
		"owned_store_count_final": 3.0,
		"satisfied_customer_count": 175.0,
		"max_reputation_tier": 2.0,
		"rare_items_sold": 7.0,
	}
	var first_id: StringName = StringName(str(_catalog_entries[0]["id"]))
	EventBus.ending_triggered.emit(first_id, test_stats)

	assert_eq(_screen._days_label.text, "Days Survived: 28")
	assert_eq(_screen._revenue_label.text, "Total Revenue: $12500.50")
	assert_eq(_screen._stores_label.text, "Stores Owned: 3")
	assert_eq(_screen._customers_label.text, "Satisfied Customers: 175")
	assert_eq(_screen._rare_items_label.text, "Rare Items Sold: 7")
	assert_eq(_screen._threads_label.text, "Secret Threads Completed: 2")
	assert_false(
		_screen._assisted_label.visible,
		"Assisted label must stay hidden when slot metadata is absent"
	)


func test_assisted_label_visible_when_current_slot_metadata_is_flagged() -> void:
	_write_current_slot_metadata(true)
	var first_id: StringName = StringName(str(_catalog_entries[0]["id"]))
	EventBus.ending_triggered.emit(first_id, {"days_survived": 30.0})

	assert_true(
		_screen._assisted_label.visible,
		"Assisted label must be visible when slot metadata marks the run assisted"
	)
	assert_eq(_screen._assisted_label.text, "Assisted Run")


func test_unknown_ending_id_shows_fallback_title() -> void:
	_screen.initialize(&"not_a_real_ending_id_xyz")
	assert_eq(
		_screen._title_label.text,
		EndingScreen.FALLBACK_TITLE,
		"Unknown ending_id must fall back to FALLBACK_TITLE"
	)


func test_ending_triggered_routes_bankruptcy_ending_id_to_correct_title() -> void:
	EventBus.ending_triggered.emit(BANKRUPTCY_ENDING_ID, {})
	var entry: Dictionary = ContentRegistry.get_entry(BANKRUPTCY_ENDING_ID)
	assert_eq(
		_screen._title_label.text,
		str(entry.get("title", EndingScreen.FALLBACK_TITLE)),
		"ending_triggered('%s') must set the correct bankruptcy title"
			% BANKRUPTCY_ENDING_ID
	)


func test_ending_triggered_routes_survival_ending_id_to_correct_title() -> void:
	EventBus.ending_triggered.emit(SURVIVAL_ENDING_ID, {})
	var entry: Dictionary = ContentRegistry.get_entry(SURVIVAL_ENDING_ID)
	assert_eq(
		_screen._title_label.text,
		str(entry.get("title", EndingScreen.FALLBACK_TITLE)),
		"ending_triggered('%s') must set the correct survival title"
			% SURVIVAL_ENDING_ID
	)


func _load_catalog_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Variant = DataLoader.load_json(CATALOG_PATH)
	if data is not Dictionary:
		push_error(
			"test_ending_screen_content: failed to load catalog at %s" % CATALOG_PATH
		)
		return result
	var endings: Variant = data.get("endings", [])
	if endings is not Array:
		push_error(
			"test_ending_screen_content: catalog 'endings' key missing or not an Array"
		)
		return result
	for item: Variant in endings:
		if item is Dictionary and (item as Dictionary).has("id"):
			result.append(item as Dictionary)
	return result


func _ensure_endings_registered() -> void:
	for entry: Dictionary in _catalog_entries:
		var raw_id: String = str(entry["id"])
		if not ContentRegistry.exists(raw_id):
			ContentRegistry.register_entry(entry, "ending")


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
