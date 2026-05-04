# gdlint:disable=max-file-lines
## Root scene for the playable game world. Instantiates runtime systems and UI.
extends Node3D

const _HUD_SCENE: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)
const _MALL_OVERVIEW_SCENE: PackedScene = preload(
	"res://game/scenes/mall/mall_overview.tscn"
)
const _INVENTORY_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/inventory_panel.tscn"
)
const _CHECKOUT_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/checkout_panel.tscn"
)
const _PRICING_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/pricing_panel.tscn"
)
const _HAGGLE_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/haggle_panel.tscn"
)
const _DAY_SUMMARY_SCENE: PackedScene = preload(
	"res://game/scenes/ui/day_summary.tscn"
)
const _FIXTURE_CATALOG_SCENE: PackedScene = preload(
	"res://game/scenes/ui/fixture_catalog.tscn"
)
const _MILESTONE_CARD_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestone_card.tscn"
)
const _MILESTONES_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestones_panel.tscn"
)
const _COMPLETION_TRACKER_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/completion_tracker_panel.tscn"
)
const _ORDER_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/order_panel.tscn"
)
const _TRENDS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/trends_panel.tscn"
)
const _PERFORMANCE_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/performance_panel.tscn"
)
const _PAUSE_MENU_SCENE: PackedScene = preload(
	"res://game/scenes/ui/pause_menu.tscn"
)
const _SAVE_LOAD_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/save_load_panel.tscn"
)
const _SETTINGS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)
const _PACK_OPENING_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/pack_opening_panel.tscn"
)
const _MALL_HALLWAY_SCENE: PackedScene = preload(
	"res://game/scenes/world/mall_hallway.tscn"
)
const _STAFF_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/staff_panel.tscn"
)
const _TUTORIAL_OVERLAY_SCENE: PackedScene = preload(
	"res://game/scenes/ui/tutorial_overlay.tscn"
)
const _FIRST_RUN_CUE_OVERLAY_SCENE: PackedScene = preload(
	"res://game/scenes/ui/first_run_cue_overlay.tscn"
)
const _ITEM_TOOLTIP_SCENE: PackedScene = preload(
	"res://game/scenes/ui/item_tooltip.tscn"
)
const _VISUAL_FEEDBACK_SCENE: PackedScene = preload(
	"res://game/scenes/ui/visual_feedback.tscn"
)
const _ENDING_SCREEN_SCENE: PackedScene = preload(
	"res://game/scenes/ui/ending_screen.tscn"
)
const _UPGRADE_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/upgrade_panel.tscn"
)
const _CONDITION_PICKER_DIALOG_SCENE: PackedScene = preload(
	"res://game/scenes/ui/condition_picker_dialog.tscn"
)
const _REFURBISHMENT_DIALOG_SCENE: PackedScene = preload(
	"res://game/scenes/ui/refurbishment_dialog.tscn"
)
const _REFURB_QUEUE_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/refurb_queue_panel.tscn"
)
const _WARRANTY_DIALOG_SCENE: PackedScene = preload(
	"res://game/scenes/ui/warranty_dialog.tscn"
)
const _MOMENTS_TRAY_SCENE: PackedScene = preload(
	"res://game/scenes/ui/moments_tray.tscn"
)
const _MOMENTS_LOG_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/moments_log_panel.tscn"
)
const _DEBUG_OVERLAY_SCENE: PackedScene = preload(
	"res://game/scenes/debug/debug_overlay.tscn"
)
const _STORE_PLAYER_SCENE: PackedScene = preload(
	"res://game/scenes/player/store_player_body.tscn"
)
const _PLAYER_ENTRY_SPAWN_NAME: String = "PlayerEntrySpawn"

var reputation_system: ReputationSystem:
	get:
		return ReputationSystemSingleton

var _inventory_panel: InventoryPanel
var _day_summary: DaySummary
var _mall_overview: MallOverview
var _fixture_catalog: FixtureCatalogPanel
var _mall_hallway: MallHallway
var _pause_menu: PauseMenu
var _save_load_panel: SaveLoadPanel
var _settings_panel: SettingsPanel
var _pack_opening_panel: PackOpeningPanel
var _staff_panel: StaffPanel
var _tutorial_overlay: TutorialOverlay
var _item_tooltip: ItemTooltip
var _ending_screen: EndingScreen
var _warranty_dialog: WarrantyDialog = null
var _condition_picker_dialog: ConditionPickerDialog = null
var _refurbishment_dialog: RefurbishmentDialog = null
var _refurb_queue_panel: RefurbQueuePanel = null
var _deferred_panels_loaded: bool = false
var _nav_mesh_rebaker: NavMeshRebaker = null

var _day_manager: DayManager = null

