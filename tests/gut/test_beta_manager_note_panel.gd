## Tests for the beta manager note panel (`BetaManagerNotePanel`).
##
## Covers the AC for the pre-chain passive overlay: dismiss button grabs
## keyboard focus on open() (Enter / Space dismiss without the mouse),
## the panel does NOT claim a CTX_MODAL frame on InputFocus (player can
## still move and look around behind the note), E and Escape both
## dismiss, body text renders as supplied, and the controller integration
## only fires `_start_day` after the player dismisses (no empty-rail
## moment because the rail signal lands synchronously inside
## `_on_vic_note_dismissed`).
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const SAMPLE_BODY: String = "Sample body text for the note panel."

var _root: Node3D = null


func before_each() -> void:
	BetaRunState.reset_new_run()
	# Reset InputFocus and ModalQueue between tests so a leaked CTX_MODAL
	# push or active-queue entry from a prior test doesn't bleed into the
	# assertions below. ModalQueue routes panel dispatch — without the
	# reset, a panel left as `_active` from a previous test would prevent
	# the next test's panel from dispatching synchronously.
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()


func after_each() -> void:
	# Dismiss any open Vic note before tearing down the scene so the
	# ModalPanel base's `_exit_tree` safety net doesn't push_error on a
	# leaked CTX_MODAL frame. Tests that have already dismissed the panel
	# (most of them) hit no-op branches inside close() and note_dismissed.
	if is_instance_valid(_root):
		var controller: Node = _beta_controller()
		if controller != null:
			var panel: BetaManagerNotePanel = (
				controller.get("_vic_note_panel") as BetaManagerNotePanel
			)
			if panel != null and panel.visible:
				panel.close()
	# Reset autoload state BEFORE freeing the scene so panel `_exit_tree`
	# sees an empty CTX_MODAL stack and skips the safety-net push_error
	# (`modal_panel.gd::_exit_tree`).
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()
	if is_instance_valid(_root):
		_root.free()
	_root = null
	BetaRunState.reset_new_run()


# ── Standalone panel: focus, signal, body, modal contract ───────────────────

func test_dismiss_button_grabs_focus_on_show() -> void:
	# AC: 'Got it' button must receive keyboard focus immediately on panel
	# open so the player can dismiss with Enter or Space without the mouse.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	await get_tree().process_frame
	var focused: Control = panel.get_viewport().gui_get_focus_owner()
	assert_eq(
		focused, panel._dismiss_button,
		"Dismiss button must own keyboard focus immediately after show_note()"
	)


func test_show_note_renders_body_text() -> void:
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	assert_eq(
		panel._body_label.text, SAMPLE_BODY,
		"show_note() must populate the body label with the supplied text"
	)


func test_show_note_does_not_push_ctx_modal() -> void:
	# Passive-overlay contract: the note must NOT claim CTX_MODAL, so the
	# player can keep moving / looking around while reading it. Chain
	# progression is gated by `_stage`, not the input focus stack.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	assert_ne(
		String(InputFocus.current()), String(InputFocus.CTX_MODAL),
		"Open note must NOT push CTX_MODAL — it is a passive overlay"
	)


func test_dismiss_button_press_emits_note_dismissed() -> void:
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	watch_signals(panel)
	panel._dismiss_button.emit_signal("pressed")
	assert_signal_emitted(
		panel, "note_dismissed",
		"Pressing the dismiss button must emit note_dismissed"
	)


func test_dismiss_does_not_touch_input_focus_stack() -> void:
	# Symmetry guard: a no-op pop would corrupt a sibling's frame, so the
	# panel must leave the stack untouched on close.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline_depth: int = InputFocus.depth()
	panel.show_note(SAMPLE_BODY)
	panel._dismiss_button.emit_signal("pressed")
	assert_eq(
		InputFocus.depth(), baseline_depth,
		"Open/close round-trip must leave InputFocus depth unchanged"
	)
	InputFocus.pop_context()


