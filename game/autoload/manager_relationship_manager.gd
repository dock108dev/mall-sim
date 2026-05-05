## ManagerRelationshipManager — owner of the player↔manager trust relationship.
##
## Holds the manager-trust scalar (0.0–1.0) for the active run, derives the
## tier label (cold/neutral/warm/trusted), tracks per-day event categories so
## the morning note can react to yesterday's behavior, and selects the note to
## render at day_started.
##
## Responsibilities:
##   - Hold manager_trust and tier; mutate via apply_trust_delta only.
##   - Listen to EventBus signals that imply trust deltas (task completed,
##     staff quit, payroll missed, etc.) and apply the documented amounts.
##   - Track per-day event categories (operational / sales / staff) so
##     _select_note can pick a tier×category note.
##   - At day_started, pick a note (Day 1 / Day 10 / Day 20 / unlock-override
##     mornings → fixed override; otherwise tier×top-category) and emit
##     EventBus.manager_note_shown(note_id, body, allow_auto_dismiss).
##   - At day_closed, evaluate the metric payload (items_sold, inventory,
##     stockout / queue counters under shift_summary), pick a tier×condition
##     comment from end_of_day_comments and emit
##     EventBus.manager_end_of_day_comment(id, body).
##
## Note selection contract (acceptance criteria):
##   - Day 1 → date override "note_override_day_1", manual dismiss only.
##   - Day 10 / Day 20 → date overrides, auto-dismiss allowed.
##   - Day after an unlock_granted (recorded via _pending_unlock_note) →
##     unlock-specific override, manual dismiss only.
##   - Otherwise → derive top_event_category from yesterday's event tally;
##     null falls back to "operational"; selection lookup is
##     tier_notes[tier][category]. If unknown, fall back to
##     tier_notes[tier]["operational"], then to the global fallback note.
extends Node


const NOTES_PATH: String = "res://game/content/manager/manager_notes.json"
const MANAGER_NAME: String = "Vic Harlow"

const TRUST_MIN: float = 0.0
const TRUST_MAX: float = 1.0
const DEFAULT_TRUST: float = 0.5

const TIER_COLD: StringName = &"cold"
const TIER_NEUTRAL: StringName = &"neutral"
const TIER_WARM: StringName = &"warm"
const TIER_TRUSTED: StringName = &"trusted"

const COLD_MAX: float = 0.25
const NEUTRAL_MAX: float = 0.50
const WARM_MAX: float = 0.75

const CATEGORY_OPERATIONAL: StringName = &"operational"
const CATEGORY_SALES: StringName = &"sales"
const CATEGORY_STAFF: StringName = &"staff"

# End-of-day comment conditions, in priority order (highest first). Listed as
# constants so tests and external callers can refer to them without string
# literals scattered through the codebase.
const EOD_CONDITION_ZERO_SALES: StringName = &"zero_sales"
const EOD_CONDITION_EMPTY_SHELVES: StringName = &"empty_shelves"
const EOD_CONDITION_STOCKOUT_WALKOUTS: StringName = &"stockout_walkouts"
const EOD_CONDITION_QUEUE_TIMEOUT: StringName = &"queue_timeout"
const EOD_CONDITION_NORMAL: StringName = &"normal"

# Thresholds for the metric-driven conditions. Comments with counts at or
# below these floors fall through to lower-priority conditions or `normal`.
const EOD_STOCKOUT_THRESHOLD: int = 2
const EOD_QUEUE_TIMEOUT_THRESHOLD: int = 3

## Per-event trust deltas (issue spec).
const DELTA_TASK_COMPLETED: float = 0.06
const DELTA_COMPLAINT_HANDLED: float = 0.03
const DELTA_MYSTERY_INVENTORY_ACK: float = 0.04
const DELTA_STAFF_QUIT: float = -0.05
const DELTA_MISSING_PAYROLL: float = -0.10

const REASON_TASK_COMPLETED: String = "task_completed"
const REASON_COMPLAINT_HANDLED: String = "complaint_handled"
const REASON_MYSTERY_INVENTORY_ACK: String = "mystery_inventory_acknowledged"
const REASON_STAFF_QUIT: String = "staff_quit"
const REASON_MISSING_PAYROLL: String = "missing_payroll"

