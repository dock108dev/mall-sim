## Day 1 quarantine guards: HaggleSystem, MarketEventSystem, SeasonalEventSystem,
## MetaShiftSystem, TrendSystem must not emit on Day 1; HUD ticker must yield to
## ObjectiveRail and InteractionPrompt; MilestonesButton hidden in STORE_VIEW
## on Day 1.
extends GutTest


const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _saved_state: GameManager.State
var _saved_day: int
var _saved_data_loader: DataLoader


func before_all() -> void:
	_saved_state = GameManager.current_state
	_saved_day = GameManager.get_current_day()
	_saved_data_loader = GameManager.data_loader
	DataLoaderSingleton.load_all_content()
	GameManager.data_loader = DataLoaderSingleton


func after_all() -> void:
	GameManager.current_state = _saved_state
	GameManager.set_current_day(_saved_day)
	GameManager.data_loader = _saved_data_loader


func before_each() -> void:
	GameManager.set_current_day(1)


func after_each() -> void:
	GameManager.set_current_day(1)


# ── HaggleSystem ─────────────────────────────────────────────────────────────

func test_haggle_system_should_not_haggle_on_day_one() -> void:
	var rep: ReputationSystem = ReputationSystem.new()
	rep.auto_connect_bus = false
	add_child_autofree(rep)
	rep.initialize_store("retro_games")

	var haggle: HaggleSystem = HaggleSystem.new()
	add_child_autofree(haggle)
	haggle.initialize(rep)

	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "test_buyer"
	profile.customer_name = "Test Buyer"
	profile.budget_range = [5.0, 200.0]
	profile.patience = 0.9
	profile.price_sensitivity = 1.0
	profile.preferred_categories = PackedStringArray(["games"])
	profile.preferred_tags = PackedStringArray([])
	profile.condition_preference = "good"
	profile.browse_time_range = [30.0, 60.0]
	profile.purchase_probability_base = 0.8
	profile.impulse_buy_chance = 0.0
	profile.mood_tags = PackedStringArray([])

	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = profile

	var defn: ItemDefinition = ItemDefinition.new()
	defn.id = "test_game"
	defn.item_name = "Test Game"
	defn.category = "games"
	defn.base_price = 50.0
	defn.rarity = "common"
	defn.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	var item: ItemInstance = ItemInstance.create_from_definition(defn, "good")
	item.player_set_price = 65.0

	GameManager.set_current_day(1)
	for i: int in range(20):
		assert_false(
			haggle.should_haggle(customer, item),
			"HaggleSystem must never trigger on Day 1"
		)


# ── MarketEventSystem ────────────────────────────────────────────────────────

func test_market_event_system_silent_on_day_one() -> void:
	var system: MarketEventSystem = MarketEventSystem.new()
	add_child_autofree(system)
	system.initialize()

	watch_signals(EventBus)
	GameManager.set_current_day(1)
	system._on_day_started(1)

	assert_signal_not_emitted(EventBus, "market_event_announced")
	assert_signal_not_emitted(EventBus, "market_event_started")
	assert_signal_not_emitted(EventBus, "market_event_active")
	assert_signal_not_emitted(EventBus, "market_event_ended")


# ── SeasonalEventSystem ──────────────────────────────────────────────────────

func test_seasonal_event_system_silent_on_day_one() -> void:
	var system: SeasonalEventSystem = SeasonalEventSystem.new()
	add_child_autofree(system)
	system.initialize(GameManager.data_loader)

	watch_signals(EventBus)
	GameManager.set_current_day(1)
	system._on_day_started(1)

	assert_signal_not_emitted(EventBus, "seasonal_event_started")
	assert_signal_not_emitted(EventBus, "seasonal_event_announced")
	assert_signal_not_emitted(EventBus, "seasonal_multipliers_updated")
	assert_signal_not_emitted(EventBus, "season_changed")
	assert_signal_not_emitted(EventBus, "tournament_event_announced")
	assert_signal_not_emitted(EventBus, "tournament_event_started")


# ── MetaShiftSystem ──────────────────────────────────────────────────────────

func test_meta_shift_system_silent_on_day_one() -> void:
	var system: MetaShiftSystem = MetaShiftSystem.new()
	add_child_autofree(system)
	system.initialize(GameManager.data_loader)

	watch_signals(EventBus)
	system._on_day_started(1)

	assert_signal_not_emitted(EventBus, "meta_shift_announced")
	assert_signal_not_emitted(EventBus, "meta_shift_telegraphed")
	assert_signal_not_emitted(EventBus, "meta_shift_activated")
	assert_signal_not_emitted(EventBus, "meta_shift_started")


# ── TrendSystem ──────────────────────────────────────────────────────────────

func test_trend_system_silent_on_day_one() -> void:
	var system: TrendSystem = TrendSystem.new()
	add_child_autofree(system)
	system.initialize(GameManager.data_loader)

	watch_signals(EventBus)
	system._on_day_started(1)

	assert_signal_not_emitted(EventBus, "trend_changed")
	assert_signal_not_emitted(EventBus, "trend_updated")
	assert_signal_not_emitted(EventBus, "notification_requested")


# ── HUD ticker priority ──────────────────────────────────────────────────────

func test_telegraph_card_hidden_when_objective_active() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	EventBus.game_state_changed.emit(
		int(GameManager.State.MAIN_MENU),
		int(GameManager.State.MALL_OVERVIEW)
	)

	EventBus.event_telegraphed.emit("summer_sale", 2)
	var card: Label = hud.get_node("TelegraphCard")
	assert_true(card.visible, "Telegraph card should appear with no higher priority")

	EventBus.objective_text_changed.emit("Place merchandise on the empty shelves")
	assert_false(
		card.visible,
		"Telegraph card must hide when ObjectiveRail has active objective text"
	)

	EventBus.objective_text_changed.emit("")
	assert_true(
		card.visible,
		"Telegraph card must reappear when objective text is cleared"
	)


func test_telegraph_card_hidden_when_interactable_focused() -> void:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	EventBus.game_state_changed.emit(
		int(GameManager.State.MAIN_MENU),
		int(GameManager.State.MALL_OVERVIEW)
	)

	EventBus.event_telegraphed.emit("summer_sale", 2)
	var card: Label = hud.get_node("TelegraphCard")
	assert_true(card.visible)

	EventBus.interactable_focused.emit("Stock shelf")
	assert_false(
		card.visible,
		"Telegraph card must hide while an interactable is focused"
	)

	EventBus.interactable_unfocused.emit()
	assert_true(
		card.visible,
		"Telegraph card must reappear after interactable_unfocused"
	)
