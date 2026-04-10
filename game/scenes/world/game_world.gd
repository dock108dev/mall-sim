## Root scene for the playable game world. Instantiates runtime systems and UI.
extends Node3D

const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)
const _InventoryPanelScene: PackedScene = preload(
	"res://game/scenes/ui/inventory_panel.tscn"
)
const _CheckoutPanelScene: PackedScene = preload(
	"res://game/scenes/ui/checkout_panel.tscn"
)
const _PricingPanelScene: PackedScene = preload(
	"res://game/scenes/ui/pricing_panel.tscn"
)
const _HagglePanelScene: PackedScene = preload(
	"res://game/scenes/ui/haggle_panel.tscn"
)
const _DaySummaryScene: PackedScene = preload(
	"res://game/scenes/ui/day_summary.tscn"
)
const _FixtureCatalogScene: PackedScene = preload(
	"res://game/scenes/ui/fixture_catalog.tscn"
)
const _MilestonePopupScene: PackedScene = preload(
	"res://game/scenes/ui/milestone_popup.tscn"
)
const _MilestonesPanelScene: PackedScene = preload(
	"res://game/scenes/ui/milestones_panel.tscn"
)
const _OrderPanelScene: PackedScene = preload(
	"res://game/scenes/ui/order_panel.tscn"
)
const _TrendsPanelScene: PackedScene = preload(
	"res://game/scenes/ui/trends_panel.tscn"
)
const _PauseMenuScene: PackedScene = preload(
	"res://game/scenes/ui/pause_menu.tscn"
)
const _SaveLoadPanelScene: PackedScene = preload(
	"res://game/scenes/ui/save_load_panel.tscn"
)
const _SettingsPanelScene: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)
const _PackOpeningPanelScene: PackedScene = preload(
	"res://game/scenes/ui/pack_opening_panel.tscn"
)
const _MallHallwayScene: PackedScene = preload(
	"res://game/scenes/world/mall_hallway.tscn"
)
const _StaffPanelScene: PackedScene = preload(
	"res://game/scenes/ui/staff_panel.tscn"
)
const _TutorialOverlayScene: PackedScene = preload(
	"res://game/scenes/ui/tutorial_overlay.tscn"
)
const _ItemTooltipScene: PackedScene = preload(
	"res://game/scenes/ui/item_tooltip.tscn"
)
const _VisualFeedbackScene: PackedScene = preload(
	"res://game/scenes/ui/visual_feedback.tscn"
)
const _EndingScreenScene: PackedScene = preload(
	"res://game/scenes/ui/ending_screen.tscn"
)
const _DebugOverlayScene: PackedScene = preload(
	"res://game/scenes/debug/debug_overlay.tscn"
)

var time_system: TimeSystem
var economy_system: EconomySystem
var inventory_system: InventorySystem
var customer_system: CustomerSystem
var mall_customer_spawner: MallCustomerSpawner
var reputation_system: ReputationSystem
var checkout_system: CheckoutSystem
var haggle_system: HaggleSystem
var save_manager: SaveManager
var build_mode: BuildMode
var fixture_placement: FixturePlacementSystem
var store_state_manager: StoreStateManager
var progression_system: ProgressionSystem
var trend_system: TrendSystem
var tournament_system: TournamentSystem
var meta_shift_system: MetaShiftSystem
var seasonal_event_system: SeasonalEventSystem
var random_event_system: RandomEventSystem
var staff_system: StaffSystem
var tutorial_system: TutorialSystem
var performance_manager: PerformanceManager
var secret_thread_manager: SecretThreadManager
var ambient_moments_system: AmbientMomentsSystem
var ending_evaluator: EndingEvaluator

var _inventory_panel: InventoryPanel
var _day_summary: DaySummary
var _fixture_catalog: FixtureCatalog
var _mall_hallway: MallHallway
var _pause_menu: PauseMenu
var _save_load_panel: SaveLoadPanel
var _settings_panel: SettingsPanel
var _pack_opening_panel: PackOpeningPanel
var _staff_panel: StaffPanel
var _tutorial_overlay: TutorialOverlay
var _item_tooltip: ItemTooltip
var _ending_screen: EndingScreen

