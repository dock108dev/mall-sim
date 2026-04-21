## Tests issue-119 resource aliases, typed getters, and typed loading surfaces.
extends GutTest


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func test_item_definition_aliases_stay_in_sync() -> void:
	var item := ItemDefinition.new()
	item.id = "issue_119_card"
	item.category = "trading_cards"
	item.store_type = "sports"
	item.rarity = "rare"
	item.tags = ["rookie", "foil"]

	assert_eq(item.item_id, &"issue_119_card")
	assert_eq(item.category, &"trading_cards")
	assert_eq(item.store_type, &"sports")
	assert_eq(item.get_rarity_tier(), 2)
	assert_eq(Array(item.tags), ["rookie", "foil"])


func test_store_definition_builds_starter_inventory_alias() -> void:
	var store := StoreDefinition.new()
	store.id = "issue_119_store"
	store.display_name = "Issue 119 Store"
	store.starting_inventory = PackedStringArray(["card_a", "card_b"])

	assert_eq(store.store_id, &"issue_119_store")
	assert_eq(store.store_name, "Issue 119 Store")
	assert_eq(store.starter_inventory.size(), 2)
	assert_eq(store.starter_inventory[0].get("item_id"), &"card_a")


func test_customer_type_definition_supports_vector_budget_and_affinity_alias() -> void:
	var customer := CustomerTypeDefinition.new()
	customer.id = "issue_119_customer"
	customer.display_name = "Issue 119 Customer"
	customer.store_types = PackedStringArray(["sports", "retro_games"])
	customer.budget_range = [10.0, 50.0]

	assert_eq(customer.type_id, &"issue_119_customer")
	assert_eq(customer.customer_name, "Issue 119 Customer")
	assert_eq(customer.store_affinity, [StringName("sports"), StringName("retro_games")])
	assert_eq(customer.budget_range_vector, Vector2(10.0, 50.0))


func test_item_instance_tracks_definition_aliases() -> void:
	var item_def := ItemDefinition.new()
	item_def.id = "issue_119_instance_item"
	item_def.item_name = "Issue 119 Item"
	item_def.base_price = 10.0
	item_def.condition_range = PackedStringArray(["good"])

	var instance: ItemInstance = ItemInstance.create_from_definition(item_def)
	instance.player_price = 15.0
	instance.location = &"shelf:test"
	instance.is_authenticated = true

	assert_true(instance is Resource)
	assert_eq(instance.definition_id, &"issue_119_instance_item")
	assert_eq(instance.player_set_price, 15.0)
	assert_eq(instance.current_location, "shelf:test")
	assert_eq(instance.authentication_status, "authenticated")


func test_content_registry_typed_getters_return_resources() -> void:
	var item: ItemDefinition = ContentRegistry.get_item_definition(&"sports_duvall_hr_common")
	var store: StoreDefinition = ContentRegistry.get_store_definition(&"sports")
	var customer: CustomerTypeDefinition = ContentRegistry.get_customer_type_definition(&"power_shopper")
	var economy: EconomyConfig = ContentRegistry.get_economy_config()

	assert_not_null(item)
	assert_not_null(store)
	assert_not_null(customer)
	assert_not_null(economy)
	assert_true(item is ItemDefinition)
	assert_true(store is StoreDefinition)
	assert_true(customer is CustomerTypeDefinition)
	assert_true(economy is EconomyConfig)
