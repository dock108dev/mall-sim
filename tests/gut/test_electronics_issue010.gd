## GUT tests for ISSUE-010: Electronics warranty upsell price comparison and
## demo unit footfall multiplier comparison.
extends GutTest


func _make_item_def(
	id: String,
	category: String,
	base_price: float,
	tiers: Array = []
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test %s" % id
	def.category = category
	def.store_type = "electronics"
	def.base_price = base_price
	def.can_be_demo_unit = true
	def.warranty_tiers = tiers.duplicate(true)
	return def


# ── AC5: Premium warranty produces higher final price than None ───────────────

func test_premium_warranty_produces_higher_final_price_than_none() -> void:
	var base_price: float = 100.0

	var no_warranty: PriceResolver.Result = PriceResolver.resolve(base_price, [])
	var no_warranty_price: float = no_warranty.final_price

	var premium_factor: float = 1.25
	var premium_result: PriceResolver.Result = PriceResolver.resolve(
		base_price,
		[{
			"slot": "warranty",
			"label": "Warranty (Extended)",
			"factor": premium_factor,
			"detail": "Extended warranty fee: $25.00",
		}]
	)

	assert_true(
		premium_result.final_price > no_warranty_price,
		"Premium warranty must produce a higher final price than no warranty"
	)
	assert_almost_eq(
		premium_result.final_price, base_price * premium_factor, 0.001
	)


func test_basic_warranty_produces_higher_final_price_than_none() -> void:
	var base_price: float = 100.0

	var no_warranty: PriceResolver.Result = PriceResolver.resolve(base_price, [])

	var basic_factor: float = 1.15
	var basic_result: PriceResolver.Result = PriceResolver.resolve(
		base_price,
		[{
			"slot": "warranty",
			"label": "Warranty (Basic)",
			"factor": basic_factor,
			"detail": "Basic warranty fee: $15.00",
		}]
	)

	assert_true(basic_result.final_price > no_warranty.final_price)
	assert_almost_eq(basic_result.final_price, 115.0, 0.001)


func test_premium_warranty_higher_than_basic() -> void:
	var base_price: float = 200.0

	var basic_result: PriceResolver.Result = PriceResolver.resolve(
		base_price,
		[{"slot": "warranty", "label": "Warranty (Basic)", "factor": 1.15}]
	)
	var premium_result: PriceResolver.Result = PriceResolver.resolve(
		base_price,
		[{"slot": "warranty", "label": "Warranty (Extended)", "factor": 1.25}]
	)

	assert_true(
		premium_result.final_price > basic_result.final_price,
		"Premium tier must produce higher total than basic"
	)


func test_warranty_audit_step_present_in_trace() -> void:
	var result: PriceResolver.Result = PriceResolver.resolve(
		100.0,
		[{
			"slot": "warranty",
			"label": "Warranty (Basic)",
			"factor": 1.15,
			"detail": "Basic warranty fee: $15.00",
		}]
	)
	var has_step: bool = false
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			if (step as PriceResolver.AuditStep).label.begins_with("Warranty"):
				has_step = true
				break
	assert_true(
		has_step,
		"PriceResolver audit trace must include a warranty step"
	)


func test_warranty_slot_placed_after_haggle_in_chain() -> void:
	var haggle_idx: int = PriceResolver.CHAIN_ORDER.find("haggle")
	var warranty_idx: int = PriceResolver.CHAIN_ORDER.find("warranty")
	assert_true(haggle_idx >= 0, "haggle must be in CHAIN_ORDER")
	assert_true(warranty_idx >= 0, "warranty must be in CHAIN_ORDER")
	assert_true(
		warranty_idx > haggle_idx,
		"warranty slot must come after haggle in canonical chain order"
	)


# ── AC6: Demo unit active flag increases footfall multiplier vs inactive ───────

func test_demo_unit_active_increases_footfall_multiplier_vs_inactive() -> void:
	var inventory := InventorySystem.new()
	add_child_autofree(inventory)
	inventory.initialize(null)

	var controller := ElectronicsStoreController.new()
	add_child_autofree(controller)
	controller.set_inventory_system(inventory)

	var result_inactive: PriceResolver.Result = controller.resolve_browse_rate(
		"portable_audio", 1.0
	)
	var footfall_inactive: float = result_inactive.final_price

	var def: ItemDefinition = _make_item_def(
		"demo_ac6_item", "portable_audio", 80.0
	)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "mint")
	inventory.register_item(item)
	item.is_demo = true
	controller._demo_item_ids.append(item.instance_id)

	var result_active: PriceResolver.Result = controller.resolve_browse_rate(
		"portable_audio", 1.0
	)
	var footfall_active: float = result_active.final_price

	assert_true(
		footfall_active > footfall_inactive,
		"Demo unit active must produce a higher footfall multiplier than inactive"
	)
	assert_almost_eq(
		footfall_active,
		1.0 * (1.0 + controller.get_demo_interest_bonus()),
		0.001
	)


func test_inactive_demo_footfall_equals_base() -> void:
	var inventory := InventorySystem.new()
	add_child_autofree(inventory)
	inventory.initialize(null)

	var controller := ElectronicsStoreController.new()
	add_child_autofree(controller)
	controller.set_inventory_system(inventory)

	var result: PriceResolver.Result = controller.resolve_browse_rate(
		"handheld_gaming", 1.0
	)
	assert_almost_eq(result.final_price, 1.0, 0.001)


func test_demo_unit_in_different_category_does_not_boost_footfall() -> void:
	var inventory := InventorySystem.new()
	add_child_autofree(inventory)
	inventory.initialize(null)

	var controller := ElectronicsStoreController.new()
	add_child_autofree(controller)
	controller.set_inventory_system(inventory)

	var def: ItemDefinition = _make_item_def(
		"demo_other_cat", "handheld_gaming", 80.0
	)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "mint")
	inventory.register_item(item)
	item.is_demo = true
	controller._demo_item_ids.append(item.instance_id)

	var result: PriceResolver.Result = controller.resolve_browse_rate(
		"portable_audio", 1.0
	)
	assert_almost_eq(
		result.final_price, 1.0, 0.001,
		"Demo in gaming should not boost audio browse rate"
	)
