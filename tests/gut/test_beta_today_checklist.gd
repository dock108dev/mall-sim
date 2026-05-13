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
	var header: Label = checklist.get_node("Anchor/Margin/Container/Header") as Label
	assert_not_null(header, "Checklist must have a Header label")
	if header == null:
		return
	assert_eq(
		header.text, "Today",
		"Header must read the plain word 'Today' (no 'Day 1:' prefix)"
	)


func test_only_first_objective_seeds_at_construction() -> void:
	# AC (ISSUE-006): the checklist must NOT display all four chain entries
	# simultaneously at Day 1 start. Only the first row (the active beat)
	# is surfaced; later rows lift in as the chain advances.
	var checklist: BetaTodayChecklist = _make_checklist()
	assert_eq(
		checklist.get_visible_item_count(), 1,
		"Only the active beat must seed at construction (not the full chain)"
	)
	var first_id: StringName = StringName(str(_OBJECTIVES[0].get("id", "")))
	assert_eq(
		checklist.get_item_glyph(first_id), "•",
		"First row '%s' must render with a bullet glyph" % String(first_id)
	)
	for i: int in range(1, _OBJECTIVES.size()):
		var obj_id: StringName = StringName(str(_OBJECTIVES[i].get("id", "")))
		assert_eq(
			checklist.get_item_glyph(obj_id), "",
			"Future row '%s' must stay hidden at construction" % String(obj_id)
		)


func test_objective_changed_lifts_active_step_into_visible_list() -> void:
	# AC: chain advance flips a future row into the active visible list.
	# The controller emits the steps payload via objective_changed; the
	# checklist surfaces the row whose state is "active". Matching is by
	# the `id` field carried in each step entry (see
	# BetaDayOneController._build_steps_payload).
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.objective_changed.emit({
		"text": "Day 1: Check today's back room stock.",
		"action": "Check inventory",
		"key": "E",
		"steps": [
			{
				"id": "talk_to_customer",
				"text": "Day 1: Help the customer at the register.",
				"state": "completed",
			},
			{
				"id": "back_room_inventory",
				"text": "Day 1: Check today's back room stock.",
				"state": "active",
			},
			{
				"id": "stock_shelf",
				"text": "Day 1: Put a few items on the used games shelf.",
				"state": "future",
			},
			{
				"id": "close_day",
				"text": "Day 1: Close the day at the register.",
				"state": "future",
			},
		],
	})
	await get_tree().process_frame
	assert_eq(
		checklist.get_item_glyph(&"back_room_inventory"), "•",
		"Active back-room row must surface as a pending bullet after the chain advances"
	)
	assert_eq(
		checklist.get_item_glyph(&"stock_shelf"), "",
		"stock_shelf must remain hidden while it is still 'future'"
	)
	assert_eq(
		checklist.get_item_glyph(&"close_day"), "",
		"close_day must remain hidden while it is still 'future'"
	)


func test_objective_changed_matches_by_step_id_when_text_differs() -> void:
	# AC: row matching uses `step.id`, not `step.text`. Even when the
	# step text has drifted from the chain's `label` (e.g. controller
	# label rewrite for Day 2 copy), the row still surfaces because the
	# id is the authoritative key.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.objective_changed.emit({
		"text": "different copy",
		"steps": [
			{
				"id": "back_room_inventory",
				"text": "Totally different label that drifted from the chain.",
				"state": "active",
			},
		],
	})
	await get_tree().process_frame
	assert_eq(
		checklist.get_item_glyph(&"back_room_inventory"), "•",
		"Row must surface via step.id even when step.text no longer matches the chain label"
	)


func test_item_label_strips_day_one_prefix() -> void:
	# Header already says "Today" — the per-row copy must not echo the
	# "Day 1: ..." rail prefix.
	var checklist: BetaTodayChecklist = _make_checklist()
	var label: Label = checklist.get_node_or_null(
		"Anchor/Margin/Container/Item_talk_to_customer"
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
	# The other rows are still hidden (no objective_changed has surfaced
	# them yet), so the visible count drops to zero after the seeded row
	# collapses.
	assert_eq(
		checklist.get_visible_item_count(), 0,
		"Visible count must drop to zero after the seeded row collapses"
	)


func test_unsurfaced_rows_stay_hidden_after_one_completion() -> void:
	# AC: future rows do not appear until the chain advances. Completing
	# the first row must NOT auto-surface later rows.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	for obj_id: StringName in [
		&"back_room_inventory", &"stock_shelf", &"close_day"
	]:
		assert_eq(
			checklist.get_item_glyph(obj_id), "",
			"Row '%s' must stay hidden until objective_changed surfaces it" % String(obj_id)
		)


# ── day_started reset ─────────────────────────────────────────────────────────

func test_day_started_reseeds_only_the_first_row() -> void:
	# Day-2 entry must repopulate the checklist so it never reaches Day 2
	# with a stale empty list — but only the first row reseeds (consistent
	# with the no-front-loaded-checklist rule). Later rows surface via
	# objective_changed as Day-2 progresses.
	var checklist: BetaTodayChecklist = _make_checklist()
	EventBus.beta_objective_completed.emit(&"talk_to_customer")
	await get_tree().process_frame
	EventBus.day_started.emit(2)
	await get_tree().process_frame
	assert_eq(
		checklist.get_visible_item_count(), 1,
		"day_started must reseed only the first row, not the full chain"
	)
	var first_id: StringName = StringName(str(_OBJECTIVES[0].get("id", "")))
	assert_eq(
		checklist.get_item_glyph(first_id), "•",
		"After day_started, the first row must reseed as a bullet"
	)
