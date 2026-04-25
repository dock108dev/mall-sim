## GUT tests for MetaShiftSystem JSON-driven type-based meta shifts.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/signal_utils.gd")

const FIRE_SHIFT: Dictionary = {
	"id": "fire_surge",
	"affected_types": ["fire"],
	"multiplier": 1.8,
	"day_offset": 3,
	"telegraph_message": "Fire types rising.",
}
const WATER_SHIFT: Dictionary = {
	"id": "water_meta",
	"affected_types": ["water", "ice"],
	"multiplier": 2.0,
	"day_offset": 3,
	"telegraph_message": "Water and ice types surging.",
}
const GRASS_SHIFT: Dictionary = {
	"id": "grass_correction",
	"affected_types": ["grass"],
	"multiplier": 0.6,
	"day_offset": 3,
	"telegraph_message": "Grass types cooling.",
}

var _system: MetaShiftSystem = null
var _telegraphed: Array[Dictionary] = []
var _applied: Array[Dictionary] = []


func _on_telegraphed(
	shift_id: String, affected_types: Array[String], message: String
) -> void:
	_telegraphed.append({
		"id": shift_id,
		"types": affected_types,
		"message": message,
	})


func _on_applied(
	shift_id: String, affected_types: Array[String], multiplier: float
) -> void:
	_applied.append({
		"id": shift_id,
		"types": affected_types,
		"multiplier": multiplier,
	})


func before_each() -> void:
	_system = MetaShiftSystem.new()
	add_child_autofree(_system)
	_telegraphed = []
	_applied = []
	EventBus.meta_shift_telegraphed.connect(_on_telegraphed)
	EventBus.meta_shift_applied.connect(_on_applied)

	# Inject test defs directly; bypass file I/O and the DataLoader.
	_system._json_shift_defs = [FIRE_SHIFT, WATER_SHIFT, GRASS_SHIFT]
	_system._json_shift_index = 0
	# Prevent the per-item card-shift path from firing during test days.
	_system._days_until_next_announcement = 100
	# fire_surge activates at day 1 + 3 = 4; telegraphed at day 3.
	_system._schedule_next_json_shift(1)


func after_each() -> void:
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.meta_shift_telegraphed, _on_telegraphed
	)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.meta_shift_applied, _on_applied)
	if is_instance_valid(_system):
		_system.queue_free()
	_system = null


# ── Telegraph timing ─────────────────────────────────────────────────────────

func test_no_telegraph_before_penultimate_day() -> void:
	_system._on_day_started(2)
	assert_eq(_telegraphed.size(), 0, "No telegraph signal before day 3")


func test_telegraph_fires_exactly_one_day_before_activation() -> void:
	_system._on_day_started(3)
	assert_eq(_telegraphed.size(), 1, "Telegraph must fire on day 3")
	assert_eq(
		_telegraphed[0]["id"], "fire_surge",
		"Telegraph must carry the correct shift_id"
	)
	assert_eq(
		_telegraphed[0]["types"], ["fire"],
		"Telegraph must carry the affected types"
	)


func test_telegraph_not_repeated_on_subsequent_days() -> void:
	_system._on_day_started(3)
	_system._on_day_started(4)
	assert_eq(
		_telegraphed.size(), 1,
		"Telegraph must fire only once per shift"
	)


# ── Applied timing ───────────────────────────────────────────────────────────

func test_no_applied_before_activation_day() -> void:
	_system._on_day_started(3)
	assert_eq(_applied.size(), 0, "Applied must not fire before activation day")


func test_applied_fires_on_activation_day() -> void:
	_system._on_day_started(3)
	_system._on_day_started(4)
	assert_eq(_applied.size(), 1, "Applied must fire on day 4")
	assert_eq(_applied[0]["id"], "fire_surge")
	assert_almost_eq(_applied[0]["multiplier"], 1.8, 0.001)


# ── PriceResolver integration (multiplier values) ────────────────────────────

func test_affected_type_resolves_at_meta_multiplier() -> void:
	_system._on_day_started(3)
	_system._on_day_started(4)
	assert_almost_eq(
		_system.get_type_multiplier("fire"), 1.8, 0.001,
		"Affected fire type must return meta multiplier"
	)


func test_unaffected_type_resolves_at_base_1() -> void:
	_system._on_day_started(4)
	assert_almost_eq(
		_system.get_type_multiplier("water"), 1.0, 0.001,
		"Unaffected water type must return 1.0"
	)
	assert_almost_eq(
		_system.get_type_multiplier("grass"), 1.0, 0.001,
		"Unaffected grass type must return 1.0"
	)


func test_multiple_affected_types_all_get_multiplier() -> void:
	# Advance to water_meta (activates at day 4 + 3 = 7 after fire_surge at day 4).
	_system._on_day_started(3)
	_system._on_day_started(4)   # fire_surge applied; water_meta scheduled day 7
	_system._on_day_started(6)   # telegraph water_meta
	_system._on_day_started(7)   # water_meta applied
	assert_almost_eq(
		_system.get_type_multiplier("water"), 2.0, 0.001,
		"water should have 2.0x after water_meta applied"
	)
	assert_almost_eq(
		_system.get_type_multiplier("ice"), 2.0, 0.001,
		"ice should also have 2.0x (co-affected type)"
	)


# ── Expiry / revert behaviour ────────────────────────────────────────────────

func test_expired_shift_reverts_affected_type_to_1() -> void:
	_system._on_day_started(3)
	_system._on_day_started(4)   # fire_surge applied
	_system._on_day_started(6)   # telegraph water_meta
	_system._on_day_started(7)   # water_meta applied; fire_surge reverted
	assert_almost_eq(
		_system.get_type_multiplier("fire"), 1.0, 0.001,
		"Fire type must revert to 1.0 once the next shift replaces it"
	)


func test_get_type_multiplier_returns_1_when_no_shift_active() -> void:
	assert_almost_eq(
		_system.get_type_multiplier("fire"), 1.0, 0.001,
		"Must return 1.0 before any shift is applied"
	)


# ── No JSON mutation ─────────────────────────────────────────────────────────

func test_json_shift_defs_not_mutated_at_runtime() -> void:
	var defs_before: Array[Dictionary] = []
	for d: Dictionary in _system._json_shift_defs:
		defs_before.append(d.duplicate(true))

	_system._on_day_started(3)
	_system._on_day_started(4)
	_system._on_day_started(6)
	_system._on_day_started(7)

	for i: int in range(defs_before.size()):
		assert_eq(
			_system._json_shift_defs[i],
			defs_before[i],
			"Shift def %d must not be mutated at runtime" % i
		)
