## Tests for HUD build mode dimming transitions.
extends GutTest


const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _hud: CanvasLayer


func before_each() -> void:
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)


func test_build_mode_enter_dims_hud_children() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(
		PanelAnimator.BUILD_MODE_TRANSITION + 0.05
	).timeout
	var top_bar: CanvasItem = _hud.get_node("TopBar")
	var store_label: CanvasItem = _hud.get_node("StoreLabel")
	assert_almost_eq(top_bar.modulate.a, 0.5, 0.05)
	assert_almost_eq(store_label.modulate.a, 0.5, 0.05)


func test_build_mode_exit_restores_hud_children() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(0.1).timeout
	EventBus.build_mode_exited.emit()
	await get_tree().create_timer(
		PanelAnimator.BUILD_MODE_TRANSITION + 0.05
	).timeout
	var top_bar: CanvasItem = _hud.get_node("TopBar")
	assert_almost_eq(top_bar.modulate.a, 1.0, 0.05)
