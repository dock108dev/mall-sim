## Static utility for constructing typed Resources from JSON content dictionaries.
class_name ContentParser


static func build_resource(
	content_type: String, data: Dictionary
) -> Resource:
	match content_type:
		"item":
			return parse_item(data)
		"store":
			return parse_store(data)
		"customer":
			return parse_customer(data)
		"fixture":
			return parse_fixture(data)
		"market_event":
			return parse_market_event(data)
		"seasonal_event":
			return parse_seasonal_event(data)
		"random_event":
			return parse_random_event(data)
		"staff":
			return parse_staff(data)
		"milestone":
			return parse_milestone(data)
		"upgrade":
			return parse_upgrade(data)
		"supplier":
			return parse_supplier(data)
		"unlock":
			return parse_unlock(data)
		"sports_season":
			return parse_sports_season(data)
		"tournament_event":
			return parse_tournament_event(data)
		"ambient_moment":
			return parse_ambient_moment(data)
	push_error("ContentParser: unknown type '%s'" % content_type)
	return null


static func parse_item(data: Dictionary) -> ItemDefinition:
	if not data.has("id") or not data.has("base_price"):
		push_error("ContentParser: item missing required fields: %s" % [data])
		return null
	var price_val: float = float(data["base_price"])
	if price_val < 0.0:
		push_error(
			"ContentParser: item '%s' has out-of-range base_price %s (must be >= 0)"
			% [str(data.get("id", "unknown")), price_val]
		)
		return null
	var item := ItemDefinition.new()
	item.id = str(data["id"])
	var item_name_raw: String = str(data.get(
		"item_name", data.get("display_name", "")
	))
	item.item_name = item_name_raw
	item.description = str(data.get("description", ""))
	item.category = str(data.get("category", ""))
	item.subcategory = str(data.get("subcategory", ""))
	item.store_type = str(data.get("store_type", ""))
	item.base_price = price_val
	item.rarity = str(data.get("rarity", "common"))
	item.icon_path = str(data.get("icon_path", ""))
	item.set_name = str(data.get("set_name", ""))
	item.depreciates = bool(data.get("depreciates", false))
	item.appreciates = bool(data.get("appreciates", false))
	item.rental_tier = str(data.get("rental_tier", ""))
	item.rental_fee = float(data.get("rental_fee", 0.0))
	item.rental_period_days = int(data.get("rental_period_days", 0))
	item.brand = str(data.get("brand", ""))
	item.product_line = str(data.get("product_line", ""))
	item.generation = int(data.get("generation", 0))
	item.lifecycle_phase = str(data.get("lifecycle_phase", ""))
	item.launch_day = int(data.get("launch_day", 0))
	item.depreciation_rate = float(data.get("depreciation_rate", 0.0))
	item.min_value_ratio = float(data.get("min_value_ratio", 0.1))
	item.launch_demand_multiplier = float(
		data.get("launch_demand_multiplier", 1.0)
	)
	item.launch_spike_days = int(data.get("launch_spike_days", 0))
	item.platform = str(data.get("platform", ""))
	item.region = str(data.get("region", ""))
	if data.has("condition_range"):
		item.condition_range = PackedStringArray(data["condition_range"])
	if data.has("condition_value_multipliers"):
		item.condition_value_multipliers = data["condition_value_multipliers"]
	if data.has("tags"):
		item.tags = PackedStringArray(data["tags"])
	var extra: Dictionary = {}
	var known_keys: PackedStringArray = [
		"id", "item_name", "display_name", "description", "category",
		"subcategory", "store_type", "base_price", "rarity", "icon_path",
		"set_name", "depreciates", "appreciates", "rental_tier",
		"rental_fee", "rental_period_days", "brand", "product_line",
		"generation", "lifecycle_phase", "launch_day",
		"depreciation_rate", "min_value_ratio",
		"launch_demand_multiplier", "launch_spike_days", "platform",
		"region", "condition_range", "condition_value_multipliers",
		"tags",
	]
	for key: String in data:
		if key not in known_keys:
			extra[key] = data[key]
	if not extra.is_empty():
		item.extra = extra
	return item


