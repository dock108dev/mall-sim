## Tests for PlatformSystem autoload, PlatformDefinition resource, and the
## PlatformInventoryState runtime state. Covers catalog loading, the daily
## tick, shortage transitions, hype tier signals, restock crediting, and
## customer spawn weight integration.
extends GutTest


func _make_definition(
	platform_id: StringName,
	initial_stock: int,
	shortage_threshold: int = 2,
	base_price: float = 100.0,
) -> PlatformDefinition:
	var definition: PlatformDefinition = PlatformDefinition.new()
	definition.platform_id = platform_id
	definition.display_name = String(platform_id).capitalize()
	definition.initial_stock = initial_stock
	definition.shortage_threshold = shortage_threshold
	definition.base_price = base_price
	definition.shortage_hype_gain_per_day = 0.1
	definition.hype_decay_per_day = 0.05
	definition.hype_price_elasticity = 1.0
	definition.price_floor_multiplier = 0.5
	definition.price_ceiling_multiplier = 4.0
	definition.shortage_spawn_weight_boost = 1.5
	return definition


func before_each() -> void:
	# Reset the autoload to a deterministic empty catalog. Tests opt-in to the
	# fixtures they need via _set_catalog_for_testing.
	PlatformSystem._set_catalog_for_testing([])


func after_each() -> void:
	PlatformSystem._set_catalog_for_testing([])


# ── PlatformDefinition resource ──────────────────────────────────────────────


func test_platform_definition_has_documented_fields() -> void:
	var definition: PlatformDefinition = PlatformDefinition.new()
	assert_eq(definition.platform_id, &"")
	assert_eq(definition.display_name, "")
	assert_eq(definition.manufacturer, "")
	assert_eq(definition.era, 0)
	assert_eq(definition.base_demand, 1.0)
	assert_eq(definition.collector_appeal, 0.5)
	assert_eq(definition.casual_appeal, 0.5)
	assert_eq(definition.initial_stock, 10)
	assert_eq(definition.launch_window_start_day, 0)
	assert_eq(definition.launch_window_end_day, 0)
	assert_eq(definition.supply_constrained, false)
	assert_eq(definition.shortage_threshold, 2)
	assert_eq(definition.base_price, 29.99)
	assert_eq(definition.hype_price_elasticity, 1.0)
	assert_eq(definition.shortage_hype_gain_per_day, 0.05)
	assert_eq(definition.hype_decay_per_day, 0.02)
	assert_eq(definition.shortage_spawn_weight_boost, 1.5)


# ── PlatformInventoryState ───────────────────────────────────────────────────


func test_inventory_state_resets_to_definition_defaults() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 5)
	var state: PlatformInventoryState = PlatformInventoryState.new()
	state.reset_to_defaults(definition)
	assert_eq(state.units_in_stock, 5)
	assert_eq(state.hype_level, 0.0)
	assert_eq(state.shortage_days, 0)
	assert_false(state.in_shortage)
	assert_eq(state.current_sell_price, definition.base_price)


# ── Catalog loading + per-platform state ─────────────────────────────────────


func test_initializes_one_state_per_definition() -> void:
	var alpha: PlatformDefinition = _make_definition(&"alpha", 5)
	var beta: PlatformDefinition = _make_definition(&"beta", 1)
	PlatformSystem._set_catalog_for_testing([alpha, beta])
	var ids: Array[StringName] = PlatformSystem.get_all_platform_ids()
	assert_eq(ids.size(), 2)
	assert_true(ids.has(&"alpha"))
	assert_true(ids.has(&"beta"))
	# Beta starts in shortage because initial_stock < shortage_threshold.
	assert_true(PlatformSystem.is_shortage(&"beta"))
	assert_false(PlatformSystem.is_shortage(&"alpha"))


