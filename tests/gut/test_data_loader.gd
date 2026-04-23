## Tests for the DataLoader boot utility and ContentRegistry integration.
extends GutTest

func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func test_load_json_valid_file() -> void:
	var data: Variant = DataLoader.load_catalog_entries(
		"res://game/content/stores/store_definitions.json"
	)
	assert_not_null(data, "Should parse valid JSON")
	assert_true(data is Array, "Store definitions should be array")


func test_load_json_missing_file_returns_null() -> void:
	var data: Variant = DataLoader.load_json(
		"res://nonexistent_file.json"
	)
	assert_null(data, "Missing file should return null")


func test_load_json_oversized_file_returns_null() -> void:
	var path: String = "user://test_oversized_data_loader.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should create oversized test file")
	if file == null:
		return
	file.store_string(
		"{\"padding\":\"%s\"}" % "x".repeat(DataLoader.MAX_JSON_FILE_BYTES)
	)
	file.close()

	var data: Variant = DataLoader.load_json(path)
	assert_null(data, "Oversized JSON file should be rejected")

	var cleanup_error: Error = DirAccess.remove_absolute(path)
	assert_eq(cleanup_error, OK, "Oversized test file should be removed")


func test_items_loaded() -> void:
	assert_gt(
		DataLoaderSingleton.get_item_count(), 0,
		"Should load at least one item"
	)


func test_stores_loaded() -> void:
	assert_gt(
		DataLoaderSingleton.get_store_count(), 0,
		"Should load at least one store"
	)


func test_customers_loaded() -> void:
	assert_gt(
		DataLoaderSingleton.get_customer_count(), 0,
		"Should load at least one customer"
	)


func test_fixtures_loaded() -> void:
	assert_gt(
		DataLoaderSingleton.get_fixture_count(), 0,
		"Should load at least one fixture"
	)


func test_economy_config_loaded() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config, "Should load economy config")
	assert_gt(
		config.starting_cash, 0.0,
		"Economy config should have positive starting_cash"
	)


func test_milestones_loaded() -> void:
	var milestones: Array[MilestoneDefinition] = (
		DataLoaderSingleton.get_all_milestones()
	)
	assert_gt(milestones.size(), 0, "Should load milestones")


func test_milestone_has_required_fields() -> void:
	var milestones: Array[MilestoneDefinition] = (
		DataLoaderSingleton.get_all_milestones()
	)
	for m: MilestoneDefinition in milestones:
		assert_ne(m.id, "", "Milestone should have id")
		assert_ne(
			m.display_name, "",
			"Milestone should have display_name"
		)
		assert_ne(
			m.trigger_stat_key, "",
			"Milestone '%s' should have trigger_stat_key"
			% m.id
		)


func test_item_has_required_fields() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	for item: ItemDefinition in items:
		assert_ne(item.id, "", "Item should have id")
		assert_gt(
			item.base_price, 0.0,
			"Item '%s' should have positive base_price" % item.id
		)


func test_store_has_required_fields() -> void:
	var stores: Array[StoreDefinition] = (
		DataLoaderSingleton.get_all_stores()
	)
	for store: StoreDefinition in stores:
		assert_ne(store.id, "", "Store should have id")
		assert_ne(store.store_name, "", "Store should have name")


func test_items_by_store_filter() -> void:
	var stores: Array[StoreDefinition] = (
		DataLoaderSingleton.get_all_stores()
	)
	if stores.is_empty():
		return
	var store_id: String = stores[0].id
	var items: Array[ItemDefinition] = (
		DataLoaderSingleton.get_items_by_store(store_id)
	)
	for item: ItemDefinition in items:
		assert_eq(
			item.store_type, store_id,
			"Filtered item should match store_type"
		)


func test_content_registry_has_stores() -> void:
	var ids: Array[StringName] = (
		ContentRegistry.get_all_ids("store")
	)
	assert_gt(
		ids.size(), 0,
		"ContentRegistry should have store entries"
	)


