## Tests that the HUD scene parents the ToastNotificationUI to a CanvasLayer
## with a layer value sandwiched between the passive HUD/rail and the modal
## dim overlay so toasts pop above persistent chrome but never cover modals.
extends GutTest


const HUD_SCENE_PATH: String = "res://game/scenes/ui/hud.tscn"
const MODAL_DIM_LAYER: int = 49
const HUD_LAYER: int = 30
const RAIL_LAYER: int = 40

var _hud: CanvasLayer


func before_each() -> void:
	var scene: PackedScene = load(HUD_SCENE_PATH)
	assert_not_null(scene, "hud.tscn must load")
	if scene == null:
		return
	_hud = scene.instantiate() as CanvasLayer
	add_child_autofree(_hud)


func test_toast_lives_on_dedicated_canvas_layer() -> void:
	var toast_layer: CanvasLayer = _hud.get_node_or_null("ToastLayer") as CanvasLayer
	assert_not_null(
		toast_layer,
		"hud.tscn must wrap the toast in a dedicated ToastLayer CanvasLayer "
		+ "so its z-order is independent of the HUD CanvasLayer"
	)


func test_toast_layer_is_above_hud_and_rail() -> void:
	var toast_layer: CanvasLayer = _hud.get_node_or_null("ToastLayer") as CanvasLayer
	if toast_layer == null:
		return
	assert_gt(
		toast_layer.layer, HUD_LAYER,
		"Toast layer must sit above the passive HUD (layer %d)" % HUD_LAYER
	)
	assert_gt(
		toast_layer.layer, RAIL_LAYER,
		"Toast layer must sit above the objective rail (layer %d)" % RAIL_LAYER
	)


func test_toast_layer_is_below_modal_dim_overlay() -> void:
	var toast_layer: CanvasLayer = _hud.get_node_or_null("ToastLayer") as CanvasLayer
	if toast_layer == null:
		return
	assert_lt(
		toast_layer.layer, MODAL_DIM_LAYER,
		(
			"Toast layer must sit below the modal dim overlay (layer %d) so "
			+ "open modals always sit on top of any momentary toast"
		) % MODAL_DIM_LAYER,
	)


func test_toast_ui_is_child_of_toast_layer() -> void:
	var toast_layer: CanvasLayer = _hud.get_node_or_null("ToastLayer") as CanvasLayer
	if toast_layer == null:
		return
	var toast_ui: Node = toast_layer.get_node_or_null("ToastNotificationUI")
	assert_not_null(
		toast_ui,
		"ToastNotificationUI must be parented under ToastLayer"
	)
	assert_true(
		toast_ui is ToastNotificationUI,
		"Child node must carry the ToastNotificationUI script"
	)
