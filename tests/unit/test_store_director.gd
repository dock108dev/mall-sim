## Unit tests for StoreDirector autoload (ISSUE-008).
## Covers:
##   - unknown store_id failure path (emits store_failed, returns false)
##   - happy path with a fixture store + mock SceneRouter (emits store_ready)
##   - concurrent enter_store rejection while a load is in flight
##   - state-machine AuditLog checkpoints fire for every transition
extends GutTest

const StoreDirectorScript: GDScript = preload("res://game/autoload/store_director.gd")
const StoreRegistryScript: GDScript = preload("res://game/autoload/store_registry.gd")
const AuditLogScript: GDScript = preload("res://game/autoload/audit_log.gd")
const StoreRegistryEntryScript: GDScript = preload(
	"res://game/autoload/store_registry_entry.gd"
)

var _director: Node
var _registry: Node
var _audit: Node


func before_each() -> void:
	_audit = AuditLogScript.new()
	add_child_autofree(_audit)
	_audit.clear()

	_registry = StoreRegistryScript.new()
	add_child_autofree(_registry)

	_director = StoreDirectorScript.new()
	add_child_autofree(_director)
	_director.set_registry_for_tests(_registry)
	_director.set_audit_for_tests(_audit)


# ---------- mock router ----------------------------------------------------

class MockRouter extends Node:
	signal scene_ready(target: StringName, payload: Dictionary)
	signal scene_failed(target: StringName, reason: String)

	var should_fail: bool = false
	var fail_reason: String = "mock failure"
	var route_calls: Array[String] = []

	func route_to_path(scene_path: String, payload: Dictionary = {}) -> void:
		route_calls.append(scene_path)
		# Fire on the next frame so callers using `await` actually suspend.
		call_deferred("_emit_after_frame", scene_path, payload)

	func _emit_after_frame(scene_path: String, payload: Dictionary) -> void:
		await get_tree().process_frame
		if should_fail:
			scene_failed.emit(StringName(scene_path), fail_reason)
		else:
			scene_ready.emit(StringName(scene_path), payload)


# ---------- fixture store scene -------------------------------------------

class FixtureStoreScene extends Node:
	signal controller_ready

	var store_id: StringName = &"fixture_store"

	func _ready() -> void:
		# Deferred emit so a director awaiting `controller_ready` actually
		# suspends and resumes — emitting in _ready() before the await would
		# be missed.
		call_deferred("emit_signal", "controller_ready")

	func get_store_id() -> StringName:
		return store_id

	func is_controller_initialized() -> bool:
		return true

	func get_input_context() -> StringName:
		return &"store_gameplay"

	func has_blocking_modal() -> bool:
		return false

	func objective_matches_action() -> bool:
		return true


func _build_fixture_scene() -> FixtureStoreScene:
	var root: FixtureStoreScene = FixtureStoreScene.new()
	root.name = "FixtureStoreScene"
	add_child_autofree(root)

	var content: Node = Node.new()
	content.name = "StoreContent"
	root.add_child(content)
	var prop: Node = Node.new()
	prop.name = "Shelf"
	content.add_child(prop)

	var camera: Camera3D = Camera3D.new()
	camera.name = "StoreCamera"
	camera.current = true
	root.add_child(camera)

	var player: Node = Node.new()
	player.name = "Player"
	root.add_child(player)

	var interactable: Node = Node.new()
	interactable.name = "Interactable"
	interactable.add_to_group(&"interactables")
	root.add_child(interactable)

	return root


# ---------- tests ----------------------------------------------------------

func test_unknown_store_id_fails_loud() -> void:
	var router: MockRouter = MockRouter.new()
	add_child_autofree(router)
	_director.set_router_for_tests(router)

	var failures: Array = []
	_director.store_failed.connect(
		func(sid: StringName, reason: String) -> void:
			failures.append([sid, reason])
	)

	var ok: bool = await _director.enter_store(&"unknown")
	assert_false(ok, "enter_store(unknown) must return false")
	assert_eq(failures.size(), 1, "exactly one store_failed emission expected")
	assert_eq(failures[0][0], &"unknown")
	assert_string_contains(failures[0][1], "unknown store_id: unknown")
	assert_eq(router.route_calls.size(), 0,
		"router must not be called for unresolved store_id")


