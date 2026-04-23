## ISSUE-015: MallHub Sneaker Citadel tile + StoreDirector handoff.
##
## Verifies the new wiring without booting the full mall_hub.tscn (which
## instances GameWorld and dozens of unrelated systems). We attach
## mall_hub.gd to a bare Node, inject a mock StoreDirector, and exercise the
## activation path directly.
extends GutTest

const MallHubScript: GDScript = preload("res://game/scenes/mall/mall_hub.gd")


class MockStoreDirector extends Node:
	signal store_ready(store_id: StringName)
	signal store_failed(store_id: StringName, reason: String)

	var enter_store_calls: Array[StringName] = []
	var should_fail: bool = false
	var fail_reason: String = "mock failure"

	func enter_store(store_id: StringName) -> bool:
		enter_store_calls.append(store_id)
		if should_fail:
			store_failed.emit(store_id, fail_reason)
			return false
		store_ready.emit(store_id)
		return true


var _hub: Node
var _director: MockStoreDirector


func before_each() -> void:
	_hub = MallHubScript.new()
	_director = MockStoreDirector.new()
	add_child_autofree(_director)
	# Skip _ready by not parenting the hub to the tree — _ready uses @onready
	# nodes from mall_hub.tscn that don't exist on a bare Node.
	_hub.set_director_for_tests(_director)


func after_each() -> void:
	_hub.free()


func test_activate_calls_store_director_enter_store_with_sneaker_citadel() -> void:
	_hub.activate_sneaker_citadel()
	assert_eq(_director.enter_store_calls.size(), 1,
		"activate must call director exactly once")
	assert_eq(_director.enter_store_calls[0], &"sneaker_citadel",
		"activation must pass the sneaker_citadel store_id")


func test_constant_store_id_is_sneaker_citadel() -> void:
	assert_eq(MallHubScript.SNEAKER_CITADEL_ID, &"sneaker_citadel",
		"hub must target the registered sneaker_citadel store_id")


func test_activation_with_no_director_does_not_crash() -> void:
	_hub.set_director_for_tests(null)
	# Without a parented tree there's no StoreDirector autoload available
	# either, so this exercises the null-guard path.
	_hub.activate_sneaker_citadel()
	# No director was injected and the hub isn't parented (so no autoload
	# lookup either) — activate_sneaker_citadel must push_error and return,
	# not crash. Reaching this assertion proves the no-crash contract.
	assert_true(true, "activate_sneaker_citadel no-ops without a director")


func test_input_focus_constant_matches_autoload_context() -> void:
	# The hub pushes InputFocus.CTX_MALL_HUB on _ready; the autoload exposes
	# the canonical StringName. This guards against a literal drift.
	assert_eq(InputFocus.CTX_MALL_HUB, &"mall_hub",
		"InputFocus.CTX_MALL_HUB must remain &\"mall_hub\"")
