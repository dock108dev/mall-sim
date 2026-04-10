## Loads JSON content files from the content directory and builds typed registries.
class_name DataLoader
extends RefCounted

var _items: Dictionary = {}  # id -> ItemDefinition
var _stores: Dictionary = {}  # id -> StoreDefinition
var _customers: Dictionary = {}  # id -> CustomerProfile
var _fixtures: Dictionary = {}  # id -> FixtureDefinition
var _market_events: Dictionary = {}  # id -> MarketEventDefinition
var _seasonal_events: Dictionary = {}  # id -> SeasonalEventDefinition
var _random_events: Dictionary = {}  # id -> RandomEventDefinition
var _staff_definitions: Dictionary = {}  # id -> StaffDefinition
var _economy_config: EconomyConfig = null

var _loaded: bool = false


## Loads all content from the standard content directories and builds registries.
func load_all_content() -> void:
	if _loaded:
		return
	_load_items(Constants.ITEMS_PATH)
	_load_stores(Constants.STORES_PATH)
	_load_customers(Constants.CUSTOMERS_PATH)
	_load_economy(Constants.ECONOMY_PATH)
	_load_fixtures(Constants.FIXTURES_PATH)
	_load_market_events(Constants.EVENTS_PATH)
	_load_seasonal_events(Constants.SEASONAL_EVENTS_PATH)
	_load_random_events(Constants.RANDOM_EVENTS_PATH)
	_load_staff_definitions(Constants.STAFF_PATH)
	_loaded = true


## Returns the ItemDefinition for the given id, or null if not found.
func get_item(id: String) -> ItemDefinition:
	if not _items.has(id):
		push_warning("DataLoader: item '%s' not found" % id)
		return null
	return _items[id] as ItemDefinition


## Returns all ItemDefinitions whose store_type matches the given store type.
func get_items_by_store(store_type: String) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		if item.store_type == store_type:
			result.append(item)
	return result


## Returns all loaded ItemDefinitions.
func get_all_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		result.append(item)
	return result


## Returns all ItemDefinitions whose category matches the given category.
func get_items_by_category(category: String) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		if item.category == category:
			result.append(item)
	return result


## Returns the StoreDefinition for the given id, or null if not found.
func get_store(id: String) -> StoreDefinition:
	if not _stores.has(id):
		push_warning("DataLoader: store '%s' not found" % id)
		return null
	return _stores[id] as StoreDefinition


## Returns all loaded StoreDefinitions.
func get_all_stores() -> Array[StoreDefinition]:
	var result: Array[StoreDefinition] = []
	for store: StoreDefinition in _stores.values():
		result.append(store)
	return result


## Returns CustomerProfiles whose store_types include the given store type.
func get_customer_types_for_store(store_type: String) -> Array[CustomerProfile]:
	var result: Array[CustomerProfile] = []
	for profile: CustomerProfile in _customers.values():
		if store_type in profile.store_types:
			result.append(profile)
	return result


## Returns all loaded CustomerProfiles.
func get_all_customers() -> Array[CustomerProfile]:
	var result: Array[CustomerProfile] = []
	for profile: CustomerProfile in _customers.values():
		result.append(profile)
	return result


## Returns the parsed economy configuration resource.
func get_economy_config() -> EconomyConfig:
	return _economy_config


## Returns the FixtureDefinition for the given id, or null if not found.
func get_fixture(id: String) -> FixtureDefinition:
	if not _fixtures.has(id):
		push_warning("DataLoader: fixture '%s' not found" % id)
		return null
	return _fixtures[id] as FixtureDefinition


## Returns all loaded FixtureDefinitions.
func get_all_fixtures() -> Array[FixtureDefinition]:
	var result: Array[FixtureDefinition] = []
	for fixture: FixtureDefinition in _fixtures.values():
		result.append(fixture)
	return result


## Returns fixtures available for a given store type (universal + matching store-specific).
func get_fixtures_for_store(store_type: String) -> Array[FixtureDefinition]:
	var result: Array[FixtureDefinition] = []
	for fixture: FixtureDefinition in _fixtures.values():
		if fixture.store_types.is_empty() or store_type in fixture.store_types:
			result.append(fixture)
	return result


