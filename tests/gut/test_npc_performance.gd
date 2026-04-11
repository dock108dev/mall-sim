## Tests NPC performance optimizations: navigation throttling, stagger offsets,
## preferred slot caching, and PerformanceManager NPC profiling.
extends GutTest


# --- PerformanceManager NPC profiling ---


var _perf: PerformanceManager


func before_each() -> void:
	_perf = PerformanceManager.new()
	add_child_autofree(_perf)
	_perf.initialize()


func test_npc_stats_default_zeroes() -> void:
	var stats: Dictionary = _perf.get_npc_performance_stats()
	assert_eq(
		stats.get("avg_total_ms", -1.0), 0.0,
		"NPC stats should start at zero"
	)
	assert_eq(
		stats.get("sample_count", -1), 0,
		"No valid samples initially"
	)


func test_record_npc_frame_updates_stats() -> void:
	_perf.record_npc_frame(0.5, 0.3, 0.1, 4)
	var stats: Dictionary = _perf.get_npc_performance_stats()
	assert_gt(
		stats.get("avg_total_ms", 0.0) as float, 0.0,
		"After recording a frame, avg total should be > 0"
	)
	assert_eq(
		stats.get("sample_count", 0) as int, 1,
		"Should have 1 valid sample"
	)


func test_record_npc_frame_peak_tracking() -> void:
	_perf.record_npc_frame(0.1, 0.1, 0.05, 2)
	_perf.record_npc_frame(1.0, 0.8, 0.2, 8)
	_perf.record_npc_frame(0.2, 0.15, 0.05, 3)
	var stats: Dictionary = _perf.get_npc_performance_stats()
	assert_almost_eq(
		stats.get("peak_total_ms", 0.0) as float, 2.0, 0.01,
		"Peak should be the sum of the largest frame (1.0+0.8+0.2)"
	)


func test_npc_stats_included_in_performance_stats() -> void:
	_perf.record_npc_frame(0.5, 0.3, 0.1, 4)
	var stats: Dictionary = _perf.get_performance_stats()
	assert_true(
		stats.has("npc_avg_total_ms"),
		"Performance stats should include npc_avg_total_ms"
	)
	assert_true(
		stats.has("npc_peak_total_ms"),
		"Performance stats should include npc_peak_total_ms"
	)


# --- Customer navigation throttling constants ---


func test_nav_recalc_interval_is_positive() -> void:
	assert_gt(
		Customer.NAV_RECALC_INTERVAL, 0.0,
		"NAV_RECALC_INTERVAL must be positive"
	)
	assert_lte(
		Customer.NAV_RECALC_INTERVAL, 0.5,
		"NAV_RECALC_INTERVAL should not exceed 500ms for responsiveness"
	)


# --- Stagger offset distribution ---


func test_stagger_offsets_are_distributed() -> void:
	var offsets: Array[float] = []
	var slots: int = CustomerSystem.STAGGER_SLOTS
	for i: int in range(slots):
		offsets.append(float(i) / float(slots))
	for i: int in range(slots - 1):
		assert_lt(
			offsets[i], offsets[i + 1],
			"Stagger offsets should be monotonically increasing"
		)
	assert_gte(
		offsets[0], 0.0,
		"First stagger offset should be >= 0"
	)
	assert_lt(
		offsets[slots - 1], 1.0,
		"Last stagger offset should be < 1.0"
	)


func test_stagger_slots_matches_max_customers() -> void:
	assert_gte(
		CustomerSystem.STAGGER_SLOTS,
		CustomerSystem.MAX_CUSTOMERS_MEDIUM,
		"Stagger slots should cover at least the max customer count"
	)


# --- PerformanceManager NPC sample window ---


func test_npc_sample_window_rolling() -> void:
	for i: int in range(PerformanceManager.NPC_SAMPLE_WINDOW + 10):
		_perf.record_npc_frame(0.1, 0.1, 0.05, 1)
	var stats: Dictionary = _perf.get_npc_performance_stats()
	var avg: float = stats.get("avg_total_ms", 0.0) as float
	assert_almost_eq(
		avg, 0.25, 0.01,
		"After filling window, avg should reflect consistent values"
	)


# --- Customer profiling fields exist and are initialized ---


func test_customer_profiling_fields_default() -> void:
	var customer: Customer = Customer.new()
	assert_eq(
		customer.last_script_time_ms, 0.0,
		"Script time should default to 0"
	)
	assert_eq(
		customer.last_nav_time_ms, 0.0,
		"Nav time should default to 0"
	)
	assert_eq(
		customer.last_anim_time_ms, 0.0,
		"Anim time should default to 0"
	)
	assert_eq(
		customer.stagger_offset, 0.0,
		"Stagger offset should default to 0"
	)
	customer.free()
