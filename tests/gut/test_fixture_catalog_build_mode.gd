## Tests for FixtureCatalog build mode entry and exit transitions.
extends GutTest


const _CatalogScene: PackedScene = preload(
	"res://game/scenes/ui/fixture_catalog.tscn"
)

var _catalog: FixtureCatalog


func before_each() -> void:
	_catalog = _CatalogScene.instantiate() as FixtureCatalog
	_catalog.data_loader = DataLoader.new()
	add_child_autofree(_catalog.data_loader)
	add_child_autofree(_catalog)


func test_build_mode_enter_opens_catalog_after_delay() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(
		FixtureCatalog.BUILD_MODE_OPEN_DELAY + 0.05
	).timeout
	assert_true(_catalog.is_open())
	assert_true(_catalog._panel.visible)


func test_build_mode_exit_closes_catalog() -> void:
	_catalog.open()
	EventBus.build_mode_exited.emit()
	assert_false(_catalog.is_open())


func test_rapid_build_mode_toggle_keeps_catalog_closed() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().create_timer(
		FixtureCatalog.BUILD_MODE_OPEN_DELAY * 0.5
	).timeout
	EventBus.build_mode_exited.emit()
	await get_tree().create_timer(
		FixtureCatalog.BUILD_MODE_OPEN_DELAY + 0.05
	).timeout
	assert_false(_catalog.is_open())
	assert_false(_catalog._panel.visible)
	assert_eq(_catalog._panel.position.x, _catalog._rest_x)