func test_real_catalog_loads_from_disk() -> void:
	# Reload from the on-disk catalog (before_each empties the autoload).
	PlatformSystem._load_catalog()
	assert_gt(
		PlatformSystem.get_all_platform_ids().size(), 0,
		"on-disk platform catalog must register at least one platform"
	)


# ── Daily tick: shortage_days + hype accumulation ────────────────────────────


func test_daily_tick_accumulates_shortage_days_and_hype() -> void:
	var definition: PlatformDefinition = _make_definition(&"scarce", 1)
	PlatformSystem._set_catalog_for_testing([definition])
	# initial_stock(1) < shortage_threshold(2) so first tick should accumulate.
	PlatformSystem.run_daily_tick()
	var state: PlatformInventoryState = PlatformSystem.get_state(&"scarce")
	assert_eq(state.shortage_days, 1)
	assert_almost_eq(state.hype_level, 0.1, 0.001)
	PlatformSystem.run_daily_tick()
	assert_eq(state.shortage_days, 2)
	assert_almost_eq(state.hype_level, 0.2, 0.001)


func test_daily_tick_resets_shortage_days_when_restocked() -> void:
	var definition: PlatformDefinition = _make_definition(&"scarce", 1)
	PlatformSystem._set_catalog_for_testing([definition])
	PlatformSystem.run_daily_tick()
	PlatformSystem.run_daily_tick()
	# Restock above threshold and tick again.
	PlatformSystem.receive_restock(&"scarce", 5)
	PlatformSystem.run_daily_tick()
	var state: PlatformInventoryState = PlatformSystem.get_state(&"scarce")
	assert_eq(state.shortage_days, 0)
	assert_lt(
		state.hype_level, 0.2,
		"hype must decay once shortage ends"
	)


# ── is_shortage + get_current_price ──────────────────────────────────────────


func test_is_shortage_returns_true_for_constrained_platform() -> void:
	var definition: PlatformDefinition = _make_definition(&"constrained", 0)
	PlatformSystem._set_catalog_for_testing([definition])
	assert_true(PlatformSystem.is_shortage(&"constrained"))


func test_get_current_price_lifts_with_hype() -> void:
	var definition: PlatformDefinition = _make_definition(&"hot", 1)
	PlatformSystem._set_catalog_for_testing([definition])
	var base_price: float = PlatformSystem.get_current_price(&"hot")
	assert_almost_eq(base_price, 100.0, 0.001)
	# Tick five times — hype should reach 0.5 and price should rise to 150.
	for i: int in range(5):
		PlatformSystem.run_daily_tick()
	var hype_price: float = PlatformSystem.get_current_price(&"hot")
	assert_almost_eq(hype_price, 150.0, 0.001)
	assert_gt(hype_price, base_price)


func test_get_current_price_clamps_to_ceiling() -> void:
	var definition: PlatformDefinition = _make_definition(&"capped", 0)
	definition.hype_price_elasticity = 10.0
	PlatformSystem._set_catalog_for_testing([definition])
	for i: int in range(20):
		PlatformSystem.run_daily_tick()
	# elasticity * hype = 10.0, but ceiling multiplier is 4.0 → max price = 400.
	assert_almost_eq(
		PlatformSystem.get_current_price(&"capped"),
		definition.base_price * definition.price_ceiling_multiplier,
		0.001,
	)


func test_unknown_platform_returns_safe_defaults() -> void:
	assert_false(PlatformSystem.is_shortage(&"nonexistent"))
	assert_eq(PlatformSystem.get_current_price(&"nonexistent"), 0.0)
	assert_eq(PlatformSystem.get_hype(&"nonexistent"), 0.0)


# ── Signals ──────────────────────────────────────────────────────────────────


func test_shortage_started_emitted_on_transition_into_shortage() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 5)
	PlatformSystem._set_catalog_for_testing([definition])
	# Drain stock below threshold and tick.
	watch_signals(EventBus)
	PlatformSystem.record_sale(&"alpha", 4)
	# record_sale fires the transition immediately when stock drops.
	assert_signal_emitted(EventBus, "platform_shortage_started")


