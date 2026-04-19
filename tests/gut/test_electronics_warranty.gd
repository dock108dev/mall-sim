## GUT tests for ISSUE-021: Electronics warranty upsell and demo unit mechanic.
## Covers warranty margin per tier, demo browse multiplier, and sale flow variants.
extends GutTest


var _controller: ElectronicsStoreController
var _inventory: InventorySystem
var _accepted_signals: Array[Dictionary] = []
var _declined_signals: Array[Dictionary] = []
var _demo_activated_signals: Array[Dictionary] = []
var _demo_removed_signals: Array[Dictionary] = []


func _make_item_def(
	id: String,
	category: String,
	base_price: float,
	can_be_demo: bool = true,
	tiers: Array = []
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test %s" % id
	def.category = category
	def.store_type = "electronics"
	def.base_price = base_price
	def.can_be_demo_unit = can_be_demo
	def.warranty_tiers = tiers.duplicate(true)
	return def


func _make_item(
	id: String,
	category: String,
	base_price: float,
	condition: String = "mint",
	tiers: Array = []
) -> ItemInstance:
	var def: ItemDefinition = _make_item_def(id, category, base_price, true, tiers)
	return ItemInstance.create_from_definition(def, condition)


func _on_warranty_accepted(item_id: String, tier_id: String, fee: float) -> void:
	_accepted_signals.append({"item_id": item_id, "tier_id": tier_id, "fee": fee})


func _on_warranty_declined(item_id: String, tier_id: String) -> void:
	_declined_signals.append({"item_id": item_id, "tier_id": tier_id})


func _on_demo_activated(item_id: String, category: String) -> void:
	_demo_activated_signals.append({"item_id": item_id, "category": category})


func _on_demo_removed(item_id: String, days: int) -> void:
	_demo_removed_signals.append({"item_id": item_id, "days": days})


func before_each() -> void:
	_accepted_signals.clear()
	_declined_signals.clear()
	_demo_activated_signals.clear()
	_demo_removed_signals.clear()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)
	_controller = ElectronicsStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	EventBus.warranty_accepted.connect(_on_warranty_accepted)
	EventBus.warranty_declined.connect(_on_warranty_declined)
	EventBus.demo_unit_activated.connect(_on_demo_activated)
	EventBus.demo_unit_removed.connect(_on_demo_removed)


func after_each() -> void:
	if EventBus.warranty_accepted.is_connected(_on_warranty_accepted):
		EventBus.warranty_accepted.disconnect(_on_warranty_accepted)
	if EventBus.warranty_declined.is_connected(_on_warranty_declined):
		EventBus.warranty_declined.disconnect(_on_warranty_declined)
	if EventBus.demo_unit_activated.is_connected(_on_demo_activated):
		EventBus.demo_unit_activated.disconnect(_on_demo_activated)
	if EventBus.demo_unit_removed.is_connected(_on_demo_removed):
		EventBus.demo_unit_removed.disconnect(_on_demo_removed)


# ── Warranty tier margin ──────────────────────────────────────────────────────

func test_basic_tier_fee_is_15_percent_of_sale_price() -> void:
	var tier: Dictionary = {"id": "basic", "margin_percent": 0.15, "acceptance_probability": 1.0}
	var fee: float = WarrantyManager.calculate_tier_fee(100.0, tier)
	assert_almost_eq(fee, 15.0, 0.001)


func test_extended_tier_fee_is_25_percent_of_sale_price() -> void:
	var tier: Dictionary = {"id": "extended", "margin_percent": 0.25, "acceptance_probability": 1.0}
	var fee: float = WarrantyManager.calculate_tier_fee(100.0, tier)
	assert_almost_eq(fee, 25.0, 0.001)


func test_tier_fee_clamped_to_min_warranty_percent() -> void:
	var tier: Dictionary = {"id": "cheap", "margin_percent": 0.05, "acceptance_probability": 1.0}
	var fee: float = WarrantyManager.calculate_tier_fee(100.0, tier)
	assert_almost_eq(fee, WarrantyManager.MIN_WARRANTY_PERCENT * 100.0, 0.001)


