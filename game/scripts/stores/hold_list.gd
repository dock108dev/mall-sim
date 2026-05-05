## Store-local hold/reservation list. Owned by a per-store controller (e.g.
## RetroGames); not an autoload, because holds are scoped to a single store.
##
## The HoldList holds the in-memory Array[HoldSlip], allocates HOLD-####
## identifiers, runs duplicate detection at intake, expires stale slips on day
## rollover, and resolves Fulfillment Conflicts. It emits its own local
## signals; the store controller forwards the cross-system events
## (hold_added, hold_fulfilled, hold_expired, hold_duplicate_detected,
## hold_shady_request_received, hold_conflict_bypassed) onto EventBus so other
## systems (HiddenThreadSystem, terminal UI, narrative thread tracking) can
## listen without reaching into store internals.
##
## Conflict resolution choices match the issue spec:
##   - resolve_conflict_honor_earliest: fulfill the slip closest to expiry
##   - resolve_conflict_escalate: manager handles deterministically (earliest
##     expiry); same fulfillment as honor but a different trust outcome at
##     the controller level
##   - resolve_conflict_walk_in: bypass all holds; competing slips → DISPUTED;
##     emits hold_conflict_bypassed (HiddenThreadSystem Tier 2 trigger)
class_name HoldList
extends Resource


const DEFAULT_HOLD_DURATION_DAYS: int = 3
const _ID_PREFIX: String = "HOLD-"
# §F-126 — save-load clamps. _next_id allocates "HOLD-####" identifiers via
# `"%04d" % _next_id`; a hand-edited save with `next_id` set to a near-INT_MAX
# value would overflow the 64-bit int on the next allocation (Godot ints are
# 64-bit signed) and emit negative IDs. _MAX_HOLD_ID_VALUE caps it at 1M which
# is far above any real campaign and still well below the overflow threshold.
# _MIN_HOLD_DURATION_DAYS guards `expiry_day = current_day + max(...,1)` from
# zero/negative durations that would produce immediately-expired holds at load.
const _MIN_NEXT_ID: int = 1
const _MAX_NEXT_ID: int = 1_000_000
const _MIN_HOLD_DURATION_DAYS: int = 1
const _MAX_HOLD_DURATION_DAYS: int = 365

## Conflict resolution outcomes returned by the resolve_* methods. Treat as a
## frozen contract for callers that mirror the result onto trust deltas and
## EventBus signals.
enum ConflictChoice {
	HONOR_EARLIEST = 0,
	ESCALATE_TO_MANAGER = 1,
	GIVE_TO_WALK_IN = 2,
}

signal hold_added(slip: HoldSlip)
signal hold_fulfilled(slip: HoldSlip, reason: String)
signal hold_expired(slip: HoldSlip)
signal duplicate_detected(
	new_slip: HoldSlip, existing_slip: HoldSlip, conflict_field: StringName
)
signal shady_request_received(slip: HoldSlip)
signal hold_conflict_bypassed(item_id: StringName, disputed_slips: Array)


@export var hold_duration_days: int = DEFAULT_HOLD_DURATION_DAYS

var _slips: Array[HoldSlip] = []
var _next_id: int = 1