static func parse_store(data: Dictionary) -> StoreDefinition:
	if not data.has("id") or not data.has("name"):
		push_error(
			"ContentParser: store missing required fields: %s" % [data]
		)
		return null
	var store := StoreDefinition.new()
	store.id = str(data["id"])
	store.store_name = str(data["name"])
	store.store_type = str(data.get("store_type", ""))
	store.description = str(data.get("description", ""))
	store.scene_path = str(data.get("scene_path", ""))
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
	store.music = str(data.get("music", ""))
	if data.has("allowed_categories"):
		store.allowed_categories = PackedStringArray(
			data["allowed_categories"]
		)
	if data.has("starting_inventory"):
		store.starting_inventory = PackedStringArray(
			data["starting_inventory"]
		)
	if data.has("fixtures"):
		var arr: Array[Dictionary] = []
		for f: Variant in data["fixtures"]:
			if f is Dictionary:
				arr.append(f)
		store.fixtures = arr
	if data.has("available_supplier_tiers"):
		var tiers: Array[int] = []
		for t: Variant in data["available_supplier_tiers"]:
			tiers.append(int(t))
		store.available_supplier_tiers = tiers
	if data.has("unique_mechanics"):
		store.unique_mechanics = PackedStringArray(
			data["unique_mechanics"]
		)
	if data.has("aesthetic_tags"):
		store.aesthetic_tags = PackedStringArray(data["aesthetic_tags"])
	if data.has("recommended_markup"):
		var m: Variant = data["recommended_markup"]
		if m is Dictionary:
			store.recommended_markup_optimal_min = float(
				m.get("optimal_min", 0.0)
			)
			store.recommended_markup_optimal_max = float(
				m.get("optimal_max", 0.0)
			)
			store.recommended_markup_max_viable = float(
				m.get("max_viable", 0.0)
			)
	return store


static func parse_customer(
	data: Dictionary
) -> CustomerTypeDefinition:
	if not data.has("id") or not data.has("name"):
		push_error(
			"ContentParser: customer missing required fields: %s"
			% [data]
		)
		return null
	var p := CustomerTypeDefinition.new()
	p.id = str(data["id"])
	p.customer_name = str(data["name"])
	p.description = str(data.get("description", ""))
	p.patience = float(data.get("patience", 0.5))
	p.price_sensitivity = float(data.get("price_sensitivity", 0.5))
	p.impulse_buy_chance = float(data.get("impulse_buy_chance", 0.1))
	p.condition_preference = str(
		data.get("condition_preference", "good")
	)
	p.purchase_probability_base = float(
		data.get("purchase_probability_base", 0.5)
	)
	p.visit_frequency = str(data.get("visit_frequency", "medium"))
	p.max_price_to_market_ratio = float(
		data.get("max_price_to_market_ratio", 1.0)
	)
	p.snack_purchase_probability = float(
		data.get("snack_purchase_probability", 0.0)
	)
	p.leaves_if_unavailable = bool(
		data.get("leaves_if_unavailable", false)
	)
	p.dialogue_pool = str(data.get("dialogue_pool", ""))
	p.model_path = str(data.get("model", data.get("model_path", "")))
	if data.has("store_types"):
		p.store_types = PackedStringArray(data["store_types"])
	if data.has("preferred_categories"):
		p.preferred_categories = PackedStringArray(
			data["preferred_categories"]
		)
	if data.has("preferred_tags"):
		p.preferred_tags = PackedStringArray(data["preferred_tags"])
	if data.has("preferred_rarities"):
		p.preferred_rarities = PackedStringArray(
			data["preferred_rarities"]
		)
	if data.has("mood_tags"):
		p.mood_tags = PackedStringArray(data["mood_tags"])
	p.budget_range = _parse_float_array(data, "budget_range")
	p.spending_range = _parse_float_array(data, "spending_range")
	p.browse_time_range = _parse_float_array(data, "browse_time_range")
	if data.has("typical_rental_count"):
		var arr: Array[int] = []
		for val: Variant in data["typical_rental_count"]:
			arr.append(int(val))
		p.typical_rental_count = arr
	return p


static func parse_fixture(data: Dictionary) -> FixtureDefinition:
	var has_name: bool = data.has("name") or data.has("display_name")
	var has_price: bool = (
		data.has("price") or data.has("cost")
		or data.has("purchase_cost")
	)
	if not data.has("id") or not has_name or not has_price:
		push_error(
			"ContentParser: fixture missing required fields: %s"
			% [data]
		)
		return null
	var f := FixtureDefinition.new()
	f.id = str(data["id"])
	f.display_name = str(
		data.get("display_name", data.get("name", ""))
	)
	f.name = f.display_name
	f.cost = float(data.get(
		"cost", data.get("price", data.get("purchase_cost", 0.0))
	))
	f.price = f.cost
	f.description = str(data.get("description", ""))
	f.slot_count = int(
		data.get("slot_count", data.get("item_capacity", 0))
	)
	f.rotation_support = bool(data.get("rotation_support", false))
	f.unlock_rep = float(data.get("unlock_rep", 0.0))
	f.unlock_day = int(data.get("unlock_day", 0))
	f.requires_wall = bool(data.get("requires_wall", false))
	f.visual_category = str(data.get("visual_category", ""))
	f.scene_path = str(data.get("scene_path", ""))
	_parse_fixture_unlock(f, data)
	_parse_fixture_store_types(f, data)
	_parse_fixture_footprint(f, data)
	f.tier_data = _build_tier_data(f)
	return f


