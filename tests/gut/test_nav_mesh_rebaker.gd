## Tests for NavMeshRebaker signal wiring and rebake-skip logic.
extends GutTest


var _rebaker: NavMeshRebaker
var _baked_count: int = 0
var _spawning_disabled_count: int = 0
var _spawning_enabled_count: int = 0


func before_each() -> void:
	_baked_count = 0
	_spawning_disabled_count = 0
	_spawning_enabled_count = 0
	_rebaker = NavMeshRebaker.new()
	add_child_autofree(_rebaker)
	EventBus.nav_mesh_baked.connect(_on_nav_mesh_baked)
	EventBus.customer_spawning_disabled.connect(
		_on_spawning_disabled
	)
	EventBus.customer_spawning_enabled.connect(
		_on_spawning_enabled
	)


func after_each() -> void:
	if EventBus.nav_mesh_baked.is_connected(_on_nav_mesh_baked):
		EventBus.nav_mesh_baked.disconnect(_on_nav_mesh_baked)
	if EventBus.customer_spawning_disabled.is_connected(
		_on_spawning_disabled
	):
		EventBus.customer_spawning_disabled.disconnect(
			_on_spawning_disabled
		)
	if EventBus.customer_spawning_enabled.is_connected(
		_on_spawning_enabled
	):
		EventBus.customer_spawning_enabled.disconnect(
			_on_spawning_enabled
		)


func _on_nav_mesh_baked() -> void:
	_baked_count += 1


func _on_spawning_disabled() -> void:
	_spawning_disabled_count += 1


func _on_spawning_enabled() -> void:
	_spawning_enabled_count += 1


func test_initial_state_not_baking() -> void:
	assert_false(_rebaker.is_baking())


func test_skip_rebake_when_no_fixtures_changed() -> void:
	EventBus.build_mode_entered.emit()
	EventBus.build_mode_exited.emit()
	assert_false(_rebaker.is_baking())
	assert_eq(_spawning_disabled_count, 0)


func test_skip_rebake_when_no_nav_region() -> void:
	EventBus.build_mode_entered.emit()
	EventBus.fixture_placed.emit("shelf", Vector2i(1, 2), 0)
	EventBus.build_mode_exited.emit()
	assert_false(_rebaker.is_baking())
	assert_eq(_spawning_disabled_count, 0)


func test_fixtures_changed_flag_resets_on_enter() -> void:
	EventBus.fixture_placed.emit("shelf", Vector2i(1, 2), 0)
	EventBus.build_mode_entered.emit()
	EventBus.build_mode_exited.emit()
	assert_eq(_spawning_disabled_count, 0)


func test_fixture_placed_sets_changed() -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = NavigationMesh.new()
	add_child_autofree(region)
	_rebaker.set_nav_region(region)

	EventBus.build_mode_entered.emit()
	EventBus.fixture_placed.emit("shelf", Vector2i(1, 2), 0)
	EventBus.build_mode_exited.emit()
	assert_true(_rebaker.is_baking())
	assert_eq(_spawning_disabled_count, 1)


func test_fixture_removed_sets_changed() -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = NavigationMesh.new()
	add_child_autofree(region)
	_rebaker.set_nav_region(region)

	EventBus.build_mode_entered.emit()
	EventBus.fixture_removed.emit("shelf", Vector2i(1, 2))
	EventBus.build_mode_exited.emit()
	assert_true(_rebaker.is_baking())
	assert_eq(_spawning_disabled_count, 1)


func test_bake_finished_emits_signals() -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = NavigationMesh.new()
	add_child_autofree(region)
	_rebaker.set_nav_region(region)

	EventBus.build_mode_entered.emit()
	EventBus.fixture_placed.emit("shelf", Vector2i(1, 2), 0)
	EventBus.build_mode_exited.emit()

	region.bake_finished.emit()
	assert_false(_rebaker.is_baking())
	assert_eq(_spawning_enabled_count, 1)
	assert_eq(_baked_count, 1)


func test_no_double_rebake_without_new_changes() -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = NavigationMesh.new()
	add_child_autofree(region)
	_rebaker.set_nav_region(region)

	EventBus.build_mode_entered.emit()
	EventBus.fixture_placed.emit("shelf", Vector2i(1, 2), 0)
	EventBus.build_mode_exited.emit()
	region.bake_finished.emit()

	EventBus.build_mode_entered.emit()
	EventBus.build_mode_exited.emit()
	assert_eq(_spawning_disabled_count, 1)
	assert_eq(_baked_count, 1)


func test_nav_mesh_baked_signal_exists() -> void:
	var received: bool = false
	var handler := func() -> void:
		received = true
	EventBus.nav_mesh_baked.connect(handler)
	EventBus.nav_mesh_baked.emit()
	assert_true(received)
	EventBus.nav_mesh_baked.disconnect(handler)


func test_customer_spawning_signals_exist() -> void:
	var disabled: bool = false
	var enabled: bool = false
	var d_handler := func() -> void:
		disabled = true
	var e_handler := func() -> void:
		enabled = true
	EventBus.customer_spawning_disabled.connect(d_handler)
	EventBus.customer_spawning_enabled.connect(e_handler)
	EventBus.customer_spawning_disabled.emit()
	EventBus.customer_spawning_enabled.emit()
	assert_true(disabled)
	assert_true(enabled)
	EventBus.customer_spawning_disabled.disconnect(d_handler)
	EventBus.customer_spawning_enabled.disconnect(e_handler)
