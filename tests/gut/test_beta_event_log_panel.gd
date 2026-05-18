## Tests for the bottom-left beta event-log surface (`BetaEventLogPanel`).
##
## Covers the visual contract (dark-indigo background, tag color tokens),
## the 4-row visible cap with descending-alpha fade, the bracket-tag strip,
## the modal-dim contract, and FP-mode ownership.
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
	# (BetaRightPanel, BetaEventLogPanel) shares
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


# ── rolling cap ───────────────────────────────────────────────────────────────

func test_max_visible_entries_is_four() -> void:
	# AC pin: the rendered cap is exactly 4 — the constant is part of the
	# spec contract, not a tunable.
	assert_eq(
		BetaEventLogPanel.MAX_VISIBLE_ENTRIES, 4,
		"Spec pins the rendered cap at 4 rows"
	)


func test_panel_caps_visible_entries_at_max() -> void:
	# AC: panel never displays more than MAX_VISIBLE_ENTRIES rows; the oldest
	# is queue_free()'d when a 5th arrives.
	var panel: BetaEventLogPanel = _make_panel()
	for i: int in range(BetaEventLogPanel.MAX_VISIBLE_ENTRIES + 4):
		EventBus.event_logged.emit("[STOCK]", "Stocked item %d." % i)
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(),
		BetaEventLogPanel.MAX_VISIBLE_ENTRIES,
		"Panel must cap rendered rows at MAX_VISIBLE_ENTRIES"
	)


# ── alpha-fade contract ───────────────────────────────────────────────────────

func test_alpha_descends_from_oldest_to_newest_when_full() -> void:
	# AC: row 0 (oldest) renders at ALPHA_OLDEST; the last row at 1.0;
	# intermediate rows interpolate linearly.
	var panel: BetaEventLogPanel = _make_panel()
	for i: int in range(BetaEventLogPanel.MAX_VISIBLE_ENTRIES):
		EventBus.event_logged.emit("[STOCK]", "Stocked item %d." % i)
	await get_tree().process_frame
	var oldest: float = panel.get_row_alpha(0)
	var newest: float = panel.get_row_alpha(
		BetaEventLogPanel.MAX_VISIBLE_ENTRIES - 1
	)
	assert_almost_eq(
		oldest, BetaEventLogPanel.ALPHA_OLDEST, 0.001,
		"Oldest visible row must sit at ALPHA_OLDEST (0.35)"
	)
	assert_almost_eq(
		newest, 1.0, 0.001,
		"Newest visible row must sit at full alpha"
	)
	# Monotonic interpolation — every step strictly increases.
	var prev: float = -1.0
	for i: int in range(BetaEventLogPanel.MAX_VISIBLE_ENTRIES):
		var a: float = panel.get_row_alpha(i)
		assert_gt(
			a, prev,
			"Row alpha must monotonically increase oldest -> newest (i=%d)" % i
		)
		prev = a


func test_alpha_recomputes_immediately_after_eviction() -> void:
	# AC: existing rows update their modulate.a immediately, not on the next
	# frame. After overflowing the cap the surviving oldest still reads at
	# ALPHA_OLDEST without waiting for any deferred refresh.
	var panel: BetaEventLogPanel = _make_panel()
	for i: int in range(BetaEventLogPanel.MAX_VISIBLE_ENTRIES + 3):
		EventBus.event_logged.emit("[STOCK]", "Stocked item %d." % i)
	assert_almost_eq(
		panel.get_row_alpha(0), BetaEventLogPanel.ALPHA_OLDEST, 0.001,
		"Oldest surviving row must sit at ALPHA_OLDEST right after eviction"
	)
	assert_almost_eq(
		panel.get_row_alpha(BetaEventLogPanel.MAX_VISIBLE_ENTRIES - 1),
		1.0,
		0.001,
		"Newest row must sit at 1.0 right after eviction"
	)


# ── tag-strip + tag color contract ────────────────────────────────────────────

func test_display_text_strips_bracket_tag_prefix() -> void:
	# AC: no visible row contains a bracket-wrapped tag like '[STOCK]'.
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.event_logged.emit("[STOCK]", "Stocked Crash Bandicoot 2.")
	await get_tree().process_frame
	var latest: String = panel.get_latest_row_text()
	assert_eq(
		latest, "Stocked Crash Bandicoot 2.",
		"Display text must drop the bracket-wrapped tag prefix"
	)
	assert_false(
		latest.find("[STOCK]") >= 0,
		"Visible row must not contain the literal '[STOCK]' token"
	)


func test_tag_colors_match_spec() -> void:
	# AC: TAG_COLORS covers STOCK (blue-teal), CUSTOMER (green),
	# DAY (amber/gold), SYSTEM (medium gray), OBJECTIVE (cyan).
	var panel: BetaEventLogPanel = _make_panel()
	assert_eq(
		panel.get_tag_color("STOCK"),
		Color(0.3, 0.75, 0.85, 1.0),
		"[STOCK] must render in blue-teal"
	)
	assert_eq(
		panel.get_tag_color("CUSTOMER"),
		Color(0.3, 1.0, 0.5, 1.0),
		"[CUSTOMER] must render in green"
	)
	assert_eq(
		panel.get_tag_color("DAY"),
		Color(1.0, 0.78, 0.3, 1.0),
		"[DAY] must render in amber/gold"
	)
	assert_eq(
		panel.get_tag_color("SYSTEM"),
		Color(0.65, 0.65, 0.65, 1.0),
		"[SYSTEM] must render in medium gray"
	)
	assert_eq(
		panel.get_tag_color("OBJECTIVE"),
		Color(0.4, 0.9, 1.0, 1.0),
		"[OBJECTIVE] must render in cyan"
	)