func test_shortage_ended_emitted_when_restock_clears() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 1)
	PlatformSystem._set_catalog_for_testing([definition])
	# Already in shortage at init.
	watch_signals(EventBus)
	PlatformSystem.receive_restock(&"alpha", 5)
	assert_signal_emitted(EventBus, "platform_shortage_ended")
	assert_signal_emitted(EventBus, "platform_restock_received")


func test_restock_signal_carries_quantity() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 5)
	PlatformSystem._set_catalog_for_testing([definition])
	watch_signals(EventBus)
	PlatformSystem.receive_restock(&"alpha", 7)
	var params: Array = get_signal_parameters(
		EventBus, "platform_restock_received"
	)
	assert_eq(params[0], &"alpha")
	assert_eq(params[1], 7)


func test_hype_threshold_crossed_fires_for_each_tier() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 0)
	# Tune so each tick adds 0.1 hype.
	PlatformSystem._set_catalog_for_testing([definition])
	watch_signals(EventBus)
	# Tick enough days to cross 0.3 (tier 1) and 0.6 (tier 2).
	for i: int in range(7):
		PlatformSystem.run_daily_tick()
	assert_signal_emitted(EventBus, "platform_hype_threshold_crossed")
	assert_gte(
		get_signal_emit_count(
			EventBus, "platform_hype_threshold_crossed"
		),
		2,
		"expected at least two upward tier crossings (0.3 and 0.6)",
	)


# ── Customer spawn weight integration ────────────────────────────────────────


func test_spawn_weight_modifier_unaffected_for_no_affinities() -> void:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "casual"
	profile.shortage_sensitivity = 0.5
	assert_eq(
		PlatformSystem.get_spawn_weight_modifier(profile),
		1.0,
		"empty platform_affinities must yield identity multiplier",
	)


func test_spawn_weight_modifier_unaffected_when_not_in_shortage() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 10)
	PlatformSystem._set_catalog_for_testing([definition])
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "collector"
	profile.platform_affinities = [&"alpha"]
	profile.shortage_sensitivity = 0.9
	assert_almost_eq(
		PlatformSystem.get_spawn_weight_modifier(profile),
		1.0, 0.001,
		"no shortage should leave spawn weight unchanged",
	)


func test_spawn_weight_modifier_increases_during_shortage() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 0)
	PlatformSystem._set_catalog_for_testing([definition])
	# Build hype via daily ticks so the bonus is non-zero.
	for i: int in range(5):
		PlatformSystem.run_daily_tick()
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "collector"
	profile.platform_affinities = [&"alpha"]
	profile.shortage_sensitivity = 0.9
	var modifier: float = PlatformSystem.get_spawn_weight_modifier(profile)
	assert_gt(
		modifier, 1.0,
		"shortage with built-up hype must boost spawn weight"
	)


func test_spawn_weight_modifier_zero_sensitivity_yields_identity() -> void:
	var definition: PlatformDefinition = _make_definition(&"alpha", 0)
	PlatformSystem._set_catalog_for_testing([definition])
	for i: int in range(5):
		PlatformSystem.run_daily_tick()
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "indifferent"
	profile.platform_affinities = [&"alpha"]
	profile.shortage_sensitivity = 0.0
	assert_eq(
		PlatformSystem.get_spawn_weight_modifier(profile),
		1.0,
		"zero shortage_sensitivity must short-circuit to identity",
	)


# ── EventBus.day_started wiring ──────────────────────────────────────────────


func test_day_started_runs_daily_tick() -> void:
	var definition: PlatformDefinition = _make_definition(&"hooked", 0)
	PlatformSystem._set_catalog_for_testing([definition])
	EventBus.day_started.emit(1)
	var state: PlatformInventoryState = PlatformSystem.get_state(&"hooked")
	assert_eq(state.shortage_days, 1)
	assert_gt(state.hype_level, 0.0)