## Confrontation triggers when trust drops below this threshold (cold tier
## floor — cold spans 0.00–0.24, so 0.15 is decisively in confrontation range
## without being the absolute floor).
const CONFRONTATION_FLOOR: float = 0.15


var manager_trust: float = DEFAULT_TRUST
var manager_tier: StringName = TIER_NEUTRAL

# Per-day category tally — counts of events by category. Top category is the
# one with the highest count at day_started; ties resolve in insertion order
# of CATEGORY_PRIORITY (operational > sales > staff) so the fallback is
# deterministic.
var _category_counts: Dictionary = {}
# Reset at day_started after the previous day's note has been selected.
var _last_top_category: StringName = &""

# Set by _on_unlock_granted; consumed (and cleared) at the next day_started so
# the morning-after-unlock note fires exactly once.
var _pending_unlock_id: String = ""

var _notes: Dictionary = {}
var _notes_loaded: bool = false
var _confrontation_emitted_this_day: bool = false

# Private RNG used for note variant selection — kept separate from the global
# generator so EventBus.day_started listeners that seed the global RNG (e.g.
# WarrantyManager claim rolls) are not perturbed by note picking.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_notes()
	_recalculate_tier()
	_connect_event_bus()


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the manager display name. Stored as a constant so callers don't reach
## into the JSON for it.
func get_manager_name() -> String:
	return MANAGER_NAME


## Applies a trust delta and emits manager_trust_changed when the post-clamp
## value moves. Recalculates the tier so callers always read a fresh value.
## delta is clamped against the [0,1] manager_trust range; reason is a short
## human-readable cause label that flows into the signal payload for HUD /
## telemetry.
func apply_trust_delta(delta: float, reason: String) -> void:
	if is_zero_approx(delta):
		return
	var before: float = manager_trust
	manager_trust = clampf(before + delta, TRUST_MIN, TRUST_MAX)
	var actual_delta: float = manager_trust - before
	if is_zero_approx(actual_delta):
		return
	_recalculate_tier()
	EventBus.manager_trust_changed.emit(actual_delta, reason)
	if (
		actual_delta < 0.0
		and manager_trust < CONFRONTATION_FLOOR
		and not _confrontation_emitted_this_day
	):
		_confrontation_emitted_this_day = true
		EventBus.manager_confrontation_triggered.emit(reason)


## Returns the current trust tier as a StringName ("cold"/"neutral"/...).
func get_tier() -> StringName:
	return manager_tier


## Returns the current trust tier as an ordinal index (cold=0, neutral=1,
## warm=2, trusted=3). Single canonical mapping shared with
## `MilestoneSystem` / `ProgressionSystem` so both consumers stay aligned with
## `_recalculate_tier`.
func get_tier_index() -> int:
	return tier_index_for(manager_tier)


## Maps a tier StringName to its ordinal index. Static so headless callers
## without access to a live manager autoload can still translate a tier value.
static func tier_index_for(tier: StringName) -> int:
	match String(tier):
		"cold":
			return 0
		"neutral":
			return 1
		"warm":
			return 2
		"trusted":
			return 3
	return 0


## Test seam — resets in-memory state to defaults so each test starts from a
## clean slate without re-instantiating the autoload.
func reset_for_testing() -> void:
	manager_trust = DEFAULT_TRUST
	_recalculate_tier()
	_category_counts.clear()
	_last_top_category = &""
	_pending_unlock_id = ""
	_confrontation_emitted_this_day = false


# ── Note selection ────────────────────────────────────────────────────────────