func test_tag_color_accepts_bracketed_form() -> void:
	# Call sites that already have the bracketed token should not need to
	# unwrap it themselves.
	var panel: BetaEventLogPanel = _make_panel()
	assert_eq(
		panel.get_tag_color("[STOCK]"),
		panel.get_tag_color("STOCK"),
		"Bracketed lookup must resolve to the same color as the bare key"
	)


func test_unknown_tag_falls_back_to_near_white() -> void:
	# AC: entries with an unrecognized or missing tag fall back to near-white
	# — no crash, no blank row.
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.event_logged.emit("[NEWTHING]", "Surface me.")
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(), 1,
		"Unknown tags must still render"
	)
	var color: Color = panel.get_tag_color("NEWTHING")
	assert_almost_eq(color.r, 0.95, 0.001, "Unknown-tag color stays near-white (R)")
	assert_almost_eq(color.g, 0.95, 0.001, "Unknown-tag color stays near-white (G)")
	assert_almost_eq(color.b, 0.95, 0.001, "Unknown-tag color stays near-white (B)")


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


# ── FP-mode ownership ─────────────────────────────────────────────────────────

func test_fp_mode_changed_does_not_hide_panel() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.fp_mode_changed.emit(true)
	await get_tree().process_frame
	assert_true(
		panel.visible,
		"Event log must remain visible in FP mode as the sole bottom-left event surface"
	)
	EventBus.fp_mode_changed.emit(false)
	await get_tree().process_frame
	assert_true(
		panel.visible,
		"Event log must remain visible when FP mode is disabled"
	)


func test_panel_does_not_connect_fp_mode_changed() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	var connections: Array = EventBus.fp_mode_changed.get_connections()
	for entry: Dictionary in connections:
		var callable: Callable = entry.get("callable") as Callable
		assert_ne(
			callable.get_object(), panel,
			"BetaEventLogPanel must not connect to fp_mode_changed"
		)


# ── EventLog → event_logged bridge ────────────────────────────────────────────

func test_event_log_record_broadcasts_event_logged() -> void:
	# AC: 'The surface subscribes to EventBus.event_logged(tag, message)'.
	# EventLog._record must emit player-facing beats so a release build still
	# drives the panel even though the ring buffer is debug-only.
	var panel: BetaEventLogPanel = _make_panel()
	EventBus.item_stocked.emit("crash_2", "shelf_a")
	await get_tree().process_frame
	assert_gt(
		panel.get_visible_entry_count(), 0,
		"EventLog must broadcast event_logged so the panel renders"
	)
	var latest: String = panel.get_latest_row_text()
	assert_false(
		latest.is_empty(),
		"Latest row must carry the message body after the prefix strip"
	)
	assert_false(
		latest.find("[STOCK]") >= 0,
		"Display label must strip the bracket-wrapped tag prefix; got '%s'" % latest
	)


func test_event_log_filters_debug_entries_before_panel() -> void:
	var panel: BetaEventLogPanel = _make_panel()
	var customer: Node = Node.new()
	add_child_autofree(customer)
	EventBus.modal_opened.emit(&"CanvasLayer/DecisionCard")
	EventBus.customer_state_changed.emit(customer, Customer.State.BROWSING)
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(), 0,
		"Panel must not render modal or customer-FSM debug rows"
	)
	EventBus.objective_completed.emit(&"talk_to_customer", "Customer served.")
	await get_tree().process_frame
	assert_eq(
		panel.get_visible_entry_count(), 1,
		"Panel must still render player-facing activity rows"
	)
	assert_eq(panel.get_latest_row_text(), "Customer served.")


# ── width / layout contract ───────────────────────────────────────────────────

func test_background_is_constrained_to_content_width() -> void:
	# AC: the panel's dark background must sit inside the 260px content
	# anchor — never spanning the full viewport width. Otherwise the bottom
	# of the screen reads as a single fused console with the interaction
	# prompt.
	var panel: BetaEventLogPanel = _make_panel()
	await get_tree().process_frame
	var anchor: Control = panel.get_node("Anchor") as Control
	assert_not_null(anchor, "Panel must own a sized Anchor control")
	# Anchor footprint matches the 260px panel width — anchors collapsed
	# (left == right) so the size comes from offsets alone.
	assert_eq(
		anchor.anchor_left, anchor.anchor_right,
		"Anchor must use collapsed anchors so width is offset-driven"
	)
	var anchor_width: float = anchor.offset_right - anchor.offset_left
	assert_almost_eq(
		anchor_width, BetaEventLogPanel._PANEL_WIDTH, 0.5,
		"Anchor width (%.0fpx) must match the 260px panel content width"
			% anchor_width
	)
	var background: ColorRect = anchor.get_node("Background") as ColorRect
	assert_not_null(background, "Anchor must contain the panel background ColorRect")
	# Background fills the parent Anchor, not the viewport — bounded by the
	# 260px anchor footprint above.
	assert_eq(background.anchor_left, 0.0)
	assert_eq(background.anchor_right, 1.0)
	assert_eq(
		background.get_parent(), anchor,
		"Background must be parented to the 260px Anchor, not the CanvasLayer root"
	)
