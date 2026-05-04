## Verifies the F3 debug overlay surfaces the active store id alongside
## the inventory line so DX can confirm which store the player is in.
extends GutTest


const _OverlayScene: PackedScene = preload(
	"res://game/scenes/debug/debug_overlay.tscn"
)

var _saved_active_store_id: StringName
var _saved_current_store_id: StringName


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func before_each() -> void:
	var ssm: StoreStateManager = GameManager.get_store_state_manager()
	if ssm != null:
		_saved_active_store_id = ssm.active_store_id
	_saved_current_store_id = GameManager.current_store_id


func after_each() -> void:
	var ssm: StoreStateManager = GameManager.get_store_state_manager()
	if ssm != null:
		ssm.active_store_id = _saved_active_store_id
	GameManager.current_store_id = _saved_current_store_id


func _make_overlay() -> CanvasLayer:
	var overlay: CanvasLayer = _OverlayScene.instantiate()
	add_child_autofree(overlay)
	return overlay


func test_overlay_shows_active_store_when_set() -> void:
	var ssm: StoreStateManager = GameManager.get_store_state_manager()
	if ssm == null:
		# StoreStateManager only exists once GameWorld tier 2 has run; fall
		# back to the GameManager mirror so the test still proves the field
		# is rendered.
		GameManager.current_store_id = &"retro_games"
	else:
		ssm.active_store_id = &"retro_games"

	var overlay: CanvasLayer = _make_overlay()
	var text: String = overlay.call("_build_display_text") as String
	assert_true(
		text.contains("ActiveStore: retro_games"),
		"Debug overlay must surface ActiveStore field with the canonical id"
	)


func test_overlay_shows_none_when_no_store_active() -> void:
	var ssm: StoreStateManager = GameManager.get_store_state_manager()
	if ssm == null:
		GameManager.current_store_id = &""
	else:
		ssm.active_store_id = &""
		GameManager.current_store_id = &""

	var overlay: CanvasLayer = _make_overlay()
	var text: String = overlay.call("_build_display_text") as String
	assert_true(
		text.contains("ActiveStore: none"),
		"Debug overlay must render 'none' when no store is active"
	)


func test_active_store_line_appears_adjacent_to_inventory() -> void:
	var overlay: CanvasLayer = _make_overlay()
	var text: String = overlay.call("_build_display_text") as String
	var lines: PackedStringArray = text.split("\n")

	var active_idx: int = -1
	var inventory_idx: int = -1
	for i: int in range(lines.size()):
		if lines[i].begins_with("ActiveStore:"):
			active_idx = i
		elif lines[i].begins_with("Inventory"):
			inventory_idx = i

	assert_ne(active_idx, -1, "Overlay must emit an ActiveStore line")
	assert_ne(inventory_idx, -1, "Overlay must emit an Inventory line")
	assert_eq(
		inventory_idx - active_idx,
		1,
		"ActiveStore line must sit immediately above the Inventory line"
	)
