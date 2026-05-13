## Tests for TutorialContextSystem context-entered emission semantics.
##
## Day-1 first-boot duplicate-render regression: store_entered followed by
## day_started must emit `tutorial_context_entered` exactly once for the
## first-step prompt, and a fresh subsequent day must still re-emit so the
## rail can refresh "what can I do now?" copy.
extends GutTest


const _STORE_ID: StringName = &"retro_games"

var _emitted: Array = []
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	TutorialContextSystem.clear_active_context()
	TutorialContextSystem.reload()
	_emitted.clear()
	EventBus.tutorial_context_entered.connect(_on_context_entered)


func after_each() -> void:
	if EventBus.tutorial_context_entered.is_connected(_on_context_entered):
		EventBus.tutorial_context_entered.disconnect(_on_context_entered)
	TutorialContextSystem.clear_active_context()
	TutorialContextSystem.reload()
	GameManager.current_state = _saved_state
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()


func _on_context_entered(
	store_id: StringName, context_id: StringName, prompt_text: String
) -> void:
	_emitted.append({
		"store_id": store_id,
		"context_id": context_id,
		"prompt_text": prompt_text,
	})


func test_store_entered_followed_by_day_started_emits_once() -> void:
	# Day 1 boot sequence: store_entered → morning note → day_started. The
	# context system should emit exactly once for the first-step prompt; the
	# day_started re-emit guard must drop the duplicate.
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)

	assert_eq(
		_emitted.size(), 1,
		"tutorial_context_entered must fire once across store_entered + day_started"
	)


func test_subsequent_day_started_re_emits_after_dedupe_consumed() -> void:
	# After the first day_started consumes the dedupe flag, a fresh
	# day_started (Day 2 still inside the same store) should re-emit so the
	# rail can refresh.
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)

	assert_eq(
		_emitted.size(), 2,
		"second day_started must re-emit after the dedupe flag is consumed"
	)


func test_re_entry_arms_dedupe_flag_again() -> void:
	# Exit the store and re-enter: the dedupe flag must be re-armed so the
	# next store_entered + day_started pair still emits exactly once.
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)
	EventBus.store_exited.emit(_STORE_ID)
	_emitted.clear()

	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(2)

	assert_eq(
		_emitted.size(), 1,
		"after store_exited + re-entry, the next store_entered + day_started must emit once"
	)


func test_day_started_without_active_context_does_not_emit() -> void:
	# Day starts before player enters a store: nothing to emit.
	EventBus.day_started.emit(1)
	assert_eq(
		_emitted.size(), 0,
		"day_started with no active context must not emit"
	)


func test_first_step_id_renamed_to_avoid_welcome_collision() -> void:
	# Fix 3: the retro_games first-step `id` was renamed from "welcome" to
	# "ctx_welcome" to eliminate ambiguity with TutorialSystem.STEP_IDS[WELCOME].
	TutorialContextSystem.reload()
	var first: Dictionary = TutorialContextSystem.get_first_step(_STORE_ID)
	assert_eq(
		String(first.get("id", "")),
		"ctx_welcome",
		"tutorial_contexts.json retro_games first step id must be 'ctx_welcome' to avoid collision with TutorialSystem WELCOME id 'welcome'"
	)


# ── Dedup gap regressions ───────────────────────────────────────────────────


func test_day_started_before_store_entered_does_not_suppress_next_day() -> void:
	# Restart-ordering regression: in the natural Day-1 boot path
	# (game_world.gd emits day_started(1) before _auto_enter_default_store_in_hub
	# triggers store_entered), day_started(1) hits the early-return branch
	# with active_context_id == "". Without the dedup-gate adjustment, the
	# subsequent store_entered raised `_context_shown_since_entry = true`,
	# and the Day-2 day_started silently consumed that stale gate and
	# skipped the re-emit. After the fix, the Day-2 re-emit must still fire.
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(2)

	assert_eq(
		_emitted.size(), 2,
		(
			"day_started(1) → store_entered → day_started(2) must produce two emissions"
			+ " (Day 1 entry + Day 2 re-emit); the Day 2 re-emit was being eaten"
			+ " by a stale dedup gate raised by store_entered"
		)
	)


func test_reload_clears_dedup_gate_between_test_cases() -> void:
	# `reload()` is the documented test seam for re-parsing JSON between
	# cases. It must also reset the dedup state — without it,
	# `_context_shown_since_entry` could carry over from the prior test and
	# silently drop the next test's first day_started re-emit.
	EventBus.store_entered.emit(_STORE_ID)
	# At this point the dedup gate is armed; if reload() did NOT clear it,
	# the day_started below would consume-and-return without emitting.
	TutorialContextSystem.clear_active_context()
	TutorialContextSystem.reload()
	_emitted.clear()

	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)

	assert_eq(
		_emitted.size(), 2,
		(
			"after reload() between cases, the next store_entered/day_started"
			+ " sequence must dedupe normally (1 emit for entry, then re-emit"
			+ " on Day 2)"
		)
	)


func test_modal_queue_busy_suppresses_tutorial_context_emission() -> void:
	# BRAINDUMP §4.4: "letter first, tutorial unlock popup after letter
	# closes — no tutorial text appears behind the Vic letter." Open a
	# BetaManagerNotePanel through ModalQueue at VIC_NOTE priority and then
	# fire a tutorial trigger (store_entered). With ModalQueue.is_busy()
	# folded into is_tutorial_rendering_allowed(), the emission is
	# suppressed and the tutorial does not stack on top of the Vic letter.
	var panel: BetaManagerNotePanel = BetaManagerNotePanel.new()
	add_child_autofree(panel)
	panel.show_note("Sample Vic note body for ModalQueue suppression test.")
	assert_true(
		ModalQueue.is_busy(),
		"BetaManagerNotePanel.show_note must mark the queue as busy"
	)

	EventBus.store_entered.emit(_STORE_ID)

	assert_eq(
		_emitted.size(), 0,
		(
			"tutorial_context_entered must NOT emit while a higher-priority"
			+ " ModalQueue panel (Vic letter) is active"
		)
	)
	assert_eq(
		ModalQueue.pending_count(), 0,
		"no tutorial panel should be queued behind the Vic letter — depth must remain 1 (active only)"
	)
	assert_same(
		ModalQueue.active_panel(), panel,
		"the Vic letter must remain the sole active modal in the queue"
	)

	# After the Vic letter dismisses, ModalQueue is idle again. A fresh
	# store_entered now emits normally.
	panel.close()
	EventBus.store_entered.emit(_STORE_ID)
	assert_eq(
		_emitted.size(), 1,
		(
			"once the Vic letter dismisses and the queue drains, a fresh"
			+ " store_entered must emit tutorial_context_entered as usual"
		)
	)


func test_clean_restart_path_produces_single_emission() -> void:
	# Clean restart path: store_exited → store_entered → day_started must
	# produce exactly one tutorial_context_entered emission per AC.
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)
	# Establish dirty state from a prior day; then exit cleanly.
	EventBus.store_exited.emit(_STORE_ID)
	_emitted.clear()

	EventBus.store_entered.emit(_STORE_ID)
	EventBus.day_started.emit(1)

	assert_eq(
		_emitted.size(), 1,
		(
			"clean-restart path (store_exited → store_entered → day_started)"
			+ " must produce exactly one tutorial_context_entered emission"
		)
	)
