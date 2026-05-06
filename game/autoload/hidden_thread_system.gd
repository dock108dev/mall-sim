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
const TIER2_DEFECTIVE_RETURNS_THRESHOLD: int = 2

const AWARENESS_TIER_BOUNDARIES: Array[float] = [25.0, 50.0, 75.0]

## Tiered consequence-text copy emitted by `finalize_day()`. Index is the
## per-day count of distinct hidden-thread props inspected; counts of 2 or
## more share the escalating string. Empty string at index 0 keeps the
## DaySummary label hidden when no inspection occurred.
const CONSEQUENCE_TEXT_ZERO: String = ""
const CONSEQUENCE_TEXT_ONE: String = "A minor irregularity was noted today."
const CONSEQUENCE_TEXT_MULTIPLE: String = (
	"Several items of interest were flagged during the shift."
)

const PAPER_TRAIL_DELTA_WARRANTY_BINDER: float = 2.0
const PAPER_TRAIL_DELTA_EMPLOYEE_SCHEDULE: float = 1.0

const BACKROOM_PANEL_NAME: String = "back_room_inventory"

## Caps on save-derived collections. The 30-day run upper-bounds the meaningful
## key range for `_artifact_days_processed`; ARTIFACT_SCHEDULE has 5 entries so
## `discovered_artifacts` cannot legitimately exceed that. Caps are defensive
## ceilings for hand-edited or corrupted save payloads — see security-report.md §3.
const MAX_RUN_DAY: int = 30
const MAX_DISCOVERED_ARTIFACTS: int = 32
const MAX_PERSISTED_ID_LENGTH: int = 64

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
var _defective_returns_today: int = 0

# Pattern fire-once-per-day flags so a single Tier 2 pattern cannot rack up
# multiple +10 awareness ticks within the same day.
var _tier2_unsatisfied_fired_today: bool = false
var _tier2_backroom_fired_today: bool = false
var _tier2_discrepancies_fired_today: bool = false
var _tier2_defective_returns_fired_today: bool = false

# Per-day idempotency set keyed by interactable_id. Each hidden-thread prop
# inspection is awareness-credited exactly once per day; repeat presses still
# emit the EventBus signal but the handler skips the score increment.
var _inspected_this_day: Dictionary = {}

# Counts the number of distinct hidden-thread inspections that ran today.
# Drives the tiered `hidden_thread_consequence_triggered` text emitted by
# `finalize_day`. Reset at day_started.
var _inspections_today: int = 0

# Tracks days for which `finalize_day` has already emitted the consequence
# text so a defensive double-call (autoload handler + explicit caller) cannot
# double-fire the signal.
var _finalized_days: Dictionary = {}

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
	EventBus.hold_shelf_inspected.connect(_on_hold_shelf_inspected)
	EventBus.warranty_binder_examined.connect(_on_warranty_binder_examined)
	EventBus.backordered_item_examined.connect(_on_backordered_item_examined)
	EventBus.register_note_examined.connect(_on_register_note_examined)
	EventBus.security_flyer_examined.connect(_on_security_flyer_examined)
	EventBus.returned_item_examined.connect(_on_returned_item_examined)
	EventBus.employee_schedule_examined.connect(_on_employee_schedule_examined)
	EventBus.defective_item_received.connect(_on_defective_item_received)


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


# ── Hidden-thread interactable handlers (idempotent per object per day) ──────

func _on_hold_shelf_inspected(
	store_id: StringName, suspicious_slip_count: int
) -> void:
	if not _claim_inspection(&"hold_shelf"):
		return
	_apply_tier1_trigger(&"hold_shelf_inspected", {
		"store_id": store_id,
		"suspicious_slip_count": suspicious_slip_count,
	})


func _on_warranty_binder_examined(store_id: StringName, day: int) -> void:
	if not _claim_inspection(&"warranty_binder"):
		return
	paper_trail_score += PAPER_TRAIL_DELTA_WARRANTY_BINDER
	_apply_tier1_trigger(&"warranty_binder_examined", {
		"store_id": store_id, "day": day,
	})


func _on_backordered_item_examined(
	store_id: StringName, item_id: StringName, days_pending: int
) -> void:
	if not _claim_inspection(&"backordered_item"):
		return
	_apply_tier1_trigger(&"backordered_item_examined", {
		"store_id": store_id,
		"item_id": item_id,
		"days_pending": days_pending,
	})


func _on_register_note_examined(store_id: StringName, day: int) -> void:
	if not _claim_inspection(&"register_note"):
		return
	_apply_tier1_trigger(&"register_note_examined", {
		"store_id": store_id, "day": day,
	})


func _on_security_flyer_examined(store_id: StringName) -> void:
	if not _claim_inspection(&"security_flyer"):
		return
	_apply_tier1_trigger(&"security_flyer_examined", {
		"store_id": store_id,
	})


func _on_returned_item_examined(
	store_id: StringName, item_id: StringName
) -> void:
	if not _claim_inspection(&"returned_item"):
		return
	_apply_tier1_trigger(&"returned_item_examined", {
		"store_id": store_id, "item_id": item_id,
	})


