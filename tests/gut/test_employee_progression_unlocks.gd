# gdlint:disable=max-public-methods
## Tests for the employee skill-progression unlock chain.
##
## Covers: the six employee unlock IDs are registered and gateable through
## UnlockSystem; the six milestone definitions in milestone_definitions.json
## carry the expected day / trust / threshold gates; the
## MilestoneSystem honors min_day and min_manager_trust_tier_index; the
## ProgressionSystem signal-chain bridge into milestone_unlocked grants the
## unlock; the manager_notes.json unlock_overrides exist for the four
## post-Day-1 employee skills; and the LockedFeatureGate helper emits the
## 2-second auto-dismissing label and never grants access for an ungranted
## unlock.
extends GutTest


const _EMPLOYEE_UNLOCK_IDS: Array[StringName] = [
	&"employee_register_access",
	&"employee_stocking_trained",
	&"employee_tradein_certified",
	&"employee_holdlist_access",
	&"employee_display_authority",
	&"employee_closing_certified",
]

const _UNLOCK_OVERRIDE_IDS: Array[String] = [
	"employee_tradein_certified",
	"employee_holdlist_access",
	"employee_display_authority",
	"employee_closing_certified",
]

const _MILESTONE_FILE: String = (
	"res://game/content/progression/milestone_definitions.json"
)
const _UNLOCKS_FILE: String = "res://game/content/unlocks/unlocks.json"
const _MANAGER_NOTES_FILE: String = (
	"res://game/content/manager/manager_notes.json"
)


# ── Unlock catalog (unlocks.json) ────────────────────────────────────────────

func test_six_employee_unlocks_present_in_unlock_catalog() -> void:
	var data: Dictionary = _load_json(_UNLOCKS_FILE)
	var present: Dictionary = {}
	for entry: Variant in data.get("entries", []):
		if entry is Dictionary:
			present[str((entry as Dictionary).get("id", ""))] = true
	for unlock_id: StringName in _EMPLOYEE_UNLOCK_IDS:
		assert_true(
			present.has(String(unlock_id)),
			"unlocks.json must define employee unlock '%s'" % unlock_id
		)


func test_employee_unlocks_use_employee_skill_effect_type() -> void:
	var data: Dictionary = _load_json(_UNLOCKS_FILE)
	for entry: Variant in data.get("entries", []):
		if entry is not Dictionary:
			continue
		var dict: Dictionary = entry as Dictionary
		var id: String = str(dict.get("id", ""))
		if not id.begins_with("employee_"):
			continue
		assert_eq(
			str(dict.get("effect_type", "")),
			"employee_skill",
			"employee unlock '%s' must use the employee_skill effect type" % id
		)


# ── Milestone catalog (milestone_definitions.json) ───────────────────────────

func test_six_employee_milestones_present_in_definitions() -> void:
	var ids: Array[String] = _milestone_ids_for_employee_unlocks()
	assert_eq(
		ids.size(),
		6,
		"milestone_definitions.json must include six unlock milestones bound "
		+ "to the employee_* unlock ids (got %d)" % ids.size()
	)


func test_register_milestone_targets_clock_in_counter() -> void:
	var milestone: Dictionary = _milestone_with_unlock("employee_register_access")
	assert_eq(
		str(milestone.get("trigger_stat_key", "")),
		"clock_in_completed_count",
		"register-access milestone must trigger on clock_in_completed_count"
	)
	assert_eq(
		float(milestone.get("trigger_threshold", 0.0)),
		1.0,
		"register-access milestone must fire on the first clock-in"
	)


func test_stocking_milestone_targets_first_restock_counter() -> void:
	var milestone: Dictionary = _milestone_with_unlock(
		"employee_stocking_trained"
	)
	assert_eq(
		str(milestone.get("trigger_stat_key", "")),
		"first_restock_completed_count",
		"stocking milestone must trigger on first_restock_completed_count"
	)


func test_tradein_milestone_has_day_and_trust_gates() -> void:
	var milestone: Dictionary = _milestone_with_unlock(
		"employee_tradein_certified"
	)
	assert_eq(
		int(milestone.get("min_day", 0)),
		8,
		"trade-in milestone must wait until day 8"
	)
	assert_eq(
		int(milestone.get("min_manager_trust_tier_index", 0)),
		2,
		"trade-in milestone must wait until manager trust >= warm (tier 2)"
	)
	assert_eq(
		float(milestone.get("trigger_threshold", 0.0)),
		5.0,
		"trade-in milestone must require five customer purchases"
	)


func test_holdlist_milestone_has_day_15_and_15_transactions() -> void:
	var milestone: Dictionary = _milestone_with_unlock(
		"employee_holdlist_access"
	)
	assert_eq(int(milestone.get("min_day", 0)), 15)
	assert_eq(float(milestone.get("trigger_threshold", 0.0)), 15.0)


