## First-minute onboarding contract — three regression bars for the
## stacked-modal / duplicated-text / duplicated-objective bugs the
## "Shelf Life — Onboarding Flow Cleanup" brief identified. Each test
## is named after the brief's numbered acceptance criterion.
##
## NOTE: instantiates `retro_games.tscn` directly via the same fixture
## pattern as `test_beta_day_one_critical_path.gd` — exercises the beta
## Day-1 controller without driving the full GameManager scene-swap path.
extends GutTest


const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const MILESTONE_CARD_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestone_card.tscn"
)

var _root: Node3D = null
var _milestone_card: MilestoneCard = null


func before_each() -> void:
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load for onboarding tests")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	# MilestoneCard lives on `GameWorld._ui_layer` in production. The store
	# scene alone does not bring it into the tree, so mount one explicitly
	# in notification mode — Test 1 needs a real listener for the
	# `milestone_completed` emit to exercise.
	_milestone_card = MILESTONE_CARD_SCENE.instantiate() as MilestoneCard
	_milestone_card.notification_mode = true
	add_child(_milestone_card)
	# Two frames for _ready + call_deferred(_open_vic_note_and_then_start_day).
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	# Reset modal/focus stacks FIRST so panel `_exit_tree` calls see an
	# empty CTX_MODAL frame and skip the safety-net push_error. Reversing
	# the order produces a cascade of "freed with unreleased InputFocus
	# push" lines that GUT treats as errors.
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()
	if is_instance_valid(_milestone_card):
		_milestone_card._reset_for_tests()
		_milestone_card.free()
	_milestone_card = null
	if is_instance_valid(_root):
		_root.free()
	_root = null
	BetaRunState.reset_new_run()


func _beta_controller() -> BetaDayOneController:
	if _root == null:
		return null
	return _root.get_node_or_null("BetaDayOneController") as BetaDayOneController


func _dismiss_vic_note() -> void:
	var controller: BetaDayOneController = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	panel.close()
	panel.note_dismissed.emit()


# ── Test 1 — Spawn Does Not Stack Blocking Modals ────────────────────────────
# AC (from brief): "there is at most one blocking modal open / there are zero
# hidden blocking modals rendered behind it." The Vic note opens as a passive
# overlay (no CTX_MODAL push) but is `ModalQueue._active` while visible. A
# `milestone_completed` for `employee_register_unlock` fired during this
# window must NOT push CTX_MODAL onto InputFocus on top of the visible note —
# the milestone surface should defer until the note is dismissed.


func test_milestone_completed_during_vic_note_does_not_stack_ctx_modal() -> void:
	var controller: BetaDayOneController = _beta_controller()
	assert_not_null(controller, "Day-1 controller must spawn from retro_games.tscn")
	if controller == null:
		return
	var note: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	assert_not_null(note, "Vic note panel must exist after Day-1 spawn")
	if note == null:
		return
	assert_true(
		note.visible,
		"Precondition: Vic note must be visible at Day-1 spawn before the milestone fires"
	)
	assert_same(
		ModalQueue.active_panel(),
		note,
		"Precondition: Vic note must own the ModalQueue active slot"
	)
	var focus_before: StringName = InputFocus.current()
	assert_false(
		_milestone_card.visible,
		"Precondition: MilestoneCard must be hidden before the milestone fires"
	)
	# Synthesize the spawn-window race: the player clocks in (or anything
	# else completes `employee_register_unlock`) while Vic's note is still
	# on screen. The MilestoneCard listens to `EventBus.milestone_completed`
	# unconditionally today and slides in, pushing CTX_MODAL.
	EventBus.milestone_completed.emit(
		"employee_register_unlock", "Showing the Ropes", "Register access unlocked"
	)
	await get_tree().process_frame
	assert_eq(
		InputFocus.current(),
		focus_before,
		(
			"MilestoneCard must NOT push CTX_MODAL while the Vic note is the "
			+ "active ModalQueue entry — that creates the stacked-modal feel "
			+ "the onboarding brief calls out."
		)
	)
	assert_false(
		_milestone_card.visible,
		"MilestoneCard must remain hidden while ModalQueue is busy with the Vic note"
	)
	assert_true(
		note.visible,
		"Vic note must remain visible — no second blocking surface should occlude it"
	)


func test_at_spawn_at_most_one_modal_surface_is_visible() -> void:
	# Survey the tree for every modal-class panel currently visible. The
	# brief's "at most one blocking modal open" rule extends to passive
	# overlays too: even with the Vic note in passive mode, no other
	# tutorial / milestone / summary surface should be simultaneously
	# visible at Day-1 spawn.
	var visible_modals: Array[String] = _collect_visible_modal_names(_root)
	assert_lte(
		visible_modals.size(),
		1,
		(
			"Day-1 spawn renders %d simultaneously-visible modal surfaces: %s. "
			+ "Brief requires at most one."
		) % [visible_modals.size(), ", ".join(visible_modals)]
	)


