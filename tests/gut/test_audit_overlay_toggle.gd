## Verifies that AuditOverlay's F3 toggle does not mutate GameManager state.
extends GutTest


func before_each() -> void:
	DataLoaderSingleton.load_all()


func test_toggle_does_not_mutate_game_manager_state() -> void:
	var state_before: int = GameManager.current_state
	var store_before: StringName = GameManager.current_store_id
	var day_before: int = GameManager.current_day

	AuditOverlay.toggle()
	AuditOverlay.toggle()

	assert_eq(
		GameManager.current_state,
		state_before,
		"toggle must not change GameManager.current_state"
	)
	assert_eq(
		GameManager.current_store_id,
		store_before,
		"toggle must not change current_store_id"
	)
	assert_eq(
		GameManager.current_day,
		day_before,
		"toggle must not change current_day"
	)


func test_overlay_starts_hidden() -> void:
	assert_false(AuditOverlay.visible, "AuditOverlay must be hidden by default")


func test_toggle_changes_visibility() -> void:
	var was_visible: bool = AuditOverlay.visible
	AuditOverlay.toggle()
	assert_ne(AuditOverlay.visible, was_visible, "toggle must change visibility")
	AuditOverlay.toggle()
	assert_eq(AuditOverlay.visible, was_visible, "double toggle must restore original visibility")


func test_push_pop_modal_does_not_mutate_game_manager() -> void:
	var state_before: int = GameManager.current_state
	AuditOverlay.push_modal("test_modal")
	AuditOverlay.pop_modal()
	assert_eq(GameManager.current_state, state_before, "push/pop modal must not change GameManager state")


func test_report_interactable_does_not_mutate_game_manager() -> void:
	var state_before: int = GameManager.current_state
	AuditOverlay.report_interactable("test_node")
	assert_eq(GameManager.current_state, state_before, "report_interactable must not change GameManager state")
