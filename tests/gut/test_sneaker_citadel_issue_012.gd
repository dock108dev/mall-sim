## ISSUE-012: Sneaker Citadel vertical-slice store scene.
##
## Instantiates the authored scene, lets _ready wire the controller, and
## asserts the full StoreReadyContract (all 10 invariants) plus the shelf
## interaction signal the acceptance criteria call out.
extends GutTest


const STORE_ID: StringName = &"sneaker_citadel"
const SCENE_PATH: String = (
	"res://game/scenes/stores/sneaker_citadel/store_sneaker_citadel.tscn"
)


var _scene_root: Node


func before_each() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(packed, "PackedScene must load from SCENE_PATH")
	_scene_root = packed.instantiate()
	add_child_autofree(_scene_root)
	# Let _ready, the Interactable's group registration, and the controller's
	# camera/objective wiring all run before asserting the contract.
	await get_tree().process_frame


func test_registry_resolves_to_authored_scene() -> void:
	var path: String = StoreRegistry.resolve_scene(STORE_ID)
	assert_eq(path, SCENE_PATH,
		"StoreRegistry.resolve_scene(sneaker_citadel) must return the authored path")


func test_root_reports_store_id() -> void:
	assert_true(_scene_root.has_method("get_store_id"),
		"scene root must expose get_store_id()")
	assert_eq(_scene_root.call("get_store_id"), STORE_ID)


func test_required_unique_name_nodes_exist() -> void:
	assert_not_null(_scene_root.get_node_or_null("%StoreContent"),
		"%StoreContent must be unique-named on the scene root")
	assert_not_null(_scene_root.get_node_or_null("%StoreCamera"),
		"%StoreCamera must be unique-named on the scene root")
	assert_not_null(_scene_root.get_node_or_null("%Player"),
		"%Player must be unique-named on the scene root")
	assert_not_null(_scene_root.get_node_or_null("%EntryMarker"),
		"%EntryMarker must be unique-named on the scene root")


func test_store_content_has_counter_and_three_shelves() -> void:
	var content: Node = _scene_root.get_node("%StoreContent")
	assert_not_null(content.get_node_or_null("Counter"),
		"%StoreContent must include a Counter child")
	assert_not_null(content.get_node_or_null("Shelf1"))
	assert_not_null(content.get_node_or_null("Shelf2"))
	assert_not_null(content.get_node_or_null("Shelf3"))
	assert_not_null(content.get_node_or_null("InteractableShelf"),
		"%StoreContent must include the InteractableShelf")


func test_store_camera_is_current() -> void:
	var cam: Camera3D = _scene_root.get_node("%StoreCamera") as Camera3D
	assert_not_null(cam)
	assert_true(cam.current, "%StoreCamera must be the current viewport camera")


func test_store_ready_contract_passes() -> void:
	var result: StoreReadyResult = StoreReadyContract.check(_scene_root)
	assert_true(result.ok,
		"StoreReadyContract must return ok=true. failures=%s reason=%s"
		% [result.failures, result.reason])
	assert_eq(result.failures.size(), 0)


func test_interactable_shelf_emits_signal_on_interact() -> void:
	var shelf: Interactable = (
		_scene_root.get_node("%StoreContent/InteractableShelf") as Interactable
	)
	assert_not_null(shelf, "InteractableShelf must be an Interactable")
	watch_signals(shelf)
	shelf.interact(_scene_root.get_node("%Player"))
	assert_signal_emitted(shelf, "interacted",
		"shelf must emit 'interacted' when the player triggers it")
	assert_signal_emitted(shelf, "interacted_by",
		"shelf must emit 'interacted_by' carrying the actor")


func test_objective_text_references_real_interactable() -> void:
	var ctrl: StoreController = _scene_root as StoreController
	assert_false(ctrl.current_objective_text.is_empty(),
		"controller must set a non-empty objective on _ready")
	assert_true(ctrl.objective_matches_action(),
		"objective_matches_action() must find a matching registered shelf")
