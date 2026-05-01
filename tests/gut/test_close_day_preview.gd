## Verifies the Close Day preview modal is wired between the HUD button
## and EventBus.day_close_requested for the Day 1 end-to-end loop.
extends GutTest


const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)
const _PreviewScene: PackedScene = preload(
	"res://game/scenes/ui/close_day_preview.tscn"
)

var _saved_state: GameManager.State
var _saved_day: int


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_day = GameManager.get_current_day()
	GameState.reset_new_game()
	GameManager.set_current_day(1)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.set_current_day(_saved_day)
	GameState.reset_new_game()


func test_preview_scene_loads_with_required_nodes() -> void:
	var preview: CanvasLayer = _PreviewScene.instantiate()
	add_child_autofree(preview)
	assert_not_null(
		preview.get_node_or_null("Control/Overlay"),
		"Preview must have Control/Overlay ColorRect"
	)
	assert_not_null(
		preview.get_node_or_null("Control/Panel"),
		"Preview must have Control/Panel container"
	)
	assert_not_null(
		preview.get_node_or_null(
			"Control/Panel/Margin/VBox/ButtonRow/CancelButton"
		),
		"Preview must expose CancelButton"
	)
	assert_not_null(
		preview.get_node_or_null(
			"Control/Panel/Margin/VBox/ButtonRow/ConfirmButton"
		),
		"Preview must expose ConfirmButton"
	)
	assert_false(
		preview.visible,
		"Preview must start hidden until show_preview() is called"
	)


func test_hud_instances_close_day_preview() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	var preview: Node = hud.get_node_or_null("CloseDayPreview")
	assert_not_null(
		preview, "HUD scene must instance CloseDayPreview as a child"
	)


func test_pressing_close_day_opens_preview_after_first_sale() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.current_state = GameManager.State.STORE_VIEW
	GameState.set_flag(&"first_sale_complete", true)
	hud._on_close_day_pressed()
	var preview: CanvasLayer = hud.get_node("CloseDayPreview")
	assert_true(
		preview.visible,
		"Pressing Close Day after the gate releases must open the preview"
	)


func test_preview_confirm_emits_day_close_requested_once() -> void:
	var preview: CanvasLayer = _PreviewScene.instantiate()
	add_child_autofree(preview)
	# Wire an empty-snapshot callback so the show_preview() warning about
	# missing wiring (EH-05) does not fire from this confirm-flow unit test.
	preview.set_snapshot_callback(func() -> Array: return [])
	preview.show_preview()
	var emits: Array[bool] = []
	var on_close: Callable = func() -> void: emits.append(true)
	EventBus.day_close_requested.connect(on_close)
	preview._on_confirm_pressed()
	EventBus.day_close_requested.disconnect(on_close)
	assert_eq(
		emits.size(), 1,
		"Confirm must emit day_close_requested exactly once"
	)
	assert_false(preview.visible, "Confirm must hide the preview")


func test_preview_cancel_does_not_emit_day_close_requested() -> void:
	var preview: CanvasLayer = _PreviewScene.instantiate()
	add_child_autofree(preview)
	# Wire an empty-snapshot callback so the show_preview() warning about
	# missing wiring (EH-05) does not fire from this cancel-flow unit test.
	preview.set_snapshot_callback(func() -> Array: return [])
	preview.show_preview()
	var emits: Array[bool] = []
	var on_close: Callable = func() -> void: emits.append(true)
	EventBus.day_close_requested.connect(on_close)
	preview._on_cancel_pressed()
	EventBus.day_close_requested.disconnect(on_close)
	assert_eq(
		emits.size(), 0,
		"Cancel must not emit day_close_requested"
	)
	assert_false(preview.visible, "Cancel must hide the preview")


func test_close_day_preview_runs_with_empty_inventory() -> void:
	var preview: CanvasLayer = _PreviewScene.instantiate()
	add_child_autofree(preview)
	preview.set_snapshot_callback(func() -> Array: return [])
	preview.show_preview()
	# Empty snapshot -> dry-run returns no events -> confirm is enabled.
	var confirm_button: Button = preview.get_node(
		"Control/Panel/Margin/VBox/ButtonRow/ConfirmButton"
	)
	assert_false(
		confirm_button.disabled,
		"Empty inventory must not block the confirm button"
	)


func test_show_preview_uses_callback_snapshot() -> void:
	var preview: CanvasLayer = _PreviewScene.instantiate()
	add_child_autofree(preview)
	var captured: Array[bool] = []
	var callback: Callable = func() -> Array:
		captured.append(true)
		return []
	preview.set_snapshot_callback(callback)
	preview.show_preview()
	assert_eq(
		captured.size(), 1,
		"show_preview must invoke the snapshot callback exactly once per open"
	)
