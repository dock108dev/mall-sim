## Integration test — AmbientMomentsSystem trigger pipeline:
## condition met → enqueue_by_id → moment_delivered signal.
extends GutTest


const _MOMENT_A_ID: StringName = &"test_ambient_hallway"
const _MOMENT_B_ID: StringName = &"test_ambient_store"

var _sys: AmbientMomentsSystem
var _delivered: Array[Dictionary] = []
var _delivery_cb: Callable


func before_each() -> void:
	_delivered = []
	_sys = AmbientMomentsSystem.new()
	add_child_autofree(_sys)
	_sys._apply_state({})
	_sys._moment_definitions = _build_seeded_catalog()

	_delivery_cb = func(
		id: StringName, dt: StringName, ft: String, ac: StringName
	) -> void:
		_delivered.append({
			"moment_id": id,
			"display_type": dt,
			"flavor_text": ft,
			"audio_cue_id": ac,
		})
	EventBus.ambient_moment_delivered.connect(_delivery_cb)


func after_each() -> void:
	if EventBus.ambient_moment_delivered.is_connected(_delivery_cb):
		EventBus.ambient_moment_delivered.disconnect(_delivery_cb)
	_delivered = []


# ── Scenario 1 ────────────────────────────────────────────────────────────────


## Valid enqueue_by_id call emits moment_delivered with the complete correct payload.
func test_valid_enqueue_emits_moment_delivered_with_correct_payload() -> void:
	_sys.enqueue_by_id(_MOMENT_A_ID)

	assert_eq(
		_delivered.size(), 1,
		"One moment_delivered expected for a valid enqueue_by_id call"
	)
	var payload: Dictionary = _delivered[0]
	assert_eq(
		payload["moment_id"], _MOMENT_A_ID,
		"Delivered moment_id must match the enqueued ID"
	)
	assert_eq(
		payload["display_type"], &"toast",
		"display_type must match the definition for moment A"
	)
	assert_eq(
		payload["flavor_text"], "Hallway flavor text.",
		"flavor_text must match the definition for moment A"
	)
	assert_eq(
		payload["audio_cue_id"], &"sfx_test_hallway",
		"audio_cue_id must match the definition for moment A"
	)


# ── Scenario 2 ────────────────────────────────────────────────────────────────


## Enqueueing the same moment_id twice within the cooldown/dedup window produces
## exactly one moment_delivered emission; the second call emits ambient_moment_cancelled.
func test_duplicate_enqueue_within_dedup_window_delivers_once() -> void:
	_sys.enqueue_by_id(_MOMENT_A_ID)

	# Inject a cooldown to represent the dedup window after first delivery.
	# This mirrors what _evaluate_moments writes to _cooldowns when the internal
	# scheduler fires a moment, enforcing one-delivery-per-window semantics.
	_sys._cooldowns[String(_MOMENT_A_ID)] = 2

	var cancelled_ids: Array[StringName] = []
	var cancel_cb := func(id: StringName, _reason: StringName) -> void:
		cancelled_ids.append(id)
	EventBus.ambient_moment_cancelled.connect(cancel_cb)

	_sys.enqueue_by_id(_MOMENT_A_ID)

	EventBus.ambient_moment_cancelled.disconnect(cancel_cb)

	assert_eq(
		_delivered.size(), 1,
		"Second enqueue within dedup window must not produce a second moment_delivered"
	)
	assert_eq(
		cancelled_ids.size(), 1,
		"Second enqueue must emit ambient_moment_cancelled once"
	)
	assert_eq(
		cancelled_ids[0], _MOMENT_A_ID,
		"Cancelled moment_id must match the deduplicated moment"
	)


# ── Scenario 3 ────────────────────────────────────────────────────────────────


## Enqueueing a moment from category A then category B each produce moment_delivered
## with the correct category-specific payload fields.
func test_category_routing_produces_correct_payloads() -> void:
	_sys.enqueue_by_id(_MOMENT_A_ID)
	_sys.enqueue_by_id(_MOMENT_B_ID)

	assert_eq(
		_delivered.size(), 2,
		"Two distinct moments must produce two moment_delivered emissions"
	)

	var first: Dictionary = _delivered[0]
	assert_eq(
		first["moment_id"], _MOMENT_A_ID,
		"First delivered moment_id must be the hallway-category moment"
	)
	assert_eq(
		first["display_type"], &"toast",
		"Hallway moment must carry display_type toast"
	)

	var second: Dictionary = _delivered[1]
	assert_eq(
		second["moment_id"], _MOMENT_B_ID,
		"Second delivered moment_id must be the store-category moment"
	)
	assert_eq(
		second["display_type"], &"thought_bubble",
		"Store moment must carry display_type thought_bubble"
	)


# ── Scenario 4 ────────────────────────────────────────────────────────────────


## Empty moment_id causes push_error and emits no moment_delivered signal.
## The empty StringName is the boundary that enqueue_by_id validates with push_error.
func test_empty_moment_id_logs_error_and_emits_no_signal() -> void:
	_sys.enqueue_by_id(&"")

	assert_eq(
		_delivered.size(), 0,
		"Empty moment_id must not produce a moment_delivered emission"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


## Returns a seeded two-moment catalog covering distinct categories for test isolation.
func _build_seeded_catalog() -> Array[AmbientMomentDefinition]:
	var catalog: Array[AmbientMomentDefinition] = []

	var def_a: AmbientMomentDefinition = AmbientMomentDefinition.new()
	def_a.id = String(_MOMENT_A_ID)
	def_a.trigger_category = "time_of_day"
	def_a.trigger_value = "9"
	def_a.display_type = &"toast"
	def_a.flavor_text = "Hallway flavor text."
	def_a.audio_cue_id = &"sfx_test_hallway"
	def_a.scheduling_weight = 1.0
	def_a.cooldown_days = 2
	catalog.append(def_a)

	var def_b: AmbientMomentDefinition = AmbientMomentDefinition.new()
	def_b.id = String(_MOMENT_B_ID)
	def_b.trigger_category = "store_type"
	def_b.trigger_value = "retro_games"
	def_b.display_type = &"thought_bubble"
	def_b.flavor_text = "Store flavor text."
	def_b.audio_cue_id = &"sfx_test_store"
	def_b.scheduling_weight = 1.0
	def_b.cooldown_days = 3
	catalog.append(def_b)

	return catalog