func test_happy_path_emits_store_ready_once() -> void:
	var router: MockRouter = MockRouter.new()
	add_child_autofree(router)
	_director.set_router_for_tests(router)

	_registry.register(StoreRegistryEntryScript.new(
		&"fixture_store",
		"res://test/fixture_store.tscn",
		null,
		"Fixture",
		{}
	))

	var fixture: FixtureStoreScene = _build_fixture_scene()
	_director.set_scene_provider_for_tests(func() -> Node: return fixture)

	var ready_emissions: Array = []
	_director.store_ready.connect(
		func(sid: StringName) -> void: ready_emissions.append(sid)
	)

	var ok: bool = await _director.enter_store(&"fixture_store")
	assert_true(ok, "enter_store(fixture_store) must return true on READY")
	assert_eq(ready_emissions.size(), 1, "store_ready must fire exactly once")
	assert_eq(ready_emissions[0], &"fixture_store")
	assert_eq(_director.state, StoreDirectorScript.State.IDLE,
		"director should return to IDLE after READY so subsequent calls are accepted")
	assert_eq(router.route_calls.size(), 1)
	assert_eq(router.route_calls[0], "res://test/fixture_store.tscn")


func test_concurrent_enter_store_is_rejected() -> void:
	var router: MockRouter = MockRouter.new()
	add_child_autofree(router)
	_director.set_router_for_tests(router)

	_registry.register(StoreRegistryEntryScript.new(
		&"fixture_store",
		"res://test/fixture_store.tscn",
		null,
		"Fixture",
		{}
	))

	var fixture: FixtureStoreScene = _build_fixture_scene()
	_director.set_scene_provider_for_tests(func() -> Node: return fixture)

	var failures: Array = []
	_director.store_failed.connect(
		func(sid: StringName, reason: String) -> void:
			failures.append([sid, reason])
	)

	# Kick off the first call but DO NOT await — it stays in flight.
	var first_call: Signal = _director.store_ready
	_director.enter_store(&"fixture_store")
	# Try to start a second one while the first is still mid-flight.
	var second_ok: bool = await _director.enter_store(&"fixture_store")
	assert_false(second_ok, "second enter_store must be rejected")
	assert_true(failures.size() >= 1, "rejected call must emit store_failed")
	assert_string_contains(failures[0][1], "rejected")
	# Drain the first call so the test ends in a clean state.
	await first_call


func test_state_transitions_emit_audit_checkpoints() -> void:
	var router: MockRouter = MockRouter.new()
	add_child_autofree(router)
	_director.set_router_for_tests(router)

	_registry.register(StoreRegistryEntryScript.new(
		&"fixture_store",
		"res://test/fixture_store.tscn",
		null,
		"Fixture",
		{}
	))
	var fixture: FixtureStoreScene = _build_fixture_scene()
	_director.set_scene_provider_for_tests(func() -> Node: return fixture)

	var checkpoints: Array[StringName] = []
	_audit.checkpoint_passed.connect(
		func(cp: StringName, _detail: String) -> void: checkpoints.append(cp)
	)

	var ok: bool = await _director.enter_store(&"fixture_store")
	assert_true(ok)
	for expected in [
		&"director_state_requested",
		&"director_state_loading_scene",
		&"director_state_instantiating",
		&"director_state_verifying",
		&"director_state_ready",
	]:
		assert_true(checkpoints.has(expected),
			"expected AuditLog checkpoint %s in %s" % [expected, checkpoints])


func test_unknown_id_emits_failed_state_audit_checkpoint() -> void:
	var router: MockRouter = MockRouter.new()
	add_child_autofree(router)
	_director.set_router_for_tests(router)

	var failed_checkpoints: Array[StringName] = []
	_audit.checkpoint_failed.connect(
		func(cp: StringName, _reason: String) -> void: failed_checkpoints.append(cp)
	)

	await _director.enter_store(&"unknown")
	assert_true(failed_checkpoints.has(&"director_state_failed"),
		"failed transition must emit director_state_failed checkpoint")
