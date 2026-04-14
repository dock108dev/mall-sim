## Tests that pricing_config.json loads correctly into EconomyConfig.
extends GutTest

func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()

const PRICING_CONFIG_PATH := "res://game/content/economy/pricing_config.json"
const CANONICAL_STORE_IDS: Array[String] = [
	"sports_memorabilia",
	"retro_games",
	"video_rental",
	"pocket_creatures",
	"consumer_electronics",
]


func test_pricing_config_file_exists() -> void:
	assert_true(
		FileAccess.file_exists(PRICING_CONFIG_PATH),
		"pricing_config.json must exist"
	)


func test_pricing_config_type_field() -> void:
	var data: Variant = DataLoaderSingleton.load_json(PRICING_CONFIG_PATH)
	assert_not_null(data, "pricing_config.json must parse without errors")
	assert_true(data is Dictionary, "pricing_config root must be a Dictionary")
	var d: Dictionary = data as Dictionary
	assert_true(d.has("type"), "pricing_config must have a 'type' field")
	assert_eq(
		str(d["type"]), "economy_config",
		"type field must equal 'economy_config'"
	)


func test_starting_cash_is_500() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config, "EconomyConfig must be loaded")
	assert_eq(
		config.starting_cash, 500.0,
		"starting_cash must be 500.0"
	)


func test_rarity_multipliers_has_five_entries() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_eq(
		config.rarity_multipliers.size(), 5,
		"rarity_multipliers must have exactly 5 entries"
	)
	for val: float in config.rarity_multipliers:
		assert_gt(val, 0.0, "Each rarity multiplier must be positive")


func test_rarity_multipliers_ordering() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_eq(config.rarity_multipliers.size(), 5)
	# Common < Uncommon < Rare < Epic < Legendary
	for i: int in range(1, config.rarity_multipliers.size()):
		assert_gt(
			config.rarity_multipliers[i],
			config.rarity_multipliers[i - 1],
			"Rarity multipliers must be strictly ascending"
		)


func test_condition_multipliers_has_five_entries() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_eq(
		config.condition_multipliers.size(), 5,
		"condition_multipliers must have exactly 5 entries"
	)
	for val: float in config.condition_multipliers:
		assert_gt(val, 0.0, "Each condition multiplier must be positive")


func test_condition_multipliers_ordering() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_eq(config.condition_multipliers.size(), 5)
	# Poor < Fair < Good < VeryGood < Mint
	for i: int in range(1, config.condition_multipliers.size()):
		assert_gt(
			config.condition_multipliers[i],
			config.condition_multipliers[i - 1],
			"Condition multipliers must be strictly ascending"
		)


func test_daily_rent_multipliers_has_all_store_ids() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	for store_id: String in CANONICAL_STORE_IDS:
		assert_true(
			config.daily_rent_multipliers.has(store_id),
			"daily_rent_multipliers must contain '%s'" % store_id
		)


func test_haggle_fields_present() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_gt(
		config.haggle_floor_ratio, 0.0,
		"haggle_floor_ratio must be positive"
	)
	assert_lt(
		config.haggle_floor_ratio, 1.0,
		"haggle_floor_ratio must be less than 1.0"
	)
	assert_gt(
		config.haggle_max_rounds, 0,
		"haggle_max_rounds must be positive"
	)


func test_authentication_price_bonus_present() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_gt(
		config.authentication_price_bonus, 0.0,
		"authentication_price_bonus must be positive"
	)


func test_late_fee_per_day_present() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	assert_gt(
		config.late_fee_per_day, 0.0,
		"late_fee_per_day must be positive"
	)


func test_content_registry_resolves_economy_config() -> void:
	var resource: Resource = ContentRegistry._resources.get(
		&"economy_config"
	)
	assert_not_null(
		resource,
		"ContentRegistry must have 'economy_config' registered"
	)
	assert_true(
		resource is EconomyConfig,
		"Registered 'economy_config' must be an EconomyConfig resource"
	)


func test_get_daily_rent_applies_multiplier() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config)
	var sports_rent: float = config.get_daily_rent("sports_memorabilia")
	var electronics_rent: float = config.get_daily_rent("consumer_electronics")
	assert_gt(sports_rent, 0.0, "Sports rent must be positive")
	assert_gt(
		electronics_rent, sports_rent,
		"Electronics rent must exceed sports rent (higher multiplier)"
	)
