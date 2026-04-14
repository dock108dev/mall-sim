## Tests for supplier catalog loading and data integrity.
extends GutTest


func test_suppliers_loaded() -> void:
	assert_gt(
		DataLoaderSingleton.get_supplier_count(), 0,
		"Should load at least one supplier"
	)


func test_supplier_count_is_fifteen() -> void:
	assert_eq(
		DataLoaderSingleton.get_supplier_count(), 15,
		"Should have exactly 15 suppliers (3 tiers x 5 stores)"
	)


func test_all_suppliers_have_required_fields() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	for s: SupplierDefinition in suppliers:
		assert_ne(s.id, "", "Supplier should have id")
		assert_ne(
			s.display_name, "",
			"Supplier '%s' should have display_name" % s.id
		)
		assert_between(
			s.tier, 1, 3,
			"Supplier '%s' tier should be 1-3" % s.id
		)
		assert_ne(
			s.store_type, "",
			"Supplier '%s' should have store_type" % s.id
		)
		assert_gt(
			s.lead_time_min, 0,
			"Supplier '%s' should have positive lead_time min"
			% s.id
		)
		assert_gt(
			s.lead_time_max, 0,
			"Supplier '%s' should have positive lead_time max"
			% s.id
		)
		assert_gte(
			s.lead_time_max, s.lead_time_min,
			"Supplier '%s' lead_time max >= min" % s.id
		)
		assert_between(
			s.reliability_rate, 0.0, 1.0,
			"Supplier '%s' reliability should be 0-1" % s.id
		)
		assert_false(
			s.unlock_condition.is_empty(),
			"Supplier '%s' should have unlock_condition" % s.id
		)
		assert_gt(
			s.catalog.size(), 0,
			"Supplier '%s' should have non-empty catalog" % s.id
		)


func test_all_ids_unique_snake_case() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	var seen: Dictionary = {}
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]{0,63}$")
	for s: SupplierDefinition in suppliers:
		assert_false(
			seen.has(s.id),
			"Supplier id '%s' should be unique" % s.id
		)
		seen[s.id] = true
		assert_not_null(
			pattern.search(s.id),
			"Supplier id '%s' should be snake_case" % s.id
		)


func test_all_five_stores_have_tier_one_and_two() -> void:
	var required_stores: Array[String] = [
		"sports", "retro_games", "rentals",
		"pocket_creatures", "electronics",
	]
	for store_type: String in required_stores:
		var t1: Array[SupplierDefinition] = (
			DataLoaderSingleton.get_suppliers_by_tier(store_type, 1)
		)
		assert_gt(
			t1.size(), 0,
			"Store '%s' should have at least one Tier 1 supplier"
			% store_type
		)
		var t2: Array[SupplierDefinition] = (
			DataLoaderSingleton.get_suppliers_by_tier(store_type, 2)
		)
		assert_gt(
			t2.size(), 0,
			"Store '%s' should have at least one Tier 2 supplier"
			% store_type
		)


func test_electronics_and_pocket_creatures_have_tier_three() -> void:
	var elec_t3: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_suppliers_by_tier("electronics", 3)
	)
	assert_gt(
		elec_t3.size(), 0,
		"Electronics should have a Tier 3 supplier"
	)
	var pc_t3: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_suppliers_by_tier("pocket_creatures", 3)
	)
	assert_gt(
		pc_t3.size(), 0,
		"PocketCreatures should have a Tier 3 supplier"
	)


func test_tier_unlock_conditions() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	for s: SupplierDefinition in suppliers:
		var cond: Dictionary = s.unlock_condition
		match s.tier:
			1:
				assert_eq(
					str(cond.get("type", "")), "always",
					"Tier 1 '%s' should be always available"
					% s.id
				)
			2:
				assert_eq(
					str(cond.get("type", "")),
					"days_and_revenue",
					"Tier 2 '%s' should use days_and_revenue"
					% s.id
				)
				assert_eq(
					float(cond.get("threshold", 0)),
					1200.0,
					"Tier 2 '%s' revenue threshold = $1200"
					% s.id
				)
				assert_eq(
					int(cond.get("days_required", 0)),
					14,
					"Tier 2 '%s' days required = 14" % s.id
				)
			3:
				assert_eq(
					str(cond.get("type", "")),
					"days_and_revenue_or_reputation",
					"Tier 3 '%s' should use compound condition"
					% s.id
				)
				assert_eq(
					float(cond.get("threshold", 0)),
					4000.0,
					"Tier 3 '%s' revenue threshold = $4000"
					% s.id
				)
				assert_eq(
					int(cond.get("days_required", 0)),
					30,
					"Tier 3 '%s' days required = 30" % s.id
				)
				assert_eq(
					int(cond.get("reputation_threshold", 0)),
					75,
					"Tier 3 '%s' reputation threshold = 75"
					% s.id
				)


func test_catalog_item_ids_exist_in_items() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	for s: SupplierDefinition in suppliers:
		for entry: Dictionary in s.catalog:
			var item_id: String = str(entry.get("item_id", ""))
			assert_ne(
				item_id, "",
				"Catalog entry in '%s' should have item_id"
				% s.id
			)
			var item: ItemDefinition = DataLoaderSingleton.get_item(item_id)
			assert_not_null(
				item,
				"Item '%s' in supplier '%s' should exist"
				% [item_id, s.id]
			)


func test_catalog_entries_have_valid_pricing() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	for s: SupplierDefinition in suppliers:
		for entry: Dictionary in s.catalog:
			var cost: float = float(entry.get("cost_per_unit", 0))
			var min_qty: int = int(entry.get("min_order_qty", 0))
			var max_qty: int = int(entry.get("max_order_qty", 0))
			var item_id: String = str(entry.get("item_id", ""))
			assert_gt(
				cost, 0.0,
				"'%s' cost in '%s' should be positive"
				% [item_id, s.id]
			)
			assert_gt(
				min_qty, 0,
				"'%s' min_order_qty in '%s' should be positive"
				% [item_id, s.id]
			)
			assert_gte(
				max_qty, min_qty,
				"'%s' max_qty >= min_qty in '%s'"
				% [item_id, s.id]
			)


func test_catalog_cost_below_base_price() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	for s: SupplierDefinition in suppliers:
		for entry: Dictionary in s.catalog:
			var item_id: String = str(entry.get("item_id", ""))
			var cost: float = float(entry.get("cost_per_unit", 0))
			var item: ItemDefinition = DataLoaderSingleton.get_item(item_id)
			if item == null:
				continue
			assert_lt(
				cost, item.base_price,
				"Wholesale cost $%.2f for '%s' in '%s' "
				% [cost, item_id, s.id]
				+ "should be below base_price $%.2f"
				% [item.base_price]
			)


func test_supplier_display_names_are_original() -> void:
	var suppliers: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_all_suppliers()
	)
	var seen_names: Dictionary = {}
	for s: SupplierDefinition in suppliers:
		assert_false(
			seen_names.has(s.display_name),
			"Display name '%s' should be unique"
			% s.display_name
		)
		seen_names[s.display_name] = true


func test_get_suppliers_for_store() -> void:
	var sports: Array[SupplierDefinition] = (
		DataLoaderSingleton.get_suppliers_for_store("sports")
	)
	assert_eq(
		sports.size(), 3,
		"Sports should have 3 suppliers"
	)
	for s: SupplierDefinition in sports:
		assert_eq(
			s.store_type, "sports",
			"Filtered supplier should match store_type"
		)
