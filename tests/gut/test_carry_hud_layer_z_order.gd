## Tests that the BetaCarryLabel renders above the ObjectiveRail.
##
## Regression: the label was previously created lazily as a direct child of
## the HUD CanvasLayer (layer 30), which placed it behind the ObjectiveRail
## (layer 40) and the InteractionPrompt (layer 60). Wrapping the label in a
## dedicated CarryHUD CanvasLayer at layer 41 puts it above the rail while
## staying below the toast layer (45) and modal dim overlay (49).
extends GutTest


const HUD_SCENE_PATH: String = "res://game/scenes/ui/hud.tscn"
const HUD_LAYER: int = 30
const RAIL_LAYER: int = 40
const TOAST_LAYER: int = 45
const MODAL_DIM_LAYER: int = 49

var _hud: CanvasLayer


func before_each() -> void:
	var scene: PackedScene = load(HUD_SCENE_PATH)
	assert_not_null(scene, "hud.tscn must load")
	if scene == null:
		return
	_hud = scene.instantiate() as CanvasLayer
	add_child_autofree(_hud)


func test_carry_hud_lives_on_dedicated_canvas_layer() -> void:
	var carry_layer: CanvasLayer = _hud.get_node_or_null("CarryHUD") as CanvasLayer
	assert_not_null(
		carry_layer,
		"hud.tscn must wrap BetaCarryLabel in a dedicated CarryHUD CanvasLayer "
		+ "so its z-order is independent of the HUD CanvasLayer"
	)


func test_carry_hud_layer_is_above_hud_and_rail() -> void:
	var carry_layer: CanvasLayer = _hud.get_node_or_null("CarryHUD") as CanvasLayer
	if carry_layer == null:
		return
	assert_gt(
		carry_layer.layer, HUD_LAYER,
		"CarryHUD layer must sit above the passive HUD (layer %d)" % HUD_LAYER
	)
	assert_gt(
		carry_layer.layer, RAIL_LAYER,
		(
			"CarryHUD layer must sit above the objective rail (layer %d) so the "
			+ "carry indicator is not occluded by the bottom-strip rail"
		) % RAIL_LAYER
	)


func test_carry_hud_layer_is_below_toast_and_modal_layers() -> void:
	var carry_layer: CanvasLayer = _hud.get_node_or_null("CarryHUD") as CanvasLayer
	if carry_layer == null:
		return
	assert_lt(
		carry_layer.layer, TOAST_LAYER,
		(
			"CarryHUD must sit below the toast layer (%d) so toast cards are not "
			+ "covered by a persistent indicator"
		) % TOAST_LAYER
	)
	assert_lt(
		carry_layer.layer, MODAL_DIM_LAYER,
		(
			"CarryHUD must sit below the modal dim overlay (%d) so open modals "
			+ "always read above the carry indicator"
		) % MODAL_DIM_LAYER
	)


func test_beta_carry_label_is_child_of_carry_hud() -> void:
	var carry_layer: CanvasLayer = _hud.get_node_or_null("CarryHUD") as CanvasLayer
	if carry_layer == null:
		return
	var label: Label = carry_layer.get_node_or_null("BetaCarryLabel") as Label
	assert_not_null(
		label,
		"BetaCarryLabel must be parented under CarryHUD"
	)
	if label == null:
		return
	assert_false(
		label.visible,
		"BetaCarryLabel must default to hidden until the player picks up stock"
	)
	assert_eq(
		label.text, "",
		"BetaCarryLabel must default to empty text"
	)
