## MiddayEventSystem — owner of the midday decision-beat queue.
##
## At day_started, seeds a 2-beat queue from the eligible pool sourced from
## DataLoader.get_midday_events(). Subscribes to TimeSystem's hour_changed and
## fires queued beats at their assigned hours. While a beat is pending, time is
## paused via EventBus.time_speed_requested(SpeedTier.PAUSED). When the player
## resolves the beat (UI emits midday_event_resolved), the structured effects
## are applied and time resumes at SpeedTier.NORMAL.
##
## Eligibility filter (is_eligible):
##   min_day <= current_day <= max_day
##   AND (unlock_required is null OR unlock_required is in unlocked set)
##   AND (current_day - last_fired_day) > cooldown_days
##
## Pool exhaustion: when the eligible pool produces 0 beats, the day runs
## silently with no error or hang.
##
## Effects:
##   money              -> EconomySystem.add_cash / deduct_cash
##   reputation         -> ReputationSystemSingleton.add_reputation(active_store)
##   trust              -> EmploymentSystem.apply_trust_delta
##   inventory_flag     -> GameState.set_flag(<flag_name>)
##   hidden_thread_flag -> GameState.set_flag(&"hidden_thread:<flag_name>") and
##                         increment scapegoat_risk counter on GameState.flags.
##
## Special-case probability: on Days 18–22 inclusive, when PlatformSystem reports
## VecForce HD as supply_constrained, the launch_reservation_conflict beat is
## guaranteed inclusion in the day's queue (replacing the lowest-priority other
## beat if needed).
extends Node


const MIDDAY_WINDOW_START_HOUR: int = 11
const MIDDAY_WINDOW_END_HOUR: int = 14
const BEATS_PER_DAY: int = 2
const LAUNCH_BEAT_ID: StringName = &"launch_reservation_conflict"
const LAUNCH_PLATFORM_ID: StringName = &"vecforce_hd"
const LAUNCH_WINDOW_START_DAY: int = 18
const LAUNCH_WINDOW_END_DAY: int = 22
const SCAPEGOAT_RISK_KEY: StringName = &"scapegoat_risk"
const HIDDEN_THREAD_PREFIX: String = "hidden_thread:"


var _beat_pool: Array = []
var _day_queue: Array = []
var _pending_beat: Dictionary = {}
var _last_fired_days: Dictionary = {}
var _last_seeded_id: StringName = &""
var _previous_day_seeded_ids: Array[StringName] = []
var _current_day: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_connect_event_bus()
	_load_pool_if_available()


# ── Public API ───────────────────────────────────────────────────────────────


## Replaces the live beat pool. Used by GameWorld at Tier-3 init when
## DataLoader has finished loading content, and by tests that want to install
## a deterministic fixture pool.
func set_beat_pool(pool: Array) -> void:
	_beat_pool = pool.duplicate(true)


## Pure eligibility filter — exposed for unit tests. Returns true when the beat
## passes the day-range, unlock, and cooldown checks against the supplied state.
##
## - current_day: today's in-game day number.
## - unlocked_ids: set of UnlockSystem ids currently granted (Dictionary used
##   as a set for O(1) membership checks).
## - last_fired_days: per-beat-id Dictionary recording the last day each beat
##   was queued; missing entries are treated as "never fired".
static func is_eligible(
	beat: Dictionary,
	current_day: int,
	unlocked_ids: Dictionary,
	last_fired_days: Dictionary,
) -> bool:
	var min_day: int = int(beat.get("min_day", 1))
	var max_day: int = int(beat.get("max_day", 30))
	if current_day < min_day or current_day > max_day:
		return false
	var unlock_required: Variant = beat.get("unlock_required", null)
	if unlock_required != null and str(unlock_required) != "":
		if not unlocked_ids.has(StringName(str(unlock_required))):
			return false
	var beat_id: StringName = StringName(str(beat.get("id", "")))
	var cooldown_days: int = int(beat.get("cooldown_days", 2))
	if last_fired_days.has(beat_id):
		var last_day: int = int(last_fired_days[beat_id])
		if (current_day - last_day) <= cooldown_days:
			return false
	return true


## Returns a defensive copy of the day's seeded queue. Used by tests and HUD
## listeners that want to peek the schedule without mutating it.
func get_day_queue() -> Array:
	return _day_queue.duplicate(true)


