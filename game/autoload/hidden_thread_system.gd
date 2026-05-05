## Hidden-thread awareness tracker.
##
## Owns four cumulative stats — hidden_thread_interactions, paper_trail_score,
## scapegoat_risk, awareness_score — plus the discovered_artifacts catalog used
## to gate the secret ending. Stats accumulate across all 30 days of a run and
## are not reset at day_started. Persistence round-trips through get_save_data()
## / load_state() so cross-session continuity is preserved.
##
## Tier 1 triggers fire immediately on a single signal (+5 awareness).
## Tier 2 triggers fire on a per-day pattern threshold (+10 awareness, once per
## pattern per day). Per-day counters reset at day_started.
## Tier 3 triggers fire at day_ended on days 5/10/15/20/25 if the awareness
## threshold for that day is met; missed artifacts are permanently absent for
## the run (no catch-up — the secret ending is gated behind sustained attention).
class_name HiddenThreadSystem
extends Node


# ── Constants ─────────────────────────────────────────────────────────────────

const TIER1_AWARENESS_DELTA: float = 5.0
const TIER2_AWARENESS_DELTA: float = 10.0
const TIER3_AWARENESS_DELTA: float = 20.0

## scapegoat_risk increment applied per inventory_variance_noted event. Each
## unexplained discrepancy nudges the player closer to a scapegoat ending —
## the magnitude is intentionally small so a single rare miscount does not
## dominate, but a sustained stream over a 30-day run accumulates meaningfully.
const SCAPEGOAT_RISK_DELTA_VARIANCE: float = 1.0

const TIER2_UNSATISFIED_THRESHOLD: int = 3
const TIER2_BACKROOM_REENTRY_THRESHOLD: int = 3
const TIER2_DISCREPANCY_THRESHOLD: int = 2

const AWARENESS_TIER_BOUNDARIES: Array[float] = [25.0, 50.0, 75.0]

const BACKROOM_PANEL_NAME: String = "back_room_inventory"

# Day-boundary artifact unlock schedule. Key is the day; value carries the
# artifact id and the awareness_score floor that must be met at day_ended.
const ARTIFACT_SCHEDULE: Dictionary = {
	5: {"id": &"delivery_manifest_carbon", "threshold": 15.0},
	10: {"id": &"vacant_unit_manifesto", "threshold": 30.0},
	15: {"id": &"directory_ghost_entry", "threshold": 50.0},
	20: {"id": &"escalator_loop_token", "threshold": 75.0},
	25: {"id": &"wax_reflection_shard", "threshold": 100.0},
}

# ── Cumulative stats (cross-day, save-persistent) ─────────────────────────────

var hidden_thread_interactions: int = 0
var paper_trail_score: float = 0.0
var scapegoat_risk: float = 0.0
var awareness_score: float = 0.0
var discovered_artifacts: Array[StringName] = []

# ── Per-day pattern counters (reset at day_started) ───────────────────────────

var _unsatisfied_today: int = 0
var _backroom_reentries_today: int = 0
var _discrepancies_today: int = 0

# Pattern fire-once-per-day flags so a single Tier 2 pattern cannot rack up
# multiple +10 awareness ticks within the same day.
var _tier2_unsatisfied_fired_today: bool = false
var _tier2_backroom_fired_today: bool = false
var _tier2_discrepancies_fired_today: bool = false

# Days whose end-of-day artifact check has already run. Guarantees the gate
# is evaluated exactly once per scheduled day per run.
var _artifact_days_processed: Dictionary = {}


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.delivery_manifest_examined.connect(_on_delivery_manifest_examined)
	EventBus.hold_shady_request_received.connect(_on_hold_shady_request_received)
	EventBus.inventory_variance_noted.connect(_on_inventory_variance_noted)
	EventBus.display_exposes_weird_inventory.connect(_on_display_exposes_weird_inventory)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.hold_conflict_bypassed.connect(_on_hold_conflict_bypassed)


# ── Tier 1 handlers ───────────────────────────────────────────────────────────

func _on_delivery_manifest_examined(store_id: StringName, day: int) -> void:
	_apply_tier1_trigger(&"delivery_manifest_examined", {
		"store_id": store_id, "day": day,
	})


func _on_hold_shady_request_received(
	store_id: StringName, slip_id: String, item_id: StringName, requestor_tier: int
) -> void:
	_apply_tier1_trigger(&"hold_suspicious_request_received", {
		"store_id": store_id, "slip_id": slip_id,
		"item_id": item_id, "requestor_tier": requestor_tier,
	})


