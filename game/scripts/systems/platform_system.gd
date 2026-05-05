## PlatformSystem — owner of the per-platform supply / demand / hype state.
##
## Loads the platform catalog at boot, builds one PlatformInventoryState per
## platform, and runs a daily tick on EventBus.day_started:
##   1. shortage flag = (units_in_stock < shortage_threshold)
##   2. while in shortage, accumulate shortage_days and add hype_gain_per_day
##   3. while not in shortage, decay hype and reset shortage_days
##   4. recompute current_sell_price from base_price * (1 + hype * elasticity)
##      clamped to [floor_multiplier, ceiling_multiplier]
##   5. emit shortage_started / shortage_ended on transitions and
##      hype_threshold_crossed on upward hype-tier crossings.
##
## Public read API:
##   - is_shortage(platform_id) -> bool
##   - get_current_price(platform_id) -> float
##   - get_hype(platform_id) -> float
##   - get_state(platform_id) -> PlatformInventoryState (for advanced readers)
##
## Customer spawn integration:
##   - get_spawn_weight_modifier(profile) walks the profile's platform_affinities
##     and returns a multiplier ≥ 1.0 reflecting current shortage state.
##
## Registered as the `PlatformSystem` autoload in project.godot. Other systems
## should reach this through that name rather than re-instantiating.
extends Node


const CATALOG_PATH: String = "res://game/content/platforms.json"

const HYPE_MIN: float = 0.0
const HYPE_MAX: float = 1.0
## Hype tiers fired via platform_hype_threshold_crossed. Tier 0 is the resting
## baseline (no signal); upward crossings into 1, 2, 3 each emit once per
## shortage spell. Decaying back below a threshold resets the latch so the next
## upward crossing fires again.
const HYPE_TIER_THRESHOLDS: Array[float] = [0.3, 0.6, 0.9]


var _definitions: Dictionary = {}  # StringName -> PlatformDefinition
var _states: Dictionary = {}       # StringName -> PlatformInventoryState
var _hype_tier_latched: Dictionary = {}  # StringName -> int (max tier emitted)
var _initialized: bool = false


func _ready() -> void:
	_load_catalog()
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	_initialized = true


# ── Public read API ──────────────────────────────────────────────────────────

func is_shortage(platform_id: StringName) -> bool:
	var state: PlatformInventoryState = _states.get(platform_id, null)
	if state == null:
		return false
	return state.in_shortage


func get_current_price(platform_id: StringName) -> float:
	var state: PlatformInventoryState = _states.get(platform_id, null)
	if state == null:
		return 0.0
	return state.current_sell_price


func get_hype(platform_id: StringName) -> float:
	var state: PlatformInventoryState = _states.get(platform_id, null)
	if state == null:
		return 0.0
	return state.hype_level


func get_state(platform_id: StringName) -> PlatformInventoryState:
	return _states.get(platform_id, null)


func get_definition(platform_id: StringName) -> PlatformDefinition:
	return _definitions.get(platform_id, null)


func get_all_platform_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _definitions:
		result.append(id)
	return result


# ── Stock mutation ───────────────────────────────────────────────────────────

## Records a successful restock event. Updates state, recomputes derived
## fields, and emits both platform_restock_received and (if applicable)
## platform_shortage_ended. Returns true if the platform was found.
func receive_restock(platform_id: StringName, qty: int) -> bool:
	var state: PlatformInventoryState = _states.get(platform_id, null)
	if state == null or qty <= 0:
		return false
	state.units_in_stock += qty
	EventBus.platform_restock_received.emit(platform_id, qty)
	_evaluate_shortage_transition(platform_id, state)
	_recompute_current_price(state)
	return true


## Decrements stock for a sale. Tracks revenue and triggers shortage transition
## if this drop crosses the threshold. Returns true if the platform was found
## and stock was decremented.
func record_sale(
	platform_id: StringName, qty: int = 1, revenue: float = 0.0
) -> bool:
	var state: PlatformInventoryState = _states.get(platform_id, null)
	if state == null or qty <= 0:
		return false
	state.units_in_stock = maxi(0, state.units_in_stock - qty)
	state.total_units_sold += qty
	state.total_revenue += revenue
	_evaluate_shortage_transition(platform_id, state)
	_recompute_current_price(state)
	return true


# ── Customer spawn integration ───────────────────────────────────────────────

