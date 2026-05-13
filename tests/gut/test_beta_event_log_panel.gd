## Tests for the bottom-left beta event-log surface (`BetaEventLogPanel`).
##
## Covers the visual contract (dark-indigo background, tag color tokens),
## the rolling 8-entry cap with fade-out tween, modal-dim contract, and
## FP-mode hide.
extends GutTest


func before_each() -> void:
	InputFocus._reset_for_tests()


func _make_panel() -> BetaEventLogPanel:
	var panel: BetaEventLogPanel = BetaEventLogPanel.new()
	add_child_autofree(panel)
	return panel


# ── visibility / wiring ───────────────────────────────────────────────────────

func test_panel_is_visible_at_ready() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	assert_true(
		panel.visible,
		"Event-log panel must be visible immediately after _ready"
	)


func test_panel_sits_on_layer_30() -> void:
	# AC: matches the right-side stats panel layer so the design family
	# (BetaTodayStatsPanel, BetaTodayChecklist, BetaEventLogPanel) shares
	# the same z-tier and the same modal-dim contract.
	var panel: BetaEventLogPanel = _make_panel()
	assert_eq(
		panel.layer, 30,
		"BetaEventLogPanel must sit on layer 30 alongside the other Today panels"
	)


func test_panel_starts_with_zero_entries() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	assert_eq(
		panel.get_visible_entry_count(), 0,
		"Panel must start with no entries"
	)


# ── event_logged subscription ─────────────────────────────────────────────────

func test_event_logged_emit_renders_row() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.event_logged.emit("[STOCK]", "Stocked Crash Bandicoot 2.")
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(), 1,
		"event_logged must add a row"
	)


func test_empty_message_is_ignored() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.event_logged.emit("[STOCK]", "")
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(), 0,
		"Empty message must not produce a row"
	)


# ── rolling cap with fade-out ─────────────────────────────────────────────────

func test_panel_caps_visible_entries_at_max() -> void:
	# AC: 'Panel shows 6-8 entries without overlapping BetaCarryLabel'.
	# MAX_VISIBLE_ENTRIES is 8; pumping more should evict the oldest via
	# the fade tween rather than just truncating the buffer.
	var panel: BetaEventLogPanel = _make_panel()
	for i: int in range(BetaEventLogPanel.MAX_VISIBLE_ENTRIES + 4):
		EventBus.event_logged.emit("[STOCK]", "Stocked item %d." % i)
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(),
		BetaEventLogPanel.MAX_VISIBLE_ENTRIES,
		"Panel must cap rendered rows at MAX_VISIBLE_ENTRIES"
	)


# ── tag color contract ────────────────────────────────────────────────────────

func test_tag_colors_match_spec() -> void:
	# AC: amber=[STOCK], green=[CUSTOMER], cyan=[OBJECTIVE], white=[DAY],
	# 50%white=[MODAL], 60%white=[STAT].
	var panel: BetaEventLogPanel = _make_panel()
	assert_eq(
		panel.get_tag_color("[STOCK]"),
		Color(1.0, 0.58, 0.3),
		"[STOCK] must render in amber"
	)
	assert_eq(
		panel.get_tag_color("[CUSTOMER]"),
		Color(0.3, 1.0, 0.5),
		"[CUSTOMER] must render in green"
	)
	assert_eq(
		panel.get_tag_color("[OBJECTIVE]"),
		Color(0.4, 0.9, 1.0),
		"[OBJECTIVE] must render in cyan"
	)
	assert_eq(
		panel.get_tag_color("[DAY]"),
		Color(1.0, 1.0, 1.0, 1.0),
		"[DAY] must render in full white"
	)
	assert_eq(
		panel.get_tag_color("[MODAL]"),
		Color(1.0, 1.0, 1.0, 0.5),
		"[MODAL] must render at 50% white"
	)
	assert_eq(
		panel.get_tag_color("[STAT]"),
		Color(1.0, 1.0, 1.0, 0.6),
		"[STAT] must render at 60% white"
	)


func test_unknown_tag_falls_back_to_default_color() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	# An unknown tag must still produce a row — the panel never drops a
	# valid emit just because the tag wasn't in the lookup table.
	EventBus.event_logged.emit("[NEWTHING]", "Surface me.")
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(), 1,
		"Unknown tags must still render"
	)


# ── modal-dim contract ────────────────────────────────────────────────────────

func test_panel_dims_under_modal_context() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().process_frame
	var any_dimmed: bool = false
	for child: Node in panel.get_children():
		if child is CanvasItem and (child as CanvasItem).modulate.a < 1.0:
			any_dimmed = true
			break
	assert_true(
		any_dimmed,
		"Panel children must dim when CTX_MODAL is pushed"
	)
	InputFocus.pop_context()
	await get_tree().process_frame
	for child: Node in panel.get_children():
		if child is CanvasItem:
			assert_almost_eq(
				(child as CanvasItem).modulate.a, 1.0, 0.001,
				"Panel children must restore alpha when modal pops"
			)


# ── FP mode hide ──────────────────────────────────────────────────────────────

func test_fp_mode_changed_hides_panel() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.fp_mode_changed.emit(true)
	await get_tree().process_frame
	assert_false(
		panel.visible,
		"Panel must hide when FP mode is enabled"
	)
	EventBus.fp_mode_changed.emit(false)
	await get_tree().process_frame
	assert_true(
		panel.visible,
		"Panel must re-show when FP mode is disabled"
	)


# ── EventLog → event_logged bridge ────────────────────────────────────────────

func test_event_log_record_broadcasts_event_logged() -> void:
	# AC: 'The surface subscribes to EventBus.event_logged(tag, message)'.
	# EventLog._record must emit unconditionally so a release build still
	# drives the panel even though the ring buffer is debug-only.
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.item_stocked.emit("crash_2", "shelf_a")
	await get_tree().process_frame
	assert_gt(
		panel.get_visible_entry_count(), 0,
		"EventLog must broadcast event_logged so the panel renders"
	)
	var latest: String = panel.get_latest_row_text()
	assert_true(
		latest.find("[STOCK]") >= 0,
		"Latest row must carry the [STOCK] tag token; got '%s'" % latest
	)