static func parse_market_event(
	data: Dictionary
) -> MarketEventDefinition:
	if not data.has("id") or not data.has("event_type"):
		push_error(
			"ContentParser: market event missing required fields: %s"
			% [data]
		)
		return null
	var e := MarketEventDefinition.new()
	e.id = str(data["id"])
	e.name = str(data.get("name", ""))
	e.description = str(data.get("description", ""))
	e.event_type = str(data["event_type"])
	e.magnitude = float(data.get("magnitude", 1.0))
	e.duration_days = int(data.get("duration_days", 5))
	e.announcement_days = int(data.get("announcement_days", 2))
	e.ramp_up_days = int(data.get("ramp_up_days", 1))
	e.ramp_down_days = int(data.get("ramp_down_days", 1))
	e.cooldown_days = int(data.get("cooldown_days", 15))
	e.weight = float(data.get("weight", 1.0))
	e.announcement_text = str(data.get("announcement_text", ""))
	e.active_text = str(data.get("active_text", ""))
	if data.has("target_tags"):
		e.target_tags = PackedStringArray(data["target_tags"])
	if data.has("target_categories"):
		e.target_categories = PackedStringArray(
			data["target_categories"]
		)
	if data.has("target_store_types"):
		e.target_store_types = PackedStringArray(
			data["target_store_types"]
		)
	return e


static func parse_seasonal_event(
	data: Dictionary
) -> SeasonalEventDefinition:
	if not data.has("id") or not data.has("name"):
		push_error(
			"ContentParser: seasonal event missing required fields: %s"
			% [data]
		)
		return null
	var e := SeasonalEventDefinition.new()
	e.id = str(data["id"])
	e.name = str(data["name"])
	e.description = str(data.get("description", ""))
	e.frequency_days = int(data.get("frequency_days", 30))
	e.duration_days = int(data.get("duration_days", 5))
	e.offset_days = int(data.get("offset_days", 0))
	e.customer_traffic_multiplier = float(
		data.get("customer_traffic_multiplier", 1.0)
	)
	e.spending_multiplier = float(
		data.get("spending_multiplier", 1.0)
	)
	if data.has("customer_type_weights"):
		var raw: Variant = data["customer_type_weights"]
		if raw is Dictionary:
			e.customer_type_weights = raw as Dictionary
	if data.has("target_categories"):
		e.target_categories = PackedStringArray(
			data["target_categories"]
		)
	e.announcement_text = str(data.get("announcement_text", ""))
	e.active_text = str(data.get("active_text", ""))
	return e


static func parse_random_event(
	data: Dictionary
) -> RandomEventDefinition:
	if not data.has("id") or not data.has("name"):
		push_error(
			"ContentParser: random event missing required fields: %s"
			% [data]
		)
		return null
	var e := RandomEventDefinition.new()
	e.id = str(data["id"])
	e.name = str(data["name"])
	e.description = str(data.get("description", ""))
	e.effect_type = str(data.get("effect_type", ""))
	e.duration_days = int(data.get("duration_days", 1))
	e.severity = str(data.get("severity", "medium"))
	e.cooldown_days = int(data.get("cooldown_days", 10))
	e.probability_weight = float(data.get("probability_weight", 1.0))
	e.target_category = str(data.get("target_category", ""))
	e.target_item_id = str(data.get("target_item_id", ""))
	e.notification_text = str(data.get("notification_text", ""))
	e.resolution_text = str(data.get("resolution_text", ""))
	e.toast_message = str(data.get("toast_message", ""))
	e.time_window_start = int(data.get("time_window_start", -1))
	e.time_window_end = int(data.get("time_window_end", -1))
	e.bulk_order_quantity = int(data.get("bulk_order_quantity", 3))
	e.bulk_order_price_multiplier = float(
		data.get("bulk_order_price_multiplier", 1.2)
	)
	return e