@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _store_container: Node3D = $StoreContainer


func _ready() -> void:
	_setup_mall_hallway()
	_setup_systems()
	_setup_ui()
	_setup_build_mode()
	if _fixture_catalog:
		_fixture_catalog.placement_system = fixture_placement
	if _mall_hallway:
		_mall_hallway.set_systems(
			economy_system, reputation_system, inventory_system
		)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.storefront_entered.connect(_on_storefront_entered)
	EventBus.storefront_exited.connect(_on_storefront_exited)
	EventBus.all_milestones_completed.connect(
		_on_all_milestones_completed
	)
	_apply_pending_load.call_deferred()


func _setup_mall_hallway() -> void:
	_mall_hallway = _MallHallwayScene.instantiate() as MallHallway
	_store_container.add_child(_mall_hallway)


func _setup_systems() -> void:
	time_system = TimeSystem.new()
	time_system.name = "TimeSystem"
	add_child(time_system)
	time_system.initialize()

	economy_system = EconomySystem.new()
	economy_system.name = "EconomySystem"
	add_child(economy_system)
	economy_system.initialize()

	inventory_system = InventorySystem.new()
	inventory_system.name = "InventorySystem"
	add_child(inventory_system)
	inventory_system.initialize(GameManager.data_loader)

	economy_system.set_inventory_system(inventory_system)

	trend_system = TrendSystem.new()
	trend_system.name = "TrendSystem"
	add_child(trend_system)
	trend_system.initialize(GameManager.data_loader)
	economy_system.set_trend_system(trend_system)

	customer_system = CustomerSystem.new()
	customer_system.name = "CustomerSystem"
	add_child(customer_system)
	var store_ctrl: StoreController = _find_store_controller()
	customer_system.initialize(store_ctrl, inventory_system)
	if store_ctrl:
		customer_system.set_store_id(
			GameManager.current_store_id
		)

	reputation_system = ReputationSystem.new()
	reputation_system.name = "ReputationSystem"
	add_child(reputation_system)
	reputation_system.initialize()

	mall_customer_spawner = MallCustomerSpawner.new()
	mall_customer_spawner.name = "MallCustomerSpawner"
	add_child(mall_customer_spawner)
	mall_customer_spawner.initialize(
		customer_system, reputation_system, trend_system
	)

	economy_system.set_reputation_system(reputation_system)

	haggle_system = HaggleSystem.new()
	haggle_system.name = "HaggleSystem"
	add_child(haggle_system)

	checkout_system = CheckoutSystem.new()
	checkout_system.name = "CheckoutSystem"
	add_child(checkout_system)
	checkout_system.initialize(
		economy_system,
		inventory_system,
		customer_system,
		reputation_system
	)
	checkout_system.set_haggle_system(haggle_system)
	if store_ctrl:
		var reg: Area3D = store_ctrl.get_register_area()
		var ent: Area3D = store_ctrl.get_entry_area()
		if reg and ent:
			checkout_system.setup_queue_positions(
				reg.global_position, ent.global_position
			)

	store_state_manager = StoreStateManager.new()
	store_state_manager.name = "StoreStateManager"
	add_child(store_state_manager)
	store_state_manager.initialize(inventory_system, economy_system)

	progression_system = ProgressionSystem.new()
	progression_system.name = "ProgressionSystem"
	add_child(progression_system)
	progression_system.initialize(economy_system, reputation_system)

	tournament_system = TournamentSystem.new()
	tournament_system.name = "TournamentSystem"
	add_child(tournament_system)
	tournament_system.initialize(
		economy_system,
		reputation_system,
		customer_system,
		fixture_placement,
		GameManager.data_loader
	)

	meta_shift_system = MetaShiftSystem.new()
	meta_shift_system.name = "MetaShiftSystem"
	add_child(meta_shift_system)
	meta_shift_system.initialize(GameManager.data_loader)
	economy_system.set_meta_shift_system(meta_shift_system)

	seasonal_event_system = SeasonalEventSystem.new()
	seasonal_event_system.name = "SeasonalEventSystem"
	add_child(seasonal_event_system)
	seasonal_event_system.initialize(GameManager.data_loader)
	mall_customer_spawner.set_seasonal_event_system(
		seasonal_event_system
	)

	random_event_system = RandomEventSystem.new()
	random_event_system.name = "RandomEventSystem"
	add_child(random_event_system)
	random_event_system.initialize(
		GameManager.data_loader,
		inventory_system,
		reputation_system
	)

	staff_system = StaffSystem.new()
	staff_system.name = "StaffSystem"
	add_child(staff_system)
	staff_system.initialize(
		economy_system,
		reputation_system,
		inventory_system,
		GameManager.data_loader,
	)

	tutorial_system = TutorialSystem.new()
	tutorial_system.name = "TutorialSystem"
	add_child(tutorial_system)

	performance_manager = PerformanceManager.new()
	performance_manager.name = "PerformanceManager"
	add_child(performance_manager)
	performance_manager.initialize(economy_system)

	secret_thread_manager = SecretThreadManager.new()
	secret_thread_manager.name = "SecretThreadManager"
	add_child(secret_thread_manager)

	ambient_moments_system = AmbientMomentsSystem.new()
	ambient_moments_system.name = "AmbientMomentsSystem"
	add_child(ambient_moments_system)
	ambient_moments_system.initialize(
		secret_thread_manager, inventory_system, time_system
	)

	ending_evaluator = EndingEvaluator.new()
	ending_evaluator.name = "EndingEvaluator"
	add_child(ending_evaluator)
	ending_evaluator.initialize(
		progression_system, secret_thread_manager
	)

	save_manager = SaveManager.new()
	save_manager.name = "SaveManager"
	add_child(save_manager)
	save_manager.initialize(
		economy_system,
		inventory_system,
		time_system,
		reputation_system,
	)
	save_manager.set_store_state_manager(store_state_manager)
	save_manager.set_progression_system(progression_system)
	save_manager.set_trend_system(trend_system)
	save_manager.set_tournament_system(tournament_system)
	save_manager.set_meta_shift_system(meta_shift_system)
	save_manager.set_seasonal_event_system(seasonal_event_system)
	save_manager.set_random_event_system(random_event_system)
	save_manager.set_staff_system(staff_system)
	save_manager.set_tutorial_system(tutorial_system)
	save_manager.set_secret_thread_manager(secret_thread_manager)
	save_manager.set_ambient_moments_system(ambient_moments_system)
	save_manager.set_ending_evaluator(ending_evaluator)

	var initial_ctrl: StoreController = _find_store_controller()
	if initial_ctrl:
		_wire_rental_system(initial_ctrl)
		_wire_electronics_system(initial_ctrl)
		_wire_sports_memorabilia_system(initial_ctrl)