## Returns the pending beat (the one currently waiting on player resolution).
## Empty Dictionary when no beat is pending.
func get_pending_beat() -> Dictionary:
	return _pending_beat.duplicate(true)


## Test seam — clears all in-flight state so deterministic tests can start
## from a clean slate without re-loading the autoload.
func reset_for_testing() -> void:
	_beat_pool.clear()
	_day_queue.clear()
	_pending_beat.clear()
	_last_fired_days.clear()
	_last_seeded_id = &""
	_previous_day_seeded_ids.clear()
	_current_day = 0


# ── Internals ────────────────────────────────────────────────────────────────


func _connect_event_bus() -> void:
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.hour_changed, _on_hour_changed)
	_connect_signal(EventBus.midday_event_resolved, _on_event_resolved)
	_connect_signal(EventBus.content_loaded, _on_content_loaded)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _load_pool_if_available() -> void:
	# DataLoader is an autoload that loads up at boot; in headless tests we may
	# come up before content is loaded — set_beat_pool() can refresh later.
	if GameManager == null or GameManager.data_loader == null:
		return
	var loader: DataLoader = GameManager.data_loader
	if loader.has_method("get_midday_events"):
		_beat_pool = (loader.get_midday_events() as Array).duplicate(true)


func _on_content_loaded() -> void:
	_load_pool_if_available()


func _on_day_started(day: int) -> void:
	_current_day = day
	_pending_beat.clear()
	_seed_day_queue(day)


func _seed_day_queue(day: int) -> void:
	# Track yesterday's queued ids so the dedup guard can prevent the same beat
	# id from appearing two days in a row.
	_previous_day_seeded_ids = _collect_queued_ids()
	_day_queue.clear()
	if _beat_pool.is_empty():
		return
	var unlocked: Dictionary = _collect_unlocked_ids()
	var eligible: Array = []
	for beat: Variant in _beat_pool:
		if beat is not Dictionary:
			continue
		if not is_eligible(beat as Dictionary, day, unlocked, _last_fired_days):
			continue
		eligible.append(beat)
	if eligible.is_empty():
		return
	# Apply the previous-day dedup guard: drop any beat whose id matches one
	# that fired (was queued) yesterday, but only if removing it still leaves
	# at least one eligible beat — otherwise the dedup guard would silently
	# create a 0-beat day when only the dedup'd beat is otherwise eligible.
	var deduped: Array = eligible.duplicate()
	if not _previous_day_seeded_ids.is_empty():
		var filtered: Array = []
		for beat: Variant in deduped:
			var beat_id: StringName = StringName(
				str((beat as Dictionary).get("id", ""))
			)
			if beat_id in _previous_day_seeded_ids:
				continue
			filtered.append(beat)
		if not filtered.is_empty():
			deduped = filtered
	deduped.shuffle()
	var queue: Array = deduped.slice(0, BEATS_PER_DAY)
	# Force-include the launch beat on Days 18–22 when VecForce HD is supply-
	# constrained — this is the spec'd "elevated probability" channel.
	if _should_force_launch_beat(day):
		var launch_beat: Dictionary = _find_pool_beat(LAUNCH_BEAT_ID)
		if (
			not launch_beat.is_empty()
			and is_eligible(launch_beat, day, unlocked, _last_fired_days)
		):
			queue = _ensure_beat_in_queue(queue, launch_beat)
	# Assign trigger hours from the midday window.
	var hours: Array[int] = _pick_trigger_hours(queue.size())
	for i: int in range(queue.size()):
		var entry: Dictionary = (queue[i] as Dictionary).duplicate(true)
		entry["_trigger_hour"] = hours[i]
		queue[i] = entry
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		if entry_id != &"":
			_last_fired_days[entry_id] = day
	_day_queue = queue


func _collect_queued_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for beat: Variant in _day_queue:
		if beat is not Dictionary:
			continue
		var id: StringName = StringName(str((beat as Dictionary).get("id", "")))
		if id != &"":
			ids.append(id)
	return ids


func _collect_unlocked_ids() -> Dictionary:
	var unlocked: Dictionary = {}
	var unlock_system: Node = get_node_or_null("/root/UnlockSystemSingleton")
	if unlock_system == null or not unlock_system.has_method("get_unlocked_ids"):
		return unlocked
	var ids: Variant = unlock_system.call("get_unlocked_ids")
	if ids is Array:
		for id_value: Variant in ids as Array:
			unlocked[StringName(str(id_value))] = true
	return unlocked