## Adds a new hold slip. customer_name and serial together drive duplicate
## detection. item_id and item_label describe the SKU the slip points to.
## tier is HoldSlip.RequestorTier; current_day stamps creation_day and
## drives expiry_day = current_day + hold_duration_days. thread_id may be
## empty; populated only when the slip belongs to a known narrative thread.
##
## Returns the newly-created HoldSlip (never null). When a duplicate is
## detected, the new slip is recorded with status=FLAGGED and the existing
## conflicting slip is also promoted to FLAGGED so the terminal renders both
## sides of the diff. The duplicate_detected signal carries both slip refs.
func add_hold(
	customer_name: String,
	serial: String,
	item_id: StringName,
	item_label: String,
	tier: int,
	current_day: int,
	thread_id: String = "",
) -> HoldSlip:
	var slip := HoldSlip.new()
	slip.id = _allocate_id()
	slip.customer_name = customer_name
	slip.serial = serial
	slip.item_id = item_id
	slip.item_label = item_label
	slip.creation_day = current_day
	slip.expiry_day = current_day + max(hold_duration_days, 1)
	slip.requestor_tier = tier
	slip.thread_id = thread_id
	var conflict: Dictionary = _find_conflict(slip)
	if conflict.is_empty():
		slip.status = HoldSlip.Status.ACTIVE
	else:
		slip.status = HoldSlip.Status.FLAGGED
		var existing: HoldSlip = conflict["existing"]
		# Flag both sides so the diff view is symmetric — neither slip is
		# "trusted" in the duplicate case; the player must adjudicate.
		if existing.status == HoldSlip.Status.ACTIVE:
			existing.status = HoldSlip.Status.FLAGGED
	_slips.append(slip)
	hold_added.emit(slip)
	if not conflict.is_empty():
		duplicate_detected.emit(
			slip, conflict["existing"], conflict["field"]
		)
	if (
		tier == HoldSlip.RequestorTier.SHADY
		or tier == HoldSlip.RequestorTier.ANONYMOUS
	):
		shady_request_received.emit(slip)
	return slip


## Returns the active slip whose serial matches, or null. Used for terminal
## fulfillment lookups and external callers.
func find_active_slip_for_serial(serial: String) -> HoldSlip:
	for slip: HoldSlip in _slips:
		if slip.is_active() and slip.serial == serial:
			return slip
	return null


## Returns the slip with the given HOLD-#### id, or null.
func find_slip_by_id(slip_id: String) -> HoldSlip:
	for slip: HoldSlip in _slips:
		if slip.id == slip_id:
			return slip
	return null


## Returns every slip currently in the list (defensive copy).
func get_all_slips() -> Array[HoldSlip]:
	var result: Array[HoldSlip] = []
	for slip: HoldSlip in _slips:
		result.append(slip)
	return result


## Returns slips with the given status (ACTIVE by default). Defensive copy.
func get_slips_by_status(status: int = HoldSlip.Status.ACTIVE) -> Array[HoldSlip]:
	var result: Array[HoldSlip] = []
	for slip: HoldSlip in _slips:
		if slip.status == status:
			result.append(slip)
	return result


## Returns the active or flagged holds for a given item_id. Used by conflict
## detection (`pending_holds_for(item_id).size() > units_in_stock`). Slips in
## terminal states (FULFILLED / EXPIRED / DISPUTED) are excluded so they no
## longer count toward conflict detection.
func pending_holds_for(item_id: StringName) -> Array[HoldSlip]:
	var result: Array[HoldSlip] = []
	for slip: HoldSlip in _slips:
		if slip.item_id != item_id:
			continue
		if slip.is_terminal_status():
			continue
		result.append(slip)
	return result


## Returns true when the number of pending holds for `item_id` exceeds the
## available stock count. Mirrors the issue spec's
## `pending_holds_for(item_id).size() > units_in_stock(item_id)` rule.
func has_conflict(item_id: StringName, units_in_stock: int) -> bool:
	return pending_holds_for(item_id).size() > maxi(units_in_stock, 0)


## Marks a slip FULFILLED. Returns true when the slip exists and was active /
## flagged (i.e. not already in a terminal state).
func fulfill(slip_id: String, reason: String = "manual") -> bool:
	var slip: HoldSlip = find_slip_by_id(slip_id)
	if slip == null:
		return false
	if slip.is_terminal_status():
		return false
	slip.status = HoldSlip.Status.FULFILLED
	hold_fulfilled.emit(slip, reason)
	return true


## Marks a slip FLAGGED (manual flag at the terminal). Returns false when the
## slip is already flagged or in a terminal state.
func flag(slip_id: String) -> bool:
	var slip: HoldSlip = find_slip_by_id(slip_id)
	if slip == null:
		return false
	if slip.is_terminal_status():
		return false
	if slip.status == HoldSlip.Status.FLAGGED:
		return false
	slip.status = HoldSlip.Status.FLAGGED
	return true


