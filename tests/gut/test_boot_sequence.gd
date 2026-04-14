## Tests for the boot sequence — verifies DataLoader, ContentRegistry, and Settings init order.
extends GutTest

func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func test_content_registry_is_ready_after_load() -> void:
	assert_true(
		ContentRegistry.is_ready(),
		"ContentRegistry should be ready after DataLoaderSingleton.load_all_content()"
	)


func test_dataloader_load_all_content_is_idempotent() -> void:
	var count_before: int = DataLoaderSingleton.get_item_count()
	DataLoaderSingleton.load_all_content()
	assert_eq(
		DataLoaderSingleton.get_item_count(), count_before,
		"Calling load_all_content() twice should not duplicate entries"
	)


func test_dataloader_has_no_load_errors() -> void:
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_eq(
		errors.size(), 0,
		"DataLoader should have no load errors: %s" % [errors]
	)


func test_all_five_store_ids_registered() -> void:
	var store_ids: Array[StringName] = ContentRegistry.get_all_ids("store")
	assert_gte(
		store_ids.size(), 5,
		"Should have at least 5 store IDs, found %d" % store_ids.size()
	)


func test_canonical_store_ids_resolvable() -> void:
	var expected: Array[String] = [
		"sports", "retro_games", "video_rental",
		"pocket_creatures", "consumer_electronics",
	]
	for raw: String in expected:
		var canonical: StringName = ContentRegistry.resolve(raw)
		assert_ne(
			canonical, &"",
			"Store ID '%s' should resolve to a canonical ID" % raw
		)


func test_game_manager_boot_completed_flag() -> void:
	assert_true(
		GameManager.is_boot_completed(),
		"GameManager should report boot completed"
	)


func test_boot_script_uses_deferred_initialize() -> void:
	var script: GDScript = load("res://game/scenes/bootstrap/boot.gd")
	var source: String = script.source_code
	assert_true(
		source.contains("call_deferred"),
		"boot.gd should use call_deferred for initialize()"
	)
	assert_false(
		source.contains("await") and source.contains("_ready"),
		"boot.gd _ready() should not use await"
	)


func test_boot_script_calls_settings_apply() -> void:
	var script: GDScript = load("res://game/scenes/bootstrap/boot.gd")
	var source: String = script.source_code
	assert_true(
		source.contains("Settings.apply_settings()"),
		"boot.gd should explicitly call Settings.apply_settings()"
	)
	assert_true(
		source.contains("Settings.load_settings()"),
		"boot.gd should explicitly call Settings.load_settings()"
	)
