## Tests for signal-driven build mode HUD, grid, and world tint transitions.
extends GutTest


var _grid: BuildModeGrid
var _transition: BuildModeTransition
var _overlay: BuildModeCellOverlay


func before_each() -> void:
	_grid = BuildModeGrid.new()
	add_child_autofree(_grid)
	_grid.initialize(BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)

	var validator: FixturePlacementValidator = FixturePlacementValidator.new()
	validator.setup(
		_grid.grid_size, 0, BuildModeGrid.StoreSize.SMALL
	)
	var placement: FixturePlacementSystem = FixturePlacementSystem.new()
	add_child_autofree(placement)
	placement.initialize(
		_grid, null, null, 0, BuildModeGrid.StoreSize.SMALL
	)
	_overlay = BuildModeCellOverlay.new()
	add_child_autofree(_overlay)
	_overlay.setup(_grid, validator, placement)
	_overlay.build_overlay()

	_transition = BuildModeTransition.new()
	add_child_autofree(_transition)


func test_build_mode_enter_shows_grid_from_signal() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().process_frame
	assert_true(_grid._mesh_instance.visible)
	assert_not_null(_grid._fade_tween)


func test_build_mode_exit_hides_grid_from_signal() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(0.1).timeout
	EventBus.build_mode_exited.emit()
	await get_tree().create_timer(
		PanelAnimator.BUILD_MODE_TRANSITION + 0.05
	).timeout
	assert_false(_grid._mesh_instance.visible)


func test_rapid_grid_reentry_preserves_partial_fade() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(0.1).timeout
	var mid_alpha: float = _grid._material.albedo_color.a
	EventBus.build_mode_exited.emit()
	EventBus.build_mode_entered.emit()
	await get_tree().process_frame
	assert_gt(mid_alpha, 0.0)
	assert_gt(
		_grid._material.albedo_color.a,
		0.0,
		"Rapid re-entry should resume from current alpha instead of resetting"
	)


func test_overlay_reentry_preserves_partial_fade() -> void:
	_overlay.fade(true)
	await get_tree().create_timer(0.1).timeout
	var mid_alpha: float = _overlay.overlay_alpha
	_overlay.fade(false)
	_overlay.fade(true)
	await get_tree().process_frame
	assert_gt(mid_alpha, 0.0)
	assert_gt(
		_overlay.overlay_alpha,
		0.0,
		"Overlay fade should resume from the current alpha on rapid re-entry"
	)


func test_build_mode_enter_shows_world_tint_overlay() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().process_frame
	assert_true(_transition._tint_rect.visible)


func test_build_mode_exit_hides_world_tint_overlay() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(0.1).timeout
	EventBus.build_mode_exited.emit()
	await get_tree().create_timer(
		PanelAnimator.BUILD_MODE_TRANSITION + 0.05
	).timeout
	assert_false(_transition._tint_rect.visible)
