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
var _time_system: TimeSystem = null
## store_id (StringName) -> StoreSlotCard
var _cards: Dictionary = {}
## store_id (String) -> int — today's sold count per store, reset on day_started.
var _store_sold_today: Dictionary = {}
## Ordered list matching ContentRegistry.get_all_store_ids() order at setup time.
var _all_store_ids: Array[StringName] = []
var _current_day: int = 1
var _current_hour: int = TimeSystem.MALL_OPEN_HOUR
var _moments_log_panel: MomentsLogPanel = null
var _performance_panel: PerformancePanel = null
var _completion_tracker: CompletionTracker = null

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
	_refresh_optional_button_visibility()


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
	# Silent return: signals (`inventory_updated`, `customer_purchased`) can
	# fire for store ids that have not been added to `_cards` yet — for
	# example before `_populate_stores` runs after `setup()`, or for hub-side
	# events tied to an unowned/locked store. The card grid is the canonical
	# render target; if a store has no card we have nothing to redraw and
	# the call is a no-op. See EH-08.
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
	card.update_today_sold(int(_store_sold_today.get(String(store_id), 0)))


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
				req_text = "Rep %d · $%s" % [
					rep, UIThemeConstants.format_thousands(cost)
				]
		(_cards[store_id] as StoreSlotCard).set_locked(locked, req_text)


func _refresh_all_reputation_tiers() -> void:
	for store_id: StringName in _cards:
		var tier_name: String = ReputationSystemSingleton.get_tier_name(
			String(store_id)
		)
		(_cards[store_id] as StoreSlotCard).set_reputation_tier(tier_name)


## Append a timestamped entry to the event feed, capped at _MAX_FEED_ENTRIES.
func _add_feed_entry(text: String) -> void:
	var entry: Label = Label.new()
	entry.text = "%s — %s" % [_format_timestamp(), text]
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_feed.add_child(entry)
	_event_feed.move_child(entry, 0)
	# remove_child + queue_free so get_child_count reflects removal immediately.
	while _event_feed.get_child_count() > _MAX_FEED_ENTRIES:
		var oldest: Node = _event_feed.get_child(_event_feed.get_child_count() - 1)
		_event_feed.remove_child(oldest)
		oldest.queue_free()


## Returns a 12-hour AM/PM timestamp like "9:02 AM". When `_time_system` is
## injected via `set_time_system`, minutes track game_time_minutes; otherwise
## the format degrades to ":00" using the last `hour_changed` value.
## §F-101 — Cosmetic-precision seam (paired with §F-95 mall-overview feed
## fallbacks). `set_time_system` is documented as optional; the hub remains
## operational with hour-only precision in headless tests / pre-Tier-1 frames
## that drive `EventBus.hour_changed` without a TimeSystem.
func _format_timestamp() -> String:
	var hour: int = _current_hour
	var minute: int = 0
	if _time_system != null:
		var total_minutes: int = int(_time_system.game_time_minutes)
		hour = int(total_minutes / 60)
		minute = total_minutes % 60
	var period: String = "AM" if hour < 12 else "PM"
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, period]


## Resolve a display-friendly item name from a canonical or alias item ID.
## Falls back to the registry's display-name resolution (which itself echoes
## the raw id when unknown), so an unregistered id surfaces as a string.
func _resolve_item_name(item_id: StringName) -> String:
	if item_id.is_empty():
		return ""
	var def: ItemDefinition = ContentRegistry.get_item_definition(item_id)
	if def != null and not def.item_name.is_empty():
		return def.item_name
	return ContentRegistry.get_display_name(item_id)


func _connect_signals() -> void:
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.customer_entered.connect(_on_customer_entered)
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
	EventBus.ambient_moment_delivered.connect(_on_ambient_moment_delivered)
	EventBus.item_sold.connect(_on_item_sold_for_buttons)


## Inject the runtime TimeSystem so feed timestamps reflect in-game minutes
## instead of degrading to the last-emitted hour boundary. Optional — feed
## entries still render with hour-only precision when no TimeSystem is wired.
func set_time_system(time_system: TimeSystem) -> void:
	_time_system = time_system


func _on_inventory_updated(store_id: StringName) -> void:
	if not _inventory_system or not _cards.has(store_id):
		return
	var stock: Array[ItemInstance] = _inventory_system.get_stock(store_id)
	(_cards[store_id] as StoreSlotCard).update_stock(stock.size())


## §F-95 — Empty `item_name` fallback to the literal "item" mirrors the
## §F-89 fallback in `CheckoutSystem._emit_sale_toast`: the feed entry is
## informational and a content-authoring hole (item registered without an
## `item_name`) is already caught by `tests/validate_*.sh` content suite at
## CI time. ContentRegistry.get_display_name itself echoes the raw id once
## per unknown id (warning-suppressed via `_warn_helper_fallback_once`), so
## the fallback word here is the cosmetic seam, not the diagnostic surface.
func _on_item_stocked(item_id: String, _shelf_id: String) -> void:
	var item_name: String = _resolve_item_name(StringName(item_id))
	if item_name.is_empty():
		item_name = "item"
	_add_feed_entry("Stocked %s" % item_name)


## §F-95 — Empty `store_id` from the customer payload falls back to the
## literal "the mall". `EventBus.customer_entered` is also emitted for
## hub-mode wanderers with no specific store target, so the empty case is a
## legitimate non-error path; the literal is the cosmetic seam.
func _on_customer_entered(customer_data: Dictionary) -> void:
	var store_id_raw: String = String(customer_data.get("store_id", ""))
	var store_name: String = "the mall"
	if not store_id_raw.is_empty():
		store_name = ContentRegistry.get_display_name(StringName(store_id_raw))
	_add_feed_entry("Customer entered %s" % store_name)


