## Bird's-eye store navigation hub.
## Renders all five stores with live revenue, reputation tier badge, alert badges,
## and locked/unlock-requirements state. Includes a real-time event feed showing
## the last 10 player-relevant EventBus events with day/hour timestamps.
## Signal-driven: no direct store controller node references.
## Call setup() once after instantiation to wire inventory and economy systems.
class_name MallOverview
extends Control

signal store_selected(store_id: StringName)

const _STORE_SLOT_CARD_SCENE: PackedScene = preload(
	"res://game/scenes/mall/store_slot_card.tscn"
)
const _MAX_FEED_ENTRIES: int = 10

const _PHASE_NAMES: Dictionary = {
	0: "Pre-Open",
	1: "Morning",
	2: "Midday Rush",
	3: "Afternoon",
	4: "Evening",
}

var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
## store_id (StringName) -> StoreSlotCard
var _cards: Dictionary = {}
## Ordered list matching ContentRegistry.get_all_store_ids() order at setup time.
var _all_store_ids: Array[StringName] = []
var _current_day: int = 1
var _current_hour: int = 0
var _moments_log_panel: MomentsLogPanel = null
var _performance_panel: PerformancePanel = null

@onready var _store_grid: HBoxContainer = $VBox/StoreGrid
@onready var _day_close_button: Button = $VBox/BottomRow/DayCloseButton
@onready var _moments_log_button: Button = $VBox/BottomRow/MomentsLogButton
@onready var _completion_button: Button = $VBox/BottomRow/CompletionButton
@onready var _performance_button: Button = (
	$VBox/BottomRow/PerformanceButton
)
@onready var _event_feed: VBoxContainer = $VBox/EventFeedScroll/EventFeed


