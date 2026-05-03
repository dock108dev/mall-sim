## Regression tests for ISSUE-003 — retro_games starter inventory on Day 1.
##
## Verifies that DataLoaderSingleton.generate_starter_inventory("retro_games")
## (called from game_world._create_default_store_inventory during
## bootstrap_new_game_state) yields ≥3 ItemInstances suitable for the BRAINDUMP
## Validation Loop tutorial steps PLACE_ITEM / WAIT_FOR_CUSTOMER / COMPLETE_SALE.
extends GutTest

const STORE_ID: String = "retro_games"
const MIN_STARTER_ITEMS: int = 3


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func test_generate_starter_inventory_returns_at_least_three_items() -> void:
	var items: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(STORE_ID)
	)
	assert_gte(
		items.size(),
		MIN_STARTER_ITEMS,
		"retro_games starter inventory must yield ≥%d items, got %d"
			% [MIN_STARTER_ITEMS, items.size()]
	)


func test_starter_items_default_to_backroom_with_zero_player_price() -> void:
	var items: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(STORE_ID)
	)
	assert_false(items.is_empty(), "Starter inventory should not be empty")
	for item: ItemInstance in items:
		assert_eq(
			item.current_location,
			"backroom",
			"Item '%s' must land in backroom, got '%s'"
				% [item.instance_id, item.current_location]
		)
		assert_eq(
			item.player_set_price,
			0.0,
			"Item '%s' must have player_set_price == 0.0 so haggle has price headroom"
				% item.instance_id
		)


func test_starter_items_have_positive_base_price_and_retro_games_store() -> void:
	var items: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(STORE_ID)
	)
	assert_false(items.is_empty(), "Starter inventory should not be empty")
	for item: ItemInstance in items:
		assert_not_null(
			item.definition,
			"Item '%s' must have a non-null definition" % item.instance_id
		)
		var def: ItemDefinition = item.definition
		assert_gt(
			def.base_price,
			0.0,
			"Item '%s' must have base_price > 0 for PricingPanel suggestion"
				% def.id
		)
		var resolved: StringName = ContentRegistry.resolve(def.store_type)
		assert_eq(
			String(resolved),
			STORE_ID,
			"Item '%s' must resolve to retro_games, got '%s'"
				% [def.id, resolved]
		)
		assert_eq(
			def.rarity,
			"common",
			"Starter items must be common rarity, got '%s' for '%s'"
				% [def.rarity, def.id]
		)


## Verifies the catalog supplies at least one broadly desirable common
## retro_games item (low base price, "good" in condition_range) so the
## live-customer flow has a viable match path. Catalog-level check rather
## than inventory-level, since condition is randomized per instance.
func test_retro_games_common_pool_contains_broadly_desirable_item() -> void:
	var max_desirable_price: float = 30.0
	var found: bool = false
	for item_id: StringName in ContentRegistry.get_all_ids("item"):
		var def: ItemDefinition = (
			DataLoaderSingleton.get_item(String(item_id))
		)
		if def == null or def.rarity != "common":
			continue
		var resolved: StringName = ContentRegistry.resolve(def.store_type)
		if String(resolved) != STORE_ID:
			continue
		if def.base_price <= 0.0 or def.base_price > max_desirable_price:
			continue
		if "good" in def.condition_range:
			found = true
			break
	assert_true(
		found,
		(
			"retro_games common-item pool must contain ≥1 broadly desirable "
			+ "entry (base_price ≤ %.2f, 'good' in condition_range) so a "
			+ "Day-1 customer can match the live-buy step."
		) % max_desirable_price
	)
