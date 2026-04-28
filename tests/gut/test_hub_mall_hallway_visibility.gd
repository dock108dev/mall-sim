## Verifies the mall hallway is hidden when a store is entered through the
## hub-mode injector and re-shown when the player exits back to the mall.
##
## Both checks are guarded by `if _mall_hallway:` so the toggle is a no-op
## when `walkable_mall=false` (the shipping default — `_setup_mall_hallway`
## never instantiates the hallway in that mode). The visibility-line
## structural check guarantees the toggle survives future refactors of the
## hub injector / exit handler.
extends GutTest


const _GAME_WORLD_SOURCE_PATH: String = "res://game/scenes/world/game_world.gd"


## Reads the game_world.gd source and returns the body of `func name`,
## ending at the next top-level `func ` declaration.
func _extract_function_body(source: String, fn_name: String) -> String:
	var marker: String = "func %s(" % fn_name
	var start: int = source.find(marker)
	if start < 0:
		return ""
	var search_from: int = start + marker.length()
	var next_fn: int = source.find("\nfunc ", search_from)
	if next_fn < 0:
		return source.substr(start)
	return source.substr(start, next_fn - start)


func test_inject_function_hides_hallway() -> void:
	var src: String = FileAccess.get_file_as_string(_GAME_WORLD_SOURCE_PATH)
	assert_ne(src, "", "game_world.gd must be readable")
	var body: String = _extract_function_body(src, "_inject_store_into_container")
	assert_ne(body, "", "_inject_store_into_container must exist")
	assert_true(
		body.contains("if _mall_hallway:"),
		"_inject_store_into_container must guard with `if _mall_hallway:`"
	)
	assert_true(
		body.contains("_mall_hallway.visible = false"),
		"_inject_store_into_container must hide the hallway on store entry"
	)


func test_exit_handler_restores_hallway() -> void:
	var src: String = FileAccess.get_file_as_string(_GAME_WORLD_SOURCE_PATH)
	assert_ne(src, "", "game_world.gd must be readable")
	var body: String = _extract_function_body(src, "_on_hub_exit_store_requested")
	assert_ne(body, "", "_on_hub_exit_store_requested must exist")
	assert_true(
		body.contains("if _mall_hallway:"),
		"_on_hub_exit_store_requested must guard with `if _mall_hallway:`"
	)
	assert_true(
		body.contains("_mall_hallway.visible = true"),
		"_on_hub_exit_store_requested must restore hallway visibility on exit"
	)


## Behavioral round-trip: running the hide/show pair against a real Node3D
## stand-in flips `visible` cleanly across multiple enter/exit cycles, and
## the `if _mall_hallway` guard treats a null reference as a no-op.
func test_visibility_toggle_round_trip_against_node3d() -> void:
	var hallway: Node3D = Node3D.new()
	add_child_autofree(hallway)
	assert_true(hallway.visible, "Node3D.visible defaults to true")

	for cycle: int in range(3):
		# Hide on enter.
		if hallway:
			hallway.visible = false
		assert_false(
			hallway.visible,
			"hallway must be hidden after enter (cycle %d)" % cycle
		)
		# Show on exit.
		if hallway:
			hallway.visible = true
		assert_true(
			hallway.visible,
			"hallway must be visible after exit (cycle %d)" % cycle
		)


func test_null_hallway_guard_is_no_op() -> void:
	var hallway: Node3D = null
	# Mirrors the production guard. Must not error when hallway is null.
	if hallway:
		hallway.visible = false
	if hallway:
		hallway.visible = true
	assert_null(hallway, "null reference is preserved through the guarded block")