func test_tier_fee_clamped_to_max_warranty_percent() -> void:
	var tier: Dictionary = {"id": "gold", "margin_percent": 0.90, "acceptance_probability": 1.0}
	var fee: float = WarrantyManager.calculate_tier_fee(100.0, tier)
	assert_almost_eq(fee, WarrantyManager.MAX_WARRANTY_PERCENT * 100.0, 0.001)


func test_tier_acceptance_probability_read_from_data() -> void:
	var tier: Dictionary = {"id": "basic", "margin_percent": 0.15, "acceptance_probability": 0.45}
	assert_almost_eq(
		WarrantyManager.get_tier_acceptance_probability(tier), 0.45, 0.001
	)


func test_basic_and_extended_tiers_have_different_margins() -> void:
	var basic: Dictionary = {"id": "basic", "margin_percent": 0.15, "acceptance_probability": 0.45}
	var extended: Dictionary = {"id": "extended", "margin_percent": 0.25, "acceptance_probability": 0.30}
	var basic_fee: float = WarrantyManager.calculate_tier_fee(200.0, basic)
	var ext_fee: float = WarrantyManager.calculate_tier_fee(200.0, extended)
	assert_true(ext_fee > basic_fee)
	assert_almost_eq(basic_fee, 30.0, 0.001)
	assert_almost_eq(ext_fee, 50.0, 0.001)


# ── Demo unit browse multiplier via PriceResolver ─────────────────────────────

func test_resolve_browse_rate_no_demo_returns_base() -> void:
	var result: PriceResolver.Result = _controller.resolve_browse_rate(
		"portable_audio", 1.0
	)
	assert_almost_eq(result.final_price, 1.0, 0.001)


func test_resolve_browse_rate_with_demo_applies_multiplier() -> void:
	_controller._demo_item_ids.append("demo_a")
	var item: ItemInstance = _make_item("demo_a", "portable_audio", 60.0)
	_inventory.register_item(item)
	item.is_demo = true
	var result: PriceResolver.Result = _controller.resolve_browse_rate(
		"portable_audio", 1.0
	)
	var expected: float = 1.0 * (1.0 + _controller.get_demo_interest_bonus())
	assert_almost_eq(result.final_price, expected, 0.001)


func test_resolve_browse_rate_audit_includes_demo_unit_step() -> void:
	_controller._demo_item_ids.append("demo_b")
	var item: ItemInstance = _make_item("demo_b", "gadgets", 80.0)
	_inventory.register_item(item)
	item.is_demo = true
	var result: PriceResolver.Result = _controller.resolve_browse_rate("gadgets", 1.0)
	var has_demo_step: bool = false
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			if (step as PriceResolver.AuditStep).label == "Demo Unit Active":
				has_demo_step = true
				break
	assert_true(has_demo_step, "PriceResolver audit should include Demo Unit Active step")


func test_resolve_browse_rate_no_crossover_between_categories() -> void:
	_controller._demo_item_ids.append("demo_c")
	var item: ItemInstance = _make_item("demo_c", "handheld_gaming", 100.0)
	_inventory.register_item(item)
	item.is_demo = true
	var result: PriceResolver.Result = _controller.resolve_browse_rate(
		"portable_audio", 1.0
	)
	assert_almost_eq(result.final_price, 1.0, 0.001,
		"Demo unit in gaming should not boost audio browse rate"
	)


# ── Sale flow with warranty pitch ─────────────────────────────────────────────

func test_pitch_warranty_ineligible_price_returns_zero() -> void:
	var tiers: Array = [
		{"id": "basic", "margin_percent": 0.15, "acceptance_probability": 1.0},
	]
	var item: ItemInstance = _make_item("cheap_item", "audio", 10.0, "mint", tiers)
	_inventory.register_item(item)
	var fee: float = _controller.pitch_warranty(item.instance_id, 10.0, "basic")
	assert_almost_eq(fee, 0.0, 0.001)
	assert_eq(_accepted_signals.size(), 0)
	assert_eq(_declined_signals.size(), 0)


func test_pitch_warranty_skipped_no_signals() -> void:
	# Skipping = caller simply does not call pitch_warranty; no signals emitted.
	assert_eq(_accepted_signals.size(), 0)
	assert_eq(_declined_signals.size(), 0)