static func parse_staff(data: Dictionary) -> StaffDefinition:
	if not data.has("id") or not data.has("name"):
		push_error(
			"ContentParser: staff missing required fields: %s" % [data]
		)
		return null
	var d := StaffDefinition.new()
	d.staff_id = str(data["id"])
	d.display_name = str(data["name"])
	d.skill_level = clampi(int(data.get("skill_level", 1)), 1, 3)
	d.daily_wage = float(data.get("daily_wage", 20.0))
	d.hire_cost = float(data.get("hire_cost", 0.0))
	d.morale = float(
		data.get("morale_start", StaffDefinition.DEFAULT_MORALE)
	)
	d.morale_decay_per_day = float(
		data.get(
			"morale_decay_per_day",
			StaffDefinition.DEFAULT_MORALE_DECAY,
		)
	)
	d.skill_bonus = float(data.get("skill_bonus", 0.0))
	d.description = str(data.get("description", ""))
	var role_str: String = str(data.get("role", "cashier")).to_lower()
	match role_str:
		"stocker":
			d.role = StaffDefinition.StaffRole.STOCKER
		"greeter":
			d.role = StaffDefinition.StaffRole.GREETER
		_:
			d.role = StaffDefinition.StaffRole.CASHIER
	return d


static func parse_milestone(data: Dictionary) -> MilestoneDefinition:
	var has_name: bool = (
		data.has("display_name") or data.has("name")
	)
	if not data.has("id") or not has_name:
		push_error(
			"ContentParser: milestone missing required fields: %s"
			% [data]
		)
		return null
	var m := MilestoneDefinition.new()
	m.id = str(data["id"])
	m.display_name = str(
		data.get("display_name", data.get("name", ""))
	)
	m.description = str(data.get("description", ""))
	m.is_visible = bool(data.get("is_visible", true))
	m.tier = str(data.get("tier", ""))
	m.trigger_type = str(data.get("trigger_type", ""))
	m.trigger_threshold = float(
		data.get(
			"trigger_threshold", data.get("threshold", 0.0)
		)
	)
	m.trigger_stat_key = str(
		data.get(
			"trigger_stat_key",
			data.get("condition_type", "")
		)
	)
	m.reward_type = str(data.get("reward_type", "none"))
	m.reward_value = float(data.get("reward_value", 0.0))
	var raw_unlock: Variant = data.get("unlock_id")
	m.unlock_id = str(raw_unlock) if raw_unlock != null else ""
	return m


static func parse_upgrade(data: Dictionary) -> UpgradeDefinition:
	if not data.has("id") or not data.has("display_name"):
		push_error(
			"ContentParser: upgrade missing required fields: %s"
			% [data]
		)
		return null
	var u := UpgradeDefinition.new()
	u.id = str(data["id"])
	u.display_name = str(data["display_name"])
	u.description = str(data.get("description", ""))
	u.cost = float(data.get("cost", 0.0))
	u.rep_required = float(data.get("rep_required", 0.0))
	u.store_type = str(data.get("store_type", ""))
	u.effect_type = str(data.get("effect_type", ""))
	u.effect_value = float(data.get("effect_value", 0.0))
	return u


static func parse_supplier(data: Dictionary) -> SupplierDefinition:
	if not data.has("id") or not data.has("display_name"):
		push_error(
			"ContentParser: supplier missing required fields: %s"
			% [data]
		)
		return null
	var s := SupplierDefinition.new()
	s.id = str(data["id"])
	s.display_name = str(data["display_name"])
	s.tier = int(data.get("tier", 1))
	s.store_type = str(data.get("store_type", ""))
	s.reliability_rate = float(data.get("reliability_rate", 1.0))
	if data.has("lead_time_days"):
		var lt: Variant = data["lead_time_days"]
		if lt is Dictionary:
			s.lead_time_min = int(lt.get("min", 1))
			s.lead_time_max = int(lt.get("max", 2))
	if data.has("unlock_condition"):
		var uc: Variant = data["unlock_condition"]
		if uc is Dictionary:
			s.unlock_condition = uc
	if data.has("catalog"):
		var cat: Array[Dictionary] = []
		for entry: Variant in data["catalog"]:
			if entry is Dictionary:
				cat.append(entry)
		s.catalog = cat
	return s


