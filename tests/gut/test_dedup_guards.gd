## Dedup-guard tests for Day-1 boot surfaces that are prone to duplicate
## emissions: the Vic morning note (BetaManagerNotePanel) and the
## per-store tutorial context emission (TutorialContextSystem).
##
## The Vic note test instantiates `retro_games.tscn` and intentionally does
## NOT dismiss the panel in before_each so the rendered body can be
## inspected after `_open_vic_note_and_then_start_day` settles. The tutorial
## test drives store_entered / day_started through EventBus to verify that
## the dedup gate prevents same-window double-emission across one entry and
## across a restart-style second store_entered without an intervening exit.
extends GutTest


const _STORE_SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const _STORE_ID: StringName = &"retro_games"

var _saved_state: GameManager.State
var _root: Node3D = null
var _tutorial_emissions: Array = []


func before_each() -> void:
	# STORE_VIEW lets `is_tutorial_rendering_allowed()` clear its game-state
	# guard so emissions can land. The Vic note test does NOT call
	# `_dismiss_vic_note_for_test()` so the panel stays on screen for the
	# duplicate-paragraph assertion.
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	# Ensure ContentRegistry has the retro_games store route so
	# TutorialContextSystem._on_store_entered can resolve the tutorial
	# context id. Idempotent — load_all() short-circuits once registry is
	# ready, so this is a no-op when an earlier test already loaded content.
	if not ContentRegistry.is_ready():
		DataLoaderSingleton.load_all()
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	TutorialContextSystem.clear_active_context()
	TutorialContextSystem.reload()
	_tutorial_emissions.clear()
	EventBus.tutorial_context_entered.connect(_on_tutorial_context_entered)


func after_each() -> void:
	if EventBus.tutorial_context_entered.is_connected(_on_tutorial_context_entered):
		EventBus.tutorial_context_entered.disconnect(_on_tutorial_context_entered)
	if is_instance_valid(_root):
		var controller: Node = get_tree().get_first_node_in_group("beta_day_one_controller")
		if controller != null:
			var panel: BetaManagerNotePanel = (
				controller.get("_vic_note_panel") as BetaManagerNotePanel
			)
			if panel != null and panel.visible:
				panel.close()
		_root.free()
	_root = null
	BetaRunState.reset_new_run()
	TutorialContextSystem.clear_active_context()
	TutorialContextSystem.reload()
	GameManager.current_state = _saved_state
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()


func _on_tutorial_context_entered(
	store_id: StringName, context_id: StringName, prompt_text: String
) -> void:
	_tutorial_emissions.append({
		"store_id": store_id,
		"context_id": context_id,
		"prompt_text": prompt_text,
	})


# ── Vic note: single instance, no duplicate paragraph in body ───────────────