func test_display_authority_milestone_requires_trusted_tier_at_day_20() -> void:
	var milestone: Dictionary = _milestone_with_unlock(
		"employee_display_authority"
	)
	assert_eq(int(milestone.get("min_day", 0)), 20)
	assert_eq(
		str(milestone.get("trigger_stat_key", "")),
		"manager_trust_tier_index",
	)
	assert_eq(float(milestone.get("trigger_threshold", 0.0)), 3.0)


func test_closing_milestone_requires_day_22_and_25_transactions() -> void:
	var milestone: Dictionary = _milestone_with_unlock(
		"employee_closing_certified"
	)
	assert_eq(int(milestone.get("min_day", 0)), 22)
	assert_eq(float(milestone.get("trigger_threshold", 0.0)), 25.0)


# ── Manager notes (manager_notes.json) ───────────────────────────────────────

func test_manager_unlock_overrides_present_for_post_day1_unlocks() -> void:
	var data: Dictionary = _load_json(_MANAGER_NOTES_FILE)
	var overrides: Dictionary = data.get("unlock_overrides", {})
	for unlock_id: String in _UNLOCK_OVERRIDE_IDS:
		assert_true(
			overrides.has(unlock_id),
			"manager_notes.json must define unlock_overrides['%s']" % unlock_id
		)
		var entry: Variant = overrides.get(unlock_id, null)
		assert_true(
			entry is Dictionary,
			"unlock override '%s' must be a Dictionary" % unlock_id
		)
		var dict: Dictionary = entry as Dictionary
		assert_false(
			str(dict.get("body", "")).is_empty(),
			"unlock override '%s' must have a non-empty body" % unlock_id
		)


func test_tradein_unlock_override_body_references_trade_in() -> void:
	var data: Dictionary = _load_json(_MANAGER_NOTES_FILE)
	var entry: Dictionary = (
		(data.get("unlock_overrides", {}) as Dictionary)
			.get("employee_tradein_certified", {}) as Dictionary
	)
	var body: String = str(entry.get("body", "")).to_lower()
	assert_true(
		body.contains("trade-in") or body.contains("trade in"),
		"trade-in override body must reference trade-in"
	)


func test_holdlist_unlock_override_body_references_hold_list() -> void:
	var data: Dictionary = _load_json(_MANAGER_NOTES_FILE)
	var entry: Dictionary = (
		(data.get("unlock_overrides", {}) as Dictionary)
			.get("employee_holdlist_access", {}) as Dictionary
	)
	assert_true(
		str(entry.get("body", "")).to_lower().contains("hold list"),
		"hold-list override body must reference 'hold list'"
	)


func test_display_unlock_override_body_references_featured_display() -> void:
	var data: Dictionary = _load_json(_MANAGER_NOTES_FILE)
	var entry: Dictionary = (
		(data.get("unlock_overrides", {}) as Dictionary)
			.get("employee_display_authority", {}) as Dictionary
	)
	assert_true(
		str(entry.get("body", "")).to_lower().contains("display"),
		"display authority override body must reference the featured display"
	)


func test_closing_unlock_override_body_references_close() -> void:
	var data: Dictionary = _load_json(_MANAGER_NOTES_FILE)
	var entry: Dictionary = (
		(data.get("unlock_overrides", {}) as Dictionary)
			.get("employee_closing_certified", {}) as Dictionary
	)
	var body: String = str(entry.get("body", "")).to_lower()
	assert_true(
		body.contains("close") or body.contains("checklist"),
		"closing override body must reference close / checklist"
	)


# ── ProgressionSystem signal-chain bridge ────────────────────────────────────

func test_progression_system_emits_milestone_unlocked_when_milestone_completes() -> void:
	# The signal-chain fix: ProgressionSystem must emit milestone_unlocked so
	# UnlockSystem (listening for that signal, not milestone_completed) actually
	# grants the unlock.
	var ctx: Dictionary = _build_progression_context()
	watch_signals(EventBus)
	ctx["progression"].increment_progress("test_unlock_milestone", 1.0)
	assert_signal_emit_count(
		EventBus,
		"milestone_unlocked",
		1,
		"ProgressionSystem must emit milestone_unlocked when its own milestone "
		+ "completes"
	)
	var params: Array = get_signal_parameters(
		EventBus, "milestone_unlocked", 0
	)
	assert_eq(
		params[0] as StringName,
		StringName("test_unlock_milestone"),
		"milestone_unlocked must carry the milestone id"
	)
	var reward: Dictionary = params[1] as Dictionary
	assert_eq(
		str(reward.get("reward_type", "")),
		"unlock",
		"milestone_unlocked reward payload must expose reward_type"
	)


