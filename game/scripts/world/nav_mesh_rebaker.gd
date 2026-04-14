## Deferred navigation mesh rebake on build mode exit when fixtures changed.
class_name NavMeshRebaker
extends Node

var _nav_region: NavigationRegion3D = null
var _is_baking: bool = false
var _fixtures_changed: bool = false


func _ready() -> void:
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.fixture_placed.connect(_on_fixture_placed)
	EventBus.fixture_removed.connect(_on_fixture_removed)


## Sets the NavigationRegion3D to rebake.
func set_nav_region(region: NavigationRegion3D) -> void:
	if _nav_region and _nav_region.bake_finished.is_connected(
		_on_bake_finished
	):
		_nav_region.bake_finished.disconnect(_on_bake_finished)
	_nav_region = region
	if _nav_region:
		_nav_region.bake_finished.connect(_on_bake_finished)


## Returns true while an async bake is in progress.
func is_baking() -> bool:
	return _is_baking


func _on_build_mode_entered() -> void:
	_fixtures_changed = false


func _on_build_mode_exited() -> void:
	if not _fixtures_changed:
		return
	if not _nav_region:
		push_error("NavMeshRebaker: no NavigationRegion3D set")
		return
	_start_rebake()


func _on_fixture_placed(
	_fixture_id: String, _grid_pos: Vector2i, _rotation: int
) -> void:
	_fixtures_changed = true


func _on_fixture_removed(_fixture_id: String, _grid_pos: Vector2i) -> void:
	_fixtures_changed = true


func _start_rebake() -> void:
	_is_baking = true
	EventBus.customer_spawning_disabled.emit()
	_nav_region.bake_navigation_mesh()


func _on_bake_finished() -> void:
	_is_baking = false
	_fixtures_changed = false
	EventBus.customer_spawning_enabled.emit()
	EventBus.nav_mesh_baked.emit()
