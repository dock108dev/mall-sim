## Tests for the boot sequence — verifies DataLoader, ContentRegistry, and Settings init order.
extends GutTest

func before_all() -> void:
	DataLoaderSingleton.load_all()
	DifficultySystemSingleton._load_config()


func test_content_registry_is_ready_after_load() -> void:
	assert_true(
		ContentRegistry.is_ready(),
		"ContentRegistry should be ready after DataLoaderSingleton.load_all()"
	)


func test_dataloader_load_all_is_idempotent() -> void:
	var count_before: int = DataLoaderSingleton.get_item_count()
	DataLoaderSingleton.load_all()
	assert_eq(
		DataLoaderSingleton.get_item_count(), count_before,
		"Calling load_all() twice should not duplicate entries"
	)


func test_dataloader_has_no_load_errors() -> void:
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_eq(
		errors.size(), 0,
		"DataLoader should have no load errors: %s" % [errors]
	)


func test_all_five_store_ids_registered() -> void:
	var store_ids: Array[StringName] = ContentRegistry.get_all_store_ids()
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


func test_boot_script_uses_deferred_initialize() -> void:
	var script: GDScript = load("res://game/scripts/core/boot.gd")
	var source: String = script.source_code
	assert_true(
		source.contains("call_deferred"),
		"boot.gd should use call_deferred for initialize()"
	)
	assert_false(
		source.contains("await") and source.contains("_ready"),
		"boot.gd _ready() should not use await"
	)


func test_boot_script_uses_issue_137_sequence() -> void:
	var script: GDScript = load("res://game/scripts/core/boot.gd")
	var source: String = script.source_code
	assert_true(
		source.contains("DataLoaderSingleton.load_all()"),
		"boot.gd should call DataLoaderSingleton.load_all()"
	)
	assert_true(
		source.contains("ContentRegistry.is_ready()"),
		"boot.gd should verify ContentRegistry readiness"
	)
	assert_true(
		source.contains("Settings.load()"),
		"boot.gd should explicitly call Settings.load()"
	)
	assert_true(
		source.contains("AudioManager.initialize()"),
		"boot.gd should initialize AudioManager"
	)
	assert_true(
		source.contains("GameManager.transition_to(GameManager.GameState.MAIN_MENU)"),
		"boot.gd should transition through GameManager.transition_to()"
	)

	var settings_pos: int = source.find("Settings.load()")
	var audio_pos: int = source.find("AudioManager.initialize()")
	assert_true(
		settings_pos >= 0 and audio_pos > settings_pos,
		"Settings.load() must run before AudioManager.initialize()"
	)
	var load_pos: int = source.find("DataLoaderSingleton.load_all()")
	var transition_pos: int = source.find(
		"GameManager.transition_to(GameManager.GameState.MAIN_MENU)"
	)
	assert_true(
		load_pos >= 0 and transition_pos > load_pos,
		"Boot transition to main menu must happen after DataLoader.load_all()"
	)