func test_progression_system_milestone_unlock_grants_unlock_through_unlock_system() -> void:
	var ctx: Dictionary = _build_progression_context()
	UnlockSystemSingleton._valid_ids = {&"test_employee_unlock_id": true}
	UnlockSystemSingleton._granted = {}
	watch_signals(EventBus)
	ctx["progression"].increment_progress("test_unlock_milestone", 1.0)
	assert_true(
		UnlockSystemSingleton.is_unlocked(&"test_employee_unlock_id"),
		"the milestone_unlocked emit must reach UnlockSystem and grant the id"
	)


# ── MilestoneSystem gate honoring (min_day / min_manager_trust_tier_index) ───

func test_milestone_system_blocks_unlock_until_min_day_reached() -> void:
	var ctx: Dictionary = _build_milestone_system_context()
	var ms: MilestoneSystem = ctx["milestone_system"]
	var data_loader: DataLoader = ctx["data_loader"]
	var gated: MilestoneDefinition = MilestoneDefinition.new()
	gated.id = "gated_holdlist"
	gated.display_name = "Hold list gated"
	gated.trigger_stat_key = "customer_purchased_count"
	gated.trigger_threshold = 2.0
	gated.reward_type = "unlock"
	gated.unlock_id = "gated_unlock"
	gated.min_day = 15
	data_loader._milestones[gated.id] = gated
	ms._milestones = [gated]
	UnlockSystemSingleton._valid_ids = {&"gated_unlock": true}
	UnlockSystemSingleton._granted = {}

	# Reach the trigger threshold on day 1 — gate must suppress.
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"customer_a"
	)
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"customer_b"
	)
	assert_false(
		ms.is_complete(&"gated_holdlist"),
		"gated milestone must not fire before min_day"
	)

	# Advance to day 15 — gate clears, milestone fires.
	EventBus.day_ended.emit(15)
	assert_true(
		ms.is_complete(&"gated_holdlist"),
		"gated milestone must fire once current_day reaches min_day"
	)
	assert_true(
		UnlockSystemSingleton.is_unlocked(&"gated_unlock"),
		"unlock must be granted once the day gate clears"
	)


func test_milestone_system_blocks_unlock_until_manager_trust_tier_reached() -> void:
	var ctx: Dictionary = _build_milestone_system_context()
	var ms: MilestoneSystem = ctx["milestone_system"]
	var data_loader: DataLoader = ctx["data_loader"]
	var gated: MilestoneDefinition = MilestoneDefinition.new()
	gated.id = "gated_tradein"
	gated.display_name = "Trade-in gated"
	gated.trigger_stat_key = "customer_purchased_count"
	gated.trigger_threshold = 1.0
	gated.reward_type = "unlock"
	gated.unlock_id = "gated_tradein_unlock"
	gated.min_day = 8
	gated.min_manager_trust_tier_index = 2  # warm
	data_loader._milestones[gated.id] = gated
	ms._milestones = [gated]
	UnlockSystemSingleton._valid_ids = {&"gated_tradein_unlock": true}
	UnlockSystemSingleton._granted = {}

	# Move to day 8 with neutral trust — still blocked by the trust gate.
	ManagerRelationshipManager.reset_for_testing()
	ManagerRelationshipManager.apply_trust_delta(-0.01, "to_neutral")
	EventBus.day_started.emit(8)
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"customer_a"
	)
	assert_false(
		ms.is_complete(&"gated_tradein"),
		"trust gate must suppress the unlock at neutral tier"
	)

	# Push trust to warm — gate clears, milestone fires on the next event.
	ManagerRelationshipManager.apply_trust_delta(0.10, "to_warm")
	assert_true(
		ms.is_complete(&"gated_tradein"),
		"trust gate must clear once trust reaches warm"
	)
	assert_true(
		UnlockSystemSingleton.is_unlocked(&"gated_tradein_unlock"),
		"unlock must be granted once both gates clear"
	)


# ── New stat counters ────────────────────────────────────────────────────────

func test_milestone_system_increments_clock_in_counter_on_shift_started() -> void:
	var ctx: Dictionary = _build_milestone_system_context()
	var ms: MilestoneSystem = ctx["milestone_system"]
	EventBus.shift_started.emit(&"test_store", 540.0, false)
	assert_eq(
		int(ms._counters["clock_in_completed_count"]),
		1,
		"shift_started must bump clock_in_completed_count"
	)


func test_milestone_system_first_restock_counter_caps_at_one() -> void:
	var ctx: Dictionary = _build_milestone_system_context()
	var ms: MilestoneSystem = ctx["milestone_system"]
	EventBus.item_stocked.emit("item_001", "shelf_a")
	EventBus.item_stocked.emit("item_002", "shelf_b")
	EventBus.item_stocked.emit("item_003", "shelf_c")
	assert_eq(
		int(ms._counters["first_restock_completed_count"]),
		1,
		"first_restock_completed_count must cap at 1"
	)


