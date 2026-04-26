## Regression tests for ISSUE-004 — reliable Day 1 live customer spawn for retro_games.
##
## Verifies two contracts the BRAINDUMP Validation Loop steps 6-7 depend on:
##   1. MallCustomerSpawner produces a customer in retro_games within ≤2 in-game
##      hours of store-open at default time speed (rep 50/REPUTABLE, hour 9
##      morning), with no probability-base tuning.
##   2. The Day-1 retro_games starter cartridge → customer profile pipeline has
##      at least one path through `_is_item_desirable` that does not exit on
##      `&"no_matching_item"` (the issue's gate criterion).
extends GutTest


const STORE_ID: String = "retro_games"
## Real-seconds upper bound for first-spawn timing at default speed (1x):
## 1 real second = 1 in-game minute, so 120s = 2 in-game hours.
const TWO_GAME_HOURS_SECONDS: float = 120.0
const RETRO_PROFILE_IDS: Array = [
	"retro_nostalgic_adult",
	"retro_speedrunner",
	"retro_parent",
	"retro_reseller",
]

var _saved_owned_stores: Array[StringName] = []


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func before_each() -> void:
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.owned_stores = [StringName(STORE_ID)]


func after_each() -> void:
	GameManager.owned_stores = _saved_owned_stores


# ── Spawn timing ─────────────────────────────────────────────────────────────


func test_default_day1_spawn_interval_within_two_in_game_hours() -> void:
	var customer_system: CustomerSystem = CustomerSystem.new()
	add_child_autofree(customer_system)
	var reputation: ReputationSystem = ReputationSystem.new()
	reputation.auto_connect_bus = false
	add_child_autofree(reputation)
	reputation.initialize_store(STORE_ID)

	var spawner: MallCustomerSpawner = MallCustomerSpawner.new()
	add_child_autofree(spawner)
	spawner.initialize(customer_system, reputation)

	var interval: float = spawner._get_spawn_interval()
	assert_lte(
		interval,
		TWO_GAME_HOURS_SECONDS,
		(
			"At default Day-1 reputation (50/REPUTABLE) and morning hour-of-day "
			+ "(0.5×), the spawn interval must be ≤ 2 in-game hours so a live "
			+ "customer can enter retro_games within Validation Loop step 6's "
			+ "window. Got %.2fs."
		) % interval
	)


func test_spawn_picks_retro_games_when_only_owned_store() -> void:
	# When retro_games is the sole owned store, every successful selection
	# must target retro_games — otherwise the Day-1 single-store spawn never
	# reaches the live Customer3D path.
	var customer_system: CustomerSystem = CustomerSystem.new()
	add_child_autofree(customer_system)
	var reputation: ReputationSystem = ReputationSystem.new()
	reputation.auto_connect_bus = false
	add_child_autofree(reputation)
	reputation.initialize_store(STORE_ID)

	var spawner: MallCustomerSpawner = MallCustomerSpawner.new()
	add_child_autofree(spawner)
	spawner.initialize(customer_system, reputation)

	var weights: Dictionary = spawner._store_selector.calculate_store_weights()
	assert_true(
		weights.has(STORE_ID),
		"StoreSelector must include retro_games when it is the only owned store"
	)
	assert_eq(
		weights.size(), 1,
		"With one owned store, weights should contain exactly retro_games"
	)


# ── Desirability gates ───────────────────────────────────────────────────────


func test_starter_inventory_items_use_good_condition() -> void:
	# ISSUE-004 fix: deterministic "good" condition keeps Day-1 prices at the
	# base_price baseline so the live customer's _is_item_desirable budget
	# check has a stable input.
	var items: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(STORE_ID)
	)
	assert_false(items.is_empty(), "Starter inventory must not be empty")
	for item: ItemInstance in items:
		assert_eq(
			item.condition,
			"good",
			(
				"Starter item '%s' must seed at 'good' condition for a "
				+ "deterministic Day-1 desirability path; got '%s'."
			) % [item.instance_id, item.condition]
		)


