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
	TutorialContextSystem.clear_active_context()
	_emitted.clear()
	EventBus.tutorial_context_entered.connect(_on_context_entered)


func after_each() -> void:
	if EventBus.tutorial_context_entered.is_connected(_on_context_entered):
		EventBus.tutorial_context_entered.disconnect(_on_context_entered)
	TutorialContextSystem.clear_active_context()
	GameManager.current_state = _saved_state
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