func test_interact_key_dismisses_note() -> void:
	# AC: pressing E (interact) while the note is up dismisses it. The
	# panel marks the press as handled so it cannot also fire a world
	# interaction behind the note.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	watch_signals(panel)
	var event: InputEventAction = InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	panel._unhandled_input(event)
	assert_signal_emitted(
		panel, "note_dismissed",
		"Pressing E (interact) must dismiss the note"
	)


func test_ui_cancel_dismisses_note() -> void:
	# AC: pressing Escape (ui_cancel) while the note is up dismisses it.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	watch_signals(panel)
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	panel._unhandled_input(event)
	assert_signal_emitted(
		panel, "note_dismissed",
		"Pressing Escape (ui_cancel) must dismiss the note"
	)


func test_keypress_after_dismiss_is_ignored() -> void:
	# Once the note is dismissed it must stop swallowing input — a second
	# E press should fall through to world interactables.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note(SAMPLE_BODY)
	panel._dismiss_button.emit_signal("pressed")
	watch_signals(panel)
	var event: InputEventAction = InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	panel._unhandled_input(event)
	assert_signal_emit_count(
		panel, "note_dismissed", 0,
		"Dismissed note must ignore further input"
	)


func test_panel_starts_hidden_until_show_note_called() -> void:
	# Panels are constructed in BetaDayOneController._ensure_panels() before
	# the player has a chance to dismiss anything. They must stay invisible
	# until show_note() opens them or the screen will flash a blocker.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	assert_false(
		panel.visible,
		"Panel must be invisible at construction; show_note() opens it"
	)


# ── Controller integration: Day 1 starts immediately; later notes still work ─

func test_day1_starts_without_opening_note_panel() -> void:
	# Day 1 should land directly on the first actionable beat. This keeps
	# first play from requiring a note dismissal before the tutorial begins.
	BetaRunState.preopening_complete = true
	await _load_beta_scene()
	var controller: Node = _beta_controller()
	assert_not_null(controller, "BetaDayOneController must exist after scene load")
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	assert_not_null(panel, "Controller must own a BetaManagerNotePanel after _ready")
	if panel == null:
		return
	assert_false(
		panel.visible,
		"Vic's note panel must stay hidden on Day 1 so no extra start gate appears"
	)
	var active_event: Dictionary = (
		controller.get("_active_event") as Dictionary
	)
	assert_false(
		active_event.is_empty(),
		"_active_event must be ready immediately on Day 1"
	)
	assert_eq(
		String(controller.get("_stage")), "talk_to_customer",
		"Day 1 must start on the customer beat"
	)


func test_dismissing_note_arms_chain_in_same_frame() -> void:
	# AC: After note dismissed the objective rail must show 'Talk to the
	# customer at the register.' within the same frame — _start_day fires
	# synchronously inside _on_vic_note_dismissed, not deferred.
	BetaRunState.day = 2
	await _load_beta_scene()
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	assert_not_null(panel, "Controller must own a BetaManagerNotePanel")
	if panel == null:
		return
	watch_signals(EventBus)
	# Drive the dismiss path the same way the runtime player would:
	# pressing the button runs _on_dismiss_pressed which closes + emits
	# note_dismissed; the controller's listener calls _start_day on the
	# same call stack.
	panel._dismiss_button.emit_signal("pressed")
	# No `await` — the rail emit must have happened synchronously.
	assert_signal_emitted(
		EventBus, "objective_changed",
		"objective_changed must fire on the same call stack as note dismiss"
	)


func test_dismissing_note_emits_manager_note_dismissed_with_id() -> void:
	# Sanity: the controller forwards the dismiss to EventBus with the
	# stable note id so any non-beta listener (e.g. ObjectiveDirector) can
	# react. Day 2 keeps the opening-note path, so it emits `vic_day02`.
	BetaRunState.day = 2
	await _load_beta_scene()
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	watch_signals(EventBus)
	panel._dismiss_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(
		EventBus, "manager_note_dismissed", ["vic_day02"]
	)


# ── Stage-machine coherence: STAGE_VIC_NOTE while note is up ────────────────
# The chain must sit at STAGE_VIC_NOTE while the note is on screen, then
# advance to STAGE_TALK_TO_CUSTOMER on dismiss. This rules out the rail /
# gating ever showing the customer beat before the player has read the note.