func _pick_trigger_hours(count: int) -> Array[int]:
	# Evenly spread within [MIDDAY_WINDOW_START_HOUR, MIDDAY_WINDOW_END_HOUR].
	# For BEATS_PER_DAY=2 in the 11–14 window the result is [11, 13].
	var hours: Array[int] = []
	if count <= 0:
		return hours
	var span: int = MIDDAY_WINDOW_END_HOUR - MIDDAY_WINDOW_START_HOUR
	if span <= 0 or count == 1:
		hours.append(MIDDAY_WINDOW_START_HOUR)
		return hours
	var step: int = maxi(1, span / count)
	for i: int in range(count):
		var hour: int = MIDDAY_WINDOW_START_HOUR + step * i
		if hour > MIDDAY_WINDOW_END_HOUR:
			hour = MIDDAY_WINDOW_END_HOUR
		hours.append(hour)
	return hours


func _should_force_launch_beat(day: int) -> bool:
	if day < LAUNCH_WINDOW_START_DAY or day > LAUNCH_WINDOW_END_DAY:
		return false
	var platform_system: Node = get_node_or_null("/root/PlatformSystem")
	if platform_system == null:
		return false
	if not platform_system.has_method("get_definition"):
		return false
	var definition: Variant = platform_system.call(
		"get_definition", LAUNCH_PLATFORM_ID
	)
	if definition == null:
		return false
	if not (definition as Object).get("supply_constrained"):
		return false
	return true


func _find_pool_beat(beat_id: StringName) -> Dictionary:
	for beat: Variant in _beat_pool:
		if beat is not Dictionary:
			continue
		if StringName(str((beat as Dictionary).get("id", ""))) == beat_id:
			return beat as Dictionary
	return {}


func _ensure_beat_in_queue(queue: Array, beat: Dictionary) -> Array:
	var beat_id: StringName = StringName(str(beat.get("id", "")))
	for entry: Variant in queue:
		if entry is not Dictionary:
			continue
		if StringName(str((entry as Dictionary).get("id", ""))) == beat_id:
			return queue
	var updated: Array = queue.duplicate()
	if updated.size() >= BEATS_PER_DAY:
		updated.pop_back()
	updated.append(beat)
	return updated


func _on_hour_changed(hour: int) -> void:
	if not _pending_beat.is_empty():
		return
	if _day_queue.is_empty():
		return
	for beat: Variant in _day_queue:
		if beat is not Dictionary:
			continue
		var beat_dict: Dictionary = beat as Dictionary
		if int(beat_dict.get("_trigger_hour", -1)) != hour:
			continue
		_day_queue.erase(beat)
		_pending_beat = beat_dict
		EventBus.midday_event_fired.emit(beat_dict.duplicate(true))
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.PAUSED)
		return


func _on_event_resolved(beat_id: StringName, choice_index: int) -> void:
	# Idempotency / out-of-order signal guards — empty pending beat means the
	# UI fired resolved twice or fired before any beat was queued; mismatched
	# id means a stale signal from an earlier (already-cleared) beat. Both
	# are legitimate run-time states, not error conditions.
	if _pending_beat.is_empty():
		return
	if StringName(str(_pending_beat.get("id", ""))) != beat_id:
		return
	_apply_choice_effects(_pending_beat, choice_index)
	_pending_beat.clear()
	EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.NORMAL)


func _apply_choice_effects(beat: Dictionary, choice_index: int) -> void:
	# §F-122 — every reject branch below indicates a content-authoring
	# regression in midday_events.json (a beat reached resolution but its
	# choices / effects payload is malformed). Surfacing as push_error means
	# the validate suite + playtest catch the bad row instead of dropping the
	# player's chosen effects on the floor.
	var beat_id: String = str(beat.get("id", "<unknown>"))
	var choices_raw: Variant = beat.get("choices", [])
	if choices_raw is not Array:
		push_error(
			"MiddayEventSystem: beat '%s' choices field is not an Array (got %s)"
			% [beat_id, type_string(typeof(choices_raw))]
		)
		return
	var choices: Array = choices_raw as Array
	if choices.is_empty():
		push_error(
			"MiddayEventSystem: beat '%s' has empty choices array" % beat_id
		)
		return
	var clamped: int = clampi(choice_index, 0, choices.size() - 1)
	var choice_entry: Variant = choices[clamped]
	if choice_entry is not Dictionary:
		push_error(
			"MiddayEventSystem: beat '%s' choice[%d] is not a Dictionary (got %s)"
			% [beat_id, clamped, type_string(typeof(choice_entry))]
		)
		return
	var effects_raw: Variant = (choice_entry as Dictionary).get("effects", {})
	if effects_raw is not Dictionary:
		push_error(
			"MiddayEventSystem: beat '%s' choice[%d] effects field is not a Dictionary (got %s)"
			% [beat_id, clamped, type_string(typeof(effects_raw))]
		)
		return
	_dispatch_effects(beat, effects_raw as Dictionary)