func test_speedrunner_profile_accepts_starter_cartridge() -> void:
	# retro_speedrunner ($15-60) is the minimum-budget profile and must accept
	# any common cartridge at "good" condition. This is the guaranteed
	# "no &\"no_matching_item\"" path required by the acceptance criterion.
	var profile: CustomerTypeDefinition = (
		_find_profile_by_id("retro_speedrunner")
	)
	assert_not_null(
		profile, "retro_speedrunner profile must be loaded from content"
	)

	var item: ItemInstance = _make_starter_cartridge()
	assert_not_null(item, "Test fixture must yield a starter cartridge")

	var customer: Customer = _build_customer_for_profile(profile)
	add_child_autofree(customer)

	assert_true(
		customer._is_item_desirable(item),
		(
			"retro_speedrunner must accept a 'good' starter cartridge "
			+ "(price=%.2f, category=%s); rejecting blocks the only "
			+ "guaranteed Day-1 desirability path."
		) % [item.get_current_value(), item.definition.category]
	)


func test_at_least_one_retro_profile_accepts_each_starter_cartridge() -> void:
	# Stronger contract: for *every* generated starter cartridge, at least one
	# of the four retro profiles must pass _is_item_desirable. If none pass,
	# the spawner can deliver a customer who immediately leaves with
	# &"no_matching_item" regardless of how the player priced the SKU.
	var items: Array[ItemInstance] = (
		DataLoaderSingleton.generate_starter_inventory(STORE_ID)
	)
	assert_false(items.is_empty(), "Starter inventory must not be empty")

	for item: ItemInstance in items:
		var matched_profile_id: String = ""
		for profile_id: String in RETRO_PROFILE_IDS:
			var profile: CustomerTypeDefinition = (
				_find_profile_by_id(profile_id)
			)
			if profile == null:
				continue
			var customer: Customer = _build_customer_for_profile(profile)
			add_child_autofree(customer)
			if customer._is_item_desirable(item):
				matched_profile_id = profile_id
				break
		assert_ne(
			matched_profile_id,
			"",
			(
				"Starter cartridge '%s' (price=%.2f, category=%s) must be "
				+ "desirable to ≥1 retro profile; otherwise the live customer "
				+ "flow is gated to &\"no_matching_item\" by content alone."
			) % [
				item.definition.id,
				item.get_current_value(),
				item.definition.category,
			]
		)


func test_match_quality_for_speedrunner_yields_positive_buy_chance() -> void:
	# `_calculate_match_quality` ∈ [0.5, 1.5]. For the speedrunner reading a
	# common cartridge at "good" condition, the category bonus must apply so
	# match_quality * purchase_probability_base > 0 — that is the input to the
	# DECIDING-state randf() roll in customer.gd.
	var profile: CustomerTypeDefinition = (
		_find_profile_by_id("retro_speedrunner")
	)
	assert_not_null(profile, "retro_speedrunner profile must be loaded")

	var item: ItemInstance = _make_starter_cartridge()
	assert_not_null(item, "Test fixture must yield a starter cartridge")

	var customer: Customer = _build_customer_for_profile(profile)
	add_child_autofree(customer)

	var quality: float = customer._calculate_match_quality(item)
	assert_gt(
		quality,
		1.0,
		(
			"Match quality for speedrunner reading a 'cartridges' item at "
			+ "'good' condition should clear the 1.0 baseline (category bonus "
			+ "applied); got %.3f."
		) % quality
	)
	var buy_chance: float = profile.purchase_probability_base * quality
	assert_gt(
		buy_chance,
		0.0,
		"buy_chance must be > 0 for the DECIDING-state randf() roll to ever pass"
	)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _find_profile_by_id(profile_id: String) -> CustomerTypeDefinition:
	var profiles: Array[CustomerTypeDefinition] = (
		DataLoaderSingleton.get_customer_types_for_store(STORE_ID)
	)
	for profile: CustomerTypeDefinition in profiles:
		if profile.id == profile_id:
			return profile
	return null


func _make_starter_cartridge() -> ItemInstance:
	# Pick the first common cartridge from retro_games content so the test
	# does not depend on randomized selection.
	for item_id: StringName in ContentRegistry.get_all_ids("item"):
		var def: ItemDefinition = (
			DataLoaderSingleton.get_item(String(item_id))
		)
		if def == null:
			continue
		if def.rarity != "common":
			continue
		if def.category != "cartridges":
			continue
		var resolved: StringName = ContentRegistry.resolve(def.store_type)
		if String(resolved) != STORE_ID:
			continue
		return ItemInstance.create_from_definition(def, "good")
	return null


func _build_customer_for_profile(
	profile: CustomerTypeDefinition
) -> Customer:
	var scene: PackedScene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	var customer: Customer = scene.instantiate() as Customer
	customer.profile = profile
	customer._budget_multiplier = 1.0
	customer._browse_min_multiplier = 1.0
	return customer
