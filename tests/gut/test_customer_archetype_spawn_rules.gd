## Tests the conditional spawn rules for retro_games archetype profiles.
##
## Covers:
##   - angry_return_customer is gated on `defective_sale_occurred` firing
##     earlier in the same day; resets at day_started.
##   - shady_regular is capped at 1 spawn per day at this store, and its
##     spawn weight is multiplied by 3× during the AFTERNOON DayPhase.
##   - hype_teen receives a positive spawn-weight modifier from PlatformSystem
##     when its affinity platform (vecforce_hd) is in shortage.
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
	# Bypass the Day 1 gate so we can focus on archetype rules.
	GameManager.set_current_day(2)
	_system._day1_spawn_unlocked = true


func after_each() -> void:
	GameManager.set_current_day(_previous_day)
	GameManager.data_loader = _previous_data_loader


# ── angry_return_customer ─────────────────────────────────────────────────────


func test_angry_return_blocked_without_prior_defective_sale() -> void:
	var profile: CustomerTypeDefinition = _profile_for("angry_return_customer")
	assert_not_null(profile, "retro_angry_return profile must load")
	assert_false(
		_system.is_profile_currently_spawnable(profile),
		"angry_return must be blocked when no defective sale has occurred today"
	)
	_system.spawn_customer(profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(), 0,
		"spawn_customer must reject angry_return until a defective sale fires"
	)


func test_angry_return_unblocked_after_defective_sale_signal() -> void:
	var profile: CustomerTypeDefinition = _profile_for("angry_return_customer")
	_system._on_defective_sale_occurred("widget_001", "warranty_failed")
	assert_true(
		_system.is_profile_currently_spawnable(profile),
		"angry_return must be spawnable after defective_sale_occurred fires"
	)
	_system.spawn_customer(profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(), 1,
		"angry_return must spawn after the defective-sale flag is set"
	)


func test_defective_sale_flag_clears_on_day_start() -> void:
	var profile: CustomerTypeDefinition = _profile_for("angry_return_customer")
	_system._on_defective_sale_occurred("widget_001", "warranty_failed")
	_system._on_day_started(3)
	assert_false(
		_system.is_profile_currently_spawnable(profile),
		"defective-sale flag must clear at day_started"
	)


# ── shady_regular ─────────────────────────────────────────────────────────────


func test_shady_regular_capped_at_one_per_day() -> void:
	var profile: CustomerTypeDefinition = _profile_for("shady_regular")
	assert_not_null(profile, "retro_shady_regular profile must load")
	assert_true(
		_system.is_profile_currently_spawnable(profile),
		"shady_regular must be spawnable before reaching the daily cap"
	)
	_system.spawn_customer(profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(), 1,
		"first shady_regular spawn must succeed"
	)
	assert_false(
		_system.is_profile_currently_spawnable(profile),
		"shady_regular must be gated after reaching the daily cap"
	)
	_system.spawn_customer(profile, _STORE_ID)
	assert_eq(
		_system.get_active_customer_count(), 1,
		"second shady_regular spawn must be rejected on the same day"
	)


func test_shady_regular_cap_resets_at_day_start() -> void:
	var profile: CustomerTypeDefinition = _profile_for("shady_regular")
	_system.spawn_customer(profile, _STORE_ID)
	assert_false(
		_system.is_profile_currently_spawnable(profile),
		"pre-condition: cap reached after first spawn"
	)
	_system._on_day_started(3)
	assert_true(
		_system.is_profile_currently_spawnable(profile),
		"day_started must reset the per-day archetype counters"
	)


func test_shady_regular_weight_3x_in_afternoon_phase() -> void:
	var profile: CustomerTypeDefinition = _profile_for("shady_regular")
	_system._on_day_phase_changed(int(TimeSystem.DayPhase.MIDDAY_RUSH))
	var midday_weight: float = _system.get_profile_spawn_weight(profile)
	_system._on_day_phase_changed(int(TimeSystem.DayPhase.AFTERNOON))
	var afternoon_weight: float = _system.get_profile_spawn_weight(profile)
	assert_almost_eq(
		afternoon_weight,
		midday_weight * CustomerSystem.SHADY_REGULAR_LATE_AFTERNOON_WEIGHT,
		0.001,
		"shady_regular weight must triple in the AFTERNOON DayPhase"
	)


# ── hype_teen ─────────────────────────────────────────────────────────────────


func test_hype_teen_weight_increases_under_vecforce_hd_shortage() -> void:
	var profile: CustomerTypeDefinition = _profile_for("hype_teen")
	assert_not_null(profile, "retro_hype_teen profile must load")
	var platform_id: StringName = &"vecforce_hd"
	var state: PlatformInventoryState = PlatformSystem.get_state(platform_id)
	assert_not_null(state, "vecforce_hd platform state must exist")
	# Snapshot original state so the test does not bleed into the rest of the run.
	var prior_units: int = state.units_in_stock
	var prior_shortage: bool = state.in_shortage
	var prior_hype: float = state.hype_level
	# Force "no shortage" baseline.
	state.units_in_stock = state.platform.shortage_threshold + 10
	state.in_shortage = false
	state.hype_level = 0.0
	var baseline: float = _system.get_profile_spawn_weight(profile)
	# Drive the platform into shortage with hype to verify the boost.
	state.units_in_stock = 0
	state.in_shortage = true
	state.hype_level = 0.6
	var boosted: float = _system.get_profile_spawn_weight(profile)
	# Restore prior platform state.
	state.units_in_stock = prior_units
	state.in_shortage = prior_shortage
	state.hype_level = prior_hype
	assert_gt(
		boosted, baseline,
		"hype_teen weight must increase when vecforce_hd is in shortage"
	)


# ── pick_spawn_profile filtering ──────────────────────────────────────────────


func test_pick_spawn_profile_excludes_blocked_archetypes() -> void:
	var angry: CustomerTypeDefinition = _profile_for("angry_return_customer")
	var nostalgic: CustomerTypeDefinition = _profile_by_id("retro_nostalgic_adult")
	assert_not_null(nostalgic, "retro_nostalgic_adult profile must load")
	for _i: int in range(10):
		var picked: CustomerTypeDefinition = _system.pick_spawn_profile(
			[angry, nostalgic]
		)
		assert_eq(
			picked.id, nostalgic.id,
			"angry_return must never be picked while gated"
		)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _profile_for(archetype_id: String) -> CustomerTypeDefinition:
	for profile: CustomerTypeDefinition in (
		_data_loader.get_customer_types_for_store(_STORE_ID)
	):
		if String(profile.archetype_id) == archetype_id:
			return profile
	return null


func _profile_by_id(profile_id: String) -> CustomerTypeDefinition:
	for profile: CustomerTypeDefinition in (
		_data_loader.get_customer_types_for_store(_STORE_ID)
	):
		if profile.id == profile_id:
			return profile
	return null