func test_content_registry_has_fixtures() -> void:
	var ids: Array[StringName] = (
		ContentRegistry.get_all_ids("fixture")
	)
	assert_gt(
		ids.size(), 0,
		"ContentRegistry should have fixture entries"
	)


func test_content_registry_resolve_store_id() -> void:
	var canonical: StringName = ContentRegistry.resolve("sports")
	assert_ne(
		canonical, &"",
		"Should resolve canonical store ID"
	)


func test_content_registry_resolve_alias() -> void:
	var canonical: StringName = ContentRegistry.resolve(
		"sports_memorabilia"
	)
	assert_ne(
		canonical, &"",
		"Should resolve store alias"
	)


func test_create_starting_inventory() -> void:
	var stores: Array[StoreDefinition] = (
		DataLoaderSingleton.get_all_stores()
	)
	for store: StoreDefinition in stores:
		if store.starting_inventory.is_empty():
			continue
		var inv: Array[ItemInstance] = (
			DataLoaderSingleton.create_starting_inventory(store.id)
		)
		assert_gt(
			inv.size(), 0,
			"Store '%s' should produce starting inventory"
			% store.id
		)
		break


func test_generate_starter_inventory() -> void:
	var stores: Array[StoreDefinition] = (
		DataLoaderSingleton.get_all_stores()
	)
	if stores.is_empty():
		return
	var inv: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(stores[0].id)
	)
	assert_gt(
		inv.size(), 0,
		"Should generate starter inventory"
	)


func test_create_starting_inventory_accepts_alias_store_id() -> void:
	var inv: Array[ItemInstance] = (
		DataLoaderSingleton.create_starting_inventory("video_rental")
	)
	assert_gt(
		inv.size(), 0,
		"Alias store ID should resolve for create_starting_inventory()"
	)


func test_generate_starter_inventory_accepts_alias_store_id() -> void:
	var inv: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(
			"sports_memorabilia"
		)
	)
	assert_gt(
		inv.size(), 0,
		"Alias store ID should resolve for generate_starter_inventory()"
	)


func test_upgrades_loaded() -> void:
	assert_gt(
		DataLoaderSingleton.get_upgrade_count(), 0,
		"Should load at least one upgrade"
	)


func test_market_events_loaded() -> void:
	var events: Array[MarketEventDefinition] = (
		DataLoaderSingleton.get_all_market_events()
	)
	assert_gt(events.size(), 0, "Should load market events")


func test_seasonal_events_loaded() -> void:
	var events: Array[SeasonalEventDefinition] = (
		DataLoaderSingleton.get_all_seasonal_events()
	)
	assert_gt(events.size(), 0, "Should load seasonal events")


func test_random_events_loaded() -> void:
	var events: Array[RandomEventDefinition] = (
		DataLoaderSingleton.get_all_random_events()
	)
	assert_gt(events.size(), 0, "Should load random events")


func test_staff_definitions_loaded() -> void:
	var staff: Array[StaffDefinition] = (
		DataLoaderSingleton.get_all_staff_definitions()
	)
	assert_gt(staff.size(), 0, "Should load staff definitions")


func test_secret_threads_loaded() -> void:
	var threads: Array[Dictionary] = (
		DataLoaderSingleton.get_all_secret_threads()
	)
	assert_gt(threads.size(), 0, "Should load secret threads")


func test_validate_all_references_clean() -> void:
	var errors: Array[String] = (
		ContentRegistry.validate_all_references()
	)
	assert_eq(
		errors.size(), 0,
		"Should have no reference errors: %s" % [errors]
	)