func _setup_ui() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	_ui_layer.add_child(hud)

	_inventory_panel = (
		_InventoryPanelScene.instantiate() as InventoryPanel
	)
	_inventory_panel.inventory_system = inventory_system
	_inventory_panel.store_id = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(_inventory_panel)

	var pricing_panel: PricingPanel = (
		_PricingPanelScene.instantiate() as PricingPanel
	)
	pricing_panel.inventory_system = inventory_system
	pricing_panel.economy_system = economy_system
	_ui_layer.add_child(pricing_panel)

	var checkout_panel: CheckoutPanel = (
		_CheckoutPanelScene.instantiate() as CheckoutPanel
	)
	_ui_layer.add_child(checkout_panel)
	checkout_system.set_checkout_panel(checkout_panel)

	var haggle_panel: HagglePanel = (
		_HagglePanelScene.instantiate() as HagglePanel
	)
	_ui_layer.add_child(haggle_panel)
	checkout_system.set_haggle_panel(haggle_panel)

	_day_summary = _DaySummaryScene.instantiate() as DaySummary
	_ui_layer.add_child(_day_summary)
	_day_summary.continue_pressed.connect(_on_day_summary_continue)

	_fixture_catalog = (
		_FixtureCatalogScene.instantiate() as FixtureCatalog
	)
	_fixture_catalog.data_loader = GameManager.data_loader
	_fixture_catalog.economy_system = economy_system
	_fixture_catalog.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(_fixture_catalog)

	var milestone_popup: MilestonePopup = (
		_MilestonePopupScene.instantiate() as MilestonePopup
	)
	_ui_layer.add_child(milestone_popup)

	var visual_feedback: VisualFeedback = (
		_VisualFeedbackScene.instantiate() as VisualFeedback
	)
	_ui_layer.add_child(visual_feedback)

	var milestones_panel: MilestonesPanel = (
		_MilestonesPanelScene.instantiate() as MilestonesPanel
	)
	milestones_panel.progression_system = progression_system
	_ui_layer.add_child(milestones_panel)

	var order_panel: OrderPanel = (
		_OrderPanelScene.instantiate() as OrderPanel
	)
	order_panel.economy_system = economy_system
	order_panel.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(order_panel)

	var trends_panel: TrendsPanel = (
		_TrendsPanelScene.instantiate() as TrendsPanel
	)
	trends_panel.trend_system = trend_system
	_ui_layer.add_child(trends_panel)

	_pause_menu = _PauseMenuScene.instantiate() as PauseMenu
	_ui_layer.add_child(_pause_menu)
	_pause_menu.save_pressed.connect(_on_pause_save_pressed)
	_pause_menu.settings_pressed.connect(_on_pause_settings_pressed)
	_pause_menu.return_to_menu_pressed.connect(
		_on_return_to_menu_pressed
	)

	_settings_panel = (
		_SettingsPanelScene.instantiate() as SettingsPanel
	)
	_ui_layer.add_child(_settings_panel)

	_save_load_panel = (
		_SaveLoadPanelScene.instantiate() as SaveLoadPanel
	)
	_save_load_panel.save_manager = save_manager
	_ui_layer.add_child(_save_load_panel)
	_save_load_panel.save_requested.connect(
		_on_save_slot_requested
	)
	_save_load_panel.load_requested.connect(
		_on_load_slot_requested
	)

	_pack_opening_panel = (
		_PackOpeningPanelScene.instantiate() as PackOpeningPanel
	)
	_ui_layer.add_child(_pack_opening_panel)

	_staff_panel = _StaffPanelScene.instantiate() as StaffPanel
	_staff_panel.staff_system = staff_system
	_staff_panel.economy_system = economy_system
	_staff_panel.reputation_system = reputation_system
	_ui_layer.add_child(_staff_panel)

	_tutorial_overlay = (
		_TutorialOverlayScene.instantiate() as TutorialOverlay
	)
	_tutorial_overlay.tutorial_system = tutorial_system
	_ui_layer.add_child(_tutorial_overlay)

	_item_tooltip = (
		_ItemTooltipScene.instantiate() as ItemTooltip
	)
	_item_tooltip.economy_system = economy_system
	_item_tooltip.inventory_system = inventory_system
	_ui_layer.add_child(_item_tooltip)

	_ending_screen = (
		_EndingScreenScene.instantiate() as EndingScreen
	)
	add_child(_ending_screen)
	_ending_screen.dismissed.connect(_on_ending_dismissed)

	var initial_ctrl: StoreController = _find_store_controller()
	if initial_ctrl:
		_wire_pack_system(initial_ctrl)

	_setup_debug_overlay()


