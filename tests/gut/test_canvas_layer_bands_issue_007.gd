## ISSUE-007: Verify each tracked CanvasLayer ships with the explicit
## `layer = N` value from the band table in
## docs/research/canvas-layer-z-order-conflicts.md so that z-intent
## no longer depends on scene-tree order.
extends GutTest


const _BANDS: Dictionary = {
	"res://game/scenes/world/game_world.tscn": {"name": "UILayer", "layer": 5},
	"res://game/scenes/mall/mall_hub.tscn": {"name": "HubLayer", "layer": 20},
	"res://game/scenes/ui/hud.tscn": {"name": "HUD", "layer": 30},
	"res://game/scenes/ui/objective_rail.tscn": {"name": "ObjectiveRail", "layer": 40},
	"res://game/scenes/ui/tutorial_overlay.tscn": {"name": "TutorialOverlay", "layer": 50},
	"res://game/scenes/ui/interaction_prompt.tscn": {"name": "InteractionPrompt", "layer": 60},
	"res://game/scenes/ui/inventory_panel.tscn": {"name": "InventoryPanel", "layer": 70},
	"res://game/scenes/ui/pause_menu.tscn": {"name": "PauseMenu", "layer": 90},
	"res://game/scenes/ui/crt_overlay.tscn": {"name": "CRTOverlay", "layer": 110},
}


func test_each_canvas_layer_matches_band_table() -> void:
	for path in _BANDS.keys():
		var info: Dictionary = _BANDS[path]
		var src: String = FileAccess.get_file_as_string(path)
		assert_ne(src, "", "%s must be readable" % path)
		var node_marker: String = '[node name="%s" type="CanvasLayer"' % info["name"]
		assert_true(
			src.contains(node_marker),
			"%s must declare CanvasLayer node %s" % [path, info["name"]]
		)
		var layer_marker: String = "layer = %d" % info["layer"]
		assert_true(
			src.contains(layer_marker),
			(
				"%s must set %s explicitly to %d (band table); not the engine default"
				% [path, info["name"], info["layer"]]
			)
		)


func test_no_layer_collisions_in_band_table() -> void:
	var seen: Dictionary = {}
	for path in _BANDS.keys():
		var info: Dictionary = _BANDS[path]
		var layer: int = info["layer"]
		assert_false(
			seen.has(layer),
			(
				"layer %d collides between %s and %s"
				% [layer, seen.get(layer, ""), path]
			)
		)
		seen[layer] = path


func test_ui_layers_constants_match_band_table() -> void:
	var script_path: String = "res://game/scripts/ui/ui_layers.gd"
	assert_true(
		ResourceLoader.exists(script_path),
		"ui_layers.gd constants file must exist"
	)
	var src: String = FileAccess.get_file_as_string(script_path)
	for token in [
		"WORLDSPACE: int = 5",
		"HUB_CHROME: int = 20",
		"HUD: int = 30",
		"RAIL: int = 40",
		"TUTORIAL: int = 50",
		"WORLD_PROMPT: int = 60",
		"DRAWER: int = 70",
		"PAUSE: int = 90",
		"POST_FX: int = 110",
	]:
		assert_true(
			src.contains(token),
			"ui_layers.gd must declare const matching '%s'" % token
		)
