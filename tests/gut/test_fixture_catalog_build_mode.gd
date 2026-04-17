## Tests fixture catalog panel animation, filtering, and build mode selection flow.
extends GutTest

const _CatalogScene: PackedScene = preload(
	"res://game/scenes/ui/fixture_catalog.tscn"
)
const _CatalogScript := preload(
	"res://game/scripts/ui/fixture_catalog_panel.gd"
)

var _saved_game_state: GameManager.GameState
var _saved_store_id: StringName = &""
var _catalog
var _data_loader: DataLoader
var _economy_system: EconomySystem


func before_each() -> void:
	_saved_game_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.current_store_id = &"sports"

	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	add_child_autofree(_data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(1000.0)

	_catalog = _CatalogScene.instantiate()
	_catalog.data_loader = _data_loader
	_catalog.economy_system = _economy_system
	_catalog.store_type = &"sports"
	add_child_autofree(_catalog)


func after_each() -> void:
	GameManager.current_state = _saved_game_state
	GameManager.current_store_id = _saved_store_id


func test_build_mode_enter_opens_catalog_without_delay() -> void:
	EventBus.build_mode_entered.emit()
	await get_tree().process_frame
	assert_true(_catalog.is_open())
	assert_true(_catalog._panel.visible)


func test_retro_locked_fixture_is_grayed_out_with_tooltip() -> void:
	_catalog.store_type = &"retro_games"
	GameManager.current_store_id = &"retro_games"
	_catalog.open()

	var card: PanelContainer = _catalog._card_panels.get("repair_workbench") as PanelContainer
	var button: Button = _catalog._card_buttons.get("repair_workbench") as Button
	assert_not_null(card)
	assert_not_null(button)
	assert_true(button.disabled)
	assert_eq(card.modulate, _CatalogScript.LOCKED_COLOR)
	assert_string_contains(card.tooltip_text, "Reputation 15 required")
	assert_string_contains(card.tooltip_text, "Day 3 required")


func test_store_specific_fixtures_only_show_for_active_store() -> void:
	_catalog.store_type = &"sports"
	GameManager.current_store_id = &"sports"
	_catalog.open()

	assert_eq(_catalog._specific_grid.get_child_count(), 1)
	assert_not_null(_catalog._card_panels.get("authentication_station"))
	assert_null(_catalog._card_panels.get("testing_station"))


func test_selecting_fixture_emits_signal_and_enters_placement() -> void:
	var build_mode: BuildModeSystem = BuildModeSystem.new()
	add_child_autofree(build_mode)
	build_mode.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)

	var placement: FixturePlacementSystem = FixturePlacementSystem.new()
	add_child_autofree(placement)
	placement.initialize(
		build_mode.get_grid(), null, _economy_system, 8,
		BuildModeGrid.StoreSize.SMALL
	)
	placement.set_data_loader(_data_loader)
	build_mode.set_placement_system(placement)
	build_mode.enter_build_mode()

	_catalog.open()
	watch_signals(EventBus)
	var button: Button = _catalog._card_buttons.get("floor_rack") as Button
	assert_not_null(button)

	button.emit_signal("pressed")

	assert_signal_emitted(EventBus, "fixture_catalog_requested")
	assert_eq(build_mode.get_state(), BuildModeSystem.State.PLACEMENT)
	assert_eq(placement.get_selected_fixture_type(), "floor_rack")


func test_fixture_card_shows_sellback_and_icon_placeholder() -> void:
	_catalog.open()
	var card: PanelContainer = _catalog._card_panels.get("wall_shelf") as PanelContainer
	assert_not_null(card)
	var icon: Node = card.find_child("IconPlaceholder", true, false)
	assert_not_null(icon)
	var meta_label: Label = card.find_child("MetaLabel", true, false) as Label
	assert_not_null(meta_label)
	assert_string_contains(meta_label.text, "Slots: 4")
	assert_string_contains(meta_label.text, "Sell-back: $15")