func _on_inventory_variance_noted(
	store_id: StringName, item_id: StringName, expected: int, actual: int
) -> void:
	_discrepancies_today += 1
	scapegoat_risk += SCAPEGOAT_RISK_DELTA_VARIANCE
	_apply_tier1_trigger(&"inventory_variance_noted", {
		"store_id": store_id, "item_id": item_id,
		"expected": expected, "actual": actual,
	})
	_check_tier2_discrepancies()


func _on_display_exposes_weird_inventory(store_id: StringName) -> void:
	_apply_tier1_trigger(&"display_exposes_weird_inventory", {
		"store_id": store_id,
	})


# ── Tier 2 pattern accumulators ──────────────────────────────────────────────

func _on_customer_left(customer_data: Dictionary) -> void:
	var satisfied: bool = bool(customer_data.get("satisfied", false))
	if satisfied:
		return
	_unsatisfied_today += 1
	_check_tier2_unsatisfied()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != BACKROOM_PANEL_NAME:
		return
	_backroom_reentries_today += 1
	_check_tier2_backroom_reentries()


func _on_hold_conflict_bypassed(
	store_id: StringName, item_id: StringName, disputed_slip_ids: Array
) -> void:
	_apply_tier2_trigger(&"hold_conflict_bypassed", {
		"store_id": store_id, "item_id": item_id,
		"disputed_slip_ids": disputed_slip_ids,
	})


func _check_tier2_unsatisfied() -> void:
	if _tier2_unsatisfied_fired_today:
		return
	if _unsatisfied_today < TIER2_UNSATISFIED_THRESHOLD:
		return
	_tier2_unsatisfied_fired_today = true
	_apply_tier2_trigger(&"unsatisfied_streak", {
		"count": _unsatisfied_today,
	})


func _check_tier2_backroom_reentries() -> void:
	if _tier2_backroom_fired_today:
		return
	if _backroom_reentries_today < TIER2_BACKROOM_REENTRY_THRESHOLD:
		return
	_tier2_backroom_fired_today = true
	_apply_tier2_trigger(&"backroom_reentry_pattern", {
		"count": _backroom_reentries_today,
	})


func _check_tier2_discrepancies() -> void:
	if _tier2_discrepancies_fired_today:
		return
	if _discrepancies_today < TIER2_DISCREPANCY_THRESHOLD:
		return
	_tier2_discrepancies_fired_today = true
	_apply_tier2_trigger(&"discrepancy_cluster", {
		"count": _discrepancies_today,
	})


# ── Day boundary ──────────────────────────────────────────────────────────────

func _on_day_started(_day: int) -> void:
	_unsatisfied_today = 0
	_backroom_reentries_today = 0
	_discrepancies_today = 0
	_tier2_unsatisfied_fired_today = false
	_tier2_backroom_fired_today = false
	_tier2_discrepancies_fired_today = false


func _on_day_ended(day: int) -> void:
	_evaluate_artifact_unlock(day)


func _evaluate_artifact_unlock(day: int) -> void:
	if not ARTIFACT_SCHEDULE.has(day):
		return
	if _artifact_days_processed.get(day, false):
		return
	_artifact_days_processed[day] = true

	var entry: Dictionary = ARTIFACT_SCHEDULE[day]
	var threshold: float = float(entry.get("threshold", 0.0))
	if awareness_score < threshold:
		# Permanently missed for this run by design.
		return

	var artifact_id: StringName = StringName(str(entry.get("id", "")))
	if artifact_id.is_empty():
		return
	if discovered_artifacts.has(artifact_id):
		return
	_apply_tier3_trigger(artifact_id, day)


# ── Trigger application ───────────────────────────────────────────────────────

func _apply_tier1_trigger(trigger_id: StringName, context: Dictionary) -> void:
	hidden_thread_interactions += 1
	_increase_awareness(TIER1_AWARENESS_DELTA)
	var enriched: Dictionary = context.duplicate()
	enriched["trigger_id"] = trigger_id
	EventBus.hidden_thread_interaction_fired.emit(1, enriched)
	EventBus.hidden_thread_interacted.emit(trigger_id)


func _apply_tier2_trigger(trigger_id: StringName, context: Dictionary) -> void:
	_increase_awareness(TIER2_AWARENESS_DELTA)
	var enriched: Dictionary = context.duplicate()
	enriched["trigger_id"] = trigger_id
	EventBus.hidden_thread_interaction_fired.emit(2, enriched)
	EventBus.hidden_thread_interacted.emit(trigger_id)


func _apply_tier3_trigger(artifact_id: StringName, day: int) -> void:
	discovered_artifacts.append(artifact_id)
	_increase_awareness(TIER3_AWARENESS_DELTA)
	EventBus.hidden_thread_interaction_fired.emit(3, {
		"trigger_id": artifact_id, "day": day,
	})
	EventBus.hidden_thread_interacted.emit(artifact_id)
	EventBus.hidden_artifact_spawned.emit(artifact_id)