static func parse_unlock(data: Dictionary) -> UnlockDefinition:
	if not data.has("id") or not data.has("display_name"):
		push_error(
			"ContentParser: unlock missing required fields: %s"
			% [data]
		)
		return null
	var u := UnlockDefinition.new()
	u.id = str(data["id"])
	u.display_name = str(data["display_name"])
	u.description = str(data.get("description", ""))
	u.effect_type = str(data.get("effect_type", ""))
	if not u.is_valid_effect_type():
		push_error(
			"ContentParser: unlock '%s' has invalid effect_type '%s'"
			% [u.id, u.effect_type]
		)
		return null
	var target: Variant = data.get("effect_target")
	u.effect_target = str(target) if target != null else ""
	var value: Variant = data.get("effect_value")
	u.effect_value = float(value) if value != null else 0.0
	u.unlock_message = str(data.get("unlock_message", ""))
	return u


static func parse_sports_season(
	data: Dictionary
) -> SportsSeasonDefinition:
	if not data.has("id") or not data.has("sport_tag"):
		push_error(
			"ContentParser: sports season missing required fields: %s"
			% [data]
		)
		return null
	var s := SportsSeasonDefinition.new()
	s.id = str(data["id"])
	s.sport_tag = str(data["sport_tag"])
	s.start_day = int(data.get("start_day", 0))
	s.end_day = int(data.get("end_day", 0))
	s.in_season_multiplier = float(
		data.get("in_season_multiplier", 1.0)
	)
	s.off_season_multiplier = float(
		data.get("off_season_multiplier", 1.0)
	)
	return s


static func parse_economy_config(
	data: Dictionary
) -> EconomyConfig:
	var c := EconomyConfig.new()
	c.starting_cash = float(data.get("starting_cash", 500.0))
	c.daily_rent_base = float(
		data.get("daily_rent_base", data.get("daily_rent", 30.0))
	)
	if data.has("daily_rent_multipliers"):
		var raw: Variant = data["daily_rent_multipliers"]
		if raw is Dictionary:
			c.daily_rent_multipliers = raw
	if data.has("rarity_multipliers"):
		c.rarity_multipliers = _parse_float_array(data, "rarity_multipliers")
	if data.has("condition_multipliers"):
		c.condition_multipliers = _parse_float_array(
			data, "condition_multipliers"
		)
	c.haggle_floor_ratio = float(data.get("haggle_floor_ratio", 0.5))
	c.haggle_max_rounds = int(data.get("haggle_max_rounds", 3))
	c.authentication_price_bonus = float(
		data.get("authentication_price_bonus", 0.25)
	)
	c.late_fee_per_day = float(data.get("late_fee_per_day", 2.0))
	if data.has("reputation_tiers"):
		c.reputation_tiers = data["reputation_tiers"]
	if data.has("markup_ranges"):
		c.markup_ranges = data["markup_ranges"]
	if data.has("demand_modifiers"):
		c.demand_modifiers = data["demand_modifiers"]
	if data.has("daily_rent_per_size"):
		c.daily_rent_per_size = data["daily_rent_per_size"]
	if data.has("supplier_tiers"):
		var tiers: Array[Dictionary] = []
		for t: Variant in data["supplier_tiers"]:
			if t is Dictionary:
				tiers.append(t)
		c.supplier_tiers = tiers
	if data.has("price_ratio_reputation_deltas"):
		c.price_ratio_reputation_deltas = (
			data["price_ratio_reputation_deltas"]
		)
	if data.has("reputation_decay"):
		c.reputation_decay = data["reputation_decay"]
	return c


static func _parse_float_array(
	data: Dictionary, key: String
) -> Array[float]:
	if not data.has(key):
		return []
	var arr: Array[float] = []
	for val: Variant in data[key]:
		arr.append(float(val))
	return arr


static func _parse_fixture_unlock(
	f: FixtureDefinition, data: Dictionary
) -> void:
	f.unlock_condition = {}
	if f.unlock_rep > 0:
		f.unlock_condition["reputation"] = f.unlock_rep
	if f.unlock_day > 0:
		f.unlock_condition["day"] = f.unlock_day
	if data.has("unlock_condition"):
		var uc: Variant = data["unlock_condition"]
		if uc is Dictionary:
			f.unlock_condition.merge(uc, false)
			if f.unlock_condition.has("reputation"):
				f.unlock_rep = float(f.unlock_condition["reputation"])
			if f.unlock_condition.has("day"):
				f.unlock_day = int(f.unlock_condition["day"])


