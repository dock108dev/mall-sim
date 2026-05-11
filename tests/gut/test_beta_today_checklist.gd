## Tests for the beta day-1 Today checklist (`BetaTodayChecklist`).
##
## Covers the AC for the right-side panel replacement: header reads
## "Today" (no "Day 1:" prefix), every chain objective renders as a
## bullet on day start (list never empty), `EventBus.beta_objective_completed`
## flips the row to ✓ for `COMPLETION_HOLD_SECONDS` and then collapses it
## off the list.
extends GutTest


const _OBJECTIVES: Array[Dictionary] = [
	{
		"id": "talk_to_customer",
		"stage": "talk_to_customer",
		"label": "Day 1: Help the customer at the register.",
		"action": "Talk to the customer",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "back_room_inventory",
		"stage": "back_room_inventory",
		"label": "Day 1: Check today's back room stock.",
		"action": "Check inventory",
		"key": "E",
		"target_path": "BetaBackroomPickup/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "stock_shelf",
		"stage": "stock_shelf",
		"label": "Day 1: Put a few items on the used games shelf.",
		"action": "Stock the shelf",
		"key": "E",
		"target_path": "BetaRestockShelf/Interactable",
		"time_cost_minutes": 60,
		"required": true,
	},
	{
		"id": "close_day",
		"stage": "end_day",
		"label": "Day 1: Close the day at the register.",
		"action": "Close the day",
		"key": "E",
		"target_path": "BetaDayEndTrigger/Interactable",
		"time_cost_minutes": 0,
		"required": false,
	},
]


func _make_checklist() -> BetaTodayChecklist:
	var checklist: BetaTodayChecklist = BetaTodayChecklist.new()
	checklist.set_objectives(_OBJECTIVES)
	add_child_autofree(checklist)
	return checklist


# ── header / initial population ───────────────────────────────────────────────

func test_header_reads_today_with_no_day_one_prefix() -> void:
	var checklist: BetaTodayChecklist = _make_checklist()
	var header: Label = checklist.get_node("Anchor/Container/Header") as Label
	assert_not_null(header, "Checklist must have a Header label")
	if header == null:
		return
	assert_eq(
		header.text, "Today",
		"Header must read the plain word 'Today' (no 'Day 1:' prefix)"
	)


func test_all_four_objectives_seed_as_bullets_on_construction() -> void:
	# AC: "even before any objective is complete, all four items appear as
	# bullets" — the list is never empty.
	var checklist: BetaTodayChecklist = _make_checklist()
	assert_eq(
		checklist.get_visible_item_count(), _OBJECTIVES.size(),
		"All four chain entries must render as bullet rows at construction"
	)
	for entry: Dictionary in _OBJECTIVES:
		var obj_id: StringName = StringName(str(entry.get("id", "")))
		assert_eq(
			checklist.get_item_glyph(obj_id), "•",
			"Pending row '%s' must render with a bullet glyph" % String(obj_id)
		)


func test_item_label_strips_day_one_prefix() -> void:
	# Header already says "Today" — the per-row copy must not echo the
	# "Day 1: ..." rail prefix.
	var checklist: BetaTodayChecklist = _make_checklist()
	var label: Label = checklist.get_node_or_null(
		"Anchor/Container/Item_talk_to_customer"
	) as Label
	assert_not_null(label, "Item row must exist for talk_to_customer")
	if label == null:
		return
	assert_false(
		label.text.contains("Day 1:"),
		"Per-row copy must not echo the 'Day 1:' prefix; got '%s'" % label.text
	)


# ── completion → check → collapse ─────────────────────────────────────────────

func test_completion_signal_flips_row_to_checkmark() -> void:
	# AC: completed items show a checkmark (✓) before collapsing.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	assert_eq(
		checklist.get_item_glyph(&"talk_to_customer"), "✓",
		"Row must flip to ✓ after beta_objective_completed fires"
	)


func test_completion_signal_for_unknown_id_is_a_noop() -> void:
	var checklist: BetaTodayChecklist = _make_checklist()
	var before: int = checklist.get_visible_item_count()
	EventBus.beta_objective_completed.emit(&"not_a_real_objective")
	await get_tree().process_frame
	assert_eq(
		checklist.get_visible_item_count(), before,
		"Unknown objective id must not affect the visible row count"
	)


func test_completed_row_collapses_after_hold_window() -> void:
	# AC: completed rows show a checkmark for 2 seconds, then collapse off
	# the list. We wait slightly past the hold to give SceneTreeTimer +
	# queue_free a frame to settle.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	var settle: float = BetaTodayChecklist.COMPLETION_HOLD_SECONDS + 0.1
	await get_tree().create_timer(settle).timeout
	await get_tree().process_frame
	assert_eq(
		checklist.get_item_glyph(&"talk_to_customer"), "",
		"Row must collapse off the list after the completion hold"
	)
	assert_eq(
		checklist.get_visible_item_count(), _OBJECTIVES.size() - 1,
		"Remaining rows count must drop by exactly one after collapse"
	)


func test_other_rows_remain_pending_after_one_completion() -> void:
	# AC1: showing all four objectives simultaneously — completing one
	# row must not flip the others.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	for obj_id: StringName in [
		&"back_room_inventory", &"stock_shelf", &"close_day"
	]:
		assert_eq(
			checklist.get_item_glyph(obj_id), "•",
			"Row '%s' must remain a bullet while another row is completing" % String(obj_id)
		)


# ── day_started reset ─────────────────────────────────────────────────────────

func test_day_started_reseeds_all_four_bullet_rows() -> void:
	# Day-2 entry must repopulate the checklist so it never reaches Day 2
	# with a stale empty list.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	EventBus.day_started.emit(2)
	await get_tree().process_frame
	assert_eq(
		checklist.get_visible_item_count(), _OBJECTIVES.size(),
		"day_started must rebuild every chain entry as a pending row"
	)
	for entry: Dictionary in _OBJECTIVES:
		var obj_id: StringName = StringName(str(entry.get("id", "")))
		assert_eq(
			checklist.get_item_glyph(obj_id), "•",
			"After day_started, row '%s' must reseed as a bullet" % String(obj_id)
		)
