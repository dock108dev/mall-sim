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
const _MilestoneBannerScene: PackedScene = preload(
	"res://game/scenes/ui/milestone_banner.tscn"
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
const _UpgradePanelScene: PackedScene = preload(
	"res://game/scenes/ui/upgrade_panel.tscn"
)
const _AuthenticationDialogScene: PackedScene = preload(
	"res://game/scenes/ui/authentication_dialog.tscn"
)
const _RefurbishmentDialogScene: PackedScene = preload(
	"res://game/scenes/ui/refurbishment_dialog.tscn"
)
const _RefurbQueuePanelScene: PackedScene = preload(
	"res://game/scenes/ui/refurb_queue_panel.tscn"
)
const _DebugOverlayScene: PackedScene = preload(
	"res://game/scenes/debug/debug_overlay.tscn"
)

var reputation_system: ReputationSystem:
	get:
		return ReputationSystemSingleton

@onready var time_system: TimeSystem = $TimeSystem
@onready var economy_system: EconomySystem = $EconomySystem
@onready var inventory_system: InventorySystem = $InventorySystem
@onready var store_state_manager: StoreStateManager = $StoreStateManager
@onready var trend_system: TrendSystem = $TrendSystem
@onready var market_event_system: MarketEventSystem = $MarketEventSystem
@onready var seasonal_event_system: SeasonalEventSystem = (
	$SeasonalEventSystem
)
@onready var market_value_system: MarketValueSystem = $MarketValueSystem
@onready var customer_system: CustomerSystem = $CustomerSystem
@onready var mall_customer_spawner: MallCustomerSpawner = (
	$MallCustomerSpawner
)
@onready var npc_spawner_system: NPCSpawnerSystem = $NPCSpawnerSystem
@onready var haggle_system: HaggleSystem = $HaggleSystem
@onready var checkout_system: PlayerCheckout = $CheckoutSystem
@onready var queue_system: QueueSystem = $QueueSystem
@onready var progression_system: ProgressionSystem = $ProgressionSystem
@onready var milestone_system: MilestoneSystem = $MilestoneSystem
@onready var order_system: OrderSystem = $OrderSystem
@onready var staff_system: StaffSystem = $StaffSystem
@onready var store_selector_system: StoreSelectorSystem = (
	$StoreSelectorSystem
)
@onready var build_mode: BuildModeSystem = $BuildModeSystem
@onready var fixture_placement: FixturePlacementSystem = (
	$FixturePlacementSystem
)
@onready var tournament_system: TournamentSystem = $TournamentSystem
@onready var meta_shift_system: MetaShiftSystem = $MetaShiftSystem
@onready var tutorial_system: TutorialSystem = $TutorialSystem
@onready var performance_manager: PerformanceManager = $PerformanceManager
@onready var performance_report_system: PerformanceReportSystem = (
	$PerformanceReportSystem
)
@onready var random_event_system: RandomEventSystem = $RandomEventSystem
@onready var secret_thread_manager: SecretThreadManager = (
	$SecretThreadManager
)
@onready var secret_thread_system: SecretThreadSystem = (
	$SecretThreadSystem
)
@onready var ambient_moments_system: AmbientMomentsSystem = (
	$AmbientMomentsSystem
)
@onready var ending_evaluator: EndingEvaluatorSystem = (
	$EndingEvaluatorSystem
)
@onready var store_upgrade_system: StoreUpgradeSystem = (
	$StoreUpgradeSystem
)
@onready var completion_tracker: CompletionTracker = $CompletionTracker
@onready var save_manager: SaveManager = $SaveManager
@onready var day_cycle_controller: DayCycleController = (
	$DayCycleController
)
@onready var day_phase_lighting: DayPhaseLighting = $DayPhaseLighting

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
var _authentication_dialog: AuthenticationDialog = null
var _refurbishment_dialog: RefurbishmentDialog = null
var _refurb_queue_panel: RefurbQueuePanel = null
var _deferred_panels_loaded: bool = false
var _startup_time_ms: float = 0.0

@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _store_container: Node3D = $StoreContainer


func _ready() -> void:
	_setup_mall_hallway()
	GameManager.initialize_game_systems(self)
	_setup_ui()
	if _mall_hallway:
		_mall_hallway.set_systems(
			economy_system, ReputationSystemSingleton,
			inventory_system, progression_system
		)
		_mall_hallway.set_ambient_systems(
			customer_system, time_system
		)
		_mall_hallway.apply_unlock_state(progression_system)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.all_milestones_completed.connect(
		_on_all_milestones_completed
	)
	EventBus.ending_triggered.connect(
		_on_ending_triggered
	)
	_apply_pending_load.call_deferred()


func _setup_mall_hallway() -> void:
	_mall_hallway = _MallHallwayScene.instantiate() as MallHallway
	_store_container.add_child(_mall_hallway)


## Initializes all gameplay systems in dependency-tier order.
## Called by GameManager after DataLoader completes content loading.
func initialize_systems() -> void:
	_initialize_tier_1_data()
	_initialize_tier_2_state()
	_initialize_tier_3_operational()
	_initialize_tier_4_world()
	_initialize_tier_5_meta()
	_wire_save_manager()
	_wire_store_controllers()


func _initialize_tier_1_data() -> void:
	time_system.initialize()
	economy_system.initialize()


func _initialize_tier_2_state() -> void:
	# Ensure market_event_system is available — instantiate if not in scene.
	if market_event_system == null:
		market_event_system = MarketEventSystem.new()
		add_child(market_event_system)

	inventory_system.initialize(GameManager.data_loader)
	economy_system.set_inventory_system(inventory_system)

	store_state_manager.initialize(inventory_system, economy_system)

	trend_system.initialize(GameManager.data_loader)
	economy_system.set_trend_system(trend_system)

	market_event_system.initialize()
	economy_system.set_market_event_system(market_event_system)

	seasonal_event_system.initialize(GameManager.data_loader)

	market_value_system.initialize(
		inventory_system,
		market_event_system,
		seasonal_event_system,
	)


func _initialize_tier_3_operational() -> void:
	var store_ctrl: StoreController = _find_store_controller()

	ReputationSystemSingleton.initialize_store(
		String(GameManager.current_store_id)
	)

	customer_system.initialize(
		store_ctrl, inventory_system, ReputationSystemSingleton
	)
	if store_ctrl:
		customer_system.set_store_id(
			GameManager.current_store_id
		)

	mall_customer_spawner.initialize(
		customer_system, ReputationSystemSingleton, trend_system
	)
	mall_customer_spawner.set_seasonal_event_system(
		seasonal_event_system
	)

	npc_spawner_system.initialize(inventory_system)

	haggle_system.initialize(ReputationSystemSingleton)

	checkout_system.initialize(
		economy_system,
		inventory_system,
		customer_system,
		ReputationSystemSingleton
	)
	checkout_system.set_haggle_system(haggle_system)
	checkout_system.set_market_value_system(market_value_system)
	if store_ctrl:
		var reg: Area3D = store_ctrl.get_register_area()
		var ent: Area3D = store_ctrl.get_entry_area()
		if reg and ent:
			checkout_system.setup_queue_positions(
				reg.global_position, ent.global_position
			)
			queue_system.setup_queue_positions(
				reg.global_position, ent.global_position
			)

	queue_system.initialize()

	progression_system.initialize(economy_system, ReputationSystemSingleton)

	milestone_system.initialize()

	order_system.initialize(
		inventory_system, ReputationSystemSingleton, progression_system
	)
	# Also wire OrderingSystem (separate class for supplier tier logic).
	if not has_node("OrderingSystem"):
		var ordering_system: OrderingSystem = OrderingSystem.new()
		add_child(ordering_system)
		ordering_system.initialize(inventory_system, ReputationSystemSingleton)

	staff_system.initialize(
		economy_system,
		ReputationSystemSingleton,
		inventory_system,
		GameManager.data_loader,
	)


func _initialize_tier_4_world() -> void:
	if _mall_hallway:
		store_selector_system.initialize(
			store_state_manager,
			_mall_hallway.get_hallway_geometry(),
			_mall_hallway.get_store_container(),
			_mall_hallway.get_camera_controller(),
			_ui_layer
		)

	_initialize_build_mode()

	tournament_system.initialize(
		economy_system,
		ReputationSystemSingleton,
		customer_system,
		fixture_placement,
		GameManager.data_loader
	)

	meta_shift_system.initialize(GameManager.data_loader)
	economy_system.set_meta_shift_system(meta_shift_system)

	day_phase_lighting.initialize()


func _initialize_tier_5_meta() -> void:
	performance_manager.initialize(economy_system)
	customer_system.set_performance_manager(performance_manager)

	performance_report_system.initialize()

	random_event_system.initialize(
		GameManager.data_loader,
		inventory_system,
		ReputationSystemSingleton,
		economy_system
	)

	ambient_moments_system.initialize(
		secret_thread_manager, inventory_system, time_system
	)

	secret_thread_system.initialize(ambient_moments_system)

	ending_evaluator.initialize()

	store_upgrade_system.initialize(
		GameManager.data_loader,
		economy_system,
		ReputationSystemSingleton,
	)

	completion_tracker.initialize(GameManager.data_loader)

	day_cycle_controller.initialize(
		time_system,
		economy_system,
		staff_system,
		progression_system,
		ending_evaluator,
		performance_report_system,
	)
	day_cycle_controller.set_seasonal_event_system(
		seasonal_event_system
	)
	day_cycle_controller.set_ambient_moments_system(
		ambient_moments_system
	)
	day_cycle_controller.set_ensure_panels_callback(
		_ensure_deferred_panels
	)


func _wire_save_manager() -> void:
	save_manager.initialize(
		economy_system,
		inventory_system,
		time_system,
	)
	save_manager.set_order_system(order_system)
	if has_node("OrderingSystem"):
		save_manager.set_ordering_system(get_node("OrderingSystem") as OrderingSystem)
	save_manager.set_store_state_manager(store_state_manager)
	save_manager.set_progression_system(progression_system)
	save_manager.set_milestone_system(milestone_system)
	save_manager.set_trend_system(trend_system)
	save_manager.set_market_event_system(market_event_system)
	save_manager.set_tournament_system(tournament_system)
	save_manager.set_meta_shift_system(meta_shift_system)
	save_manager.set_seasonal_event_system(seasonal_event_system)
	save_manager.set_random_event_system(random_event_system)
	save_manager.set_staff_system(staff_system)
	save_manager.set_tutorial_system(tutorial_system)
	save_manager.set_secret_thread_manager(secret_thread_manager)
	save_manager.set_secret_thread_system(secret_thread_system)
	save_manager.set_ambient_moments_system(ambient_moments_system)
	save_manager.set_ending_evaluator(ending_evaluator)
	save_manager.set_store_upgrade_system(store_upgrade_system)
	save_manager.set_completion_tracker(completion_tracker)
	save_manager.set_performance_report_system(
		performance_report_system
	)
	var unlock_system: UnlockSystem = get_node_or_null(
		"/root/UnlockSystemSingleton"
	)
	if unlock_system:
		save_manager.set_unlock_system(unlock_system)
	var onboarding_system: OnboardingSystem = get_node_or_null(
		"/root/OnboardingSystemSingleton"
	)
	if onboarding_system:
		save_manager.set_onboarding_system(onboarding_system)


func _wire_store_controllers() -> void:
	var initial_ctrl: StoreController = _find_store_controller()
	if initial_ctrl:
		_wire_rental_system(initial_ctrl)
		_wire_electronics_system(initial_ctrl)
		_wire_sports_memorabilia_system(initial_ctrl)
		_wire_retro_games_system(initial_ctrl)


func _setup_ui() -> void:
	var start_usec: int = Time.get_ticks_usec()

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

	_item_tooltip = (
		_ItemTooltipScene.instantiate() as ItemTooltip
	)
	_item_tooltip.economy_system = economy_system
	_item_tooltip.inventory_system = inventory_system
	_ui_layer.add_child(_item_tooltip)

	var visual_feedback: VisualFeedback = (
		_VisualFeedbackScene.instantiate() as VisualFeedback
	)
	_ui_layer.add_child(visual_feedback)

	_tutorial_overlay = (
		_TutorialOverlayScene.instantiate() as TutorialOverlay
	)
	_tutorial_overlay.tutorial_system = tutorial_system
	_ui_layer.add_child(_tutorial_overlay)

	var essential_ms: float = (
		float(Time.get_ticks_usec() - start_usec) / 1000.0
	)
	_startup_time_ms = essential_ms

	_setup_deferred_panels.call_deferred()


func _setup_deferred_panels() -> void:
	if _deferred_panels_loaded:
		return
	var start_usec: int = Time.get_ticks_usec()

	_day_summary = _DaySummaryScene.instantiate() as DaySummary
	_ui_layer.add_child(_day_summary)
	_day_summary.review_inventory_requested.connect(
		_on_day_summary_review_inventory
	)
	day_cycle_controller.set_day_summary(_day_summary)

	_fixture_catalog = (
		_FixtureCatalogScene.instantiate() as FixtureCatalog
	)
	_fixture_catalog.data_loader = GameManager.data_loader
	_fixture_catalog.economy_system = economy_system
	_fixture_catalog.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(_fixture_catalog)
	if fixture_placement:
		_fixture_catalog.placement_system = fixture_placement

	var milestone_popup: MilestonePopup = (
		_MilestonePopupScene.instantiate() as MilestonePopup
	)
	_ui_layer.add_child(milestone_popup)

	var milestone_banner: MilestoneBanner = (
		_MilestoneBannerScene.instantiate() as MilestoneBanner
	)
	_ui_layer.add_child(milestone_banner)

	var milestones_panel: MilestonesPanel = (
		_MilestonesPanelScene.instantiate() as MilestonesPanel
	)
	milestones_panel.progression_system = progression_system
	_ui_layer.add_child(milestones_panel)

	var order_panel: OrderPanel = (
		_OrderPanelScene.instantiate() as OrderPanel
	)
	order_panel.order_system = order_system
	order_panel.economy_system = economy_system
	order_panel.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(order_panel)

	var trends_panel: TrendsPanel = (
		_TrendsPanelScene.instantiate() as TrendsPanel
	)
	trends_panel.trend_system = trend_system
	_ui_layer.add_child(trends_panel)

	_settings_panel = (
		_SettingsPanelScene.instantiate() as SettingsPanel
	)
	_ui_layer.add_child(_settings_panel)

	_pause_menu = _PauseMenuScene.instantiate() as PauseMenu
	_pause_menu.completion_tracker = completion_tracker
	_pause_menu.tutorial_system = tutorial_system
	_pause_menu.save_manager = save_manager
	_pause_menu.settings_panel = _settings_panel
	_ui_layer.add_child(_pause_menu)
	_pause_menu.return_to_menu_pressed.connect(
		_on_return_to_menu_pressed
	)
	_pause_menu.view_day_summary_requested.connect(
		_on_view_day_summary_requested
	)

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
	_ui_layer.add_child(_staff_panel)

	var upgrade_panel: UpgradePanel = (
		_UpgradePanelScene.instantiate() as UpgradePanel
	)
	upgrade_panel.upgrade_system = store_upgrade_system
	upgrade_panel.economy_system = economy_system
	upgrade_panel.reputation_system = ReputationSystemSingleton
	upgrade_panel.data_loader = GameManager.data_loader
	upgrade_panel.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(upgrade_panel)

	_ending_screen = (
		_EndingScreenScene.instantiate() as EndingScreen
	)
	add_child(_ending_screen)
	_ending_screen.dismissed.connect(_on_ending_dismissed)

	var initial_ctrl: StoreController = _find_store_controller()
	if initial_ctrl:
		_wire_pack_system(initial_ctrl)

	_setup_debug_overlay()

	_deferred_panels_loaded = true
	var deferred_ms: float = (
		float(Time.get_ticks_usec() - start_usec) / 1000.0
	)
	_startup_time_ms += deferred_ms
	_log_panel_profile(deferred_ms)


## Forces deferred panels to load if not yet initialized.
func _ensure_deferred_panels() -> void:
	if not _deferred_panels_loaded:
		_setup_deferred_panels()


func _log_panel_profile(deferred_ms: float) -> void:
	var all_panels: Array[Node] = []
	for child: Node in _ui_layer.get_children():
		all_panels.append(child)
	var profile: Dictionary = (
		PerformanceManager.estimate_panel_memory(all_panels)
	)
	push_warning(
		"UI Panel Profile: %d panels, ~%.1f KB estimated, "
		% [profile.get("panel_count", 0), profile.get("total_kb", 0.0)]
		+ "deferred batch: %.1fms, total startup: %.1fms"
		% [deferred_ms, _startup_time_ms]
	)


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


func _initialize_build_mode() -> void:
	var camera: Camera3D = CameraManager.active_camera
	var player_node: Node = _find_player_node(camera)
	if player_node and player_node.has_method("set_inventory_system"):
		player_node.set_inventory_system(inventory_system)
	var floor_center := Vector3(0.0, 0.05, 0.0)

	build_mode.initialize(
		player_node,
		BuildModeGrid.StoreSize.SMALL,
		floor_center
	)

	var grid_size: Vector2i = build_mode.get_grid().grid_size
	var entry_edge_y: int = grid_size.y - 2

	fixture_placement.initialize(
		build_mode.get_grid(),
		inventory_system,
		economy_system,
		entry_edge_y,
		BuildModeGrid.StoreSize.SMALL
	)

	if GameManager.data_loader:
		fixture_placement.set_data_loader(GameManager.data_loader)

	build_mode.set_placement_system(fixture_placement)

	var nav_region: NavigationRegion3D = _find_nav_region()
	if nav_region:
		build_mode.set_nav_region(nav_region)
		var nav_rebaker := NavMeshRebaker.new()
		nav_rebaker.name = "NavMeshRebaker"
		add_child(nav_rebaker)
		nav_rebaker.set_nav_region(nav_region)

	var build_transition := BuildModeTransition.new()
	build_transition.name = "BuildModeTransition"
	add_child(build_transition)

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


func _on_day_summary_review_inventory() -> void:
	if _inventory_panel:
		_inventory_panel.open()


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


func _on_store_entered(store_id: StringName) -> void:
	if performance_manager:
		performance_manager.begin_store_switch()

	var store_ctrl: StoreController = _find_store_controller()
	if store_ctrl and store_state_manager:
		store_state_manager.restore_store_state(
			String(store_id), store_ctrl
		)

	if store_ctrl:
		customer_system.initialize(store_ctrl, inventory_system)
		customer_system.set_store_id(String(store_id))
		_wire_rental_system(store_ctrl)
		_wire_pack_system(store_ctrl)
		_wire_electronics_system(store_ctrl)
		_wire_sports_memorabilia_system(store_ctrl)
		_wire_retro_games_system(store_ctrl)

	_ensure_deferred_panels()

	if performance_manager:
		performance_manager.end_store_switch()


## Wires up a VideoRentalStoreController with system references if applicable.
func _wire_rental_system(store_ctrl: StoreController) -> void:
	if store_ctrl is VideoRentalStoreController:
		var rental: VideoRentalStoreController = (
			store_ctrl as VideoRentalStoreController
		)
		rental.set_inventory_system(inventory_system)
		rental.set_economy_system(economy_system)
		rental.set_reputation_system(ReputationSystemSingleton)
		save_manager.set_rental_system(rental)
		if _inventory_panel:
			_inventory_panel.rental_controller = rental
	elif store_ctrl is VideoRental:
		var rental: VideoRental = store_ctrl as VideoRental
		rental.set_inventory_system(inventory_system)
		rental.initialize()


## Wires up a PocketCreaturesStoreController with pack and tournament systems.
func _wire_pack_system(store_ctrl: StoreController) -> void:
	if store_ctrl is PocketCreaturesStoreController:
		var pc_ctrl: PocketCreaturesStoreController = (
			store_ctrl as PocketCreaturesStoreController
		)
		pc_ctrl.set_economy_system(economy_system)
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


## Wires up an ElectronicsStoreController with warranty manager and demo.
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
		if _inventory_panel:
			_inventory_panel.electronics_controller = elec
	else:
		checkout_system.set_warranty_manager(null)
		if _inventory_panel:
			_inventory_panel.electronics_controller = null


## Wires up a SportsMemorabiliaController with season cycle system.
func _wire_sports_memorabilia_system(
	store_ctrl: StoreController,
) -> void:
	if store_ctrl is SportsMemorabiliaController:
		var sports: SportsMemorabiliaController = (
			store_ctrl as SportsMemorabiliaController
		)
		sports.initialize(time_system.current_day)
		sports.initialize_authentication(
			inventory_system, economy_system
		)
		var cycle: SeasonCycleSystem = sports.get_season_cycle()
		economy_system.set_season_cycle_system(cycle)
		save_manager.set_season_cycle_system(cycle)
		if _item_tooltip:
			_item_tooltip.season_cycle_system = cycle
		_ensure_authentication_dialog(sports)
	else:
		economy_system.set_season_cycle_system(null)
		save_manager.set_season_cycle_system(null)
		if _item_tooltip:
			_item_tooltip.season_cycle_system = null


## Wires up a RetroGames store controller with testing and refurbishment systems.
func _wire_retro_games_system(store_ctrl: StoreController) -> void:
	if store_ctrl is RetroGames:
		var retro: RetroGames = store_ctrl as RetroGames
		retro.set_inventory_system(inventory_system)
		var existing: TestingSystem = retro.get_testing_system()
		if not existing:
			var testing: TestingSystem = TestingSystem.new()
			testing.name = "TestingSystem"
			retro.add_child(testing)
			testing.initialize(inventory_system)
			retro.set_testing_system(testing)
			existing = testing
		market_value_system.set_testing_system(existing)
		if _inventory_panel:
			_inventory_panel.testing_system = existing
		var refurb: RefurbishmentSystem = retro.get_refurbishment_system()
		if not refurb:
			refurb = RefurbishmentSystem.new()
			refurb.name = "RefurbishmentSystem"
			retro.add_child(refurb)
			refurb.initialize(inventory_system, economy_system)
			retro.set_refurbishment_system(refurb)
		save_manager.set_refurbishment_system(refurb)
		_ensure_refurbishment_ui(refurb)
		if _inventory_panel:
			_inventory_panel.refurbishment_system = refurb
	else:
		market_value_system.set_testing_system(null)
		if _inventory_panel:
			_inventory_panel.testing_system = null
			_inventory_panel.refurbishment_system = null
			_inventory_panel.refurbishment_dialog = null


func _ensure_authentication_dialog(
	sports: SportsMemorabiliaController,
) -> void:
	if not _authentication_dialog:
		_authentication_dialog = (
			_AuthenticationDialogScene.instantiate()
			as AuthenticationDialog
		)
		_ui_layer.add_child(_authentication_dialog)
	_authentication_dialog.set_authentication_system(
		sports.get_authentication_system()
	)
	_authentication_dialog.set_inventory_system(inventory_system)


func _ensure_refurbishment_ui(
	refurb: RefurbishmentSystem,
) -> void:
	if not _refurbishment_dialog:
		_refurbishment_dialog = (
			_RefurbishmentDialogScene.instantiate()
			as RefurbishmentDialog
		)
		_ui_layer.add_child(_refurbishment_dialog)
	_refurbishment_dialog.set_refurbishment_system(refurb)
	if _inventory_panel:
		_inventory_panel.refurbishment_dialog = _refurbishment_dialog
	if not _refurb_queue_panel:
		_refurb_queue_panel = (
			_RefurbQueuePanelScene.instantiate()
			as RefurbQueuePanel
		)
		_ui_layer.add_child(_refurb_queue_panel)
	_refurb_queue_panel.refurbishment_system = refurb
	_refurb_queue_panel.inventory_system = inventory_system


func _set_systems_paused(paused: bool) -> void:
	time_system.set_process(!paused)
	economy_system.set_process(!paused)
	order_system.set_process(!paused)
	inventory_system.set_process(!paused)
	customer_system.set_process(!paused)
	mall_customer_spawner.set_process(!paused)
	checkout_system.set_process(!paused)
	haggle_system.set_process(!paused)
	store_state_manager.set_process(!paused)
	progression_system.set_process(!paused)
	trend_system.set_process(!paused)
	market_event_system.set_process(!paused)
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
		_validate_loaded_game_state()
	else:
		_initialize_new_game()
		tutorial_system.initialize(true)
		EventBus.day_started.emit(1)


## Populates the default store with starter inventory, registers its slot
## ownership, and validates that the game state is playable.
func _initialize_new_game() -> void:
	var default_store: StringName = GameManager.DEFAULT_STARTING_STORE

	_register_default_store_slot(default_store)
	_create_default_store_inventory(default_store)
	_validate_new_game_state(default_store)


func _register_default_store_slot(store_id: StringName) -> void:
	if not _mall_hallway or not store_state_manager:
		return
	var slot_ids: Array[StringName] = _mall_hallway.SLOT_STORE_IDS
	for i: int in range(slot_ids.size()):
		if slot_ids[i] == store_id:
			store_state_manager.register_slot_ownership(i, store_id)
			return
	push_error(
		"GameWorld: default store '%s' not found in storefront slots"
		% store_id
	)


func _create_default_store_inventory(store_id: StringName) -> void:
	if not GameManager.data_loader or not inventory_system:
		push_error(
			"GameWorld: cannot create starter inventory — "
			+ "missing data_loader or inventory_system"
		)
		return
	var items: Array[ItemInstance] = (
		GameManager.data_loader.create_starting_inventory(
			String(store_id)
		)
	)
	for item: ItemInstance in items:
		inventory_system.register_item(item)


func _validate_loaded_game_state() -> void:
	var errors: Array[String] = []

	if GameManager.owned_stores.is_empty():
		errors.append("No owned stores after load")

	if store_state_manager and store_state_manager.owned_slots.is_empty():
		errors.append("StoreStateManager.owned_slots is empty after load")

	if economy_system and is_nan(economy_system.get_cash()):
		errors.append("Player cash is NaN after load")

	if time_system and time_system.current_day < 1:
		errors.append(
			"Current day is %d (expected >= 1)" % time_system.current_day
		)

	if inventory_system and inventory_system.get_item_count() == 0:
		errors.append("Inventory is empty after load")

	for msg: String in errors:
		push_error("Load validation failed: %s" % msg)


func _validate_new_game_state(store_id: StringName) -> void:
	var errors: Array[String] = []

	if not GameManager.is_store_owned(String(store_id)):
		errors.append(
			"Default store '%s' not in owned_stores" % store_id
		)

	if store_state_manager and store_state_manager.owned_slots.is_empty():
		errors.append("StoreStateManager.owned_slots is empty")

	if inventory_system and inventory_system.get_item_count() == 0:
		errors.append(
			"InventorySystem has no items after starter inventory"
		)

	if economy_system and economy_system.get_cash() < Constants.STARTING_CASH:
		errors.append(
			"Player cash %.2f is below starting value %.2f"
			% [economy_system.get_cash(), Constants.STARTING_CASH]
		)

	for msg: String in errors:
		push_error("New game validation failed: %s" % msg)


func _on_view_day_summary_requested() -> void:
	if _day_summary:
		_day_summary.show_last()


func _on_return_to_menu_pressed() -> void:
	GameManager.transition_to_menu()


func _on_save_slot_requested(slot: int) -> void:
	save_manager.save_game(slot)


func _on_load_slot_requested(slot: int) -> void:
	save_manager.load_game(slot)


func _on_all_milestones_completed() -> void:
	_ensure_deferred_panels()
	if ending_evaluator.has_ending_been_shown():
		return
	EventBus.ending_requested.emit("voluntary")


func _on_ending_triggered(
	_ending_id: StringName, _final_stats: Dictionary
) -> void:
	_ensure_deferred_panels()


func _on_ending_dismissed() -> void:
	pass