## Returns the total number of loaded fixture definitions.
func get_fixture_count() -> int:
	return _fixtures.size()


## Returns the MarketEventDefinition for the given id, or null if not found.
func get_market_event(id: String) -> MarketEventDefinition:
	if not _market_events.has(id):
		push_warning("DataLoader: market event '%s' not found" % id)
		return null
	return _market_events[id] as MarketEventDefinition


## Returns all loaded MarketEventDefinitions.
func get_all_market_events() -> Array[MarketEventDefinition]:
	var result: Array[MarketEventDefinition] = []
	for evt: MarketEventDefinition in _market_events.values():
		result.append(evt)
	return result


## Returns the SeasonalEventDefinition for the given id, or null.
func get_seasonal_event(id: String) -> SeasonalEventDefinition:
	if not _seasonal_events.has(id):
		push_warning(
			"DataLoader: seasonal event '%s' not found" % id
		)
		return null
	return _seasonal_events[id] as SeasonalEventDefinition


## Returns all loaded SeasonalEventDefinitions.
func get_all_seasonal_events() -> Array[SeasonalEventDefinition]:
	var result: Array[SeasonalEventDefinition] = []
	for evt: SeasonalEventDefinition in _seasonal_events.values():
		result.append(evt)
	return result


## Returns the RandomEventDefinition for the given id, or null.
func get_random_event(id: String) -> RandomEventDefinition:
	if not _random_events.has(id):
		push_warning(
			"DataLoader: random event '%s' not found" % id
		)
		return null
	return _random_events[id] as RandomEventDefinition


## Returns all loaded RandomEventDefinitions.
func get_all_random_events() -> Array[RandomEventDefinition]:
	var result: Array[RandomEventDefinition] = []
	for evt: RandomEventDefinition in _random_events.values():
		result.append(evt)
	return result


## Returns the StaffDefinition for the given id, or null if not found.
func get_staff_definition(id: String) -> StaffDefinition:
	if not _staff_definitions.has(id):
		push_warning("DataLoader: staff '%s' not found" % id)
		return null
	return _staff_definitions[id] as StaffDefinition


## Returns all loaded StaffDefinitions.
func get_all_staff_definitions() -> Array[StaffDefinition]:
	var result: Array[StaffDefinition] = []
	for def: StaffDefinition in _staff_definitions.values():
		result.append(def)
	return result


## Returns market events that target a given store type.
func get_market_events_for_store(
	store_type: String
) -> Array[MarketEventDefinition]:
	var result: Array[MarketEventDefinition] = []
	for evt: MarketEventDefinition in _market_events.values():
		if evt.target_store_types.is_empty():
			result.append(evt)
		elif store_type in evt.target_store_types:
			result.append(evt)
	return result


## Creates ItemInstance objects from a store's starting_inventory array.
func create_starting_inventory(store_id: String) -> Array[ItemInstance]:
	var store: StoreDefinition = get_store(store_id)
	if not store:
		push_warning("DataLoader: store '%s' not found for starting inventory" % store_id)
		return []
	var instances: Array[ItemInstance] = []
	for item_id: String in store.starting_inventory:
		var def: ItemDefinition = get_item(item_id)
		if not def:
			push_warning("DataLoader: item '%s' in starting_inventory not found" % item_id)
			continue
		instances.append(ItemInstance.create_from_definition(def))
	return instances


## Returns the total number of loaded items.
func get_item_count() -> int:
	return _items.size()


## Returns the total number of loaded stores.
func get_store_count() -> int:
	return _stores.size()