## Marks a slip EXPIRED (manual expire at the terminal — NPC no-show). Emits
## hold_expired so visualization can crumple the prop.
func expire(slip_id: String) -> bool:
	var slip: HoldSlip = find_slip_by_id(slip_id)
	if slip == null:
		return false
	if slip.is_terminal_status():
		return false
	slip.status = HoldSlip.Status.EXPIRED
	hold_expired.emit(slip)
	return true


## Walks every slip past its expiry_day and transitions to EXPIRED. Returns
## the array of newly-expired slips so callers can re-spawn them in the
## crumpled visual state.
func expire_stale(current_day: int) -> Array[HoldSlip]:
	var newly_expired: Array[HoldSlip] = []
	for slip: HoldSlip in _slips:
		if slip.is_terminal_status():
			continue
		if current_day < slip.expiry_day:
			continue
		slip.status = HoldSlip.Status.EXPIRED
		newly_expired.append(slip)
		hold_expired.emit(slip)
	return newly_expired


## Returns the pending holds for `item_id` ordered earliest-expiry first.
## Stable sort: ties resolve by creation_day, then HOLD-#### id, so two slips
## with the same expiry_day still produce a deterministic resolution order.
func get_conflict_holds(item_id: StringName) -> Array[HoldSlip]:
	var holds: Array[HoldSlip] = pending_holds_for(item_id)
	holds.sort_custom(_compare_by_expiry)
	return holds


## Resolves a Fulfillment Conflict for the given item_id. choice is a
## ConflictChoice enum value. Returns a Dictionary describing the outcome:
##   {
##     "choice": ConflictChoice,
##     "fulfilled_slip_id": String,         # "" when no slip was fulfilled
##     "remaining_slip_ids": Array[String], # slips that are still ACTIVE
##     "disputed_slip_ids": Array[String],  # slips moved to DISPUTED (walk-in)
##   }
##
## HONOR_EARLIEST and ESCALATE_TO_MANAGER both fulfill the earliest-expiry
## slip; competing slips remain ACTIVE so they can clear at their natural
## expiry. GIVE_TO_WALK_IN transitions every competing slip to DISPUTED and
## emits hold_conflict_bypassed.
func resolve_conflict(
	item_id: StringName, choice: int
) -> Dictionary:
	var conflicts: Array[HoldSlip] = get_conflict_holds(item_id)
	var fulfilled_id: String = ""
	var remaining_ids: Array[String] = []
	var disputed_ids: Array[String] = []

	if choice == ConflictChoice.HONOR_EARLIEST:
		if not conflicts.is_empty():
			var winner: HoldSlip = conflicts[0]
			winner.status = HoldSlip.Status.FULFILLED
			fulfilled_id = winner.id
			hold_fulfilled.emit(winner, "earliest_expiry")
		for i: int in range(1, conflicts.size()):
			remaining_ids.append(conflicts[i].id)
	elif choice == ConflictChoice.ESCALATE_TO_MANAGER:
		if not conflicts.is_empty():
			var winner_e: HoldSlip = conflicts[0]
			winner_e.status = HoldSlip.Status.FULFILLED
			fulfilled_id = winner_e.id
			hold_fulfilled.emit(winner_e, "manager_escalation")
		for i: int in range(1, conflicts.size()):
			remaining_ids.append(conflicts[i].id)
	elif choice == ConflictChoice.GIVE_TO_WALK_IN:
		for slip: HoldSlip in conflicts:
			slip.status = HoldSlip.Status.DISPUTED
			disputed_ids.append(slip.id)
		if not disputed_ids.is_empty():
			hold_conflict_bypassed.emit(item_id, disputed_ids)
	else:
		push_warning(
			"HoldList.resolve_conflict: unknown choice %d" % choice
		)

	return {
		"choice": choice,
		"fulfilled_slip_id": fulfilled_id,
		"remaining_slip_ids": remaining_ids,
		"disputed_slip_ids": disputed_ids,
	}