func test_item_schema_alignment_all_fields_populated() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	assert_gt(items.size(), 0, "Should have loaded items")
	var store_types_seen: Dictionary = {}
	for item: ItemDefinition in items:
		assert_ne(
			item.id, "",
			"Item should have non-empty id"
		)
		assert_ne(
			item.item_name, "",
			"Item '%s' should have non-empty item_name" % item.id
		)
		assert_gt(
			item.base_price, 0.0,
			"Item '%s' should have positive base_price" % item.id
		)
		assert_ne(
			item.rarity, "",
			"Item '%s' should have non-empty rarity" % item.id
		)
		assert_ne(
			item.category, "",
			"Item '%s' should have non-empty category" % item.id
		)
		assert_ne(
			item.store_type, "",
			"Item '%s' should have non-empty store_type" % item.id
		)
		assert_gt(
			item.condition_range.size(), 0,
			"Item '%s' should have non-empty condition_range"
			% item.id
		)
		store_types_seen[item.store_type] = true
	assert_gte(
		store_types_seen.size(), 5,
		"Should have items from at least 5 store types: %s"
		% [store_types_seen.keys()]
	)


func test_difficulty_config_loaded() -> void:
	var config: Dictionary = DataLoaderSingleton.get_difficulty_config()
	assert_true(
		config.has("tiers"),
		"Difficulty config should have tiers"
	)
	assert_true(
		config.has("default_tier"),
		"Difficulty config should have default_tier"
	)
	assert_eq(
		config["default_tier"], "normal",
		"Default tier should be normal"
	)
	var tiers: Array = config["tiers"]
	assert_eq(tiers.size(), 3, "Should have 3 difficulty tiers")
	var expected_ids: Array[String] = ["easy", "normal", "hard"]
	for i: int in range(tiers.size()):
		var tier: Dictionary = tiers[i]
		assert_eq(
			tier["id"], expected_ids[i],
			"Tier %d should be '%s'" % [i, expected_ids[i]]
		)
		assert_true(
			tier.has("display_name"),
			"Tier '%s' should have display_name" % tier["id"]
		)
		assert_true(
			tier.has("tagline"),
			"Tier '%s' should have tagline" % tier["id"]
		)
		assert_true(
			tier.has("modifiers"),
			"Tier '%s' should have modifiers" % tier["id"]
		)
		assert_true(
			tier.has("flags"),
			"Tier '%s' should have flags" % tier["id"]
		)
		var mods: Dictionary = tier["modifiers"]
		assert_gte(
			mods.size(), 16,
			"Tier '%s' should have at least 16 modifier fields"
			% tier["id"]
		)


func test_difficulty_config_normal_baseline() -> void:
	var config: Dictionary = DataLoaderSingleton.get_difficulty_config()
	var tiers: Array = config["tiers"]
	var normal: Dictionary = {}
	for tier: Variant in tiers:
		if (tier as Dictionary)["id"] == "normal":
			normal = tier as Dictionary
			break
	var mods: Dictionary = normal["modifiers"]
	const NON_UNITY_MODIFIERS: Array[String] = [
		"staff_quit_threshold",
		"haggle_acceptance_base_rate",
		"haggle_concession_ceiling",
		"supplier_stockout_probability",
	]
	for key: String in mods:
		if key in NON_UNITY_MODIFIERS:
			continue
		assert_eq(
			float(mods[key]), 1.0,
			"Normal tier '%s' should be 1.0" % key
		)


func test_difficulty_config_easy_values() -> void:
	var config: Dictionary = DataLoaderSingleton.get_difficulty_config()
	var tiers: Array = config["tiers"]
	var easy: Dictionary = {}
	for tier: Variant in tiers:
		if (tier as Dictionary)["id"] == "easy":
			easy = tier as Dictionary
			break
	var mods: Dictionary = easy["modifiers"]
	assert_eq(
		float(mods["starting_cash_multiplier"]), 1.5,
		"Easy starting_cash_multiplier should be 1.50"
	)
	assert_eq(
		float(mods["daily_rent_multiplier"]), 0.7,
		"Easy daily_rent_multiplier should be 0.70"
	)


func test_difficulty_config_hard_values() -> void:
	var config: Dictionary = DataLoaderSingleton.get_difficulty_config()
	var tiers: Array = config["tiers"]
	var hard: Dictionary = {}
	for tier: Variant in tiers:
		if (tier as Dictionary)["id"] == "hard":
			hard = tier as Dictionary
			break
	var mods: Dictionary = hard["modifiers"]
	assert_eq(
		float(mods["starting_cash_multiplier"]), 0.7,
		"Hard starting_cash_multiplier should be 0.70"
	)
	assert_eq(
		float(mods["daily_rent_multiplier"]), 1.35,
		"Hard daily_rent_multiplier should be 1.35"
	)