## Returns the total number of loaded customer profiles.
func get_customer_count() -> int:
	return _customers.size()


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("DataLoader: file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning(
			"DataLoader: failed to open '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("DataLoader: parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data


func _load_items(dir_path: String) -> void:
	var entries := _load_entries_from_dir(dir_path)
	for entry: Dictionary in entries:
		var item := _parse_item(entry)
		if item:
			_register_unique(entry, item.id, _items, "ItemDefinition", item)


func _load_stores(dir_path: String) -> void:
	var entries := _load_entries_from_dir(dir_path)
	for entry: Dictionary in entries:
		var store := _parse_store(entry)
		if store:
			_register_unique(entry, store.id, _stores, "StoreDefinition", store)


func _load_customers(dir_path: String) -> void:
	var entries := _load_entries_from_dir(dir_path)
	for entry: Dictionary in entries:
		var profile := _parse_customer(entry)
		if profile:
			_register_unique(entry, profile.id, _customers, "CustomerProfile", profile)


func _load_economy(dir_path: String) -> void:
	var merged: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("DataLoader: cannot open economy dir: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var data: Variant = load_json(dir_path.path_join(file_name))
			if data is Dictionary:
				merged.merge(data, true)
		file_name = dir.get_next()
	_economy_config = _parse_economy_config(merged)


func _parse_economy_config(data: Dictionary) -> EconomyConfig:
	var config := EconomyConfig.new()
	config.starting_cash = float(data.get("starting_cash", 500.0))
	if data.has("condition_multipliers"):
		config.condition_multipliers = data["condition_multipliers"]
	if data.has("rarity_multipliers"):
		config.rarity_multipliers = data["rarity_multipliers"]
	if data.has("reputation_tiers"):
		config.reputation_tiers = data["reputation_tiers"]
	if data.has("markup_ranges"):
		config.markup_ranges = data["markup_ranges"]
	if data.has("demand_modifiers"):
		config.demand_modifiers = data["demand_modifiers"]
	if data.has("daily_rent_per_size"):
		config.daily_rent_per_size = data["daily_rent_per_size"]
	return config


func _load_entries_from_dir(dir_path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("DataLoader: cannot open dir: %s" % dir_path)
		return entries
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var data: Variant = load_json(dir_path.path_join(file_name))
			if data is Dictionary:
				entries.append(data)
			elif data is Array:
				for entry: Variant in data:
					if entry is Dictionary:
						entries.append(entry)
		file_name = dir.get_next()
	return entries


func _register_unique(
	entry: Dictionary, id: String, registry: Dictionary, type_name: String, resource: Resource
) -> void:
	if id.is_empty():
		push_warning("DataLoader: %s missing required 'id' field, skipping: %s" % [type_name, entry])
		return
	if registry.has(id):
		push_warning("DataLoader: duplicate %s id '%s', keeping first" % [type_name, id])
		return
	registry[id] = resource


func _parse_item(data: Dictionary) -> ItemDefinition:
	if not data.has("id") or not data.has("name") or not data.has("base_price"):
		push_warning("DataLoader: item missing required fields (id, name, base_price), skipping: %s" % [data])
		return null
	var item := ItemDefinition.new()
	item.id = str(data["id"])
	item.name = str(data["name"])
	item.description = str(data.get("description", ""))
	item.category = str(data.get("category", ""))
	item.subcategory = str(data.get("subcategory", ""))
	item.store_type = str(data.get("store_type", ""))
	item.base_price = float(data.get("base_price", 0.0))
	item.rarity = str(data.get("rarity", "common"))
	item.icon_path = str(data.get("icon_path", ""))
	item.depreciates = bool(data.get("depreciates", false))
	item.appreciates = bool(data.get("appreciates", false))
	item.rental_tier = str(data.get("rental_tier", ""))
	item.rental_fee = float(data.get("rental_fee", 0.0))
	item.brand = str(data.get("brand", ""))
	item.product_line = str(data.get("product_line", ""))
	item.generation = int(data.get("generation", 0))
	item.lifecycle_phase = str(data.get("lifecycle_phase", ""))
	item.launch_day = int(data.get("launch_day", 0))
	if data.has("condition_range"):
		item.condition_range = PackedStringArray(data["condition_range"])
	if data.has("tags"):
		item.tags = PackedStringArray(data["tags"])
	return item


func _parse_store(data: Dictionary) -> StoreDefinition:
	if not data.has("id") or not data.has("name"):
		push_warning("DataLoader: store missing required fields (id, name), skipping: %s" % [data])
		return null
	var store := StoreDefinition.new()
	store.id = str(data["id"])
	store.name = str(data["name"])
	store.store_type = str(data.get("store_type", ""))
	store.description = str(data.get("description", ""))
	store.size_category = str(data.get("size_category", "small"))
	store.starting_budget = float(data.get("starting_budget", 5000.0))
	store.fixture_slots = int(data.get("fixture_slots", 6))
	store.max_employees = int(data.get("max_employees", 2))
	store.shelf_capacity = int(data.get("shelf_capacity", 0))
	store.backroom_capacity = int(data.get("backroom_capacity", 0))
	store.starting_cash = float(data.get("starting_cash", 0.0))
	store.daily_rent = float(data.get("daily_rent", 0.0))
	store.base_foot_traffic = float(data.get("base_foot_traffic", 0.0))
	store.ambient_sound = str(data.get("ambient_sound", ""))
	if data.has("allowed_categories"):
		store.allowed_categories = PackedStringArray(data["allowed_categories"])
	if data.has("starting_inventory"):
		store.starting_inventory = PackedStringArray(data["starting_inventory"])
	if data.has("fixtures"):
		var fixtures_arr: Array[Dictionary] = []
		for fixture: Variant in data["fixtures"]:
			if fixture is Dictionary:
				fixtures_arr.append(fixture)
		store.fixtures = fixtures_arr
	if data.has("unique_mechanics"):
		store.unique_mechanics = PackedStringArray(data["unique_mechanics"])
	if data.has("aesthetic_tags"):
		store.aesthetic_tags = PackedStringArray(data["aesthetic_tags"])
	return store


func _load_fixtures(dir_path: String) -> void:
	var entries := _load_entries_from_dir(dir_path)
	for entry: Dictionary in entries:
		var fixture := _parse_fixture(entry)
		if fixture:
			_register_unique(
				entry, fixture.id, _fixtures,
				"FixtureDefinition", fixture
			)


func _parse_fixture(data: Dictionary) -> FixtureDefinition:
	if not data.has("id") or not data.has("name") or not data.has("price"):
		push_warning(
			"DataLoader: fixture missing required fields "
			+ "(id, name, price), skipping: %s" % [data]
		)
		return null
	var fixture := FixtureDefinition.new()
	fixture.id = str(data["id"])
	fixture.name = str(data["name"])
	fixture.category = str(data.get("category", "universal"))
	fixture.price = float(data.get("price", 0.0))
	fixture.description = str(data.get("description", ""))
	fixture.slot_count = int(data.get("slot_count", 0))
	if data.has("grid_size") and data["grid_size"] is Array:
		var gs: Array = data["grid_size"]
		if gs.size() >= 2:
			fixture.grid_size = Vector2i(int(gs[0]), int(gs[1]))
	if data.has("unlock_condition") and data["unlock_condition"] is Dictionary:
		fixture.unlock_condition = data["unlock_condition"]
	if data.has("store_types"):
		fixture.store_types = PackedStringArray(data["store_types"])
	fixture.tier_data = _build_tier_data(fixture)
	return fixture


func _build_tier_data(fixture: FixtureDefinition) -> Dictionary:
	var tiers: Dictionary = {}
	for tier: int in [
		FixtureDefinition.TierLevel.BASIC,
		FixtureDefinition.TierLevel.IMPROVED,
		FixtureDefinition.TierLevel.PREMIUM,
	]:
		tiers[tier] = {
			"slot_count": fixture.get_slots_for_tier(tier),
			"purchase_prob_bonus": fixture.get_purchase_prob_bonus(tier),
		}
	return tiers


func _parse_customer(data: Dictionary) -> CustomerProfile:
	if not data.has("id") or not data.has("name"):
		push_warning("DataLoader: customer missing required fields (id, name), skipping: %s" % [data])
		return null
	var profile := CustomerProfile.new()
	profile.id = str(data["id"])
	profile.name = str(data["name"])
	profile.description = str(data.get("description", ""))
	profile.patience = float(data.get("patience", 0.5))
	profile.price_sensitivity = float(data.get("price_sensitivity", 0.5))
	profile.impulse_buy_chance = float(data.get("impulse_buy_chance", 0.1))
	profile.condition_preference = str(data.get("condition_preference", "good"))
	profile.purchase_probability_base = float(data.get("purchase_probability_base", 0.5))
	profile.visit_frequency = str(data.get("visit_frequency", "medium"))
	if data.has("store_types"):
		profile.store_types = PackedStringArray(data["store_types"])
	if data.has("preferred_categories"):
		profile.preferred_categories = PackedStringArray(data["preferred_categories"])
	if data.has("preferred_tags"):
		profile.preferred_tags = PackedStringArray(data["preferred_tags"])
	if data.has("mood_tags"):
		profile.mood_tags = PackedStringArray(data["mood_tags"])
	if data.has("budget_range"):
		var budget: Array[float] = []
		for val: Variant in data["budget_range"]:
			budget.append(float(val))
		profile.budget_range = budget
	if data.has("spending_range"):
		var spending: Array[float] = []
		for val: Variant in data["spending_range"]:
			spending.append(float(val))
		profile.spending_range = spending
	if data.has("browse_time_range"):
		var browse: Array[float] = []
		for val: Variant in data["browse_time_range"]:
			browse.append(float(val))
		profile.browse_time_range = browse
	profile.max_price_to_market_ratio = float(
		data.get("max_price_to_market_ratio", 1.0)
	)
	profile.snack_purchase_probability = float(
		data.get("snack_purchase_probability", 0.0)
	)
	profile.leaves_if_unavailable = bool(
		data.get("leaves_if_unavailable", false)
	)
	if data.has("typical_rental_count"):
		var rentals: Array[int] = []
		for val: Variant in data["typical_rental_count"]:
			rentals.append(int(val))
		profile.typical_rental_count = rentals
	return profile


func _load_market_events(dir_path: String) -> void:
	var entries := _load_entries_from_dir(dir_path)
	for entry: Dictionary in entries:
		var evt := _parse_market_event(entry)
		if evt:
			_register_unique(
				entry, evt.id, _market_events,
				"MarketEventDefinition", evt
			)


func _load_seasonal_events(path: String) -> void:
	var data: Variant = load_json(path)
	if data is not Array:
		push_warning(
			"DataLoader: seasonal events file not an array: %s" % path
		)
		return
	for entry: Variant in data:
		if entry is not Dictionary:
			continue
		var evt := _parse_seasonal_event(entry as Dictionary)
		if evt:
			_register_unique(
				entry as Dictionary, evt.id, _seasonal_events,
				"SeasonalEventDefinition", evt
			)


func _parse_seasonal_event(
	data: Dictionary
) -> SeasonalEventDefinition:
	if not data.has("id") or not data.has("name"):
		push_warning(
			"DataLoader: seasonal event missing required fields "
			+ "(id, name), skipping: %s" % [data]
		)
		return null
	var evt := SeasonalEventDefinition.new()
	evt.id = str(data["id"])
	evt.name = str(data["name"])
	evt.description = str(data.get("description", ""))
	evt.frequency_days = int(data.get("frequency_days", 30))
	evt.duration_days = int(data.get("duration_days", 5))
	evt.offset_days = int(data.get("offset_days", 0))
	evt.customer_traffic_multiplier = float(
		data.get("customer_traffic_multiplier", 1.0)
	)
	evt.spending_multiplier = float(
		data.get("spending_multiplier", 1.0)
	)
	if data.has("customer_type_weights"):
		var raw: Variant = data["customer_type_weights"]
		if raw is Dictionary:
			evt.customer_type_weights = raw as Dictionary
	if data.has("target_categories"):
		evt.target_categories = PackedStringArray(
			data["target_categories"]
		)
	evt.announcement_text = str(
		data.get("announcement_text", "")
	)
	evt.active_text = str(data.get("active_text", ""))
	return evt


func _parse_market_event(data: Dictionary) -> MarketEventDefinition:
	if not data.has("id") or not data.has("name"):
		push_warning(
			"DataLoader: market event missing required fields "
			+ "(id, name), skipping: %s" % [data]
		)
		return null
	if not data.has("event_type"):
		push_warning(
			"DataLoader: market event '%s' missing event_type, skipping"
			% str(data.get("id", ""))
		)
		return null
	var evt := MarketEventDefinition.new()
	evt.id = str(data["id"])
	evt.name = str(data["name"])
	evt.description = str(data.get("description", ""))
	evt.event_type = str(data.get("event_type", "boom"))
	evt.magnitude = float(data.get("magnitude", 1.0))
	evt.duration_days = int(data.get("duration_days", 5))
	evt.announcement_days = int(data.get("announcement_days", 2))
	evt.ramp_up_days = int(data.get("ramp_up_days", 1))
	evt.ramp_down_days = int(data.get("ramp_down_days", 1))
	evt.cooldown_days = int(data.get("cooldown_days", 15))
	evt.weight = float(data.get("weight", 1.0))
	evt.announcement_text = str(data.get("announcement_text", ""))
	evt.active_text = str(data.get("active_text", ""))
	if data.has("target_tags"):
		evt.target_tags = PackedStringArray(data["target_tags"])
	if data.has("target_categories"):
		evt.target_categories = PackedStringArray(
			data["target_categories"]
		)
	if data.has("target_store_types"):
		evt.target_store_types = PackedStringArray(
			data["target_store_types"]
		)
	return evt


func _load_random_events(path: String) -> void:
	var data: Variant = load_json(path)
	if data is not Array:
		push_warning(
			"DataLoader: random events file not an array: %s" % path
		)
		return
	for entry: Variant in data:
		if entry is not Dictionary:
			continue
		var evt := _parse_random_event(entry as Dictionary)
		if evt:
			_register_unique(
				entry as Dictionary, evt.id, _random_events,
				"RandomEventDefinition", evt
			)


func _parse_random_event(
	data: Dictionary
) -> RandomEventDefinition:
	if not data.has("id") or not data.has("name"):
		push_warning(
			"DataLoader: random event missing required fields "
			+ "(id, name), skipping: %s" % [data]
		)
		return null
	var evt := RandomEventDefinition.new()
	evt.id = str(data["id"])
	evt.name = str(data["name"])
	evt.description = str(data.get("description", ""))
	evt.effect_type = str(data.get("effect_type", ""))
	evt.duration_days = int(data.get("duration_days", 1))
	evt.severity = str(data.get("severity", "medium"))
	evt.cooldown_days = int(data.get("cooldown_days", 10))
	evt.target_category = str(data.get("target_category", ""))
	evt.target_item_id = str(data.get("target_item_id", ""))
	evt.notification_text = str(
		data.get("notification_text", "")
	)
	evt.resolution_text = str(data.get("resolution_text", ""))
	return evt


func _load_staff_definitions(dir_path: String) -> void:
	var entries := _load_entries_from_dir(dir_path)
	for entry: Dictionary in entries:
		var def := _parse_staff_definition(entry)
		if def:
			_register_unique(
				entry, def.id, _staff_definitions,
				"StaffDefinition", def
			)


func _parse_staff_definition(
	data: Dictionary
) -> StaffDefinition:
	if not data.has("id") or not data.has("name"):
		push_warning(
			"DataLoader: staff missing required fields "
			+ "(id, name), skipping: %s" % [data]
		)
		return null
	var def := StaffDefinition.new()
	def.id = str(data["id"])
	def.name = str(data["name"])
	def.daily_wage = float(data.get("daily_wage", 20.0))
	def.skill_level = clampi(int(data.get("skill_level", 1)), 1, 5)
	def.specialization = str(
		data.get("specialization", "stocking")
	)
	def.description = str(data.get("description", ""))
	return def