func _on_customer_purchased(
	store_id: StringName,
	item_id: StringName,
	price: float,
	_customer_id: StringName,
) -> void:
	# Increment the per-store sold-today counter even when there is no card
	# for the store yet: the dict is reset by `_on_day_started` and is read
	# only through `_cards`, so unknown-store entries are bounded by one day
	# and never surface to the UI. The silent card-miss return below is
	# covered by EH-08.
	var key: String = String(store_id)
	_store_sold_today[key] = int(_store_sold_today.get(key, 0)) + 1
	# §F-95 — same cosmetic-seam fallback as `_on_item_stocked` above.
	var item_name: String = _resolve_item_name(item_id)
	if item_name.is_empty():
		item_name = "item"
	var price_text: String = UIThemeConstants.format_thousands(int(round(price)))
	_add_feed_entry("Sold %s for $%s" % [item_name, price_text])
	if not _cards.has(store_id):
		return
	var card: StoreSlotCard = _cards[store_id] as StoreSlotCard
	if _economy_system:
		card.update_revenue(_economy_system.get_store_daily_revenue(key))
	card.update_today_sold(int(_store_sold_today[key]))


func _on_day_started(day: int) -> void:
	_current_day = day
	_store_sold_today.clear()
	for store_id: StringName in _cards:
		var card: StoreSlotCard = _cards[store_id] as StoreSlotCard
		card.update_revenue(0.0)
		card.set_event_pending(false)
		card.update_today_sold(0)
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
	var store_name: String = (
		ContentRegistry.get_display_name(store_id)
		if not store_id.is_empty() else "mall"
	)
	_add_feed_entry("Market event at %s: %s" % [store_name, String(event_id)])


func _on_random_event_triggered(
	event_id: StringName, store_id: StringName, _effect: Dictionary
) -> void:
	if _cards.has(store_id):
		(_cards[store_id] as StoreSlotCard).set_event_pending(true)
	var store_name: String = (
		ContentRegistry.get_display_name(store_id)
		if not store_id.is_empty() else "mall"
	)
	_add_feed_entry("Event at %s: %s" % [store_name, String(event_id)])


func _on_milestone_reached(milestone_id: StringName) -> void:
	_add_feed_entry("Milestone: %s" % String(milestone_id))
	_refresh_optional_button_visibility()


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
	_refresh_optional_button_visibility()


func _on_ambient_moment_delivered(
	_moment_id: StringName,
	_display_type: StringName,
	_flavor_text: String,
	_audio_cue_id: StringName,
) -> void:
	_refresh_optional_button_visibility()


func _on_item_sold_for_buttons(
	_item_id: String, _price: float, _category: String
) -> void:
	# Sales advance multiple completion criteria; refresh button visibility
	# so Completion appears once the first criterion gains progress.
	_refresh_optional_button_visibility()


func _on_card_store_selected(store_id: StringName) -> void:
	var scene_path: String = ContentRegistry.get_scene_path(store_id)
	AuditLog.pass_check(
		&"mall_card_clicked",
		"store_id=%s scene=%s" % [store_id, scene_path]
	)
	store_selected.emit(store_id)
	EventBus.enter_store_requested.emit(store_id)


func set_moments_log_panel(panel: MomentsLogPanel) -> void:
	_moments_log_panel = panel
	_refresh_optional_button_visibility()


func set_performance_panel(panel: PerformancePanel) -> void:
	_performance_panel = panel


## Wire the CompletionTracker so the Completion button can hide itself when
## no criterion has any progress yet (otherwise it leads to an all-Locked
## placeholder list).
func set_completion_tracker(tracker: CompletionTracker) -> void:
	_completion_tracker = tracker
	_refresh_optional_button_visibility()


## Hide Moments Log and Completion buttons when they would lead to empty or
## placeholder content. Performance is always kept visible — it is on the
## BRAINDUMP "for now" keep list regardless of data availability.
func _refresh_optional_button_visibility() -> void:
	if _moments_log_button:
		_moments_log_button.visible = _moments_log_has_content()
	if _completion_button:
		_completion_button.visible = _completion_has_progress()
	if _performance_button:
		_performance_button.visible = true


## Silent `false` return when the panel/system isn't wired is the documented
## button-gating contract: an unwired panel cannot have content, so the
## Moments Log button hides until `set_moments_log_panel` runs and the system
## reports at least one witnessed entry. See EH-08.
func _moments_log_has_content() -> bool:
	if _moments_log_panel == null:
		return false
	var system: AmbientMomentsSystem = _moments_log_panel.ambient_moments_system
	if system == null:
		return false
	return not system.get_witnessed_log().is_empty()


## Silent `false` return when the tracker isn't wired keeps the Completion
## button hidden until `set_completion_tracker` runs (called from
## `game_world._setup_deferred_panels`). The same contract as
## `_moments_log_has_content`. See EH-08.
func _completion_has_progress() -> bool:
	if _completion_tracker == null:
		return false
	for criterion: Dictionary in _completion_tracker.get_completion_data():
		if bool(criterion.get("complete", false)):
			return true
		if float(criterion.get("current", 0.0)) > 0.0:
			return true
	return false


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
	_emit_day_close_requested()


func _emit_day_close_requested() -> void:
	EventBus.day_close_requested.emit()


func _on_completion_pressed() -> void:
	EventBus.toggle_completion_tracker_panel.emit()


func _on_store_entered(_store_id: StringName) -> void:
	visible = false


func _on_store_exited(_store_id: StringName) -> void:
	visible = true