## Selects the metric-driven end-of-day comment for the given day and payload
## and returns {id: String, body: String}. Public so tests can exercise the
## selection contract without going through the day_closed signal flow.
##
## Priority order (highest → lowest): zero_sales > empty_shelves >
## stockout_walkouts > queue_timeout > normal. The stockout / queue counters
## live under payload["shift_summary"] and are sourced from
## `CustomerSystem.get_leave_counts()` via `DayCycleController._show_day_summary`
## (the SSOT for per-day leave reasons): `customers_no_stock` is the count of
## customers that left because no matching item was on the shelf;
## `customers_timeout` is the count of customers whose patience expired
## (queue or browse). Absent fields default to 0 so the condition resolves
## to `normal` without error.
func select_end_of_day_comment(_day: int, payload: Dictionary) -> Dictionary:
	var items_sold: int = int(payload.get("items_sold", 0))
	var inventory_remaining: int = int(payload.get("inventory_remaining", 0))
	var shift_summary_raw: Variant = payload.get("shift_summary", {})
	var shift_summary: Dictionary = (
		shift_summary_raw if shift_summary_raw is Dictionary else {}
	)
	var stockout_walkouts: int = int(
		shift_summary.get("customers_no_stock", 0)
	)
	var queue_timeouts: int = int(shift_summary.get("customers_timeout", 0))
	var condition: StringName
	if items_sold == 0:
		condition = EOD_CONDITION_ZERO_SALES
	elif stockout_walkouts > 0 and inventory_remaining == 0:
		condition = EOD_CONDITION_EMPTY_SHELVES
	elif stockout_walkouts > EOD_STOCKOUT_THRESHOLD:
		condition = EOD_CONDITION_STOCKOUT_WALKOUTS
	elif queue_timeouts > EOD_QUEUE_TIMEOUT_THRESHOLD:
		condition = EOD_CONDITION_QUEUE_TIMEOUT
	else:
		condition = EOD_CONDITION_NORMAL
	return _end_of_day_comment(manager_tier, condition)


## Selects the note for the given day and returns
## {id: String, body: String, allow_auto_dismiss: bool}. Public so tests can
## exercise the selection contract without going through the day_started
## signal flow. Day 1 / unlock-override notes are manual-dismiss; everything
## else allows auto-dismiss.
func select_note_for_day(day: int) -> Dictionary:
	if day <= 1:
		return _override_note("day_1", false)
	if not _pending_unlock_id.is_empty():
		var unlock_note: Dictionary = _unlock_override_note(_pending_unlock_id)
		if not unlock_note.is_empty():
			return unlock_note
	if day == 10:
		return _override_note("day_10", true)
	if day == 20:
		return _override_note("day_20", true)
	var category: StringName = _resolve_top_category()
	return _tier_category_note(manager_tier, category)


# ── Internals ─────────────────────────────────────────────────────────────────

func _connect_event_bus() -> void:
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.day_closed, _on_day_closed)
	_connect_signal(EventBus.task_completed, _on_task_completed)
	_connect_signal(EventBus.staff_quit, _on_staff_quit)
	_connect_signal(EventBus.staff_not_paid, _on_staff_not_paid)
	_connect_signal(EventBus.unlock_granted, _on_unlock_granted)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _on_day_started(day: int) -> void:
	_confrontation_emitted_this_day = false
	var note: Dictionary = select_note_for_day(day)
	# After selection, clear the per-day tally and consumed unlock so the
	# next day's selection reflects only that day's events.
	_category_counts.clear()
	if not _pending_unlock_id.is_empty():
		_pending_unlock_id = ""
	if note.is_empty():
		return
	EventBus.manager_note_shown.emit(
		String(note.get("id", "")),
		String(note.get("body", "")),
		bool(note.get("allow_auto_dismiss", true)),
	)


func _on_day_closed(day: int, payload: Dictionary) -> void:
	var comment: Dictionary = select_end_of_day_comment(day, payload)
	if comment.is_empty():
		return
	EventBus.manager_end_of_day_comment.emit(
		String(comment.get("id", "")),
		String(comment.get("body", "")),
	)


func _on_task_completed(_task_id: StringName) -> void:
	_record_event(CATEGORY_OPERATIONAL)
	apply_trust_delta(DELTA_TASK_COMPLETED, REASON_TASK_COMPLETED)


func _on_staff_quit(_staff_id: String) -> void:
	_record_event(CATEGORY_STAFF)
	apply_trust_delta(DELTA_STAFF_QUIT, REASON_STAFF_QUIT)


func _on_staff_not_paid(_staff_id: String) -> void:
	_record_event(CATEGORY_STAFF)
	apply_trust_delta(DELTA_MISSING_PAYROLL, REASON_MISSING_PAYROLL)


func _on_unlock_granted(unlock_id: StringName) -> void:
	_pending_unlock_id = String(unlock_id)


func _record_event(category: StringName) -> void:
	_category_counts[category] = int(_category_counts.get(category, 0)) + 1