func _on_employee_schedule_examined(store_id: StringName, day: int) -> void:
	if not _claim_inspection(&"employee_schedule"):
		return
	paper_trail_score += PAPER_TRAIL_DELTA_EMPLOYEE_SCHEDULE
	_apply_tier1_trigger(&"employee_schedule_examined", {
		"store_id": store_id, "day": day,
	})


## Returns true on the first call per day for `interactable_id`, false on
## subsequent calls. Centralizes the idempotency contract so each hidden-
## thread handler stays one-line. Also bumps the per-day inspection counter
## that drives `finalize_day`'s tiered consequence text.
func _claim_inspection(interactable_id: StringName) -> bool:
	if _inspected_this_day.has(interactable_id):
		return false
	_inspected_this_day[interactable_id] = true
	_inspections_today += 1
	return true


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


## Passive Tier 2 accumulator: fires when ReturnsSystem deposits two or more
## defective items into the damaged bin in a single day. Distinct from
## `returned_item_examined`, which is the player-driven inspection trigger.
func _on_defective_item_received(_item_id: String) -> void:
	_defective_returns_today += 1
	_check_tier2_defective_returns()


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


func _check_tier2_defective_returns() -> void:
	if _tier2_defective_returns_fired_today:
		return
	if _defective_returns_today < TIER2_DEFECTIVE_RETURNS_THRESHOLD:
		return
	_tier2_defective_returns_fired_today = true
	_apply_tier2_trigger(&"defective_returns_cluster", {
		"count": _defective_returns_today,
	})


# ── Day boundary ──────────────────────────────────────────────────────────────

func _on_day_started(_day: int) -> void:
	_unsatisfied_today = 0
	_backroom_reentries_today = 0
	_discrepancies_today = 0
	_defective_returns_today = 0
	_tier2_unsatisfied_fired_today = false
	_tier2_backroom_fired_today = false
	_tier2_discrepancies_fired_today = false
	_tier2_defective_returns_fired_today = false
	_inspected_this_day.clear()
	_inspections_today = 0


func _on_day_ended(day: int) -> void:
	# Emit the consequence text BEFORE artifact evaluation so it lands on the
	# bus before any other day_ended subscriber (notably PerformanceReportSystem)
	# builds its end-of-day report. HiddenThreadSystem is an autoload, so its
	# handler is connected at autoload time and runs before scene-time
	# subscribers' connect() calls in tier-5 init.
	finalize_day(day)
	_evaluate_artifact_unlock(day)


## Emits the per-day `hidden_thread_consequence_triggered` text based on how
## many distinct hidden-thread props were inspected during the day. Idempotent
## per day so a defensive double-call (e.g., explicit invocation from
## DayCycleController) cannot double-fire the signal.
func finalize_day(day: int) -> void:
	if _finalized_days.get(day, false):
		return
	_finalized_days[day] = true
	EventBus.hidden_thread_consequence_triggered.emit(
		_consequence_text_for_count(_inspections_today)
	)


## Returns the per-day inspection count without leaking the dictionary. Used
## by tests and downstream tooling that need to verify the tiered text branch.
func get_inspections_today() -> int:
	return _inspections_today


static func _consequence_text_for_count(count: int) -> String:
	if count <= 0:
		return CONSEQUENCE_TEXT_ZERO
	if count == 1:
		return CONSEQUENCE_TEXT_ONE
	return CONSEQUENCE_TEXT_MULTIPLE


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
		# Cap array length and per-entry id length so a hand-edited save cannot
		# inject unbounded entries into a cumulative collection. See
		# security-report.md §3.
		for raw: Variant in raw_artifacts:
			if discovered_artifacts.size() >= MAX_DISCOVERED_ARTIFACTS:
				break
			var raw_str: String = str(raw)
			if raw_str.is_empty() or raw_str.length() > MAX_PERSISTED_ID_LENGTH:
				continue
			discovered_artifacts.append(StringName(raw_str))

	_artifact_days_processed.clear()
	var raw_days: Variant = data.get("artifact_days_processed", {})
	if raw_days is Dictionary:
		# Drop entries whose day key is out of the legitimate run range so an
		# oversized cfg cannot inject a wide span of stub keys that survive for
		# the rest of the session. See security-report.md §3.
		for key: Variant in (raw_days as Dictionary).keys():
			var day_key: int = int(key)
			if day_key < 1 or day_key > MAX_RUN_DAY:
				continue
			_artifact_days_processed[day_key] = bool((raw_days as Dictionary)[key])


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
	_defective_returns_today = 0
	_tier2_unsatisfied_fired_today = false
	_tier2_backroom_fired_today = false
	_tier2_discrepancies_fired_today = false
	_tier2_defective_returns_fired_today = false
	_inspected_this_day.clear()
	_inspections_today = 0
	_finalized_days.clear()
	_artifact_days_processed.clear()
