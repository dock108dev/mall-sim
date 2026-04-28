## Unit tests for StoreReadyContract — one test per invariant proving it both
## passes (on a fully-wired fixture) and fails (on a fixture missing exactly
## that piece). Also covers the aggregate behaviour: failures list every
## failed invariant, not just the first.
extends GutTest

const StoreReadyContractScript: GDScript = preload("res://game/scripts/stores/store_ready_contract.gd")
const StoreReadyResultScript: GDScript = preload("res://game/scripts/stores/store_ready_result.gd")


## Minimal root that implements the contract hooks. Invariants are toggleable
## via exported-style fields so each test can knock out exactly one.
class FixtureRoot extends Node:
	var store_id: StringName = &"fixture_store"
	var controller_initialized: bool = true
	var input_context: StringName = &"store_gameplay"
	var blocking_modal: bool = false
	var objective_matches: bool = true

	func get_store_id() -> StringName:
		return store_id

	func is_controller_initialized() -> bool:
		return controller_initialized

	func get_input_context() -> StringName:
		return input_context

	func has_blocking_modal() -> bool:
		return blocking_modal

	func objective_matches_action() -> bool:
		return objective_matches


func _make_ready_scene() -> Node:
	var root: FixtureRoot = FixtureRoot.new()
	root.name = "StoreScene"
	add_child_autofree(root)

	# A non-scaffold direct child satisfies `content_instantiated`.
	var content: Node3D = Node3D.new()
	content.name = "Geometry"
	root.add_child(content)

	var camera: Camera3D = Camera3D.new()
	camera.name = "StoreCamera"
	camera.current = true
	root.add_child(camera)

	# `PlayerController` is one of the accepted presence anchors (along with
	# `Player` and `OrbitPivot`); see StoreReadyContract `_PLAYER_ANCHOR_NAMES`.
	var player: Node = Node.new()
	player.name = "PlayerController"
	root.add_child(player)

	var interactable: Node = Node.new()
	interactable.name = "Interactable"
	interactable.add_to_group(&"interactables")
	root.add_child(interactable)

	return root


func test_ready_scene_passes_all_invariants() -> void:
	var scene: Node = _make_ready_scene()
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_true(result.ok, "expected ok=true, failures=%s" % [result.failures])
	assert_eq(result.failures.size(), 0, "failures should be empty")
	assert_eq(result.reason, "READY")


func test_null_scene_fails_all_invariants() -> void:
	var result: StoreReadyResult = StoreReadyContractScript.check(null)
	assert_false(result.ok)
	assert_eq(result.failures.size(), StoreReadyContractScript.INVARIANTS.size(),
		"null scene should fail every invariant")


func test_detached_scene_fails_scene_loaded() -> void:
	var root: FixtureRoot = FixtureRoot.new()
	# NOT added to tree.
	var result: StoreReadyResult = StoreReadyContractScript.check(root)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_SCENE_LOADED))
	root.free()


func test_empty_store_id_fails() -> void:
	var scene: Node = _make_ready_scene()
	(scene as FixtureRoot).store_id = &""
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_STORE_ID))
	assert_false(result.failures.has(StoreReadyContractScript.INV_PLAYER),
		"other invariants should still pass")


func test_controller_not_initialized_fails() -> void:
	var scene: Node = _make_ready_scene()
	(scene as FixtureRoot).controller_initialized = false
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_CONTROLLER_INIT))


func test_only_scaffolding_fails_content_instantiated() -> void:
	# Strip every non-scaffold child so only camera + player anchor remain.
	var scene: Node = _make_ready_scene()
	for child in scene.get_children():
		if child is Camera3D or child.name == "PlayerController":
			continue
		scene.remove_child(child)
		child.free()
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_CONTENT))


func test_orbit_pivot_satisfies_player_present() -> void:
	# Orbit-cam stores (sports, electronics, pocket_creatures, video_rental)
	# use an OrbitPivot Marker3D in lieu of a walking PlayerController.
	var scene: Node = _make_ready_scene()
	var anchor: Node = scene.find_child("PlayerController", true, false)
	scene.remove_child(anchor)
	anchor.free()
	var pivot: Marker3D = Marker3D.new()
	pivot.name = "OrbitPivot"
	scene.add_child(pivot)
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.failures.has(StoreReadyContractScript.INV_PLAYER),
		"OrbitPivot must satisfy player_present invariant")


func test_camera_not_current_fails() -> void:
	var scene: Node = _make_ready_scene()
	var cam: Camera3D = scene.find_child("StoreCamera", true, false) as Camera3D
	cam.current = false
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_CAMERA))


func test_missing_camera_fails() -> void:
	var scene: Node = _make_ready_scene()
	var cam: Node = scene.find_child("StoreCamera", true, false)
	scene.remove_child(cam)
	cam.free()
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_CAMERA))


func test_missing_player_fails() -> void:
	var scene: Node = _make_ready_scene()
	var player: Node = scene.find_child("PlayerController", true, false)
	scene.remove_child(player)
	player.free()
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_PLAYER))


func test_wrong_input_context_fails() -> void:
	var scene: Node = _make_ready_scene()
	(scene as FixtureRoot).input_context = &"modal"
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_INPUT))


func test_blocking_modal_fails() -> void:
	var scene: Node = _make_ready_scene()
	(scene as FixtureRoot).blocking_modal = true
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_NO_MODAL))


func test_no_interactables_fails() -> void:
	var scene: Node = _make_ready_scene()
	var interactable: Node = scene.find_child("Interactable", true, false)
	scene.remove_child(interactable)
	interactable.free()
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_INTERACTIONS))


func test_objective_mismatch_fails() -> void:
	var scene: Node = _make_ready_scene()
	(scene as FixtureRoot).objective_matches = false
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_OBJECTIVE))


func test_multiple_failures_all_reported() -> void:
	var scene: Node = _make_ready_scene()
	var fixture: FixtureRoot = scene as FixtureRoot
	fixture.store_id = &""
	fixture.controller_initialized = false
	fixture.objective_matches = false
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.failures.has(StoreReadyContractScript.INV_STORE_ID))
	assert_true(result.failures.has(StoreReadyContractScript.INV_CONTROLLER_INIT))
	assert_true(result.failures.has(StoreReadyContractScript.INV_OBJECTIVE))
	assert_eq(result.failures.size(), 3, "all three failures, no phantoms")


func test_result_reason_lists_failures_when_not_ok() -> void:
	var scene: Node = _make_ready_scene()
	(scene as FixtureRoot).store_id = &""
	var result: StoreReadyResult = StoreReadyContractScript.check(scene)
	assert_false(result.ok)
	assert_true(result.reason.find("store_id_resolved") != -1,
		"reason should mention the failing invariant; got: %s" % result.reason)


func test_invariants_list_has_ten_entries() -> void:
	assert_eq(StoreReadyContractScript.INVARIANTS.size(), 10,
		"contract must enumerate exactly 10 invariants per ISSUE-007")


func test_result_constructor_duplicates_failures() -> void:
	# Mutating the passed-in array must not mutate the result.
	var src: Array[StringName] = [&"a", &"b"]
	var result: StoreReadyResult = StoreReadyResultScript.new(false, src, "r")
	src.clear()
	assert_eq(result.failures.size(), 2, "result should hold its own copy")