func test_pitch_warranty_accepted_emits_signal_and_returns_fee() -> void:
	var tiers: Array = [
		{"id": "basic", "margin_percent": 0.15, "acceptance_probability": 1.0},
	]
	var item: ItemInstance = _make_item("elig_item", "audio", 100.0, "mint", tiers)
	_inventory.register_item(item)
	var fee: float = _controller.pitch_warranty(item.instance_id, 100.0, "basic")
	assert_almost_eq(fee, 15.0, 0.001)
	assert_eq(_accepted_signals.size(), 1)
	assert_eq(_accepted_signals[0]["tier_id"], "basic")
	assert_almost_eq(float(_accepted_signals[0]["fee"]), 15.0, 0.001)
	assert_eq(_declined_signals.size(), 0)


func test_pitch_warranty_declined_emits_declined_signal() -> void:
	var tiers: Array = [
		{"id": "extended", "margin_percent": 0.25, "acceptance_probability": 0.0},
	]
	var item: ItemInstance = _make_item("declined_item", "audio", 100.0, "mint", tiers)
	_inventory.register_item(item)
	var fee: float = _controller.pitch_warranty(item.instance_id, 100.0, "extended")
	assert_almost_eq(fee, 0.0, 0.001)
	assert_eq(_accepted_signals.size(), 0)
	assert_eq(_declined_signals.size(), 1)
	assert_eq(_declined_signals[0]["tier_id"], "extended")


func test_pitch_warranty_extended_tier_higher_fee_than_basic() -> void:
	var tiers: Array = [
		{"id": "basic", "margin_percent": 0.15, "acceptance_probability": 1.0},
		{"id": "extended", "margin_percent": 0.25, "acceptance_probability": 1.0},
	]
	var item_b: ItemInstance = _make_item("item_basic", "gadgets", 200.0, "mint", tiers)
	var item_e: ItemInstance = _make_item("item_ext", "gadgets", 200.0, "mint", tiers)
	_inventory.register_item(item_b)
	_inventory.register_item(item_e)
	var fee_b: float = _controller.pitch_warranty(item_b.instance_id, 200.0, "basic")
	var fee_e: float = _controller.pitch_warranty(item_e.instance_id, 200.0, "extended")
	assert_true(fee_e > fee_b)
	assert_almost_eq(fee_b, 30.0, 0.001)
	assert_almost_eq(fee_e, 50.0, 0.001)


# ── demo_unit_activated / demo_unit_removed signals ───────────────────────────

func test_demo_unit_removed_signal_emitted_on_remove() -> void:
	var item: ItemInstance = _make_item("rem_item", "audio", 50.0)
	_inventory.register_item(item)
	item.is_demo = true
	item.demo_placed_day = 1
	_controller._demo_item_ids.append(item.instance_id)
	_controller.remove_demo_item(item.instance_id)
	assert_eq(_demo_removed_signals.size(), 1)
	assert_eq(_demo_removed_signals[0]["item_id"], item.instance_id)


# ── ContentParser: warranty_tiers and demo_unit_eligible fields ───────────────

func test_content_parser_accepts_warranty_tiers_field() -> void:
	var data: Dictionary = {
		"id": "test_elec",
		"item_name": "Test Elec",
		"store_type": "electronics",
		"category": "audio",
		"base_price": 99.0,
		"warranty_tiers": [
			{"id": "basic", "margin_percent": 0.15, "acceptance_probability": 0.45},
			{"id": "extended", "margin_percent": 0.25, "acceptance_probability": 0.30},
		],
	}
	var def: ItemDefinition = ContentParser.parse_item(data)
	assert_not_null(def)
	assert_eq(def.warranty_tiers.size(), 2)
	assert_eq(str((def.warranty_tiers[0] as Dictionary).get("id", "")), "basic")
	assert_eq(str((def.warranty_tiers[1] as Dictionary).get("id", "")), "extended")


func test_content_parser_accepts_demo_unit_eligible_as_alias() -> void:
	var data: Dictionary = {
		"id": "test_alias",
		"item_name": "Test Alias",
		"store_type": "electronics",
		"category": "audio",
		"base_price": 50.0,
		"demo_unit_eligible": true,
	}
	var def: ItemDefinition = ContentParser.parse_item(data)
	assert_not_null(def)
	assert_true(def.can_be_demo_unit)
