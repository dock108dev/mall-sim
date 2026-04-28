## ISSUE-004: per-store tutorial context swaps on store_entered / store_exited
## and exposes context-appropriate first-step text.
extends GutTest


var _received: Array = []
var _saved_game_state: GameManager.State


func before_each() -> void:
	_saved_game_state = GameManager.current_state
	# TutorialContextSystem guards emission in MAIN_MENU / DAY_SUMMARY;
	# use STORE_VIEW so store_entered triggers fire normally in tests.
	GameManager.current_state = GameManager.State.STORE_VIEW
	DataLoaderSingleton.load_all()
	TutorialContextSystem.reload()
	TutorialContextSystem.clear_active_context()
	_received = []
	EventBus.tutorial_context_entered.connect(_capture_entered)
	EventBus.tutorial_context_cleared.connect(_capture_cleared)


func after_each() -> void:
	if EventBus.tutorial_context_entered.is_connected(_capture_entered):
		EventBus.tutorial_context_entered.disconnect(_capture_entered)
	if EventBus.tutorial_context_cleared.is_connected(_capture_cleared):
		EventBus.tutorial_context_cleared.disconnect(_capture_cleared)
	TutorialContextSystem.clear_active_context()
	GameManager.current_state = _saved_game_state


func _capture_entered(
	store_id: StringName, context_id: StringName, text: String
) -> void:
	_received.append({
		"event": "entered",
		"store_id": store_id,
		"context_id": context_id,
		"text": text,
	})


func _capture_cleared() -> void:
	_received.append({"event": "cleared"})


func _first_entered() -> Dictionary:
	for event: Dictionary in _received:
		if event.get("event") == "entered":
			return event
	return {}


func test_entering_sports_memorabilia_emits_sports_first_step() -> void:
	EventBus.store_entered.emit(StringName("sports"))
	var event: Dictionary = _first_entered()
	assert_eq(String(event.get("context_id", "")), "sports_memorabilia")
	var text: String = String(event.get("text", ""))
	assert_ne(text.strip_edges(), "", "sports_memorabilia should have first-step text")
	assert_true(
		text.to_lower().contains("backroom") or text.to_lower().contains("card"),
		"sports first step should reference backroom/cards, got: %s" % text
	)


func test_entering_retro_games_emits_retro_first_step() -> void:
	EventBus.store_entered.emit(StringName("retro_games"))
	var event: Dictionary = _first_entered()
	assert_eq(String(event.get("context_id", "")), "retro_games")
	var text: String = String(event.get("text", "")).to_lower()
	assert_true(
		text.contains("cart") or text.contains("test") or text.contains("refurb"),
		"retro_games first step should reference cart/test/refurb, got: %s" % text
	)


func test_entering_pocket_creatures_emits_pocket_first_step() -> void:
	EventBus.store_entered.emit(StringName("pocket_creatures"))
	var event: Dictionary = _first_entered()
	assert_eq(String(event.get("context_id", "")), "pocket_creatures")
	var text: String = String(event.get("text", "")).to_lower()
	assert_true(
		text.contains("service") or text.contains("pack") or text.contains("booster"),
		"pocket_creatures first step should reference packs/service, got: %s" % text
	)


func test_store_exited_clears_active_context() -> void:
	EventBus.store_entered.emit(StringName("retro_games"))
	assert_eq(String(TutorialContextSystem.active_context_id), "retro_games")
	EventBus.store_exited.emit(StringName("retro_games"))
	assert_eq(String(TutorialContextSystem.active_context_id), "")
	assert_eq(String(TutorialContextSystem.active_store_id), "")
	var saw_cleared: bool = false
	for event: Dictionary in _received:
		if event.get("event") == "cleared":
			saw_cleared = true
			break
	assert_true(saw_cleared, "tutorial_context_cleared should fire on exit")


func test_switching_stores_swaps_context() -> void:
	EventBus.store_entered.emit(StringName("sports"))
	EventBus.store_exited.emit(StringName("sports"))
	EventBus.store_entered.emit(StringName("retro_games"))
	assert_eq(String(TutorialContextSystem.active_context_id), "retro_games")


# ── is_tutorial_rendering_allowed() public API ───────────────────────────────


func test_is_tutorial_rendering_allowed_false_in_main_menu() -> void:
	GameManager.current_state = GameManager.State.MAIN_MENU
	assert_false(
		TutorialContextSystem.is_tutorial_rendering_allowed(),
		"Tutorial rendering must not be allowed in MAIN_MENU"
	)


func test_is_tutorial_rendering_allowed_false_in_mall_overview() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	assert_false(
		TutorialContextSystem.is_tutorial_rendering_allowed(),
		"Tutorial rendering must not be allowed in MALL_OVERVIEW"
	)


func test_is_tutorial_rendering_allowed_false_in_day_summary() -> void:
	GameManager.current_state = GameManager.State.DAY_SUMMARY
	assert_false(
		TutorialContextSystem.is_tutorial_rendering_allowed(),
		"Tutorial rendering must not be allowed in DAY_SUMMARY"
	)


func test_is_tutorial_rendering_allowed_false_when_modal_focused() -> void:
	GameManager.current_state = GameManager.State.STORE_VIEW
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		TutorialContextSystem.is_tutorial_rendering_allowed(),
		"Tutorial rendering must not be allowed while a modal has focus"
	)
	InputFocus.pop_context()


func test_is_tutorial_rendering_allowed_true_in_store_view() -> void:
	GameManager.current_state = GameManager.State.STORE_VIEW
	assert_true(
		TutorialContextSystem.is_tutorial_rendering_allowed(),
		"Tutorial rendering must be allowed in STORE_VIEW"
	)


func test_no_context_emission_in_mall_overview() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_received.clear()
	EventBus.store_entered.emit(StringName("retro_games"))
	var saw_entered: bool = false
	for event: Dictionary in _received:
		if event.get("event") == "entered":
			saw_entered = true
			break
	assert_false(
		saw_entered,
		"tutorial_context_entered must not fire while in MALL_OVERVIEW"
	)