func _resolve_top_category() -> StringName:
	# Priority order is the deterministic tie-breaker. Returns operational on
	# silent days so the lookup never lands on a missing key.
	const PRIORITY: Array[StringName] = [
		CATEGORY_OPERATIONAL, CATEGORY_SALES, CATEGORY_STAFF
	]
	var best: StringName = CATEGORY_OPERATIONAL
	var best_count: int = -1
	for cat: StringName in PRIORITY:
		var count: int = int(_category_counts.get(cat, 0))
		if count > best_count:
			best = cat
			best_count = count
	if best_count <= 0:
		return CATEGORY_OPERATIONAL
	_last_top_category = best
	return best


func _recalculate_tier() -> void:
	var t: float = manager_trust
	if t < COLD_MAX:
		manager_tier = TIER_COLD
	elif t < NEUTRAL_MAX:
		manager_tier = TIER_NEUTRAL
	elif t < WARM_MAX:
		manager_tier = TIER_WARM
	else:
		manager_tier = TIER_TRUSTED


func _override_note(key: String, allow_auto_dismiss: bool) -> Dictionary:
	var overrides: Dictionary = _notes.get("date_overrides", {}) as Dictionary
	var entry: Variant = overrides.get(key, null)
	if entry is Dictionary:
		var dict: Dictionary = entry as Dictionary
		return {
			"id": str(dict.get("id", "note_override_%s" % key)),
			"body": str(dict.get("body", "")),
			"allow_auto_dismiss": allow_auto_dismiss,
		}
	return _fallback_note(allow_auto_dismiss)


func _unlock_override_note(unlock_id: String) -> Dictionary:
	var overrides: Dictionary = _notes.get("unlock_overrides", {}) as Dictionary
	var entry: Variant = overrides.get(unlock_id, null)
	if entry is Dictionary:
		var dict: Dictionary = entry as Dictionary
		return {
			"id": str(dict.get("id", "note_override_unlock_%s" % unlock_id)),
			"body": str(dict.get("body", "")),
			"allow_auto_dismiss": false,
		}
	return {}


func _tier_category_note(tier: StringName, category: StringName) -> Dictionary:
	var tier_notes: Dictionary = _notes.get("tier_notes", {}) as Dictionary
	var tier_block: Variant = tier_notes.get(String(tier), null)
	if tier_block is not Dictionary:
		return _fallback_note(true)
	var tier_dict: Dictionary = tier_block as Dictionary
	var candidates: Variant = tier_dict.get(String(category), null)
	if candidates is not Array or (candidates as Array).is_empty():
		# Operational fallback so the lookup never lands on a missing key.
		candidates = tier_dict.get(String(CATEGORY_OPERATIONAL), null)
	if candidates is not Array or (candidates as Array).is_empty():
		return _fallback_note(true)
	var arr: Array = candidates as Array
	var entry: Variant = arr[_rng.randi() % arr.size()]
	if entry is not Dictionary:
		return _fallback_note(true)
	var dict: Dictionary = entry as Dictionary
	return {
		"id": str(dict.get("id", "")),
		"body": str(dict.get("body", "")),
		"allow_auto_dismiss": true,
	}


