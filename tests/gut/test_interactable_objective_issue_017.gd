## ISSUE-017: Interactable component + HUD objective text bound to store
## state. Verifies the StoreController <-> Interactable contract used by the
## StoreReadyContract objective_matches_action() invariant, and that the HUD
## ObjectiveLabel mirrors current_objective_text within a frame.
extends GutTest


const STORE_ID: StringName = &"sneaker_citadel"


var _store: Node
var _shelf: Interactable


func before_each() -> void:
	_store = Node.new()
	_store.set_script(load("res://game/scripts/stores/store_controller.gd"))
	_store.name = "SneakerCitadel"
	(_store as StoreController).initialize_store(STORE_ID, STORE_ID)
	add_child_autofree(_store)

	_shelf = Interactable.new()
	_shelf.name = "Shelf"
	_shelf.interaction_type = Interactable.InteractionType.SHELF_SLOT
	_shelf.display_name = "interactable shelf"
	_shelf.action_verb = "Interact"
	_store.add_child(_shelf)
	# StoreController auto-collects on _ready; for nodes added after _ready
	# the public register_interactable() must be called.
	(_store as StoreController).register_interactable(_shelf)


func test_action_verb_is_exposed() -> void:
	assert_eq(
		_shelf.action_verb, "Interact",
		"Interactable.action_verb should be settable and readable"
	)


func test_interactable_is_in_plural_group() -> void:
	assert_true(
		_shelf.is_in_group(&"interactables"),
		"Interactable should join the 'interactables' group used by StoreReadyContract"
	)


func test_count_visible_interactables_returns_one_for_shelf() -> void:
	var ctrl: StoreController = _store as StoreController
	assert_eq(
		ctrl.count_visible_interactables(), 1,
		"Sneaker Citadel should report one visible interactable shelf"
	)


func test_count_excludes_hidden_interactables() -> void:
	_shelf.visible = false
	var ctrl: StoreController = _store as StoreController
	assert_eq(
		ctrl.count_visible_interactables(), 0,
		"Hidden interactables must not count toward visible total"
	)


func test_objective_match_passes_when_text_references_action() -> void:
	var ctrl: StoreController = _store as StoreController
	ctrl.set_objective_text("Interact with the shelf")
	assert_true(
		ctrl.objective_matches_action(),
		"Objective text mentioning verb + subject should match a registered interactable"
	)


func test_objective_match_fails_when_verb_absent() -> void:
	var ctrl: StoreController = _store as StoreController
	ctrl.set_objective_text("Wander around the mall")
	assert_false(
		ctrl.objective_matches_action(),
		"Objective text with no matching verb should fail the contract"
	)


func test_objective_match_fails_when_no_interactables() -> void:
	_shelf.queue_free()
	await get_tree().process_frame
	var ctrl: StoreController = _store as StoreController
	# Replace internal registration to clear stale ref.
	ctrl._registered_interactables.clear()
	ctrl.set_objective_text("Interact with the shelf")
	assert_false(
		ctrl.objective_matches_action(),
		"Objective should not match once no interactables remain"
	)


func test_hud_objective_label_updates_within_one_frame() -> void:
	var hud: CanvasLayer = (
		load("res://game/scenes/ui/hud.tscn") as PackedScene
	).instantiate() as CanvasLayer
	add_child_autofree(hud)
	await get_tree().process_frame

	var ctrl: StoreController = _store as StoreController
	ctrl.set_objective_text("Interact with the shelf")
	await get_tree().process_frame

	var label: Label = hud.get_node("ObjectiveLabel") as Label
	assert_eq(
		label.text, "Interact with the shelf",
		"HUD ObjectiveLabel should mirror StoreController.current_objective_text"
	)
	assert_true(
		label.visible,
		"HUD ObjectiveLabel should be visible when objective text is non-empty"
	)