func test_item_json_uses_item_name_not_name() -> void:
	var catalog_paths: Array[String] = [
		"res://game/content/items/consumer_electronics.json",
		"res://game/content/items/pocket_creatures.json",
		"res://game/content/items/retro_games.json",
		"res://game/content/items/sports_memorabilia.json",
		"res://game/content/items/video_rental.json",
	]
	for path: String in catalog_paths:
		var data: Variant = DataLoader.load_json(path)
		assert_not_null(data, "Should parse %s" % path)
		if data is not Array:
			continue
		for entry: Variant in data:
			if entry is not Dictionary:
				continue
			var d: Dictionary = entry as Dictionary
			assert_true(
				d.has("item_name"),
				"Entry '%s' in %s should use 'item_name'"
				% [d.get("id", "?"), path]
			)
			assert_true(
				d.has("base_price"),
				"Entry '%s' in %s should use 'base_price'"
				% [d.get("id", "?"), path]
			)
			assert_true(
				d.has("condition_range"),
				"Entry '%s' in %s should use 'condition_range'"
				% [d.get("id", "?"), path]
			)
			assert_false(
				d.has("name"),
				"Entry '%s' in %s should not use 'name'"
				% [d.get("id", "?"), path]
			)
			assert_false(
				d.has("display_name"),
				"Entry '%s' in %s should not use 'display_name'"
				% [d.get("id", "?"), path]
			)
			assert_false(
				d.has("base_value"),
				"Entry '%s' in %s should not use 'base_value'"
				% [d.get("id", "?"), path]
			)
			assert_false(
				d.has("condition_variants"),
				"Entry '%s' in %s should not use 'condition_variants'"
				% [d.get("id", "?"), path]
			)


func test_unlocks_loaded() -> void:
	assert_gte(
		DataLoaderSingleton.get_unlock_count(), 6,
		"Should load at least 6 unlock definitions"
	)


func test_unlock_has_required_fields() -> void:
	var unlocks: Array[UnlockDefinition] = (
		DataLoaderSingleton.get_all_unlocks()
	)
	for u: UnlockDefinition in unlocks:
		assert_ne(u.id, "", "Unlock should have id")
		assert_ne(
			u.display_name, "",
			"Unlock '%s' should have display_name" % u.id
		)
		assert_ne(
			u.description, "",
			"Unlock '%s' should have description" % u.id
		)
		assert_ne(
			u.effect_type, "",
			"Unlock '%s' should have effect_type" % u.id
		)
		assert_ne(
			u.unlock_message, "",
			"Unlock '%s' should have unlock_message" % u.id
		)
		assert_true(
			u.is_valid_effect_type(),
			"Unlock '%s' should have valid effect_type" % u.id
		)


func test_unlock_ids_are_unique() -> void:
	var unlocks: Array[UnlockDefinition] = (
		DataLoaderSingleton.get_all_unlocks()
	)
	var seen: Dictionary = {}
	for u: UnlockDefinition in unlocks:
		assert_false(
			seen.has(u.id),
			"Unlock id '%s' should be unique" % u.id
		)
		seen[u.id] = true


func test_unlock_get_by_id() -> void:
	var u: UnlockDefinition = DataLoaderSingleton.get_unlock(
		"order_catalog_expansion_1"
	)
	assert_not_null(u, "Should find unlock by id")
	assert_eq(
		u.effect_type, "catalog_expansion",
		"Should have correct effect_type"
	)
	assert_eq(
		u.effect_target, "tier_2",
		"Should have correct effect_target"
	)


func test_unlock_content_registry_integration() -> void:
	var ids: Array[StringName] = (
		ContentRegistry.get_all_ids("unlock")
	)
	assert_gte(
		ids.size(), 6,
		"ContentRegistry should have at least 6 unlock entries"
	)