func _setup_debug_overlay() -> void:
	if not OS.is_debug_build():
		return
	var overlay: CanvasLayer = _DebugOverlayScene.instantiate()
	overlay.time_system = time_system
	overlay.economy_system = economy_system
	overlay.inventory_system = inventory_system
	overlay.customer_system = customer_system
	overlay.mall_customer_spawner = mall_customer_spawner
	add_child(overlay)


func _setup_build_mode() -> void:
	build_mode = BuildMode.new()
	build_mode.name = "BuildMode"
	add_child(build_mode)

	var camera: Camera3D = get_viewport().get_camera_3d()
	var player_node: Node = _find_player_node(camera)
	if player_node and player_node.has_method("set_inventory_system"):
		player_node.set_inventory_system(inventory_system)
	var floor_center := Vector3(0.0, 0.05, 0.0)

	build_mode.initialize(
		camera,
		player_node,
		BuildModeGrid.StoreSize.SMALL,
		floor_center
	)

	# Entry zone at the bottom of the grid (highest y rows)
	var grid_size: Vector2i = build_mode.get_grid().grid_size
	var entry_edge_y: int = grid_size.y - 2

	fixture_placement = FixturePlacementSystem.new()
	fixture_placement.name = "FixturePlacementSystem"
	add_child(fixture_placement)
	fixture_placement.initialize(
		build_mode.get_grid(),
		inventory_system,
		economy_system,
		entry_edge_y
	)

	if GameManager.data_loader:
		fixture_placement.set_data_loader(GameManager.data_loader)

	build_mode.set_placement_system(fixture_placement)

	var nav_region: NavigationRegion3D = _find_nav_region()
	if nav_region:
		build_mode.set_nav_region(nav_region)

	_register_initial_fixtures()