# ── Test 3 — Vic Note Body Does Not Duplicate ────────────────────────────────
# AC (from brief): "modal id vic_day_1_note appears once / body text does not
# contain duplicated paragraphs / closing/reopening does not append duplicate
# text." Regression guard: `show_note(body)` must REPLACE the body label
# text, not append; the body constant itself must not contain literal
# repetition.


func test_vic_note_body_does_not_contain_duplicate_paragraphs() -> void:
	# The body constant is the single source of truth — sanity-check it
	# does not concatenate the same paragraph twice. (A future content
	# edit could accidentally do this and we'd want CI to catch it.)
	var body: String = BetaDayOneController.VIC_NOTE_BODY
	var paragraphs: PackedStringArray = body.split("\n\n", false)
	var seen: Dictionary = {}
	for raw: String in paragraphs:
		var p: String = raw.strip_edges()
		if p.is_empty():
			continue
		assert_false(
			seen.has(p),
			"VIC_NOTE_BODY contains a repeated paragraph: '%s'" % p
		)
		seen[p] = true


func test_vic_note_body_replaces_not_appends_on_reopen() -> void:
	var controller: BetaDayOneController = _beta_controller()
	if controller == null:
		return
	var note: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if note == null:
		return
	var label: RichTextLabel = note.get("_body_label") as RichTextLabel
	assert_not_null(label, "BetaManagerNotePanel must expose _body_label")
	if label == null:
		return
	var first_length: int = label.text.length()
	assert_gt(first_length, 0, "Vic note body must render text on initial open")
	# Close and re-open with the same body — verify the label text length
	# stays constant. An append-instead-of-replace regression would double
	# the length.
	note.close()
	await get_tree().process_frame
	note.show_note(BetaDayOneController.VIC_NOTE_BODY)
	await get_tree().process_frame
	assert_eq(
		label.text.length(),
		first_length,
		(
			"Reopening Vic's note must REPLACE the body label, not append. "
			+ "Length went from %d to %d."
		) % [first_length, label.text.length()]
	)


# ── Test 5 — Objective Text Does Not Duplicate Across Surfaces ───────────────
# AC (from brief): "each objective id appears once in the objective manager /
# each objective label appears once in the right panel checklist / the
# bottom-left event log does not contain active objective rows." Concretely:
# `ObjectiveRail` renders both a main `_objective_label` AND a `_steps_container`
# of up to four step slots — the active step's text appears in both today.


func test_objective_rail_main_label_does_not_duplicate_active_step() -> void:
	# Dismiss the Vic note so `_start_day` fires and the rail receives the
	# real Day-1 chain payload (TALK_TO_CUSTOMER + step list).
	_dismiss_vic_note()
	await get_tree().process_frame
	await get_tree().process_frame
	var rail: CanvasLayer = ObjectiveRail
	var main_label: Label = rail.get("_objective_label") as Label
	var step_slots: Array = rail.get("_step_slots") as Array
	assert_not_null(main_label, "ObjectiveRail must expose _objective_label")
	assert_not_null(step_slots, "ObjectiveRail must expose _step_slots")
	if main_label == null or step_slots == null:
		return
	var main_text: String = main_label.text.strip_edges()
	assert_false(
		main_text.is_empty(),
		"Precondition: rail main label must have text after Day-1 starts"
	)
	for slot_v: Variant in step_slots:
		var slot: Label = slot_v as Label
		if slot == null or not slot.visible:
			continue
		var slot_text: String = slot.text.strip_edges()
		# Step slots may carry a "✓ " prefix for completed rows; strip it
		# before comparing so a checked-off completed row doesn't mask a
		# duplicate of an active row.
		if slot_text.begins_with("✓ "):
			slot_text = slot_text.substr(2).strip_edges()
		assert_ne(
			slot_text,
			main_text,
			(
				"ObjectiveRail renders '%s' in BOTH the main label and a step "
				+ "slot — the active beat must appear in exactly one surface "
				+ "(brief: 'each objective label appears once')."
			) % main_text
		)


# ── Helpers ──────────────────────────────────────────────────────────────────


## Recursively collects the names of every modal-class panel currently
## `visible` in the tree rooted at `node`. A "modal-class" panel is any
## `ModalPanel` subclass plus the `MilestoneCard` in notification mode.
## Used by Test 1 to count concurrent foreground surfaces.
func _collect_visible_modal_names(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node == null:
		return out
	if node is ModalPanel:
		var mp: ModalPanel = node as ModalPanel
		if mp.visible:
			out.append(mp.name)
	elif node is MilestoneCard:
		var mc: MilestoneCard = node as MilestoneCard
		if mc.visible and mc.notification_mode:
			out.append(mc.name)
	for child: Node in node.get_children():
		out.append_array(_collect_visible_modal_names(child))
	return out