func _end_of_day_comment(tier: StringName, condition: StringName) -> Dictionary:
	# §F-147 — Structural fallthroughs in this lookup mirror §F-116's reasoning
	# for `_load_notes`: every missing-block path silently disables Vic's
	# end-of-day commentary feature for the rest of the run. The `normal`
	# fallback further down already covers the legitimate case of an unknown
	# *condition* key, so reaching the structural-break paths means the
	# requested tier or both the condition and its `normal` fallback are
	# missing — content-authoring regressions that must surface as
	# `push_error`, not as a silently empty Dictionary. The whole-block
	# missing case (`eod_block is not Dictionary`) is downgraded to a warning
	# because production JSON always carries the block; it only fires from
	# legacy test fixtures that call `_set_notes_for_testing` with a partial
	# dict, and the documented contract for those is "must not crash"
	# (see test_no_emission_when_eod_block_missing).
	var eod_block: Variant = _notes.get("end_of_day_comments", null)
	if eod_block is not Dictionary:
		push_warning(
			(
				"ManagerRelationshipManager: `end_of_day_comments` block is "
				+ "missing or not a Dictionary in %s (got %s); end-of-day "
				+ "Vic commentary disabled."
			)
			% [NOTES_PATH, type_string(typeof(eod_block))]
		)
		return {}
	var eod: Dictionary = eod_block as Dictionary
	var tier_block: Variant = eod.get(String(tier), null)
	if tier_block is not Dictionary:
		push_error(
			(
				"ManagerRelationshipManager: `end_of_day_comments.%s` block is "
				+ "missing or not a Dictionary in %s (got %s)."
			)
			% [String(tier), NOTES_PATH, type_string(typeof(tier_block))]
		)
		return {}
	var tier_dict: Dictionary = tier_block as Dictionary
	var candidates: Variant = tier_dict.get(String(condition), null)
	if candidates is not Array or (candidates as Array).is_empty():
		# Fall back to `normal` so an unknown condition key still surfaces a
		# comment rather than silently dropping the panel slot. (Unknown
		# conditions are a legitimate runtime path — new conditions can be
		# added in code before content is updated.)
		candidates = tier_dict.get(String(EOD_CONDITION_NORMAL), null)
	if candidates is not Array or (candidates as Array).is_empty():
		# §F-147 — Both the requested condition AND the `normal` fallback are
		# missing / empty; the tier has no comments at all. Treat as
		# content-authoring break.
		push_error(
			(
				"ManagerRelationshipManager: tier `%s` has no candidates for "
				+ "condition `%s` and no `%s` fallback in %s; "
				+ "comment dropped."
			)
			% [
				String(tier), String(condition),
				String(EOD_CONDITION_NORMAL), NOTES_PATH,
			]
		)
		return {}
	var arr: Array = candidates as Array
	var entry: Variant = arr[_rng.randi() % arr.size()]
	if entry is not Dictionary:
		# §F-147 — Single malformed entry inside an otherwise-valid array.
		# Warn (not push_error) since the rest of the candidates may be
		# fine; the random pick will land on a valid entry on the next call.
		push_warning(
			(
				"ManagerRelationshipManager: malformed candidate at "
				+ "`end_of_day_comments.%s.%s` (%s); comment dropped."
			)
			% [
				String(tier), String(condition),
				type_string(typeof(entry)),
			]
		)
		return {}
	var dict: Dictionary = entry as Dictionary
	return {
		"id": str(dict.get("id", "")),
		"body": str(dict.get("body", "")),
	}


func _fallback_note(allow_auto_dismiss: bool) -> Dictionary:
	var entry: Variant = _notes.get("fallback", null)
	if entry is Dictionary:
		var dict: Dictionary = entry as Dictionary
		return {
			"id": str(dict.get("id", "note_fallback_default")),
			"body": str(dict.get("body", "")),
			"allow_auto_dismiss": allow_auto_dismiss,
		}
	return {
		"id": "note_fallback_default",
		"body": "",
		"allow_auto_dismiss": allow_auto_dismiss,
	}


func _load_notes() -> void:
	if _notes_loaded:
		return
	# §F-116 — every failure path here drops the entire morning-note feature
	# to the empty-string fallback. That regression must surface as a hard
	# error; push_warning was masquerading content-authoring breaks as silent
	# UX degradation.
	if not FileAccess.file_exists(NOTES_PATH):
		push_error(
			"ManagerRelationshipManager: notes file not found at %s" % NOTES_PATH
		)
		return
	var file: FileAccess = FileAccess.open(NOTES_PATH, FileAccess.READ)
	if file == null:
		push_error(
			"ManagerRelationshipManager: failed to open notes (%s) — err=%s"
			% [NOTES_PATH, error_string(FileAccess.get_open_error())]
		)
		return
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error(
			"ManagerRelationshipManager: parse error in %s — %s"
			% [NOTES_PATH, json.get_error_message()]
		)
		return
	if json.data is not Dictionary:
		push_error(
			"ManagerRelationshipManager: notes root must be a Dictionary (got %s)"
			% type_string(typeof(json.data))
		)
		return
	_notes = json.data as Dictionary
	_notes_loaded = true


# ── Test seam ────────────────────────────────────────────────────────────────

## Test seam — sets the in-memory note table directly so tests can run without
## the JSON file. Marks notes as loaded so _load_notes is a no-op afterward.
func _set_notes_for_testing(notes: Dictionary) -> void:
	_notes = notes
	_notes_loaded = true


## Test seam — records a category event for the next note selection.
func _record_event_for_testing(category: StringName) -> void:
	_record_event(category)


## Test seam — primes the pending unlock id for the next day_started.
func _set_pending_unlock_for_testing(unlock_id: String) -> void:
	_pending_unlock_id = unlock_id
