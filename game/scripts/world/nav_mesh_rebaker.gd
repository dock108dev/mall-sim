## Deferred navigation mesh rebake on build mode exit when fixtures changed.
class_name NavMeshRebaker
extends Node

const REQUIRED_NAV_CELL_SIZE: float = 0.25

var _nav_region: NavigationRegion3D = null
var _is_baking: bool = false
var _fixtures_changed: bool = false
var _build_session_active: bool = false
var _pending_rebake: bool = false
var _spawning_paused_for_bake: bool = false


func _enter_tree() -> void:
	if not EventBus.build_mode_entered.is_connected(_on_build_mode_entered):
		EventBus.build_mode_entered.connect(_on_build_mode_entered)
	if not EventBus.build_mode_exited.is_connected(_on_build_mode_exited):
		EventBus.build_mode_exited.connect(_on_build_mode_exited)
	if not EventBus.fixture_placed.is_connected(_on_fixture_placed):
		EventBus.fixture_placed.connect(_on_fixture_placed)
	if not EventBus.fixture_removed.is_connected(_on_fixture_removed):
		EventBus.fixture_removed.connect(_on_fixture_removed)


func _exit_tree() -> void:
	if EventBus.build_mode_entered.is_connected(_on_build_mode_entered):
		EventBus.build_mode_entered.disconnect(_on_build_mode_entered)
	if EventBus.build_mode_exited.is_connected(_on_build_mode_exited):
		EventBus.build_mode_exited.disconnect(_on_build_mode_exited)
	if EventBus.fixture_placed.is_connected(_on_fixture_placed):
		EventBus.fixture_placed.disconnect(_on_fixture_placed)
	if EventBus.fixture_removed.is_connected(_on_fixture_removed):
		EventBus.fixture_removed.disconnect(_on_fixture_removed)
	_disconnect_nav_region()


## Sets the NavigationRegion3D to rebake.
func set_nav_region(region: NavigationRegion3D) -> void:
	_disconnect_nav_region()
	_nav_region = region
	if _nav_region and not _nav_region.bake_finished.is_connected(
		_on_bake_finished
	):
		_nav_region.bake_finished.connect(_on_bake_finished)


## Returns true while an async bake is in progress.
func is_baking() -> bool:
	return _is_baking


func _on_build_mode_entered() -> void:
	_build_session_active = true
	_fixtures_changed = false


func _on_build_mode_exited() -> void:
	if not _build_session_active:
		return
	_build_session_active = false

	var should_rebake: bool = _fixtures_changed
	_fixtures_changed = false
	if not should_rebake:
		return

	if not _has_valid_nav_region():
		return
	if _is_baking:
		_pending_rebake = true
		return
	_start_rebake()


func _on_fixture_placed(
	_fixture_id: String, _grid_pos: Vector2i, _rotation: int
) -> void:
	if not _build_session_active:
		return
	_fixtures_changed = true


func _on_fixture_removed(_fixture_id: String, _grid_pos: Vector2i) -> void:
	if not _build_session_active:
		return
	_fixtures_changed = true


func _start_rebake() -> void:
	_is_baking = true
	if not _spawning_paused_for_bake:
		_spawning_paused_for_bake = true
		EventBus.customer_spawning_disabled.emit()
	_request_bake()


func _on_bake_finished() -> void:
	_is_baking = false
	if _pending_rebake:
		_pending_rebake = false
		_start_rebake()
		return
	_spawning_paused_for_bake = false
	EventBus.customer_spawning_enabled.emit()
	EventBus.nav_mesh_baked.emit()


func _disconnect_nav_region() -> void:
	if _nav_region and _nav_region.bake_finished.is_connected(
		_on_bake_finished
	):
		_nav_region.bake_finished.disconnect(_on_bake_finished)
	_nav_region = null


func _request_bake() -> void:
	_nav_region.bake_navigation_mesh(true)


func _has_valid_nav_region() -> bool:
	if not _nav_region:
		push_warning("NavMeshRebaker: no NavigationRegion3D set")
		return false
	if _nav_region.navigation_mesh == null:
		push_warning("NavMeshRebaker: NavigationRegion3D has no NavigationMesh")
		return false
	if not is_equal_approx(
		_nav_region.navigation_mesh.cell_size,
		REQUIRED_NAV_CELL_SIZE
	):
		push_warning(
			"NavMeshRebaker: NavigationMesh cell_size must be %.2f"
			% REQUIRED_NAV_CELL_SIZE
		)
		return false
	var parsed_geometry_type: int = (
		_nav_region.navigation_mesh.geometry_parsed_geometry_type
	)
	if parsed_geometry_type not in [
		NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS,
		NavigationMesh.PARSED_GEOMETRY_BOTH,
	]:
		push_error(
			"NavMeshRebaker: NavigationMesh must parse StaticBody3D colliders"
		)
		return false
	return true
