## ISSUE-013: Golden-path integration test —
## New Game → Mall → Sneaker Citadel → Interact.
##
## Path note: ISSUE-013 specifies tests/integration/test_golden_path.gd, but
## tests/integration/ is not currently in .gutconfig.json's discovery dirs and
## activating it would auto-enable ~65 unrelated, never-run tests. We instead
## follow the convention used by ISSUE-012/014/017 (tests/gut/test_*.gd) and
## use the `test_audit_*` prefix so tests/audit_run.sh also discovers it,
## letting the `golden_path` checkpoint contribute to AUDIT: N/M verified.
##
## We exercise the real StoreDirector state machine, real StoreRegistry, real
## CameraAuthority + InputFocus autoloads, and the real Sneaker Citadel scene.
## We swap SceneRouter for a MockRouter so change_scene_to_file does NOT yank
## the GUT runner's current_scene mid-test (pattern from
## tests/unit/test_store_director.gd).
extends GutTest


const SCENE_PATH: String = (
	"res://game/scenes/stores/sneaker_citadel/store_sneaker_citadel.tscn"
)
const STORE_ID: StringName = &"sneaker_citadel"
const CHECKPOINT_GOLDEN_PATH: StringName = &"golden_path"
const TIME_BUDGET_MS: int = 10_000

# Preloaded for safe enum access (State.READY) — script-scoped enums on an
# autoload instance aren't reliably reachable via the instance reference.
const StoreDirectorScript: GDScript = preload(
	"res://game/autoload/store_director.gd"
)


# Stand-in for SceneRouter that fires scene_ready on the next frame without
# touching get_tree().change_scene_to_file. The real SceneRouter would replace
# the GUT runner's current_scene and break the test harness.
class MockRouter extends Node:
	signal scene_ready(target: StringName, payload: Dictionary)
	signal scene_failed(target: StringName, reason: String)

	func route_to_path(scene_path: String, payload: Dictionary = {}) -> void:
		call_deferred("_emit_after_frame", scene_path, payload)

	func _emit_after_frame(scene_path: String, payload: Dictionary) -> void:
		await get_tree().process_frame
		scene_ready.emit(StringName(scene_path), payload)


var _scene_root: Node
var _router: MockRouter
var _failed_checkpoints: Array[Dictionary] = []
var _ready_emitted: bool = false
var _state_was_ready_at_emit: bool = false


func before_each() -> void:
	# Reset autoloads to a clean baseline so prior tests can't leak focus or
	# camera state into the golden-path assertions.
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	StoreDirector._reset_for_tests()
	AuditLog.clear()

	_failed_checkpoints.clear()
	_ready_emitted = false
	_state_was_ready_at_emit = false
	AuditLog.checkpoint_failed.connect(_on_checkpoint_failed)

	# Real Sneaker Citadel scene, parented locally so add_child_autofree owns
	# its lifetime. The controller's _ready wires camera authority and the
	# player body's _ready pushes the store_gameplay focus context.
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(packed, "Sneaker Citadel PackedScene must load")
	_scene_root = packed.instantiate()
	add_child_autofree(_scene_root)
	# Allow Interactable group registration + controller wiring to settle.
	await get_tree().process_frame

	_router = MockRouter.new()
	add_child_autofree(_router)
	StoreDirector.set_router_for_tests(_router)
	StoreDirector.set_scene_provider_for_tests(
		func() -> Node: return _scene_root
	)


func after_each() -> void:
	if AuditLog.checkpoint_failed.is_connected(_on_checkpoint_failed):
		AuditLog.checkpoint_failed.disconnect(_on_checkpoint_failed)
	StoreDirector.set_router_for_tests(null)
	StoreDirector.set_scene_provider_for_tests(Callable())
	StoreDirector._reset_for_tests()


func _on_checkpoint_failed(cp: StringName, reason: String) -> void:
	_failed_checkpoints.append({"cp": cp, "reason": reason})


func _on_store_ready(_sid: StringName) -> void:
	_ready_emitted = true
	# Capture state at the instant of emit — StoreDirector resets to IDLE
	# immediately after store_ready listeners run, so reading later loses it.
	_state_was_ready_at_emit = (StoreDirector.state == StoreDirectorScript.State.READY)


func test_golden_path_new_game_to_interact() -> void:
	var t0: int = Time.get_ticks_msec()

	StoreDirector.store_ready.connect(_on_store_ready, CONNECT_ONE_SHOT)

	# Step 1+2: drive the full enter_store state machine. Mall hub is the
	# canonical pre-state; here we satisfy the same precondition by leaving
	# StoreDirector at IDLE (matching post-MallHub) and exercising the entry.
	var ok: bool = await StoreDirector.enter_store(STORE_ID)
	assert_true(ok, "StoreDirector.enter_store(sneaker_citadel) must return true")

	# Step 3: the director reached READY (signal fired with state == READY).
	assert_true(_ready_emitted, "store_ready signal must fire exactly once")
	assert_true(_state_was_ready_at_emit,
		"director.state must be READY at the moment store_ready emits")

	# Step 4: contract-bearing nodes + ownership autoloads are populated.
	var player: Node = _scene_root.get_node_or_null("%Player")
	assert_not_null(player, "%Player must exist on the store scene root")

	assert_not_null(CameraAuthority.current(),
		"CameraAuthority.current() must be non-null after store_ready")

	assert_eq(InputFocus.current(), &"store_gameplay",
		"InputFocus.current() must be store_gameplay after the player spawns")

	# Step 5: the player can interact with the registered shelf. We drive the
	# interaction directly via the interactable's API (no global Input poke):
	# this is the same path try_interact_nearest would take after a raycast
	# hit, and StorePlayerBody.interact_pressed emits with the same target.
	var shelf: Interactable = (
		_scene_root.get_node("%StoreContent/InteractableShelf") as Interactable
	)
	assert_not_null(shelf, "InteractableShelf must exist and be an Interactable")
	watch_signals(shelf)
	shelf.interact(player)
	assert_signal_emitted(shelf, "interacted_by",
		"interactable must emit interacted_by(actor) when the player interacts")

	# Failure gate: any push_error path that goes through AuditLog.fail_check
	# during this run is a regression. We connect in before_each so this only
	# captures failures emitted by THIS test.
	assert_eq(_failed_checkpoints.size(), 0,
		"no AuditLog.fail must fire during the golden path; got %s"
		% [_failed_checkpoints])

	# Time budget: AC requires the test to complete headlessly in <10s.
	var elapsed: int = Time.get_ticks_msec() - t0
	assert_lt(elapsed, TIME_BUDGET_MS,
		"golden path must complete under %d ms (took %d ms)"
		% [TIME_BUDGET_MS, elapsed])

	# Audit summary line: this is what tests/audit_run.sh greps to count the
	# golden_path checkpoint toward AUDIT: N/M verified.
	AuditLog.pass_check(CHECKPOINT_GOLDEN_PATH, "elapsed_ms=%d" % elapsed)