static func _parse_fixture_store_types(
	f: FixtureDefinition, data: Dictionary
) -> void:
	var restriction: String = str(
		data.get("store_type_restriction", "")
	)
	f.store_type_restriction = restriction
	if not restriction.is_empty():
		f.store_types = PackedStringArray([restriction])
		f.category = "store_specific"
	elif data.has("store_type_affinity"):
		var affinity: Array = data["store_type_affinity"]
		var is_universal: bool = (
			affinity.size() == 1 and str(affinity[0]) == "universal"
		)
		if is_universal:
			f.store_types = PackedStringArray()
			f.category = "universal"
		else:
			f.store_types = PackedStringArray(affinity)
			if not f.store_types.is_empty():
				f.store_type_restriction = str(f.store_types[0])
			f.category = "store_specific"
	elif data.has("store_types"):
		f.store_types = PackedStringArray(data["store_types"])
		if not f.store_types.is_empty():
			f.category = "store_specific"
		else:
			f.category = "universal"
	else:
		f.category = str(data.get("category", "universal"))


static func _parse_fixture_footprint(
	f: FixtureDefinition, data: Dictionary
) -> void:
	if data.has("footprint_cells") and data["footprint_cells"] is Array:
		var parsed: Array[Vector2i] = []
		var max_x: int = 0
		var max_y: int = 0
		for cell: Variant in data["footprint_cells"]:
			if cell is Array and (cell as Array).size() >= 2:
				var v := Vector2i(int(cell[0]), int(cell[1]))
				parsed.append(v)
				max_x = maxi(max_x, v.x)
				max_y = maxi(max_y, v.y)
		f.footprint_cells = parsed
		f.grid_size = Vector2i(max_x + 1, max_y + 1)
	elif data.has("grid_size") and data["grid_size"] is Array:
		var gs: Array = data["grid_size"]
		if gs.size() >= 2:
			f.grid_size = Vector2i(int(gs[0]), int(gs[1]))
		f.footprint_cells = _grid_size_to_cells(f.grid_size)
	elif data.has("grid_width") and data.has("grid_depth"):
		f.grid_size = Vector2i(
			int(data["grid_width"]), int(data["grid_depth"])
		)
		f.footprint_cells = _grid_size_to_cells(f.grid_size)


static func _grid_size_to_cells(
	size: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(size.x):
		for y: int in range(size.y):
			cells.append(Vector2i(x, y))
	return cells


static func parse_tournament_event(
	data: Dictionary
) -> TournamentEventDefinition:
	var has_name: bool = data.has("name") or data.has("display_name")
	if not data.has("id") or not has_name:
		push_error(
			"ContentParser: tournament event missing required fields: %s"
			% [data]
		)
		return null
	var t := TournamentEventDefinition.new()
	t.id = str(data["id"])
	t.name = str(data.get("name", data.get("display_name", "")))
	t.description = str(data.get("description", ""))
	t.card_category = str(data.get("card_category", ""))
	t.start_day = int(data.get("start_day", data.get("day", 0)))
	t.duration_days = int(data.get("duration_days", 1))
	t.demand_multiplier = float(data.get("demand_multiplier", 1.0))
	t.announcement_text = str(data.get("announcement_text", ""))
	t.active_text = str(data.get("active_text", ""))
	t.notification_day = int(
		data.get("notification_day", t.start_day - 1)
	)
	return t


static func parse_ambient_moment(
	data: Dictionary
) -> AmbientMomentDefinition:
	if not data.has("id"):
		push_error(
			"ContentParser: ambient moment missing 'id': %s" % [data]
		)
		return null
	var m := AmbientMomentDefinition.new()
	m.id = str(data["id"])
	m.name = str(data.get("name", ""))
	m.trigger_category = str(data.get("trigger_category", ""))
	m.trigger_value = str(data.get("trigger_value", ""))
	m.display_type = StringName(
		str(data.get("display_type", "toast"))
	)
	m.flavor_text = str(data.get("flavor_text", ""))
	m.audio_cue_id = StringName(
		str(data.get("audio_cue_id", ""))
	)
	m.scheduling_weight = float(
		data.get("scheduling_weight", 1.0)
	)
	m.cooldown_days = int(data.get("cooldown_days", 1))
	return m


static func _build_tier_data(f: FixtureDefinition) -> Dictionary:
	var tiers: Dictionary = {}
	for tier: int in [
		FixtureDefinition.TierLevel.BASIC,
		FixtureDefinition.TierLevel.IMPROVED,
		FixtureDefinition.TierLevel.PREMIUM,
	]:
		tiers[tier] = {
			"slot_count": f.get_slots_for_tier(tier),
			"purchase_prob_bonus": f.get_purchase_prob_bonus(tier),
		}
	return tiers