## Hub-mode state (used when debug/walkable_mall = false).
var _hub_transition: SceneTransition = null
var _hub_is_inside_store: bool = false
var _hub_active_store_scene: Node3D = null

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
@onready var ambient_moments_system: AmbientMomentsSystem = (
	$AmbientMomentsSystem
)
@onready var regulars_log_system: RegularsLogSystem = (
	$RegularsLogSystem
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

@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _store_container: Node3D = $StoreContainer


func _ready() -> void:
	_setup_mall_hallway()
	GameManager.initialize_game_systems(self)
	_setup_ui()
	if _mall_hallway:
		_mall_hallway.set_systems(
			economy_system, ReputationSystemSingleton,
			inventory_system, progression_system, store_state_manager
		)
		_mall_hallway.set_ambient_systems(
			customer_system, time_system
		)
		_mall_hallway.apply_unlock_state(progression_system)
	# Hub-mode wiring runs after `initialize_game_systems` (which calls
	# `finalize_system_wiring`) so an early click cannot route to systems that
	# are still being constructed. The injector seam routes hub-mode entries
	# through StoreDirector while preserving all 30+ in-tree systems.
	if _hub_transition != null:
		StoreDirector.set_scene_injector(
			Callable(self, "_inject_store_into_container")
		)
		EventBus.enter_store_requested.connect(_on_hub_enter_store_requested)
		EventBus.exit_store_requested.connect(_on_hub_exit_store_requested)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.all_milestones_completed.connect(
		_on_all_milestones_completed
	)
	EventBus.ending_triggered.connect(
		_on_ending_triggered
	)
	GameManager.finalize_gameplay_start(self)


func _setup_mall_hallway() -> void:
	if not ProjectSettings.get_setting("debug/walkable_mall", false):
		_setup_hub_mode()
		return
	_mall_hallway = _MALL_HALLWAY_SCENE.instantiate() as MallHallway
	_store_container.add_child(_mall_hallway)


## Sets up the direct click-to-enter hub mode (walkable mall disabled).
## EventBus signal connections are deferred to `_ready()` until after
## `finalize_system_wiring()` so an early `enter_store_requested` cannot
## fire while runtime systems are still being constructed.
func _setup_hub_mode() -> void:
	_hub_transition = SceneTransition.new()
	add_child(_hub_transition)


## Initializes all gameplay systems in dependency-tier order.
## Called by GameManager after DataLoader completes content loading.
func initialize_systems() -> void:
	initialize_tier_1_data()
	if not initialize_tier_2_state():
		push_error("GameWorld: aborting system initialization — Tier 2 failed")
		return
	initialize_tier_3_operational()
	initialize_tier_4_world()
	initialize_tier_5_meta()
	finalize_system_wiring()


## Initializes Tier 1 data systems with no runtime system dependencies.
func initialize_tier_1_data() -> void:
	time_system.initialize()
	economy_system.initialize(_get_configured_starting_cash())
	time_system.set_day_end_summary_provider(
		Callable(economy_system, "get_day_end_summary")
	)


## Initializes Tier 2 state systems that depend on the data tier.
## Returns false on hard failure; initialize_systems() aborts subsequent tiers
## to prevent cascading null-reference errors on partially-initialized systems.
func initialize_tier_2_state() -> bool:
	if market_event_system == null:
		push_error(
			"GameWorld: cannot initialize Tier 2 without MarketEventSystem"
		)
		return false
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
	return true


## Initializes Tier 3 operational systems after state systems are ready.
func initialize_tier_3_operational() -> void:
	var store_ctrl: StoreController = _find_store_controller(false)

	ReputationSystemSingleton.initialize_store(
		String(GameManager.get_active_store_id())
	)

	customer_system.initialize(
		store_ctrl, inventory_system, ReputationSystemSingleton
	)
	if store_ctrl:
		customer_system.set_store_id(
			GameManager.get_active_store_id()
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

	staff_system.initialize(
		economy_system,
		ReputationSystemSingleton,
		inventory_system,
		GameManager.data_loader,
	)

	meta_shift_system.initialize(GameManager.data_loader)
	economy_system.set_meta_shift_system(meta_shift_system)


## Initializes Tier 4 world systems once the scene tree is fully available.
func initialize_tier_4_world() -> void:
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

	day_phase_lighting.initialize()


## Initializes Tier 5 meta systems after core gameplay systems are live.
func initialize_tier_5_meta() -> void:
	performance_manager.initialize(economy_system)
	customer_system.set_performance_manager(performance_manager)

	performance_report_system.initialize()

	random_event_system.initialize(
		GameManager.data_loader,
		inventory_system,
		ReputationSystemSingleton,
		economy_system
	)

	ambient_moments_system.initialize(inventory_system, time_system)

	regulars_log_system.initialize()

	ending_evaluator.initialize()

	_day_manager = DayManager.new()
	add_child(_day_manager)
	_day_manager.initialize(economy_system, ending_evaluator)

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
	day_cycle_controller.set_day_manager(_day_manager)
	day_cycle_controller.set_seasonal_event_system(
		seasonal_event_system
	)
	day_cycle_controller.set_ambient_moments_system(
		ambient_moments_system
	)
	day_cycle_controller.set_ensure_panels_callback(
		_ensure_deferred_panels
	)


## Wires systems that require all initialization tiers to be complete first.
func finalize_system_wiring() -> void:
	_wire_save_manager()
	_wire_store_controllers()
	day_cycle_controller.set_save_manager(save_manager)


func _wire_save_manager() -> void:
	save_manager.initialize(
		economy_system,
		inventory_system,
		time_system,
	)
	save_manager.set_order_system(order_system)
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
	save_manager.set_ambient_moments_system(ambient_moments_system)
	save_manager.set_regulars_log_system(regulars_log_system)
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
	var initial_ctrl: StoreController = _find_store_controller(false)
	if initial_ctrl:
		_wire_base_store_controller(initial_ctrl)
		_wire_rental_system(initial_ctrl)
		_wire_electronics_system(initial_ctrl)
		_wire_sports_memorabilia_system(initial_ctrl)
		_wire_retro_games_system(initial_ctrl)


func _setup_ui() -> void:
	var hud: CanvasLayer = _HUD_SCENE.instantiate()
	_ui_layer.add_child(hud)

	_inventory_panel = (
		_INVENTORY_PANEL_SCENE.instantiate() as InventoryPanel
	)
	_inventory_panel.inventory_system = inventory_system
	_inventory_panel.store_id = String(GameManager.get_active_store_id())
	_ui_layer.add_child(_inventory_panel)

	var pricing_panel: PricingPanel = (
		_PRICING_PANEL_SCENE.instantiate() as PricingPanel
	)
	pricing_panel.inventory_system = inventory_system
	pricing_panel.economy_system = economy_system
	_ui_layer.add_child(pricing_panel)
	_inventory_panel.pricing_panel = pricing_panel

	var checkout_panel: CheckoutPanel = (
		_CHECKOUT_PANEL_SCENE.instantiate() as CheckoutPanel
	)
	_ui_layer.add_child(checkout_panel)
	checkout_system.set_checkout_panel(checkout_panel)

	var haggle_panel: HagglePanel = (
		_HAGGLE_PANEL_SCENE.instantiate() as HagglePanel
	)
	_ui_layer.add_child(haggle_panel)
	checkout_system.set_haggle_panel(haggle_panel)

	_item_tooltip = (
		_ITEM_TOOLTIP_SCENE.instantiate() as ItemTooltip
	)
	_item_tooltip.economy_system = economy_system
	_item_tooltip.inventory_system = inventory_system
	_ui_layer.add_child(_item_tooltip)

	var visual_feedback: VisualFeedback = (
		_VISUAL_FEEDBACK_SCENE.instantiate() as VisualFeedback
	)
	_ui_layer.add_child(visual_feedback)

	_tutorial_overlay = (
		_TUTORIAL_OVERLAY_SCENE.instantiate() as TutorialOverlay
	)
	_tutorial_overlay.tutorial_system = tutorial_system
	_ui_layer.add_child(_tutorial_overlay)

	var first_run_cue: FirstRunCueOverlay = (
		_FIRST_RUN_CUE_OVERLAY_SCENE.instantiate() as FirstRunCueOverlay
	)
	first_run_cue.inventory_system = inventory_system
	first_run_cue.time_system = time_system
	_ui_layer.add_child(first_run_cue)

	_setup_deferred_panels.call_deferred()


func _setup_deferred_panels() -> void:
	if _deferred_panels_loaded:
		return

	_day_summary = _DAY_SUMMARY_SCENE.instantiate() as DaySummary
	_ui_layer.add_child(_day_summary)
	_day_summary.review_inventory_requested.connect(
		_on_day_summary_review_inventory
	)
	_day_summary.mall_overview_requested.connect(
		_on_day_summary_mall_overview_requested
	)
	_day_summary.main_menu_requested.connect(
		_on_day_summary_main_menu_requested
	)
	day_cycle_controller.set_day_summary(_day_summary)

	_mall_overview = _MALL_OVERVIEW_SCENE.instantiate() as MallOverview
	_ui_layer.add_child(_mall_overview)
	_mall_overview.setup(inventory_system, economy_system)
	_mall_overview.set_time_system(time_system)
	_mall_overview.set_completion_tracker(completion_tracker)
	# Day Summary hides MallOverview while open and restores on dismiss (P1.4).
	day_cycle_controller.set_mall_overview(_mall_overview)

	var moments_log_panel: MomentsLogPanel = (
		_MOMENTS_LOG_PANEL_SCENE.instantiate() as MomentsLogPanel
	)
	moments_log_panel.ambient_moments_system = ambient_moments_system
	_ui_layer.add_child(moments_log_panel)
	_mall_overview.set_moments_log_panel(moments_log_panel)

	var performance_panel: PerformancePanel = (
		_PERFORMANCE_PANEL_SCENE.instantiate() as PerformancePanel
	)
	performance_panel.performance_report_system = performance_report_system
	_ui_layer.add_child(performance_panel)
	_mall_overview.set_performance_panel(performance_panel)

	_fixture_catalog = (
		_FIXTURE_CATALOG_SCENE.instantiate()
	)
	_fixture_catalog.data_loader = GameManager.data_loader
	_fixture_catalog.economy_system = economy_system
	_fixture_catalog.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(_fixture_catalog)

	var milestone_card: MilestoneCard = (
		_MILESTONE_CARD_SCENE.instantiate() as MilestoneCard
	)
	milestone_card.notification_mode = true
	_ui_layer.add_child(milestone_card)

	var milestones_panel: MilestonesPanel = (
		_MILESTONES_PANEL_SCENE.instantiate() as MilestonesPanel
	)
	milestones_panel.progression_system = progression_system
	_ui_layer.add_child(milestones_panel)

	var completion_tracker_panel: CompletionTrackerPanel = (
		_COMPLETION_TRACKER_PANEL_SCENE.instantiate() as CompletionTrackerPanel
	)
	completion_tracker_panel.completion_tracker = completion_tracker
	_ui_layer.add_child(completion_tracker_panel)

	var order_panel: OrderPanel = (
		_ORDER_PANEL_SCENE.instantiate() as OrderPanel
	)
	order_panel.order_system = order_system
	order_panel.economy_system = economy_system
	order_panel.store_type = String(GameManager.get_active_store_id())
	_ui_layer.add_child(order_panel)
	if _inventory_panel:
		_inventory_panel.order_panel = order_panel

	var trends_panel: TrendsPanel = (
		_TRENDS_PANEL_SCENE.instantiate() as TrendsPanel
	)
	trends_panel.trend_system = trend_system
	_ui_layer.add_child(trends_panel)

	_settings_panel = (
		_SETTINGS_PANEL_SCENE.instantiate() as SettingsPanel
	)
	_ui_layer.add_child(_settings_panel)

	_pause_menu = _PAUSE_MENU_SCENE.instantiate() as PauseMenu
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
		_SAVE_LOAD_PANEL_SCENE.instantiate() as SaveLoadPanel
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
		_PACK_OPENING_PANEL_SCENE.instantiate() as PackOpeningPanel
	)
	_ui_layer.add_child(_pack_opening_panel)

	_staff_panel = _STAFF_PANEL_SCENE.instantiate() as StaffPanel
	_ui_layer.add_child(_staff_panel)

	var upgrade_panel: UpgradePanel = (
		_UPGRADE_PANEL_SCENE.instantiate() as UpgradePanel
	)
	upgrade_panel.upgrade_system = store_upgrade_system
	upgrade_panel.economy_system = economy_system
	upgrade_panel.reputation_system = ReputationSystemSingleton
	upgrade_panel.data_loader = GameManager.data_loader
	upgrade_panel.store_type = GameManager.DEFAULT_STARTING_STORE
	_ui_layer.add_child(upgrade_panel)

	_ending_screen = (
		_ENDING_SCREEN_SCENE.instantiate() as EndingScreen
	)
	add_child(_ending_screen)
	_ending_screen.dismissed.connect(_on_ending_dismissed)

	_warranty_dialog = (
		_WARRANTY_DIALOG_SCENE.instantiate() as WarrantyDialog
	)
	_ui_layer.add_child(_warranty_dialog)
	checkout_system.set_warranty_dialog(_warranty_dialog)

	var initial_ctrl: StoreController = _find_store_controller(false)
	if initial_ctrl:
		_wire_pack_system(initial_ctrl)

	var moments_tray: MomentsTray = (
		_MOMENTS_TRAY_SCENE.instantiate() as MomentsTray
	)
	add_child(moments_tray)

	_setup_debug_overlay()

	_deferred_panels_loaded = true


## Forces deferred panels to load if not yet initialized.
func _ensure_deferred_panels() -> void:
	if not _deferred_panels_loaded:
		_setup_deferred_panels()


func _setup_debug_overlay() -> void:
	if not OS.is_debug_build():
		return
	var overlay: CanvasLayer = _DEBUG_OVERLAY_SCENE.instantiate()
	overlay.time_system = time_system
	overlay.economy_system = economy_system
	overlay.inventory_system = inventory_system
	overlay.customer_system = customer_system
	overlay.mall_customer_spawner = mall_customer_spawner
	overlay.checkout_system = checkout_system
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
		if not is_instance_valid(_nav_mesh_rebaker):
			_nav_mesh_rebaker = NavMeshRebaker.new()
			_nav_mesh_rebaker.name = "NavMeshRebaker"
			add_child(_nav_mesh_rebaker)
		_nav_mesh_rebaker.set_nav_region(nav_region)

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
	var new_gs: GameManager.State = new_state as GameManager.State
	var should_pause: bool = (
		new_gs == GameManager.State.PAUSED
		or new_gs == GameManager.State.BUILD
	)
	_set_systems_paused(should_pause)


func _find_store_controller(
	should_warn: bool = true
) -> StoreController:
	var result: StoreController = (
		_find_store_controller_recursive(_store_container)
	)
	if should_warn and not result:
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


## Day-summary "Return to Mall" button completes day advancement via
## `next_day_confirmed` (handled by DayCycleController, which lands the FSM
## in GAMEPLAY) and then transitions to MALL_OVERVIEW so the hub overview
## is the explicit foreground state.
##
## §F-55 — silent return on GAME_OVER is intentional: when the day cycle has
## already routed into the game-over flow, the day summary's "Return to Mall"
## button must not yank the FSM out of the terminal state. The player has the
## game-over UI for choosing what comes next; logging here would fire on the
## happy ending path.
func _on_day_summary_mall_overview_requested() -> void:
	if GameManager.current_state == GameManager.State.GAME_OVER:
		return
	GameManager.change_state(GameManager.State.MALL_OVERVIEW)


## Routes back to the main menu from the day summary screen. Mirrors the
## pause-menu "Return to Menu" path so the run is exited cleanly without
## advancing the day or running wages/milestones (the player is leaving).
## §F-105 — Silent return on GAME_OVER matches
## `_on_day_summary_mall_overview_requested`: the terminal state owns its own
## routing (the GameOver UI flow drives the return-to-menu transition itself),
## and a duplicate `go_to_main_menu()` call here would race with that routing.
func _on_day_summary_main_menu_requested() -> void:
	if GameManager.current_state == GameManager.State.GAME_OVER:
		return
	GameManager.go_to_main_menu()


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
	var store_ctrl: StoreController = _find_store_controller(false)
	if not store_ctrl:
		return

	var store_def: StoreDefinition = null
	if GameManager.data_loader:
		store_def = GameManager.data_loader.get_store(
			store_ctrl.store_type
		)
	if not store_def:
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
		var row: int = int(i / 3.0) * (size.y + 3)
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


## Hub-mode entry: routes through StoreDirector so the 6-state machine,
## AuditLog checkpoints, and StoreReadyContract verification all run. The
## actual scene injection happens in `_inject_store_into_container`, which the
## director invokes via the injector seam registered in `_ready()`.
func _on_hub_enter_store_requested(store_id: StringName) -> void:
	if _hub_is_inside_store:
		return
	StoreDirector.enter_store(store_id)


## Injector callable handed to StoreDirector. Loads the store packed scene,
## runs a crossfade, parents it under `StoreContainer`, activates its camera,
## emits `EventBus.store_entered`, and returns the scene root so the director
## can run `StoreReadyContract.check` against it. Returns null on any load
## failure — StoreDirector treats null as a load failure and FAILs the run.
func _inject_store_into_container(
	scene_path: String, store_id: StringName
) -> Node:
	if scene_path.is_empty():
		push_error("GameWorld: hub injector — empty scene_path for '%s'" % store_id)
		return null
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error("GameWorld: hub injector — unresolvable store_id '%s'" % store_id)
		return null
	var store_packed: PackedScene = load(scene_path) as PackedScene
	if store_packed == null:
		push_error("GameWorld: hub injector — failed to load scene '%s'" % scene_path)
		return null
	_hub_is_inside_store = true
	# §F-39 — guard `as Node3D` cast so a non-Node3D scene root (content
	# authoring error) doesn't reach `_store_container.add_child(null)`. Any
	# null returned here flows into StoreDirector's `_fail()` cleanly without
	# an extra Godot engine error from add_child.
	var instantiated: Node = null
	await _hub_transition.crossfade(func() -> void:
		instantiated = store_packed.instantiate()
		_hub_active_store_scene = instantiated as Node3D
		if _hub_active_store_scene == null:
			push_error(
				"GameWorld: hub injector — scene root for '%s' is not Node3D"
				% canonical
			)
			if instantiated != null:
				instantiated.queue_free()
			return
		_store_container.add_child(_hub_active_store_scene)
		# §F-47: Hide hallway storefronts (z=0.1) so they don't bleed into
		# the interior camera sightline. `_mall_hallway` is null in shipping
		# hub mode (walkable_mall=false) — the guard is forward-compat for
		# a future walkable-mall variant routing through the same injector.
		if _mall_hallway:
			_mall_hallway.visible = false
		var fp_spawned: bool = _spawn_player_in_store(
			_hub_active_store_scene, canonical
		)
		# Skip orbit-camera activation when an FP body spawned — its embedded
		# Camera3D is already current via CameraAuthority.request_current
		# (StorePlayerBody._ready). Activating the orbit StoreCamera here would
		# clear the FP camera and revert the viewport to overhead on entry.
		if not fp_spawned:
			_activate_store_camera(_hub_active_store_scene, canonical)
		EventBus.store_entered.emit(canonical)
	)
	if _hub_active_store_scene == null:
		_hub_is_inside_store = false
	return _hub_active_store_scene


## Hub-mode exit: removes active store scene with a crossfade.
func _on_hub_exit_store_requested() -> void:
	if not _hub_is_inside_store:
		return
	var leaving_id: StringName = GameManager.get_active_store_id()
	await _hub_transition.crossfade(func() -> void:
		if _hub_active_store_scene != null:
			_hub_active_store_scene.queue_free()
			_hub_active_store_scene = null
		_hub_is_inside_store = false
		# §F-47 — restore hallway visibility on exit. Same null-guard
		# rationale as the enter path.
		if _mall_hallway:
			_mall_hallway.visible = true
		EventBus.store_exited.emit(leaving_id)
	)


## Spawns the CharacterBody3D player avatar at the store's `PlayerEntrySpawn`
## marker and retires the orbit `PlayerController`'s input handler so WASD
## doesn't drive both the body and the orbit pivot at once. Returns `true`
## when the spawn ran, `false` when the store has no spawn marker (orbit-only
## stores). When the spawn runs, `StorePlayerBody._ready` registers the
## body's embedded eye-level Camera3D with `CameraAuthority` as the current
## camera (source `&"player_fp"`), so the injector intentionally skips
## `_activate_store_camera` to keep the FP camera current. Orbit-only stores
## fall through to `_activate_store_camera`, which makes the in-scene
## `StoreCamera` current per ownership.md row 4.
func _spawn_player_in_store(store_root: Node, store_id: StringName) -> bool:
	var marker: Marker3D = (
		store_root.get_node_or_null(_PLAYER_ENTRY_SPAWN_NAME) as Marker3D
	)
	if marker == null:
		return false
	var instantiated: Node = _STORE_PLAYER_SCENE.instantiate()
	var player: StorePlayerBody = instantiated as StorePlayerBody
	if player == null:
		push_error(
			"GameWorld: failed to instantiate store_player_body for '%s'"
			% store_id
		)
		if instantiated != null:
			instantiated.queue_free()
		return false
	store_root.add_child(player)
	# Apply the marker's global_transform — not just its origin — so the
	# spawn marker drives orientation. Marker3D's identity basis already
	# faces -Z (into the store from the front entrance) so authoring a
	# rotated marker for a future store will Just Work.
	player.global_transform = marker.global_transform
	_apply_marker_bounds_override(player, marker)
	_retire_orbit_player_controller(store_root)
	return true


## Applies per-store footprint clamps from `PlayerEntrySpawn` marker metadata
## (`bounds_min` / `bounds_max`). Stores that omit the metadata fall through
## to the script's defaults — the default already targets the canonical
## 16×20 retail interior, so a missing override is not an error.
##
## §F-56 — Wrong-type metadata is a content-authoring bug (the marker carries a
## `bounds_min` key but the value isn't a `Vector3`). Falling silently through
## to the default footprint can let the player walk through walls in a store
## whose interior is smaller than the default bounds, so the type mismatch is
## escalated via `push_warning` per side instead of an unconditional silent
## fallback. `null` (key absent) is the documented opt-out and stays silent.
func _apply_marker_bounds_override(player: StorePlayerBody, marker: Marker3D) -> void:
	var bmin: Variant = marker.get_meta(&"bounds_min", null)
	if bmin is Vector3:
		player.bounds_min = bmin
	elif bmin != null:
		push_warning(
			"GameWorld: PlayerEntrySpawn.bounds_min is %s, expected Vector3 — using default"
			% type_string(typeof(bmin))
		)
	var bmax: Variant = marker.get_meta(&"bounds_max", null)
	if bmax is Vector3:
		player.bounds_max = bmax
	elif bmax != null:
		push_warning(
			"GameWorld: PlayerEntrySpawn.bounds_max is %s, expected Vector3 — using default"
			% type_string(typeof(bmax))
		)


## Disables `PlayerController._input_listening` so its WASD/orbit handler
## stops competing with the CharacterBody3D's `move_and_slide`. The orbit
## camera was already deactivated by `CameraAuthority._clear_others` when the
## body camera became current; this only silences input.
##
## §F-46 — silent return when no `PlayerController` child exists is
## intentional: stores authored without a legacy orbit controller (any store
## that uses `PlayerEntrySpawn` exclusively) have nothing to retire. The
## walking-body path runs unimpeded and there is no input contention. A
## `push_warning` here would fire on every well-formed walking-only store.
func _retire_orbit_player_controller(store_root: Node) -> void:
	var orbit: PlayerController = (
		store_root.get_node_or_null("PlayerController") as PlayerController
	)
	if orbit == null:
		return
	orbit.set_input_listening(false)


## Activates the store scene's `StoreCamera` through `CameraAuthority` so
## exactly one camera is current (per ownership.md row 4). Fails loud if the
## scene has no Camera3D — the hub path cannot render without one.
func _activate_store_camera(store_root: Node, store_id: StringName) -> void:
	var camera: Camera3D = _find_first_camera(store_root)
	if camera == null:
		push_error(
			(
				"GameWorld: store '%s' has no Camera3D — rendering will fall back"
				+ " to the default clear color (brown)"
			)
			% store_id
		)
		return
	CameraAuthority.request_current(camera, store_id)


func _find_first_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node as Camera3D
	for child: Node in node.get_children():
		var found: Camera3D = _find_first_camera(child)
		if found != null:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	# ISSUE-011: ESC globally skips an active tutorial before the existing
	# exit/cancel chain. Runs ahead of the hub-mode early returns so the skip
	# works in both Main Menu→Overview transition steps and in-store steps.
	if event.is_action_pressed("ui_cancel") and _try_skip_active_tutorial():
		get_viewport().set_input_as_handled()
		return
	if _mall_hallway != null:
		return
	if not _hub_is_inside_store:
		return
	if event.is_action_pressed("ui_cancel"):
		EventBus.exit_store_requested.emit()
		get_viewport().set_input_as_handled()


# ISSUE-011: returns true (and emits skip_tutorial_requested) when a tutorial
# step is mid-flight. Callers must consume the input event when this returns
# true so exit/cancel handlers downstream do not also fire.
func _try_skip_active_tutorial() -> bool:
	if not GameManager.is_tutorial_active:
		return false
	if tutorial_system == null:
		return false
	if tutorial_system.current_step == TutorialSystem.TutorialStep.FINISHED:
		return false
	EventBus.skip_tutorial_requested.emit()
	return true


func _on_store_entered(store_id: StringName) -> void:
	if performance_manager:
		performance_manager.begin_store_switch()

	var store_ctrl: StoreController = _find_store_controller(true)
	if store_ctrl and store_state_manager:
		store_state_manager.restore_store_state(
			String(store_id), store_ctrl
		)
	# Hub auto-enter emits `EventBus.store_entered` directly without routing
	# through `StoreStateManager.set_active_store`, leaving `active_store_id`
	# empty. Set it here so readers (InventoryPanel, tutorial gates, etc.)
	# observe the active store. Pass `false` so `set_active_store` does not
	# re-emit `store_entered` / `store_exited`.
	# §F-90 — Pass 13: silent skip on null `store_state_manager` is the
	# Tier-2 init pattern (mirrors §J2 / §F-30). `store_state_manager` is
	# created in `initialize_tier_2_state`; production paths always run
	# Tier 2 before any `store_entered` can fire. Headless/unit fixtures
	# that emit the signal without staging Tier 2 take the silent path,
	# and any reader of `active_store_id` already handles the empty case
	# loudly (e.g. `InventoryPanel._refresh_grid` push_warning).
	if store_state_manager:
		store_state_manager.set_active_store(store_id, false)

	if store_ctrl:
		_wire_base_store_controller(store_ctrl)
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


func _wire_base_store_controller(store_ctrl: StoreController) -> void:
	store_ctrl.set_inventory_system(inventory_system)
	store_ctrl.set_customer_system(customer_system)


## Wires up a VideoRentalStoreController with system references if applicable.
func _wire_rental_system(store_ctrl: StoreController) -> void:
	if not store_ctrl is VideoRentalStoreController:
		return
	var rental: VideoRentalStoreController = (
		store_ctrl as VideoRentalStoreController
	)
	rental.set_inventory_system(inventory_system)
	rental.set_economy_system(economy_system)
	rental.set_reputation_system(ReputationSystemSingleton)
	save_manager.set_rental_system(rental)
	if _inventory_panel:
		_inventory_panel.rental_controller = rental


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
		if seasonal_event_system:
			pc_ctrl.set_seasonal_event_system(seasonal_event_system)
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
		sports.set_economy_system(economy_system)
		var cycle: SeasonCycleSystem = sports.get_season_cycle()
		economy_system.set_season_cycle_system(cycle)
		save_manager.set_season_cycle_system(cycle)
		if _item_tooltip:
			_item_tooltip.season_cycle_system = cycle
		_ensure_condition_picker_dialog(sports)
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


func _ensure_condition_picker_dialog(
	_sports: SportsMemorabiliaController,
) -> void:
	if not _condition_picker_dialog:
		_condition_picker_dialog = (
			_CONDITION_PICKER_DIALOG_SCENE.instantiate()
			as ConditionPickerDialog
		)
		_ui_layer.add_child(_condition_picker_dialog)
	_condition_picker_dialog.set_inventory_system(inventory_system)


func _ensure_refurbishment_ui(
	refurb: RefurbishmentSystem,
) -> void:
	if not _refurbishment_dialog:
		_refurbishment_dialog = (
			_REFURBISHMENT_DIALOG_SCENE.instantiate()
			as RefurbishmentDialog
		)
		_ui_layer.add_child(_refurbishment_dialog)
	_refurbishment_dialog.set_refurbishment_system(refurb)
	if _inventory_panel:
		_inventory_panel.refurbishment_dialog = _refurbishment_dialog
	if not _refurb_queue_panel:
		_refurb_queue_panel = (
			_REFURB_QUEUE_PANEL_SCENE.instantiate()
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


func apply_pending_session_state() -> void:
	var slot: int = GameManager.pending_load_slot
	GameManager.pending_load_slot = -1
	if slot >= 0:
		var save_metadata: Dictionary = save_manager.get_slot_metadata(slot)
		if save_manager.load_game(slot):
			_validate_loaded_game_state(save_metadata)
		else:
			EventBus.notification_requested.emit(
				"Save slot %d could not be loaded — returning to main menu." % slot
			)
			GameManager.go_to_main_menu()
	else:
		tutorial_system.initialize(true)
		EventBus.day_started.emit(1)
		_auto_enter_default_store_in_hub()


## BRAINDUMP Phase 1: a new game must drop the player inside the starter
## store immediately rather than parking them in the mall overview UI.
## Routes through the same `enter_store_requested` signal a card click would
## emit so the StoreDirector state machine, AuditLog checkpoints, and
## StoreReadyContract verification all run unmodified. Hub mode is the only
## mode where this auto-entry applies — the walkable-mall variant routes
## through `MallHallway` and is opt-in via `debug/walkable_mall`.
##
## §F-67 — `_hub_transition == null` silent return is the test-seam fallback
## for unit fixtures that drive `apply_pending_session_state` without
## staging the hub's `HubTransition` child. Production `GameWorld._setup_ui`
## creates `_hub_transition` before this code path can run. The
## `_hub_is_inside_store` short-circuit covers the legitimate case where a
## prior load already entered a store (rentry guard); silent is correct
## because the existing store session is the desired state.
func _auto_enter_default_store_in_hub() -> void:
	if _hub_transition == null:
		return
	if _hub_is_inside_store:
		return
	EventBus.enter_store_requested.emit(GameManager.DEFAULT_STARTING_STORE)


## Populates and validates the default store before the player sees the hallway.
func bootstrap_new_game_state(
	store_id: StringName = GameManager.DEFAULT_STARTING_STORE
) -> void:
	var slot_index: int = _find_store_slot_index(store_id)
	if slot_index < 0:
		push_error(
			"GameWorld: default store '%s' not found in storefront slots"
			% store_id
		)
		return
	if not store_state_manager:
		push_error("GameWorld: cannot bootstrap new game without StoreStateManager")
		return
	store_state_manager.lease_store(slot_index, store_id, store_id)
	EventBus.owned_slots_restored.emit(store_state_manager.owned_slots)
	_create_default_store_inventory(store_id)
	_validate_new_game_state(store_id)


func _find_store_slot_index(store_id: StringName) -> int:
	if _mall_hallway:
		var slot_ids: Array[StringName] = _mall_hallway.slot_store_ids
		for i: int in range(slot_ids.size()):
			if slot_ids[i] == store_id:
				return i
		return -1
	var all_ids: Array[StringName] = ContentRegistry.get_all_ids("store")
	return all_ids.find(store_id)


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
	# §F-83 — Pass 12: surface a content-authoring regression at the call
	# site too. `create_starting_inventory` already warns when the store id
	# is unknown, but a known store whose `starting_inventory` is empty (or
	# whose every entry was filtered out by the category guard) would
	# otherwise reach Day 1 with nothing in the backroom — i.e. the tutorial
	# loop would have nothing to stock and silently stall.
	if items.is_empty():
		push_warning(
			"GameWorld: starter inventory for '%s' is empty — Day 1 backroom will be empty"
			% store_id
		)
	for item: ItemInstance in items:
		inventory_system.add_item(store_id, item)


func _get_configured_starting_cash() -> float:
	var starting_cash: float = Constants.STARTING_CASH
	if not GameManager.data_loader:
		return starting_cash
	var economy_config: EconomyConfig = (
		GameManager.data_loader.get_economy_config()
	)
	if economy_config:
		starting_cash = economy_config.starting_cash
	return starting_cash


## Matches `EconomySystem.initialize`: base config × difficulty starting_cash_multiplier.
func _get_effective_starting_cash() -> float:
	var base: float = _get_configured_starting_cash()
	var cash_mult: float = DifficultySystemSingleton.get_modifier(
		&"starting_cash_multiplier"
	)
	return base * cash_mult


func _validate_loaded_game_state(save_metadata: Dictionary = {}) -> void:
	var expected_cash: Variant = save_metadata.get("cash", null)
	var active_store_raw: String = str(
		save_metadata.get("active_store_id", "")
	)
	var expected_active_store: StringName = &""
	if not active_store_raw.is_empty():
		expected_active_store = ContentRegistry.resolve(active_store_raw)
		if expected_active_store.is_empty():
			expected_active_store = StringName(active_store_raw)
	var errors: Array[String] = _collect_state_validation_errors(
		expected_active_store,
		expected_cash,
		true,
		save_metadata.has("active_store_id")
	)
	for msg: String in errors:
		# §F-16: push_error is intentional (state inconsistency detected), but the
		# game continues — forcing a menu-return here would be worse than degraded
		# gameplay. See docs/audits/error-handling-report.md §F-16.
		push_error("Load validation failed: %s" % msg)


func _validate_new_game_state(store_id: StringName) -> void:
	var canonical_store_id: StringName = ContentRegistry.resolve(
		String(store_id)
	)
	if canonical_store_id.is_empty():
		canonical_store_id = store_id
	var errors: Array[String] = _collect_state_validation_errors(
		canonical_store_id,
		_get_effective_starting_cash(),
		true,
		false
	)
	for msg: String in errors:
		# §F-16: same as load validation — push_error is diagnostic, non-blocking.
		push_error("New game validation failed: %s" % msg)


func _collect_state_validation_errors(
	expected_store_id: StringName,
	expected_cash: Variant,
	require_inventory: bool,
	validate_active_store: bool
) -> Array[String]:
	var errors: Array[String] = []

	if GameManager.get_owned_store_ids().is_empty():
		errors.append("No owned stores are registered")

	if store_state_manager:
		if store_state_manager.owned_slots.is_empty():
			errors.append("StoreStateManager.owned_slots is empty")

	if economy_system:
		if is_nan(economy_system.get_cash()):
			errors.append("Player cash is NaN")
		elif expected_cash != null and not is_equal_approx(
			economy_system.get_cash(),
			float(expected_cash)
		):
			errors.append(
				"Player cash %.2f does not match expected %.2f"
				% [economy_system.get_cash(), float(expected_cash)]
			)

	if time_system and time_system.current_day < 1:
		errors.append(
			"Current day is %d (expected >= 1)" % time_system.current_day
		)

	if not expected_store_id.is_empty():
		if not GameManager.is_store_owned(String(expected_store_id)):
			errors.append(
				"Expected owned store '%s' is missing from owned_stores"
				% expected_store_id
			)
		if store_state_manager:
			var has_expected_slot: bool = false
			for owned_store_id: StringName in store_state_manager.owned_slots.values():
				if owned_store_id == expected_store_id:
					has_expected_slot = true
					break
			if not has_expected_slot:
				errors.append(
					"StoreStateManager has no owned slot for '%s'"
					% expected_store_id
				)
		if require_inventory and inventory_system:
			var store_stock: Array[ItemInstance] = inventory_system.get_stock(
				expected_store_id
			)
			if store_stock.is_empty():
				errors.append(
					"InventorySystem has no stock for '%s'" % expected_store_id
				)
	elif require_inventory and inventory_system and inventory_system.get_item_count() == 0:
		errors.append("Inventory is empty")

	if validate_active_store:
		var actual_active_store: StringName = GameManager.get_active_store_id()
		if actual_active_store != expected_store_id:
			errors.append(
				"Active store '%s' does not match saved active_store_id '%s'"
				% [actual_active_store, expected_store_id]
			)

	return errors


func _on_view_day_summary_requested() -> void:
	if _day_summary:
		_day_summary.show_last()


func _on_return_to_menu_pressed() -> void:
	GameManager.go_to_main_menu()


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