func _dispatch_effects(beat: Dictionary, effects: Dictionary) -> void:
	if effects.has("money"):
		_apply_money_effect(beat, float(effects["money"]))
	if effects.has("reputation"):
		_apply_reputation_effect(float(effects["reputation"]))
	if effects.has("trust"):
		_apply_trust_effect(beat, float(effects["trust"]))
	if effects.has("inventory_flag"):
		var inv_flag: String = str(effects["inventory_flag"])
		if not inv_flag.is_empty():
			GameState.set_flag(StringName(inv_flag), true)
	if effects.has("hidden_thread_flag"):
		var hidden_flag: String = str(effects["hidden_thread_flag"])
		if not hidden_flag.is_empty():
			GameState.set_flag(
				StringName(HIDDEN_THREAD_PREFIX + hidden_flag), true
			)
			_increment_scapegoat_risk()


func _apply_money_effect(beat: Dictionary, amount: float) -> void:
	if is_zero_approx(amount):
		return
	var economy: EconomySystem = GameManager.get_economy_system()
	var reason: String = "Midday: %s" % str(beat.get("id", "event"))
	if economy == null:
		# §F-123 — EconomySystem is initialized in GameWorld Tier-1; reaching
		# this branch from a midday-event resolution means a Tier ordering
		# regression. Push_warning was originally chosen for headless tests,
		# but the test suite seeds an EconomySystem before resolving any
		# beat, so this is now a hard wiring failure.
		push_error(
			"MiddayEventSystem: economy unresolved when applying money effect for '%s'"
			% str(beat.get("id", "<unknown>"))
		)
		return
	if amount > 0.0:
		economy.add_cash(amount, reason)
	else:
		economy.deduct_cash(absf(amount), reason)


func _apply_reputation_effect(delta: float) -> void:
	if is_zero_approx(delta):
		return
	var reputation: Node = get_node_or_null(
		"/root/ReputationSystemSingleton"
	)
	# §F-124 — ReputationSystemSingleton is an autoload; missing means
	# project.godot was edited or the node was removed at runtime. Either
	# is a configuration error, not a silent-drop scenario.
	if reputation == null:
		push_error(
			"MiddayEventSystem: ReputationSystemSingleton autoload missing — reputation effect dropped"
		)
		return
	if not reputation.has_method("add_reputation"):
		push_error(
			"MiddayEventSystem: ReputationSystemSingleton missing add_reputation — reputation effect dropped"
		)
		return
	var store_id: String = String(GameState.active_store_id)
	reputation.call("add_reputation", store_id, delta)


func _apply_trust_effect(beat: Dictionary, delta: float) -> void:
	if is_zero_approx(delta):
		return
	var employment: Node = get_node_or_null("/root/EmploymentSystem")
	var reason: String = "midday:%s" % str(beat.get("id", "event"))
	# §F-124 — EmploymentSystem is an autoload (project.godot:54); same
	# rationale as the reputation branch above. Silent drop hides a real
	# config / boot regression.
	if employment == null:
		push_error(
			"MiddayEventSystem: EmploymentSystem autoload missing — trust effect dropped (%s)"
			% reason
		)
		return
	if not employment.has_method("apply_trust_delta"):
		push_error(
			"MiddayEventSystem: EmploymentSystem missing apply_trust_delta — trust effect dropped (%s)"
			% reason
		)
		return
	employment.call("apply_trust_delta", delta, reason)


func _increment_scapegoat_risk() -> void:
	var current: int = int(GameState.flags.get(SCAPEGOAT_RISK_KEY, 0))
	GameState.flags[SCAPEGOAT_RISK_KEY] = current + 1