## Returns a multiplier ≥ 1.0 to scale the customer's spawn weight given the
## current platform shortage / hype state. Customers with no platform_affinities
## or zero shortage_sensitivity always receive 1.0.
func get_spawn_weight_modifier(profile: CustomerTypeDefinition) -> float:
	if profile == null:
		return 1.0
	if profile.platform_affinities.is_empty():
		return 1.0
	if profile.shortage_sensitivity <= 0.0:
		return 1.0
	var bonus: float = 0.0
	for platform_id: StringName in profile.platform_affinities:
		var state: PlatformInventoryState = _states.get(platform_id, null)
		if state == null:
			continue
		if not state.in_shortage:
			continue
		var boost: float = 1.0
		if state.platform != null:
			boost = state.platform.shortage_spawn_weight_boost
		bonus += state.hype_level * profile.shortage_sensitivity * boost
	return 1.0 + maxf(bonus, 0.0)


# ── Test seam ────────────────────────────────────────────────────────────────

## Replaces the live catalog with the supplied definitions and rebuilds states.
## Used by tests to install deterministic fixture platforms without depending on
## the on-disk catalog.
func _set_catalog_for_testing(
	definitions: Array[PlatformDefinition]
) -> void:
	_definitions.clear()
	_states.clear()
	_hype_tier_latched.clear()
	for definition: PlatformDefinition in definitions:
		if definition == null or definition.platform_id == &"":
			continue
		_register_definition(definition)


# ── Daily tick ───────────────────────────────────────────────────────────────

func run_daily_tick() -> void:
	for platform_id: StringName in _states:
		var state: PlatformInventoryState = _states[platform_id]
		if state == null or state.platform == null:
			continue
		_tick_platform(platform_id, state)


func _tick_platform(
	platform_id: StringName, state: PlatformInventoryState
) -> void:
	var definition: PlatformDefinition = state.platform
	var was_in_shortage: bool = state.in_shortage
	var now_in_shortage: bool = (
		state.units_in_stock < definition.shortage_threshold
	)
	var demand_multiplier: float = _resolve_demand_multiplier(platform_id)

	if now_in_shortage:
		state.shortage_days += 1
		state.hype_level = clampf(
			state.hype_level
			+ definition.shortage_hype_gain_per_day * demand_multiplier,
			HYPE_MIN, HYPE_MAX,
		)
	else:
		state.shortage_days = 0
		state.hype_level = clampf(
			state.hype_level - definition.hype_decay_per_day,
			HYPE_MIN, HYPE_MAX,
		)

	state.in_shortage = now_in_shortage
	if now_in_shortage and not was_in_shortage:
		EventBus.platform_shortage_started.emit(platform_id)
	elif was_in_shortage and not now_in_shortage:
		EventBus.platform_shortage_ended.emit(platform_id)

	_check_hype_tier_crossing(platform_id, state.hype_level)
	_recompute_current_price(state)


## Returns the active StoreCustomizationSystem demand multiplier for the
## platform, or 1.0 when the autoload is absent or returns nothing useful.
## Read here so the daily tick scales `shortage_hype_gain_per_day` on the
## featured platform when the player chose new-console-hype that morning.
func _resolve_demand_multiplier(platform_id: StringName) -> float:
	var customization: Node = get_node_or_null(
		"/root/StoreCustomizationSystem"
	)
	if customization == null or not customization.has_method(
		"get_demand_multiplier"
	):
		return 1.0
	return float(
		customization.call("get_demand_multiplier", platform_id)
	)


func _check_hype_tier_crossing(
	platform_id: StringName, hype_level: float
) -> void:
	var current_tier: int = _hype_tier_for(hype_level)
	var latched: int = int(_hype_tier_latched.get(platform_id, 0))
	if current_tier > latched:
		# Fire one signal for each tier we crossed upward through. This handles
		# the (rare) case where a single tick jumps multiple tiers.
		for tier: int in range(latched + 1, current_tier + 1):
			EventBus.platform_hype_threshold_crossed.emit(
				platform_id, tier
			)
		_hype_tier_latched[platform_id] = current_tier
	elif current_tier < latched:
		# Hype decayed below a previously-latched tier — reset the latch so the
		# next upward crossing fires again.
		_hype_tier_latched[platform_id] = current_tier


func _hype_tier_for(hype_level: float) -> int:
	var tier: int = 0
	for index: int in range(HYPE_TIER_THRESHOLDS.size()):
		if hype_level >= HYPE_TIER_THRESHOLDS[index]:
			tier = index + 1
	return tier