## AC 1 — instantiate retro_games.tscn without dismissing the Vic note,
## then verify the controller spawned exactly one BetaManagerNotePanel for
## this Day-1 boot and that its rendered body contains no repeated paragraph.
##
## "Exactly one" is asserted against the current controller's
## `_vic_note_panel` field rather than a tree-wide walk. BetaDayOneController
## parents the panel under `_ui_root()`, which falls back to `/root` when no
## UILayer is present (the headless test environment). The in-process GUT
## runner does not garbage-collect panels created by prior tests' (now-freed)
## controllers between scene tear-downs, so a global walk would over-count.
## Per-controller scoping is the right boundary for the dedup contract:
## `_ensure_panels` guards on `_vic_note_panel == null`, so structurally there
## can only be one panel per controller instance.
func test_morning_note_not_duplicated_on_day1_start() -> void:
	# Sweep visible BetaManagerNotePanel instances left over from earlier
	# tests in the suite. `BetaDayOneController._ensure_panels` parents the
	# Vic note under `_ui_root()`, which falls back to `/root` in headless
	# mode, so any prior test that walked past `_on_summary_continue`
	# (which calls `_open_vic_note_and_then_start_day` again to render the
	# Day-2 note) leaves its panel `visible = true` in `/root` because
	# `before_each` resets ModalQueue references without calling `close()`
	# on the active panel. Closing them up front keeps the visible-count
	# assertion below scoped to this test's freshly-spawned panel.
	for node: Node in get_tree().root.get_children():
		if node is BetaManagerNotePanel and (node as BetaManagerNotePanel).visible:
			(node as BetaManagerNotePanel).close()

	var scene: PackedScene = load(_STORE_SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	# Two frames: one for _ready, one for call_deferred(_open_vic_note_and_then_start_day).
	await get_tree().process_frame
	await get_tree().process_frame

	var controller: Node = get_tree().get_first_node_in_group("beta_day_one_controller")
	assert_not_null(controller, "BetaDayOneController must be in the scene tree after _ready")
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	assert_not_null(
		panel,
		"BetaDayOneController._ensure_panels must spawn a Vic note panel before _open_vic_note_and_then_start_day"
	)
	if panel == null:
		return
	assert_true(
		is_instance_valid(panel),
		"_vic_note_panel must remain valid through the boot settle"
	)
	assert_true(
		panel.visible,
		"Pre-condition: the Vic note must be visible after _open_vic_note_and_then_start_day"
	)

	# The controller only ever wires one Vic note instance per run because
	# `_ensure_panels` guards on `_vic_note_panel == null`. The meaningful
	# on-screen invariant: at any moment, exactly one BetaManagerNotePanel
	# is visible — counting *visible* siblings catches both a stuck panel
	# left over from a prior run and a refactor that adds a parallel spawn
	# site for the current controller. (Panels rooted in /root by prior
	# tests' freed controllers stay in the tree because the in-process GUT
	# runner does not garbage-collect them, but they are not visible.)
	var visible_count: int = 0
	for node: Node in get_tree().root.get_children():
		if node is BetaManagerNotePanel and (node as BetaManagerNotePanel).visible:
			visible_count += 1
	assert_eq(
		visible_count, 1,
		(
			"Exactly one BetaManagerNotePanel must be visible after Day-1 "
			+ "boot; got %d (a duplicate visible panel indicates a stuck "
			+ "leftover or a parallel spawn site)"
		) % visible_count
	)

	var body_label: RichTextLabel = panel.get("_body_label") as RichTextLabel
	assert_not_null(body_label, "Panel must own a _body_label RichTextLabel")
	if body_label == null:
		return
	var body: String = body_label.text
	assert_ne(body, "", "Body must be populated after _open_vic_note_and_then_start_day")

	# VIC_NOTE_BODY separates paragraphs with double newlines. Strip each
	# piece and require uniqueness so an accidental `append_text` refactor
	# that re-renders the body on a second show_note call fails.
	var paragraphs: PackedStringArray = body.split("\n\n", false)
	var seen: Dictionary = {}
	for paragraph: String in paragraphs:
		var trimmed: String = paragraph.strip_edges()
		if trimmed.is_empty():
			continue
		assert_false(
			seen.has(trimmed),
			"Body must not contain duplicate paragraph: '%s'" % trimmed
		)
		seen[trimmed] = true


# ── TutorialContextSystem: one show per entry window across restart ─────────

func test_tutorial_context_not_shown_twice_on_restart() -> void:
	# AC: TutorialContextSystem `_context_shown_since_entry` only permits one
	# show per entry. Verifies two contracts:
	#   (a) within a single store-entry window, store_entered + day_started
	#       produces exactly one tutorial_context_entered emission (the
	#       day_started is dedup'd against the gate raised by store_entered).
	#   (b) a second store_entered (restart-style, no intervening
	#       store_exited) re-raises the gate so the same-window day_started
	#       is again suppressed — the contract survives the restart path.
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)
	assert_eq(
		_tutorial_emissions.size(), 1,
		"First store_entered + day_started must produce exactly one emission"
	)
	assert_false(
		bool(TutorialContextSystem.get("_context_shown_since_entry")),
		"After the day_started consume, the dedup gate must be lowered"
	)

	# Restart-style second entry without store_exited. The second
	# store_entered counts as a new entry window and emits once; the
	# immediately-following day_started must be suppressed by the re-raised
	# gate, leaving the total at 2 (one per window) — not 3 or 4.
	EventBus.store_entered.emit(_STORE_ID)
	assert_true(
		bool(TutorialContextSystem.get("_context_shown_since_entry")),
		"Second store_entered must re-raise the dedup gate"
	)
	EventBus.day_started.emit(1)
	assert_eq(
		_tutorial_emissions.size(), 2,
		(
			"Across two store-entry windows, the dedup gate must keep the "
			+ "total emissions at one per window (got %d)"
		) % _tutorial_emissions.size()
	)