## Serializes the entire list (slips + id allocator) for save/load. Returned
## dict is plain JSON-friendly: slips are converted via HoldSlip.to_dict.
func get_save_data() -> Dictionary:
	var slip_dicts: Array = []
	for slip: HoldSlip in _slips:
		slip_dicts.append(slip.to_dict())
	return {
		"slips": slip_dicts,
		"next_id": _next_id,
		"hold_duration_days": hold_duration_days,
	}


## Restores list state from `get_save_data` output. Idempotent — safe to call
## multiple times; later calls overwrite earlier state.
##
## §F-126 — `next_id` and `hold_duration_days` come from user:// save data and
## are clamped here before they reach `_allocate_id` / `expire_stale`. Without
## the clamp a hand-edited save could (a) overflow the 64-bit int on the next
## allocation by setting `next_id` near INT_MAX, or (b) emit immediately-
## expired or never-expiring holds via a zero/negative/huge `hold_duration_days`.
func load_save_data(data: Dictionary) -> void:
	_slips = []
	var raw_slips: Variant = data.get("slips", [])
	if raw_slips is Array:
		var skipped_entries: int = 0
		for entry: Variant in raw_slips:
			if entry is Dictionary:
				_slips.append(HoldSlip.from_dict(entry as Dictionary))
			else:
				skipped_entries += 1
		if skipped_entries > 0:
			# §F-132 — malformed slip entries dropped from a corrupted /
			# hand-edited user:// save. The save round-trips through to_dict /
			# from_dict, so anything-but-Dictionary in the slips array means
			# the save was tampered with or written by an older / mismatched
			# schema. A silent drop loses outstanding holds (and any pending
			# customer commitments tied to them) without any signal to the
			# player or the operator. Mirrors the §F-126 clamp pattern for
			# next_id / hold_duration_days that already lives in this method.
			push_warning((
				"HoldList.load_save_data: dropped %d non-Dictionary slip "
				+ "entries from save data; save may be corrupted or written "
				+ "by an incompatible schema"
			) % skipped_entries)
	elif data.has("slips"):
		push_warning((
			"HoldList.load_save_data: 'slips' field present but not an Array "
			+ "(got %s); treating as empty"
		) % type_string(typeof(raw_slips)))
	_next_id = clampi(
		int(data.get("next_id", _slips.size() + 1)),
		_MIN_NEXT_ID, _MAX_NEXT_ID
	)
	if data.has("hold_duration_days"):
		hold_duration_days = clampi(
			int(data["hold_duration_days"]),
			_MIN_HOLD_DURATION_DAYS, _MAX_HOLD_DURATION_DAYS
		)


## Test seam — clears all in-memory state. Used by GUT tests that want a
## clean list per test without re-instantiating the resource.
func clear_for_testing() -> void:
	_slips = []
	_next_id = 1


# ── Internals ────────────────────────────────────────────────────────────────

func _allocate_id() -> String:
	var id := _ID_PREFIX + "%04d" % _next_id
	_next_id += 1
	return id


func _find_conflict(new_slip: HoldSlip) -> Dictionary:
	# Same-serial / different-name: classic re-reservation attempt — the
	# physical unit is already promised to someone else.
	# Same-name / different-serial / same-day: a single customer placing two
	# holds in one day on a system that defaults to one hold per name. A
	# legitimate next-day return visit (different creation_day) is not a
	# conflict.
	for existing: HoldSlip in _slips:
		if existing.is_terminal_status():
			continue
		if existing.serial == new_slip.serial:
			if existing.customer_name != new_slip.customer_name:
				return {
					"existing": existing,
					"field": &"serial",
				}
		if (
			existing.customer_name == new_slip.customer_name
			and existing.serial != new_slip.serial
			and existing.creation_day == new_slip.creation_day
		):
			return {
				"existing": existing,
				"field": &"customer_name",
			}
	return {}


func _compare_by_expiry(a: HoldSlip, b: HoldSlip) -> bool:
	if a.expiry_day != b.expiry_day:
		return a.expiry_day < b.expiry_day
	if a.creation_day != b.creation_day:
		return a.creation_day < b.creation_day
	return a.id < b.id
