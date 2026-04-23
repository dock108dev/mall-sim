## SneakerCitadelStoreController — Phase 1 vertical-slice store (ISSUE-012).
##
## Implements the five methods the StoreReadyContract duck-types on the scene
## root: `get_store_id`, `is_controller_initialized`, `get_input_context`,
## `has_blocking_modal`, `objective_matches_action` (inherited). The scene tree
## supplies the remaining invariants (`%Player`, `%StoreCamera`, `%StoreContent`
## children, ≥1 node in `interactables` group).
##
## On _ready: initializes shared store identity, lets StoreController wire its
## lifecycle signals via `super._ready()`, makes the `%StoreCamera` current via
## CameraAuthority (single-owner per `docs/architecture/ownership.md` row 3),
## and seeds an objective string that the contract's
## `objective_matches_action()` cross-checks against the real shelf.
##
## Parody-original content: "Sneaker Citadel" — no real brand references
## anywhere in this file or the matching scene.
class_name SneakerCitadelStoreController
extends StoreController

const STORE_ID: StringName = &"sneaker_citadel"
const INPUT_CTX_GAMEPLAY: StringName = &"store_gameplay"
const OBJECTIVE_TEXT: String = "Interact with the shelf to stock sneakers"

var _initialized: bool = false


func _ready() -> void:
	initialize_store(STORE_ID, STORE_ID)
	super._ready()
	_activate_camera()
	set_objective_text(OBJECTIVE_TEXT)
	_initialized = true


## StoreReadyContract INV_STORE_ID — the canonical id for this store.
func get_store_id() -> StringName:
	return STORE_ID


## StoreReadyContract INV_CONTROLLER_INIT — true once _ready has finished
## wiring and the camera/objective are in place. False during partial setup.
func is_controller_initialized() -> bool:
	return _initialized


## StoreReadyContract INV_INPUT — the gameplay focus context the player body
## pushes on InputFocus. The contract requires exactly `&"store_gameplay"`.
func get_input_context() -> StringName:
	return INPUT_CTX_GAMEPLAY


## StoreReadyContract INV_NO_MODAL — no in-scene modal steals input from the
## player. A future pause/inventory modal would flip this via the modal
## lifecycle; for the vertical slice it is constant false.
func has_blocking_modal() -> bool:
	return false


func _activate_camera() -> void:
	var cam: Node = get_node_or_null("%StoreCamera")
	if cam == null:
		push_error("SneakerCitadel: %StoreCamera node missing")
		return
	var authority: Node = _camera_authority()
	if authority != null and authority.has_method("request_current"):
		authority.call("request_current", cam, STORE_ID)
		return
	# Fallback when the autoload is absent (unit-test fixtures that don't spin
	# the full autoload set): set `current` directly. The contract inspects
	# the property, not the route taken to set it.
	if "current" in cam:
		cam.set("current", true)


func _camera_authority() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("CameraAuthority")
