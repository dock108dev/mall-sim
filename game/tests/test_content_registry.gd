## GUT tests for ContentRegistry canonical ID normalization and typed lookups.
extends GutTest


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_register_store_catalog()


func test_resolve_normalizes_kebab_case_pascal_case_and_legacy_aliases() -> void:
	assert_eq(
		ContentRegistry.resolve("retro-games"),
		&"retro_games",
		"Kebab-case IDs should normalize to canonical snake_case"
	)
	assert_eq(
		ContentRegistry.resolve("RetroGames"),
		&"retro_games",
		"PascalCase IDs should normalize to canonical snake_case"
	)
	assert_eq(
		ContentRegistry.resolve("consumer-electronics"),
		&"electronics",
		"Legacy aliases should resolve to the canonical store ID"
	)


func test_resolve_supports_display_name_and_scene_name_aliases() -> void:
	assert_eq(
		ContentRegistry.resolve("Sports Memorabilia"),
		&"sports",
		"Display names should resolve to canonical IDs"
	)
	assert_eq(
		ContentRegistry.resolve("video_rental"),
		&"rentals",
		"Legacy scene/store names should resolve to canonical IDs"
	)


func test_getters_accept_legacy_aliases() -> void:
	assert_eq(
		ContentRegistry.get_display_name(&"video_rental"),
		"Video Rental",
		"Display lookup should work through aliases"
	)
	assert_eq(
		ContentRegistry.get_scene_path(&"consumer_electronics"),
		"res://game/scenes/stores/consumer_electronics.tscn",
		"Scene lookup should work through aliases"
	)


func test_unknown_id_returns_empty_string_name() -> void:
	assert_eq(
		ContentRegistry.resolve("totally_unknown_store"),
		&"",
		"Unknown IDs should resolve to an empty StringName"
	)


func test_get_all_ids_filters_by_type() -> void:
	ContentRegistry.register_entry(
		{
			"id": "sports_common_card",
			"name": "Sports Common Card",
		},
		"item"
	)
	var store_ids: Array[StringName] = ContentRegistry.get_all_ids("store")
	var item_ids: Array[StringName] = ContentRegistry.get_all_ids("item")
	assert_eq(store_ids.size(), 5, "Expected exactly five store IDs")
	assert_true(store_ids.has(&"sports"))
	assert_true(store_ids.has(&"rentals"))
	assert_true(store_ids.has(&"electronics"))
	assert_false(
		store_ids.has(&"sports_common_card"),
		"Store ID list should not include item IDs"
	)
	assert_eq(
		item_ids,
		[&"sports_common_card"],
		"Type filtering should return only registered item IDs"
	)


func test_alias_collision_does_not_replace_existing_mapping() -> void:
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"name": "Sports Memorabilia",
			"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"name": "Video Rental",
			"aliases": ["sports_memorabilia"],
			"scene_path": "res://game/scenes/stores/video_rental.tscn",
		},
		"store"
	)

	assert_eq(
		ContentRegistry.resolve("sports_memorabilia"),
		&"sports",
		"Alias collisions should not silently remap an existing alias"
	)


func _register_store_catalog() -> void:
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"aliases": ["sports_memorabilia"],
			"name": "Sports Memorabilia",
			"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Game Store",
			"scene_path": "res://game/scenes/stores/retro_games.tscn",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"aliases": ["video_rental"],
			"name": "Video Rental",
			"scene_path": "res://game/scenes/stores/video_rental.tscn",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "pocket_creatures",
			"name": "PocketCreatures Card Shop",
			"scene_path": "res://game/scenes/stores/pocket_creatures.tscn",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "electronics",
			"aliases": ["consumer_electronics"],
			"name": "Consumer Electronics",
			"scene_path": "res://game/scenes/stores/consumer_electronics.tscn",
		},
		"store"
	)