func _find_player_node(camera: Camera3D) -> Node:
	if not camera:
		return null
	var parent: Node = camera.get_parent()
	if parent and parent.has_method("set_build_mode"):
		return parent
	return null


func _on_game_state_changed(
	_old_state: int, new_state: int
) -> void:
	var should_pause: bool = (
		new_state == GameManager.GameState.PAUSED
		or new_state == GameManager.GameState.BUILD
	)
	_set_systems_paused(should_pause)


func _find_store_controller() -> StoreController:
	var result: StoreController = (
		_find_store_controller_recursive(_store_container)
	)
	if not result:
		push_warning(
			"GameWorld: no StoreController found in StoreContainer"
		)
	return result


func _find_store_controller_recursive(
	node: Node
) -> StoreController:
	if node is StoreController:
		return node as StoreController
	for child: Node in node.get_children():
		var found: StoreController = (
			_find_store_controller_recursive(child)
		)
		if found:
			return found
	return null


func _on_day_ended(day: int) -> void:
	GameManager.change_state(GameManager.GameState.DAY_SUMMARY)
	var summary: Dictionary = economy_system.get_daily_summary()
	var warranty_rev: float = 0.0
	var warranty_claims: float = 0.0
	var store_ctrl: StoreController = _find_store_controller()
	if store_ctrl is ElectronicsStoreController:
		var elec: ElectronicsStoreController = (
			store_ctrl as ElectronicsStoreController
		)
		var wm: WarrantyManager = elec.get_warranty_manager()
		warranty_rev = wm.get_daily_warranty_revenue()
		warranty_claims = wm.get_daily_claim_costs()
	var seasonal_impact: String = ""
	if seasonal_event_system:
		seasonal_impact = seasonal_event_system.get_impact_summary()
	var discrepancy: float = 0.0
	if ambient_moments_system:
		discrepancy = ambient_moments_system.get_active_discrepancy()
	_day_summary.show_summary(
		day,
		summary.get("total_revenue", 0.0),
		summary.get("total_expenses", 0.0),
		summary.get("net_profit", 0.0),
		summary.get("items_sold", 0),
		summary.get("rent", 0.0),
		warranty_rev,
		warranty_claims,
		seasonal_impact,
		discrepancy,
	)


func _on_day_summary_continue() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
	time_system.advance_to_next_day()


func _find_nav_region() -> NavigationRegion3D:
	for child: Node in _store_container.get_children():
		var region: NavigationRegion3D = (
			_find_node_of_type(child, "NavigationRegion3D")
		)
		if region:
			return region as NavigationRegion3D
	return null