# ── LockedFeatureGate UX ─────────────────────────────────────────────────────

func test_locked_feature_gate_emits_two_second_label_when_locked() -> void:
	UnlockSystemSingleton._granted = {}
	watch_signals(EventBus)
	var allowed: bool = LockedFeatureGate.try_access(
		&"never_unlocked_id", "Trade-in"
	)
	assert_false(allowed, "try_access must refuse when unlock is missing")
	assert_signal_emit_count(EventBus, "toast_requested", 1)
	var params: Array = get_signal_parameters(EventBus, "toast_requested", 0)
	assert_eq(
		str(params[0]),
		LockedFeatureGate.LABEL_FORMAT % "Trade-in",
		"locked label must use the canonical format"
	)
	assert_eq(
		params[1] as StringName,
		LockedFeatureGate.TOAST_CATEGORY,
		"locked label must use the locked_feature toast category"
	)
	assert_almost_eq(
		float(params[2]),
		LockedFeatureGate.LABEL_DURATION_SECONDS,
		0.01,
		"locked label must request the documented 2-second auto-dismiss"
	)


func test_locked_feature_gate_repeated_attempts_emit_repeated_labels() -> void:
	UnlockSystemSingleton._granted = {}
	watch_signals(EventBus)
	for _i: int in range(3):
		var ok: bool = LockedFeatureGate.try_access(
			&"never_unlocked_id", "Hold List"
		)
		assert_false(ok)
	assert_signal_emit_count(
		EventBus,
		"toast_requested",
		3,
		"repeated locked-feature attempts must emit a label every time"
	)


func test_locked_feature_gate_grants_access_when_unlock_is_present() -> void:
	UnlockSystemSingleton._valid_ids = {&"locked_feature_test_unlock": true}
	UnlockSystemSingleton._granted = {&"locked_feature_test_unlock": true}
	watch_signals(EventBus)
	var allowed: bool = LockedFeatureGate.try_access(
		&"locked_feature_test_unlock", "Closing Checklist"
	)
	assert_true(allowed, "try_access must allow when unlock is granted")
	assert_signal_not_emitted(
		EventBus,
		"toast_requested",
		"granted features must not emit the locked-label toast"
	)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _milestone_ids_for_employee_unlocks() -> Array[String]:
	var data: Dictionary = _load_json(_MILESTONE_FILE)
	var employee_unlock_strings: Dictionary = {}
	for unlock_id: StringName in _EMPLOYEE_UNLOCK_IDS:
		employee_unlock_strings[String(unlock_id)] = true
	var ids: Array[String] = []
	for entry: Variant in data.get("entries", []):
		if entry is not Dictionary:
			continue
		var dict: Dictionary = entry as Dictionary
		if employee_unlock_strings.has(str(dict.get("unlock_id", ""))):
			ids.append(str(dict.get("id", "")))
	return ids


func _milestone_with_unlock(unlock_id: String) -> Dictionary:
	var data: Dictionary = _load_json(_MILESTONE_FILE)
	for entry: Variant in data.get("entries", []):
		if entry is not Dictionary:
			continue
		var dict: Dictionary = entry as Dictionary
		if str(dict.get("unlock_id", "")) == unlock_id:
			return dict
	return {}


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {}


func _build_progression_context() -> Dictionary:
	var economy: EconomySystem = EconomySystem.new()
	add_child_autofree(economy)
	economy.initialize(0.0)

	# Stub a single milestone definition file via a minimal in-memory
	# milestone — the test mutates _milestones directly to avoid loading the
	# full JSON catalog.
	var progression: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(progression)
	progression.initialize(economy, null)
	progression._milestones = [
		{
			"id": "test_unlock_milestone",
			"display_name": "Test Unlock Milestone",
			"description": "x",
			"trigger_stat_key": "customer_purchased_count",
			"trigger_threshold": 1,
			"reward_type": "unlock",
			"reward_value": 0.0,
			"unlock_id": "test_employee_unlock_id",
		}
	]
	return {"economy": economy, "progression": progression}


func _build_milestone_system_context() -> Dictionary:
	# Reset autoload state so each test starts clean.
	ContentRegistry.clear_for_testing()
	ManagerRelationshipManager.reset_for_testing()
	UnlockSystemSingleton._valid_ids = {}
	UnlockSystemSingleton._granted = {}

	var data_loader: DataLoader = DataLoader.new()
	add_child_autofree(data_loader)
	GameManager.data_loader = data_loader

	var ms: MilestoneSystem = MilestoneSystem.new()
	add_child_autofree(ms)
	ms.initialize()
	return {"data_loader": data_loader, "milestone_system": ms}
