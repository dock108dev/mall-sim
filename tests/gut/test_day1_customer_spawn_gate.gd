## Tests the Day 1 customer spawn gate.
##
## On Day 1, no customers may spawn until at least one item has been stocked
## on a shelf. The gate is sticky (once unlocked it stays unlocked for the
## run, even if the stocked item is later sold) and is bypassed entirely for
## Day 2 and beyond. On a save reloaded mid-Day 1 with items already on
## shelves, the gate must self-heal from InventorySystem state rather than
## blocking spawns retroactively.
extends GutTest


const _STORE_ID: String = "retro_games"
const _CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)


var _system: CustomerSystem
var _inventory: InventorySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader
var _previous_day: int
var _profile: CustomerTypeDefinition


func before_each() -> void:
	_previous_day = GameManager.get_current_day()
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_system = CustomerSystem.new()
	add_child_autofree(_system)
	_system._customer_scene = _CUSTOMER_SCENE
	_system._max_customers = 5
	_system.set_inventory_system(_inventory)
	_system.set_store_id(_STORE_ID)

	_profile = _make_profile()


func after_each() -> void:
	GameManager.set_current_day(_previous_day)
	GameManager.data_loader = _previous_data_loader


# ── Day 1 gate ────────────────────────────────────────────────────────────────


func test_day1_spawn_blocked_when_no_items_on_shelf() -> void:
	GameManager.set_current_day(1)
	_system.spawn_customer(_profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(),
		0,
		"Day 1 spawn must be blocked when no items have been stocked"
	)
	assert_false(
		_system._day1_spawn_unlocked,
		"Gate flag must remain locked when no shelf items exist"
	)


func test_day1_spawn_unblocked_after_item_stocked_signal() -> void:
	GameManager.set_current_day(1)
	_system._on_item_stocked("item_x", "slot_a")
	# `_on_item_stocked` arms the Day 1 forced-spawn fallback timer; the gate
	# itself flips open immediately so subsequent direct spawns succeed.
	assert_true(
		_system._day1_spawn_unlocked,
		"item_stocked must flip the spawn gate to unlocked"
	)
	_system.spawn_customer(_profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(),
		1,
		"Spawn must succeed after the gate is unlocked"
	)


func test_day1_spawn_self_heals_when_inventory_already_has_shelf_items() -> void:
	# Simulates a Day 1 save reloaded after the player had already stocked an
	# item: InventorySystem holds a shelved ItemInstance, but the freshly
	# constructed CustomerSystem has _day1_spawn_unlocked = false.
	GameManager.set_current_day(1)
	_seed_shelf_item("preloaded_item", "slot_42")
	assert_false(
		_system._day1_spawn_unlocked,
		"Pre-condition: gate flag starts locked on a fresh CustomerSystem"
	)
	_system.spawn_customer(_profile, _STORE_ID)
	assert_true(
		_system._day1_spawn_unlocked,
		"First spawn attempt must self-derive the gate from InventorySystem"
	)
	assert_eq(
		_system.get_active_customer_count(),
		1,
		"Loaded Day 1 with shelf items must allow customer spawns"
	)


func test_day1_gate_stays_open_after_unstocking_last_item() -> void:
	GameManager.set_current_day(1)
	_system._on_item_stocked("item_x", "slot_a")
	# Despawn so we can isolate the second spawn attempt below.
	for c: Customer in _system.get_active_customers().duplicate():
		_system.despawn_customer(c)
	# At this point the simulated item is no longer on a shelf (we never
	# actually added one to InventorySystem), but the gate flag is sticky and
	# subsequent spawns must still succeed.
	assert_true(
		_inventory.get_shelf_items().is_empty(),
		"Pre-condition: no items on shelf at this point in the test"
	)
	_system.spawn_customer(_profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(),
		1,
		"Sticky gate must keep spawns flowing even after items leave shelves"
	)


# ── Day 2+ bypass ─────────────────────────────────────────────────────────────


func test_day2_spawn_succeeds_without_any_stocking() -> void:
	GameManager.set_current_day(2)
	_system.spawn_customer(_profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(),
		1,
		"Day 2 spawn must not be gated on item_stocked"
	)


func test_day_started_for_day2_unlocks_gate_explicitly() -> void:
	GameManager.set_current_day(2)
	assert_false(
		_system._day1_spawn_unlocked,
		"Pre-condition: fresh CustomerSystem has the gate locked"
	)
	_system._on_day_started(2)
	assert_true(
		_system._day1_spawn_unlocked,
		"day_started for day > 1 must explicitly unlock the gate"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_profile() -> CustomerTypeDefinition:
	var p: CustomerTypeDefinition = CustomerTypeDefinition.new()
	p.id = "spawn_gate_test_customer"
	p.customer_name = "Gate Test Customer"
	p.budget_range = [10.0, 100.0]
	p.patience = 0.5
	p.price_sensitivity = 0.5
	p.preferred_categories = PackedStringArray([])
	p.preferred_tags = PackedStringArray([])
	p.condition_preference = "good"
	p.browse_time_range = [1.0, 2.0]
	p.purchase_probability_base = 0.9
	p.impulse_buy_chance = 0.1
	p.mood_tags = PackedStringArray([])
	return p


func _seed_shelf_item(instance_id: String, slot_id: String) -> void:
	# Bypass add_item / assign_to_shelf so the seeded state mimics a
	# post-load InventorySystem with shelved items but no item_stocked
	# signal having fired in this CustomerSystem's lifetime.
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "preloaded_def"
	def.item_name = "Preloaded Item"
	def.category = "cards"
	def.base_price = 25.0
	def.rarity = "common"
	def.tags = PackedStringArray([])
	def.condition_range = PackedStringArray(["good"])
	def.store_type = _STORE_ID
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	item.instance_id = instance_id
	item.current_location = "shelf:%s" % slot_id
	_inventory._items[instance_id] = item
	_inventory._shelf_cache_dirty = true