func test_day2_stage_is_vic_note_while_note_panel_is_up() -> void:
	BetaRunState.day = 2
	await _load_beta_scene()
	var controller: Node = _beta_controller()
	if controller == null:
		return
	assert_eq(
		String(controller.get("_stage")), "vic_note",
		"Stage must sit at STAGE_VIC_NOTE while the morning note is on screen"
	)


func test_day2_dismiss_advances_stage_past_vic_note() -> void:
	BetaRunState.day = 2
	await _load_beta_scene()
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	panel._dismiss_button.emit_signal("pressed")
	assert_eq(
		String(controller.get("_stage")), "talk_to_customer",
		"Dismissing the note must advance the chain past STAGE_VIC_NOTE"
	)


# ── Note-phase rail copy ────────────────────────────────────────────────────
# AC: while the note is on screen, the rail emits 'Read Vic's morning note.'
# rather than the customer beat. On Day 2, `_open_day` enters the Vic-note
# gate from a deferred _ready call, so loading the scene + waiting two frames
# is enough to capture it.

func test_rail_emits_note_phase_copy_before_dismiss() -> void:
	# `watch_signals` must be attached before the deferred
	# `_open_day` runs, so the signal capture has to be scheduled before the
	# scene is added to the tree.
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load for the note-phase test")
	if scene == null:
		return
	BetaRunState.day = 2
	watch_signals(EventBus)
	_root = scene.instantiate() as Node3D
	add_child(_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var found_note_phase_copy: bool = false
	for params: Array in get_signal_parameters_all(
		EventBus, "objective_changed"
	):
		if params.is_empty():
			continue
		var payload_variant: Variant = params[0]
		if not (payload_variant is Dictionary):
			continue
		var payload: Dictionary = payload_variant as Dictionary
		var text: String = String(payload.get("text", ""))
		if text == "Read Vic's morning note.":
			found_note_phase_copy = true
			break
	assert_true(
		found_note_phase_copy,
		"Rail must emit 'Read Vic's morning note.' before the player dismisses "
		+ "the note panel."
	)


# ── Delivery notification beat ─────────────────────────────────────────────
# Dismissing the note must surface the back-room delivery as an active cue
# (notification_requested), not leave the player to discover it from
# Vic's note body alone. Routes through the persistent HUD label channel
# because it complements the rail's active beat rather than narrating an
# event — toast is reserved for transient confirmations.

func test_dismiss_emits_back_room_delivery_notification() -> void:
	BetaRunState.day = 2
	await _load_beta_scene()
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	watch_signals(EventBus)
	panel._dismiss_button.emit_signal("pressed")
	var found_delivery_msg: bool = false
	for params: Array in get_signal_parameters_all(
		EventBus, "notification_requested"
	):
		if params.is_empty():
			continue
		var msg: String = String(params[0])
		if msg.to_lower().contains("delivery"):
			found_delivery_msg = true
			break
	assert_true(
		found_delivery_msg,
		"Note dismissal must emit a notification_requested whose message "
		+ "names the back-room delivery so the next beat is signposted."
	)


# ── Helpers ─────────────────────────────────────────────────────────────────

func _load_beta_scene() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load for the integration test")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	# Two frames so _ready / call_deferred(_open_day)
	# settles before assertions inspect controller / panel state.
	await get_tree().process_frame
	await get_tree().process_frame


func _beta_controller() -> Node:
	return get_tree().get_first_node_in_group("beta_day_one_controller")


## GUT's `get_signal_parameters` returns the params of one emission and
## crashes if the index runs past the end. Use `get_signal_emit_count` as
## the loop bound so the helper stays safe even when no emissions have
## been captured yet. Multiple emits land on the same channel during a
## single frame (rail updates, notification, etc.) — collect all matching
## emissions so message-content assertions can scan the whole batch.
func get_signal_parameters_all(emitter: Object, signal_name: String) -> Array:
	var out: Array = []
	var count: int = get_signal_emit_count(emitter, signal_name)
	for idx: int in range(count):
		var params: Variant = get_signal_parameters(emitter, signal_name, idx)
		if params != null:
			out.append(params)
	return out