func _find_node_of_type(
	node: Node, type_name: String
) -> Node:
	if node.get_class() == type_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_of_type(child, type_name)
		if found:
			return found
	return null


func _register_initial_fixtures() -> void:
	var store_ctrl: StoreController = _find_store_controller()
	if not store_ctrl:
		push_warning(
			"GameWorld: cannot register fixtures — no store controller"
		)
		return

	var store_def: StoreDefinition = null
	if GameManager.data_loader:
		store_def = GameManager.data_loader.get_store(
			store_ctrl.store_type
		)
	if not store_def:
		push_warning(
			"GameWorld: cannot register fixtures — no store definition "
			+ "for '%s'" % store_ctrl.store_type
		)
		return

	var grid: BuildModeGrid = build_mode.get_grid()
	var col_offset: int = 1

	for i: int in range(store_def.fixtures.size()):
		var fix_data: Dictionary = store_def.fixtures[i]
		var fix_id: String = fix_data.get("id", "fixture_%d" % i)
		var fix_type: String = fix_data.get("type", "shelf")
		var is_register: bool = fix_type == "counter"
		var price: float = FixturePlacementSystem.FIXTURE_PRICES.get(
			fix_type, 0.0
		)

		var size: Vector2i = FixturePlacementSystem.FIXTURE_SIZES.get(
			fix_type, Vector2i(1, 1)
		)
		var row: int = (i / 3) * (size.y + 3)
		var col: int = col_offset
		col_offset += size.x + 3
		if col_offset + size.x > grid.grid_size.x:
			col_offset = 1

		var pos := Vector2i(col, row + 2)
		if not grid.is_valid_cell(pos):
			pos = Vector2i(
				clampi(col, 0, grid.grid_size.x - size.x),
				clampi(row + 2, 0, grid.grid_size.y - size.y - 2)
			)

		fixture_placement.register_existing_fixture(
			fix_id, fix_type, pos, 0, is_register, price
		)


func _on_storefront_entered(
	_slot_index: int, store_id: String
) -> void:
	if not _mall_hallway:
		return

	var old_store: String = GameManager.current_store_id
	if not old_store.is_empty() and store_state_manager:
		store_state_manager.save_store_state(old_store)

	GameManager.current_store_id = store_id
	EventBus.store_opened.emit(store_id)

	var store_ctrl: StoreController = _find_store_controller()
	if store_ctrl and store_state_manager:
		store_state_manager.restore_store_state(
			store_id, store_ctrl
		)

	if store_ctrl:
		customer_system.initialize(store_ctrl, inventory_system)
		customer_system.set_store_id(store_id)
		_wire_rental_system(store_ctrl)
		_wire_pack_system(store_ctrl)
		_wire_electronics_system(store_ctrl)
		_wire_sports_memorabilia_system(store_ctrl)


## Wires up a VideoRentalStoreController with system references if applicable.
func _wire_rental_system(store_ctrl: StoreController) -> void:
	if store_ctrl is VideoRentalStoreController:
		var rental: VideoRentalStoreController = (
			store_ctrl as VideoRentalStoreController
		)
		rental.set_inventory_system(inventory_system)
		rental.set_economy_system(economy_system)
		rental.set_reputation_system(reputation_system)
		save_manager.set_rental_system(rental)
		if _inventory_panel:
			_inventory_panel.rental_controller = rental


## Wires up a PocketCreaturesStoreController with pack and tournament systems.
func _wire_pack_system(store_ctrl: StoreController) -> void:
	if store_ctrl is PocketCreaturesStoreController:
		var pc_ctrl: PocketCreaturesStoreController = (
			store_ctrl as PocketCreaturesStoreController
		)
		pc_ctrl.initialize_pack_system(
			GameManager.data_loader, inventory_system
		)
		if tournament_system:
			pc_ctrl.set_tournament_system(tournament_system)
		if meta_shift_system:
			pc_ctrl.set_meta_shift_system(meta_shift_system)
		if _inventory_panel:
			_inventory_panel.pack_controller = pc_ctrl
			_inventory_panel.pack_opening_panel = (
				_pack_opening_panel
			)
	else:
		if _inventory_panel:
			_inventory_panel.pack_controller = null
			_inventory_panel.pack_opening_panel = null


