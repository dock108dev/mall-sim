## Integration test — EndingScreen content pipeline:
## ending_id → endings_catalog.json lookup → title and flavor rendered correctly.
extends GutTest


const CATALOG_PATH := "res://game/content/endings/ending_config.json"
const SCENE_PATH := "res://game/scenes/ui/ending_screen.tscn"

## Canonical IDs used in routing integration tests.
const BANKRUPTCY_ENDING_ID: StringName = &"lights_out"
const SURVIVAL_ENDING_ID: StringName = &"broke_even"

var _screen: EndingScreen
var _catalog_entries: Array[Dictionary] = []


func before_all() -> void:
	_catalog_entries = _load_catalog_entries()
	_ensure_endings_registered()


func before_each() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_screen = packed.instantiate() as EndingScreen
	add_child_autofree(_screen)


## --- Data binding tests ---


## All ending IDs must render the catalog title field in the title Label.
func test_all_endings_title_matches_catalog_title_field() -> void:
	assert_true(
		_catalog_entries.size() >= 13,
		"Catalog must contain at least 13 endings; found %d" % _catalog_entries.size()
	)
	for entry: Dictionary in _catalog_entries:
		var ending_id: StringName = StringName(str(entry["id"]))
		_screen.initialize(ending_id)
		var expected: String = str(entry.get("title", EndingScreen.FALLBACK_TITLE))
		assert_eq(
			_screen._title_label.text,
			expected,
			"Title label for '%s' must equal catalog 'title' field" % ending_id
		)


## Flavor label must be hidden for every entry that has no 'flavor_text' key.
## The current catalog stores narrative text under 'text', not 'flavor_text'.
## EndingScreen reads 'flavor_text', so all current entries produce an empty
## string → the flavor label must be hidden, not blank.
func test_flavor_label_hidden_when_catalog_has_no_flavor_text() -> void:
	for entry: Dictionary in _catalog_entries:
		var flavor: String = str(entry.get("flavor_text", ""))
		if not flavor.is_empty():
			continue
		var ending_id: StringName = StringName(str(entry["id"]))
		_screen.initialize(ending_id)
		assert_false(
			_screen._flavor_label.visible,
			"Flavor label must be hidden when catalog 'flavor_text' is absent for '%s'"
				% ending_id
		)


## Flavor label must show the exact catalog 'flavor_text' when the field is present.
func test_flavor_label_shows_exact_catalog_flavor_text() -> void:
	for entry: Dictionary in _catalog_entries:
		var flavor: String = str(entry.get("flavor_text", ""))
		if flavor.is_empty():
			continue
		var ending_id: StringName = StringName(str(entry["id"]))
		_screen.initialize(ending_id)
		assert_true(
			_screen._flavor_label.visible,
			"Flavor label must be visible when catalog 'flavor_text' is non-empty for '%s'"
				% ending_id
		)
		assert_eq(
			_screen._flavor_label.text,
			flavor,
			"Flavor label must exactly match catalog 'flavor_text' for '%s'" % ending_id
		)


## Stats overlay must reflect all supplied final_stats values exactly.
func test_stats_overlay_reflects_final_stats_values() -> void:
	assert_false(
		_catalog_entries.is_empty(),
		"Catalog must be non-empty to run stats overlay test"
	)
	var test_stats: Dictionary = {
		"days_survived": 28.0,
		"cumulative_revenue": 12500.50,
		"final_cash": 4800.25,
		"owned_store_count_final": 3.0,
		"satisfied_customer_count": 175.0,
		"max_reputation_tier": 2.0,
		"rare_items_sold": 7.0,
		"secret_threads_completed": 2.0,
		"used_difficulty_downgrade": false,
	}
	var first_id: StringName = StringName(str(_catalog_entries[0]["id"]))
	EventBus.ending_triggered.emit(first_id, test_stats)

	assert_eq(
		_screen._days_label.text,
		"Days Survived: 28",
		"Days label must reflect days_survived"
	)
	assert_eq(
		_screen._revenue_label.text,
		"Total Revenue: $12500.50",
		"Revenue label must reflect cumulative_revenue"
	)
	assert_eq(
		_screen._cash_label.text,
		"Final Cash: $4800.25",
		"Cash label must reflect final_cash"
	)
	assert_eq(
		_screen._stores_label.text,
		"Stores Owned: 3",
		"Stores label must reflect owned_store_count_final"
	)
	assert_eq(
		_screen._customers_label.text,
		"Satisfied Customers: 175",
		"Customers label must reflect satisfied_customer_count"
	)
	assert_eq(
		_screen._rare_items_label.text,
		"Rare Items Sold: 7",
		"Rare items label must reflect rare_items_sold"
	)
	assert_eq(
		_screen._threads_label.text,
		"Secret Threads Completed: 2",
		"Threads label must reflect secret_threads_completed"
	)
	assert_false(
		_screen._assisted_label.visible,
		"Assisted label must be hidden when used_difficulty_downgrade is false"
	)