func _ready() -> void:
	_connect_signals()
	_day_close_button.pressed.connect(_on_day_close_pressed)
	_moments_log_button.pressed.connect(_on_moments_log_pressed)
	_completion_button.pressed.connect(_on_completion_pressed)
	_performance_button.pressed.connect(_on_performance_pressed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


## Wire runtime systems and populate store cards.
## Must be called from GameWorld after systems are initialized.
func setup(
	inventory_system: InventorySystem,
	economy_system: EconomySystem,
) -> void:
	_inventory_system = inventory_system
	_economy_system = economy_system
	_populate_stores()
	_refresh_all_locked_states()
	_refresh_all_reputation_tiers()


func _populate_stores() -> void:
	for child: Node in _store_grid.get_children():
		child.queue_free()
	_cards.clear()

	_all_store_ids = ContentRegistry.get_all_store_ids()
	for store_id: StringName in _all_store_ids:
		var card: StoreSlotCard = _STORE_SLOT_CARD_SCENE.instantiate() as StoreSlotCard
		_store_grid.add_child(card)
		var display_name: String = ContentRegistry.get_display_name(store_id)
		card.setup(store_id, display_name)
		card.store_selected.connect(_on_card_store_selected)
		_cards[store_id] = card
		_refresh_card(store_id)


func _refresh_card(store_id: StringName) -> void:
	if not _cards.has(store_id):
		return
	var card: StoreSlotCard = _cards[store_id] as StoreSlotCard
	if _economy_system:
		card.update_revenue(
			_economy_system.get_store_daily_revenue(String(store_id))
		)
	if _inventory_system:
		var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
		card.update_stock(stock.size())


func _refresh_all_locked_states() -> void:
	var owned: Array[StringName] = GameManager.get_owned_store_ids()
	for i: int in range(_all_store_ids.size()):
		var store_id: StringName = _all_store_ids[i]
		if not _cards.has(store_id):
			continue
		var locked: bool = not (store_id in owned)
		var req_text: String = ""
		if locked and i < StoreStateManager.LEASE_UNLOCK_REQUIREMENTS.size():
			var req: Dictionary = StoreStateManager.LEASE_UNLOCK_REQUIREMENTS[i]
			if not req.is_empty():
				var rep: int = int(req.get("reputation", 0))
				var cost: int = int(req.get("cost", 0))
				req_text = "REP %d | $%d" % [rep, cost]
		(_cards[store_id] as StoreSlotCard).set_locked(locked, req_text)


func _refresh_all_reputation_tiers() -> void:
	for store_id: StringName in _cards:
		var tier_name: String = ReputationSystemSingleton.get_tier_name(
			String(store_id)
		)
		(_cards[store_id] as StoreSlotCard).set_reputation_tier(tier_name)


## Append a timestamped entry to the event feed, capped at _MAX_FEED_ENTRIES.
func _add_feed_entry(text: String) -> void:
	var timestamp: String = "D%d %02dh" % [_current_day, _current_hour]
	var entry: Label = Label.new()
	entry.text = "[%s] %s" % [timestamp, text]
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_feed.add_child(entry)
	_event_feed.move_child(entry, 0)
	# remove_child + queue_free so get_child_count reflects removal immediately.
	while _event_feed.get_child_count() > _MAX_FEED_ENTRIES:
		var oldest: Node = _event_feed.get_child(_event_feed.get_child_count() - 1)
		_event_feed.remove_child(oldest)
		oldest.queue_free()


func _connect_signals() -> void:
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.day_started.connect(_on_day_started)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.market_event_triggered.connect(_on_market_event_triggered)
	EventBus.random_event_triggered.connect(_on_random_event_triggered)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	EventBus.rental_overdue.connect(_on_rental_overdue)
	EventBus.reputation_tier_changed.connect(_on_reputation_tier_changed)
	EventBus.owned_slots_restored.connect(_on_owned_slots_restored)
	EventBus.store_slot_unlocked.connect(_on_store_slot_unlocked)


func _on_inventory_updated(store_id: StringName) -> void:
	if not _inventory_system or not _cards.has(store_id):
		return
	var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	(_cards[store_id] as StoreSlotCard).update_stock(stock.size())


func _on_customer_purchased(
	store_id: StringName,
	_item_id: StringName,
	_price: float,
	_customer_id: StringName,
) -> void:
	if not _economy_system or not _cards.has(store_id):
		return
	(_cards[store_id] as StoreSlotCard).update_revenue(
		_economy_system.get_store_daily_revenue(String(store_id))
	)


func _on_day_started(day: int) -> void:
	_current_day = day
	for store_id: StringName in _cards:
		var card: StoreSlotCard = _cards[store_id] as StoreSlotCard
		card.update_revenue(0.0)
		card.set_event_pending(false)
		if _inventory_system:
			var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
			card.update_stock(stock.size())
	_add_feed_entry("Day %d started" % day)


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour


func _on_day_closed(_day: int, summary: Dictionary) -> void:
	var store_revenues: Dictionary = summary.get("store_daily_revenue", {})
	for store_id: StringName in _cards:
		var rev: float = store_revenues.get(String(store_id), 0.0)
		(_cards[store_id] as StoreSlotCard).update_revenue(rev)


func _on_day_phase_changed(new_phase: int) -> void:
	var phase_name: String = _PHASE_NAMES.get(new_phase, "Phase %d" % new_phase)
	_add_feed_entry("Phase: %s" % phase_name)


func _on_market_event_triggered(
	event_id: StringName, store_id: StringName, _effect: Dictionary
) -> void:
	if _cards.has(store_id):
		(_cards[store_id] as StoreSlotCard).set_event_pending(true)
	var store_name: String = ContentRegistry.get_display_name(store_id) if not store_id.is_empty() else "mall"
	_add_feed_entry("Market event at %s: %s" % [store_name, String(event_id)])


func _on_random_event_triggered(
	event_id: StringName, store_id: StringName, _effect: Dictionary
) -> void:
	if _cards.has(store_id):
		(_cards[store_id] as StoreSlotCard).set_event_pending(true)
	var store_name: String = ContentRegistry.get_display_name(store_id) if not store_id.is_empty() else "mall"
	_add_feed_entry("Event at %s: %s" % [store_name, String(event_id)])


func _on_milestone_reached(milestone_id: StringName) -> void:
	_add_feed_entry("Milestone: %s" % String(milestone_id))


func _on_rental_overdue(_customer_id: String, item_id: String) -> void:
	_add_feed_entry("Overdue rental: %s" % item_id)


func _on_reputation_tier_changed(
	store_id: String, _old_tier: int, _new_tier: int
) -> void:
	var sid: StringName = StringName(store_id)
	if not _cards.has(sid):
		return
	var tier_name: String = ReputationSystemSingleton.get_tier_name(store_id)
	(_cards[sid] as StoreSlotCard).set_reputation_tier(tier_name)
	var store_name: String = ContentRegistry.get_display_name(sid)
	_add_feed_entry("%s rep: %s" % [store_name, tier_name])


func _on_owned_slots_restored(_slots: Dictionary) -> void:
	_refresh_all_locked_states()


func _on_store_slot_unlocked(_slot_index: int) -> void:
	_refresh_all_locked_states()
	_add_feed_entry("New store slot unlocked!")


func _on_card_store_selected(store_id: StringName) -> void:
	store_selected.emit(store_id)
	EventBus.enter_store_requested.emit(store_id)


func set_moments_log_panel(panel: MomentsLogPanel) -> void:
	_moments_log_panel = panel


func set_performance_panel(panel: PerformancePanel) -> void:
	_performance_panel = panel


func _on_moments_log_pressed() -> void:
	if not _moments_log_panel:
		return
	if _moments_log_panel.is_open():
		_moments_log_panel.close()
	else:
		_moments_log_panel.open()


func _on_performance_pressed() -> void:
	if not _performance_panel:
		return
	if _performance_panel.is_open():
		_performance_panel.close()
	else:
		_performance_panel.open()


func _on_day_close_pressed() -> void:
	EventBus.day_close_requested.emit()


func _on_completion_pressed() -> void:
	EventBus.toggle_completion_tracker_panel.emit()


func _on_store_entered(_store_id: StringName) -> void:
	visible = false


func _on_store_exited(_store_id: StringName) -> void:
	visible = true