func _recompute_current_price(state: PlatformInventoryState) -> void:
	var definition: PlatformDefinition = state.platform
	if definition == null:
		state.current_sell_price = 0.0
		return
	var raw_scalar: float = (
		1.0 + state.hype_level * definition.hype_price_elasticity
	)
	var clamped_scalar: float = clampf(
		raw_scalar,
		definition.price_floor_multiplier,
		definition.price_ceiling_multiplier,
	)
	state.current_sell_price = definition.base_price * clamped_scalar


func _evaluate_shortage_transition(
	platform_id: StringName, state: PlatformInventoryState
) -> void:
	var definition: PlatformDefinition = state.platform
	if definition == null:
		return
	var was_in_shortage: bool = state.in_shortage
	var now_in_shortage: bool = (
		state.units_in_stock < definition.shortage_threshold
	)
	if now_in_shortage == was_in_shortage:
		return
	state.in_shortage = now_in_shortage
	if now_in_shortage:
		EventBus.platform_shortage_started.emit(platform_id)
	else:
		state.shortage_days = 0
		EventBus.platform_shortage_ended.emit(platform_id)


# ── Catalog loading ──────────────────────────────────────────────────────────

func _load_catalog() -> void:
	var entries: Array = DataLoader.load_catalog_entries(CATALOG_PATH)
	if entries.is_empty():
		# §F-119 — an empty catalog at the autoload path is a content-config
		# regression that breaks every read API in this system. Tests install
		# platforms via `_set_catalog_for_testing` before any read, so this
		# branch never fires under GUT; a warning would mask a missing /
		# malformed `platforms.json` in shipping. Escalate to push_error.
		push_error(
			"PlatformSystem: no entries loaded from '%s'" % CATALOG_PATH
		)
		return
	for entry: Variant in entries:
		if entry is not Dictionary:
			push_error(
				"PlatformSystem: catalog entry is not a Dictionary (got %s) — skipping"
				% type_string(typeof(entry))
			)
			continue
		var definition: PlatformDefinition = _build_definition(
			entry as Dictionary
		)
		if definition != null:
			_register_definition(definition)


func _build_definition(data: Dictionary) -> PlatformDefinition:
	var raw_id: String = str(data.get("platform_id", data.get("id", "")))
	if raw_id.is_empty():
		# §F-119 — a missing platform_id means the entry is unreachable for
		# every public read API; treat this as a data-integrity error so it
		# surfaces in CI / playtest instead of silently shrinking the
		# catalog.
		push_error(
			"PlatformSystem: catalog entry missing 'platform_id' (keys=%s)"
			% str(data.keys())
		)
		return null
	var definition: PlatformDefinition = PlatformDefinition.new()
	definition.platform_id = StringName(raw_id)
	definition.display_name = str(data.get("display_name", ""))
	definition.manufacturer = str(data.get("manufacturer", ""))
	definition.era = int(data.get("era", 0))
	definition.base_demand = float(data.get("base_demand", 1.0))
	definition.collector_appeal = float(data.get("collector_appeal", 0.5))
	definition.casual_appeal = float(data.get("casual_appeal", 0.5))
	definition.initial_stock = int(data.get("initial_stock", 10))
	definition.launch_window_start_day = int(
		data.get("launch_window_start_day", 0)
	)
	definition.launch_window_end_day = int(
		data.get("launch_window_end_day", 0)
	)
	definition.supply_constrained = bool(
		data.get("supply_constrained", false)
	)
	definition.shortage_threshold = int(data.get("shortage_threshold", 2))
	definition.base_price = float(data.get("base_price", 29.99))
	definition.price_floor_multiplier = float(
		data.get("price_floor_multiplier", 0.4)
	)
	definition.price_ceiling_multiplier = float(
		data.get("price_ceiling_multiplier", 4.0)
	)
	definition.hype_price_elasticity = float(
		data.get("hype_price_elasticity", 1.0)
	)
	definition.shortage_hype_gain_per_day = float(
		data.get("shortage_hype_gain_per_day", 0.05)
	)
	definition.hype_decay_per_day = float(
		data.get("hype_decay_per_day", 0.02)
	)
	definition.shortage_spawn_weight_boost = float(
		data.get("shortage_spawn_weight_boost", 1.5)
	)
	return definition


func _register_definition(definition: PlatformDefinition) -> void:
	var id: StringName = definition.platform_id
	_definitions[id] = definition
	var state: PlatformInventoryState = PlatformInventoryState.new()
	state.reset_to_defaults(definition)
	state.in_shortage = (
		state.units_in_stock < definition.shortage_threshold
	)
	_states[id] = state
	_hype_tier_latched[id] = 0
	_recompute_current_price(state)


func _on_day_started(_day: int) -> void:
	run_daily_tick()