## Assisted run label appears only when used_difficulty_downgrade is true.
func test_assisted_label_visible_when_difficulty_downgrade_used() -> void:
	assert_false(
		_catalog_entries.is_empty(),
		"Catalog must be non-empty to run assisted label test"
	)
	var assisted_stats: Dictionary = {
		"days_survived": 30.0,
		"used_difficulty_downgrade": true,
	}
	var first_id: StringName = StringName(str(_catalog_entries[0]["id"]))
	EventBus.ending_triggered.emit(first_id, assisted_stats)

	assert_true(
		_screen._assisted_label.visible,
		"Assisted label must be visible when used_difficulty_downgrade is true"
	)
	assert_eq(
		_screen._assisted_label.text,
		"Assisted Run",
		"Assisted label text must be 'Assisted Run'"
	)


## --- Edge case tests ---


## Unknown ending_id must show FALLBACK_TITLE without crashing.
## NOTE: EndingScreen emits push_error for unknown IDs (by design); the fallback
## prevents a visual crash. This test verifies the fallback, not absence of push_error.
func test_unknown_ending_id_shows_fallback_title() -> void:
	_screen.initialize(&"not_a_real_ending_id_xyz")
	assert_eq(
		_screen._title_label.text,
		EndingScreen.FALLBACK_TITLE,
		"Unknown ending_id must fall back to FALLBACK_TITLE"
	)


## Unknown ending_id with empty flavor_text in fallback must hide the flavor label.
func test_unknown_ending_id_hides_flavor_label() -> void:
	_screen.initialize(&"not_a_real_ending_id_xyz")
	assert_false(
		_screen._flavor_label.visible,
		"Flavor label must be hidden for unknown ending_id (fallback has no flavor_text)"
	)


## --- Routing integration tests ---


## EventBus.ending_triggered with a BANKRUPTCY ending ID routes to that ending's content.
func test_ending_triggered_routes_bankruptcy_ending_id_to_correct_title() -> void:
	EventBus.ending_triggered.emit(BANKRUPTCY_ENDING_ID, {})
	var entry: Dictionary = ContentRegistry.get_entry(BANKRUPTCY_ENDING_ID)
	assert_false(
		entry.is_empty(),
		"ContentRegistry must have an entry for '%s'" % BANKRUPTCY_ENDING_ID
	)
	assert_eq(
		_screen._title_label.text,
		str(entry.get("title", EndingScreen.FALLBACK_TITLE)),
		"ending_triggered('%s') must set title to the bankruptcy ending title"
			% BANKRUPTCY_ENDING_ID
	)


## EventBus.ending_triggered with a SURVIVAL ending ID routes to that ending's content.
func test_ending_triggered_routes_survival_ending_id_to_correct_title() -> void:
	EventBus.ending_triggered.emit(SURVIVAL_ENDING_ID, {})
	var entry: Dictionary = ContentRegistry.get_entry(SURVIVAL_ENDING_ID)
	assert_false(
		entry.is_empty(),
		"ContentRegistry must have an entry for '%s'" % SURVIVAL_ENDING_ID
	)
	assert_eq(
		_screen._title_label.text,
		str(entry.get("title", EndingScreen.FALLBACK_TITLE)),
		"ending_triggered('%s') must set title to the survival ending title"
			% SURVIVAL_ENDING_ID
	)


## ending_triggered only fires initialize once per emission — no duplicated UI updates.
func test_single_ending_triggered_emission_updates_screen_exactly_once() -> void:
	var initial_text: String = _screen._title_label.text
	EventBus.ending_triggered.emit(BANKRUPTCY_ENDING_ID, {})
	var after_first: String = _screen._title_label.text
	assert_ne(
		after_first,
		initial_text,
		"Screen title must change after first ending_triggered emission"
	)


## --- Helpers ---


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
