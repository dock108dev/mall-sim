## Tests reputation-scaled customer traffic in store selection and mall spawning.
extends GutTest


const STORE_A: String = "test_store_a"
const STORE_B: String = "test_store_b"

var _customer_system: CustomerSystem
var _reputation: ReputationSystem
var _selector: StoreSelector
var _saved_owned_stores: Array[StringName] = []
var _saved_current_store_id: StringName = &""


func before_each() -> void:
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_current_store_id = GameManager.current_store_id
	GameManager.owned_stores = [&"test_store_a"]

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_A)
	_reputation.initialize_store(STORE_B)

	_selector = StoreSelector.new()
	_selector.initialize(_reputation)


func after_each() -> void:
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_current_store_id


func test_store_selector_uses_store_specific_reputation_multiplier() -> void:
	_reputation.add_reputation(STORE_A, -50.0)
	_reputation.add_reputation(STORE_B, 30.0)

	assert_eq(
		_selector._get_reputation_multiplier(STORE_A),
		_reputation.get_customer_multiplier(STORE_A),
		"Selector should use the requested store's reputation multiplier"
	)
	assert_eq(
		_selector._get_reputation_multiplier(STORE_B),
		_reputation.get_customer_multiplier(STORE_B),
		"Selector should vary traffic weighting per store reputation"
	)


func test_legendary_reputation_halves_spawn_interval_versus_unknown() -> void:
	var spawner: MallCustomerSpawner = MallCustomerSpawner.new()
	add_child_autofree(spawner)
	spawner.initialize(_customer_system, _reputation)

	_reputation.add_reputation(STORE_A, -50.0)
	var unknown_interval: float = spawner._get_spawn_interval()

	_reputation.add_reputation(STORE_A, 80.0)
	var legendary_interval: float = spawner._get_spawn_interval()

	assert_almost_eq(
		unknown_interval / legendary_interval,
		2.0,
		0.001,
		"Legendary traffic should spawn customers at twice the Unknown cadence"
	)


func test_customer_system_uses_requested_store_budget_multiplier() -> void:
	var customer_scene: PackedScene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "test_customer"
	profile.customer_name = "Test Customer"
	profile.budget_range = [10.0, 100.0]
	profile.patience = 0.5
	profile.price_sensitivity = 0.5
	profile.preferred_categories = PackedStringArray([])
	profile.preferred_tags = PackedStringArray([])
	profile.condition_preference = "good"
	profile.browse_time_range = [1.0, 2.0]
	profile.purchase_probability_base = 0.9
	profile.impulse_buy_chance = 0.1
	profile.mood_tags = PackedStringArray([])

	GameManager.current_store_id = &"test_store_a"
	_reputation.add_reputation(STORE_A, 30.0)
	_reputation.add_reputation(STORE_B, -50.0)
	_customer_system._customer_scene = customer_scene
	_customer_system._reputation_system = _reputation

	_customer_system.spawn_customer(profile, STORE_B)

	var customers: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(customers.size(), 1, "Spawn should succeed for the requested store")
	assert_almost_eq(
		customers[0]._budget_multiplier,
		_reputation.get_budget_multiplier(STORE_B),
		0.001,
		"Budget multiplier should use the spawned store reputation"
	)