## Wires up an ElectronicsStoreController with warranty manager.
func _wire_electronics_system(store_ctrl: StoreController) -> void:
	if store_ctrl is ElectronicsStoreController:
		var elec: ElectronicsStoreController = (
			store_ctrl as ElectronicsStoreController
		)
		elec.set_inventory_system(inventory_system)
		elec.set_economy_system(economy_system)
		checkout_system.set_warranty_manager(
			elec.get_warranty_manager()
		)
	else:
		checkout_system.set_warranty_manager(null)


## Wires up a SportsMemorabiliaController with season cycle system.
func _wire_sports_memorabilia_system(
	store_ctrl: StoreController,
) -> void:
	if store_ctrl is SportsMemorabiliaController:
		var sports: SportsMemorabiliaController = (
			store_ctrl as SportsMemorabiliaController
		)
		sports.initialize(time_system.current_day)
		var cycle: SeasonCycleSystem = sports.get_season_cycle()
		economy_system.set_season_cycle_system(cycle)
		save_manager.set_season_cycle_system(cycle)
		if _item_tooltip:
			_item_tooltip.season_cycle_system = cycle
	else:
		economy_system.set_season_cycle_system(null)
		save_manager.set_season_cycle_system(null)
		if _item_tooltip:
			_item_tooltip.season_cycle_system = null


func _on_storefront_exited() -> void:
	var leaving_store: String = GameManager.current_store_id
	if not leaving_store.is_empty() and store_state_manager:
		store_state_manager.save_store_state(leaving_store)
	GameManager.current_store_id = ""
	EventBus.store_closed.emit(leaving_store)


func _set_systems_paused(paused: bool) -> void:
	time_system.set_process(!paused)
	economy_system.set_process(!paused)
	inventory_system.set_process(!paused)
	customer_system.set_process(!paused)
	mall_customer_spawner.set_process(!paused)
	reputation_system.set_process(!paused)
	checkout_system.set_process(!paused)
	haggle_system.set_process(!paused)
	store_state_manager.set_process(!paused)
	progression_system.set_process(!paused)
	trend_system.set_process(!paused)
	tournament_system.set_process(!paused)
	meta_shift_system.set_process(!paused)
	seasonal_event_system.set_process(!paused)
	random_event_system.set_process(!paused)
	staff_system.set_process(!paused)
	tutorial_system.set_process(!paused)


func _apply_pending_load() -> void:
	var slot: int = GameManager.pending_load_slot
	GameManager.pending_load_slot = -1
	if slot >= 0:
		save_manager.load_game(slot)
	else:
		tutorial_system.initialize(true)
		EventBus.day_started.emit(1)


func _on_pause_save_pressed() -> void:
	_save_load_panel.open_save()


func _on_pause_settings_pressed() -> void:
	_settings_panel.open()


func _on_return_to_menu_pressed() -> void:
	GameManager.transition_to_menu()


func _on_save_slot_requested(slot: int) -> void:
	save_manager.save_game(slot)


func _on_load_slot_requested(slot: int) -> void:
	save_manager.load_game(slot)


func _on_all_milestones_completed() -> void:
	if ending_evaluator.has_ending_been_shown():
		return
	var ending_type: String = ending_evaluator.evaluate_ending()
	var ending_data: Dictionary = (
		ending_evaluator.get_ending_data(ending_type)
	)
	if ending_data.is_empty():
		push_warning(
			"GameWorld: no ending data for type '%s'" % ending_type
		)
		return
	ending_evaluator.record_ending(ending_type)
	_ending_screen.show_ending(ending_data)


func _on_ending_dismissed() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