func _increase_awareness(delta: float) -> void:
	var old_tier: int = _compute_awareness_tier(awareness_score)
	awareness_score += delta
	var new_tier: int = _compute_awareness_tier(awareness_score)
	if new_tier != old_tier:
		EventBus.hidden_awareness_tier_changed.emit(old_tier, new_tier)


func _compute_awareness_tier(score: float) -> int:
	var tier: int = 0
	for boundary: float in AWARENESS_TIER_BOUNDARIES:
		if score >= boundary:
			tier += 1
	return tier


# ── Public read API ──────────────────────────────────────────────────────────

## Returns the count of artifacts collected — equivalent to the
## `mystery_artifacts_collected` stat read by EndingEvaluator's secret-ending
## criterion.
func get_mystery_artifacts_count() -> int:
	return discovered_artifacts.size()


## Returns a defensive copy of the artifact catalog.
func get_discovered_artifacts() -> Array[StringName]:
	var copy: Array[StringName] = []
	for id: StringName in discovered_artifacts:
		copy.append(id)
	return copy


## Returns true if the given artifact has been unlocked this run.
func has_artifact(artifact_id: StringName) -> bool:
	return discovered_artifacts.has(artifact_id)


# ── Persistence ───────────────────────────────────────────────────────────────

## Serializes cumulative state for the game save payload. The per-day pattern
## counters are intentionally excluded — those reset at every day_started and
## carry no cross-day meaning.
func get_save_data() -> Dictionary:
	var artifact_strings: Array = []
	for id: StringName in discovered_artifacts:
		artifact_strings.append(String(id))
	return {
		"hidden_thread_interactions": hidden_thread_interactions,
		"paper_trail_score": paper_trail_score,
		"scapegoat_risk": scapegoat_risk,
		"awareness_score": awareness_score,
		"discovered_artifacts": artifact_strings,
		"artifact_days_processed": _artifact_days_processed.duplicate(),
	}


## Restores cumulative state from save data. Missing keys default to zero /
## empty so loads from older save formats remain safe.
##
## §F-128 — float fields are NaN/Inf-rejected and floored at 0.0 because they
## flow into `_compute_awareness_tier` (>=-comparison) and the secret-ending
## thresholds; a NaN value silently sits below every threshold while still
## counting toward `_increase_awareness` deltas, and a negative Inf would break
## the tier-boundary walk. Same defensive load posture as `EconomySystem._apply_state`.
func load_state(data: Dictionary) -> void:
	hidden_thread_interactions = maxi(
		int(data.get("hidden_thread_interactions", 0)), 0
	)
	paper_trail_score = _safe_finite_float(
		data.get("paper_trail_score", 0.0), 0.0
	)
	scapegoat_risk = _safe_finite_float(
		data.get("scapegoat_risk", 0.0), 0.0
	)
	awareness_score = _safe_finite_float(
		data.get("awareness_score", 0.0), 0.0
	)

	discovered_artifacts.clear()
	var raw_artifacts: Variant = data.get("discovered_artifacts", [])
	if raw_artifacts is Array:
		for raw: Variant in raw_artifacts:
			discovered_artifacts.append(StringName(str(raw)))

	_artifact_days_processed.clear()
	var raw_days: Variant = data.get("artifact_days_processed", {})
	if raw_days is Dictionary:
		for key: Variant in (raw_days as Dictionary).keys():
			_artifact_days_processed[int(key)] = bool((raw_days as Dictionary)[key])


## §F-128 — coerces a save-derived Variant to a finite, non-negative float. NaN
## and ±Inf both fall back to `default_value` so a hand-edited save cannot
## stash a poison value into a cumulative awareness-tier counter.
static func _safe_finite_float(raw: Variant, default_value: float) -> float:
	var value: float = default_value
	if raw is float:
		value = raw as float
	elif raw is int:
		value = float(raw as int)
	if is_nan(value) or is_inf(value):
		return default_value
	return maxf(value, 0.0)


## Resets all state — used for new-game flows and tests. Cumulative stats and
## the artifact catalog drop to zero/empty alongside the per-day counters.
func reset() -> void:
	hidden_thread_interactions = 0
	paper_trail_score = 0.0
	scapegoat_risk = 0.0
	awareness_score = 0.0
	discovered_artifacts.clear()
	_unsatisfied_today = 0
	_backroom_reentries_today = 0
	_discrepancies_today = 0
	_tier2_unsatisfied_fired_today = false
	_tier2_backroom_fired_today = false
	_tier2_discrepancies_fired_today = false
	_artifact_days_processed.clear()
