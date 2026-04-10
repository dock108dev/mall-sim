## Manages the 5 guaranteed ambient 'something weird' moments.
class_name AmbientMomentsSystem
extends Node


const CLUE_EXTRA_DELIVERY: String = "ambient_extra_delivery"
const CLUE_WRONG_NAME: String = "ambient_wrong_name_customer"
const CLUE_ODD_NOTIFICATION: String = "ambient_odd_notification"
const CLUE_DISCREPANCY: String = "ambient_financial_discrepancy"
const CLUE_RENOVATION: String = "ambient_renovation_sounds"

const EXTRA_DELIVERY_DAY_MIN: int = 10
const EXTRA_DELIVERY_DAY_MAX: int = 20
const WRONG_NAME_DAY_MIN: int = 12
const WRONG_NAME_DAY_MAX: int = 25
const ODD_NOTIFICATION_DAY_MIN: int = 15
const ODD_NOTIFICATION_DAY_MAX: int = 30
const DISCREPANCY_DAY_MIN: int = 20
const DISCREPANCY_DAY_MAX: int = 35

const EXTRA_DELIVERY_AWARENESS: int = 5
const WRONG_NAME_AWARENESS: int = 3
const ODD_NOTIFICATION_AWARENESS: int = 3
const DISCREPANCY_AWARENESS: int = 5
const RENOVATION_AWARENESS: int = 3

const MYSTERY_ITEM_ID: String = "mystery_uncatalogued_item"

const WRONG_NAME_LINES: Array[String] = [
	"Do you have the, uh... Crimson Ledger? "
	+ "No? Hmm. I was told you would.",
	"I'm looking for a 'Phantom Frequency' unit. "
	+ "Someone said you carried them.",
	"Hi, I need the Alabaster Series catalog. "
	+ "The one with the gray cover.",
]

const ODD_NOTIFICATIONS: Array[String] = [
	"MEMO — RE: Quarterly Alignment Review\n"
	+ "Dear Tenant (Unit [REDACTED]),\nYour "
	+ "cooperation in the upcoming facility "
	+ "audit is appreciated. No action required "
	+ "at this time. — Mall Administration",
	"NOTICE: Routine infrastructure survey "
	+ "scheduled. Please disregard any unusual "
	+ "readings from sub-level instrumentation. "
	+ "Thank you for your continued tenancy.",
	"INTERNAL — DO NOT FORWARD\nRe: Anchor "
	+ "tenant reclassification pending review. "
	+ "This message was sent in error. "
	+ "Please delete.",
]

var _secret_thread_manager: SecretThreadManager
var _inventory_system: InventorySystem
var _time_system: TimeSystem

var _triggered_extra_delivery: bool = false
var _triggered_wrong_name: bool = false
var _triggered_odd_notification: bool = false
var _triggered_discrepancy: bool = false
var _triggered_renovation_sound: bool = false

var _extra_delivery_day: int = 0
var _wrong_name_day: int = 0
var _odd_notification_day: int = 0
var _discrepancy_day: int = 0

var _discrepancy_active: bool = false
var _discrepancy_amount: float = 0.0
var _discrepancy_shown_day: int = 0

var _wrong_name_active: bool = false
var _wrong_name_timer: float = 0.0
const WRONG_NAME_LINGER_TIME: float = 8.0

var _renovation_sound_timer: float = 300.0
var _renovation_sound_interval: float = 300.0

var _mystery_item_instance_id: String = ""


## Sets up the system with required references and picks trigger days.
func initialize(
	secret_thread: SecretThreadManager,
	inventory: InventorySystem,
	time: TimeSystem,
) -> void:
	_secret_thread_manager = secret_thread
	_inventory_system = inventory
	_time_system = time
	_pick_trigger_days()
	_connect_signals()


func _pick_trigger_days() -> void:
	_extra_delivery_day = _rand_day_in_range(
		EXTRA_DELIVERY_DAY_MIN, EXTRA_DELIVERY_DAY_MAX
	)
	_wrong_name_day = _rand_day_in_range(
		WRONG_NAME_DAY_MIN, WRONG_NAME_DAY_MAX
	)
	_odd_notification_day = _rand_day_in_range(
		ODD_NOTIFICATION_DAY_MIN, ODD_NOTIFICATION_DAY_MAX
	)
	_discrepancy_day = _rand_day_in_range(
		DISCREPANCY_DAY_MIN, DISCREPANCY_DAY_MAX
	)


func _connect_signals() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.mystery_item_inspected.connect(
		_on_mystery_item_inspected
	)
	EventBus.odd_notification_read.connect(
		_on_odd_notification_read
	)
	EventBus.discrepancy_noticed.connect(
		_on_discrepancy_noticed
	)
	EventBus.wrong_name_customer_interacted.connect(
		_on_wrong_name_customer_interacted
	)
	EventBus.renovation_sounds_heard.connect(
		_on_renovation_sounds_heard
	)


func _process(delta: float) -> void:
	if _wrong_name_active:
		_wrong_name_timer -= delta
		if _wrong_name_timer <= 0.0:
			_wrong_name_active = false
			EventBus.notification_requested.emit(
				"The customer left without buying anything."
			)

	_update_renovation_sounds(delta)


func _on_day_started(day: int) -> void:
	_try_extra_delivery(day)
	_try_wrong_name_customer(day)
	_try_odd_notification(day)
	_auto_correct_discrepancy(day)


func _on_day_ended(day: int) -> void:
	_try_discrepancy(day)


## Returns the discrepancy amount if active, else 0.0.
func get_active_discrepancy() -> float:
	if _discrepancy_active:
		return _discrepancy_amount
	return 0.0


## Returns true if the discrepancy is currently visible.
func is_discrepancy_active() -> bool:
	return _discrepancy_active


func _try_extra_delivery(day: int) -> void:
	if _triggered_extra_delivery:
		return
	if day != _extra_delivery_day:
		return
	_triggered_extra_delivery = true
	_create_mystery_item(day)


func _create_mystery_item(day: int) -> void:
	var mystery_def := ItemDefinition.new()
	mystery_def.id = MYSTERY_ITEM_ID
	mystery_def.name = "Unmarked Package"
	mystery_def.description = (
		"A small, tightly wrapped parcel with no return "
		+ "address. The label is smudged. It wasn't on "
		+ "your order."
	)
	mystery_def.category = "unknown"
	mystery_def.store_type = ""
	mystery_def.base_price = 0.0
	mystery_def.rarity = "common"
	mystery_def.tags = PackedStringArray(["mystery", "uncatalogued"])

	var item: ItemInstance = ItemInstance.create(
		mystery_def, "good", day, 0.0
	)
	item.current_location = "backroom"
	_mystery_item_instance_id = item.instance_id

	if _inventory_system:
		_inventory_system.register_item(item)

	EventBus.notification_requested.emit(
		"A delivery arrived with an extra unmarked package."
	)


func _try_wrong_name_customer(day: int) -> void:
	if _triggered_wrong_name:
		return
	if day != _wrong_name_day:
		return
	_triggered_wrong_name = true
	_wrong_name_active = true
	_wrong_name_timer = WRONG_NAME_LINGER_TIME

	var line: String = WRONG_NAME_LINES[
		randi() % WRONG_NAME_LINES.size()
	]
	EventBus.notification_requested.emit(
		"A customer approaches: \"%s\"" % line
	)


func _try_odd_notification(day: int) -> void:
	if _triggered_odd_notification:
		return
	if day != _odd_notification_day:
		return
	_triggered_odd_notification = true

	var message: String = ODD_NOTIFICATIONS[
		randi() % ODD_NOTIFICATIONS.size()
	]
	EventBus.notification_requested.emit(message)


func _try_discrepancy(day: int) -> void:
	if _triggered_discrepancy:
		return
	if day != _discrepancy_day:
		return
	_triggered_discrepancy = true
	_discrepancy_active = true
	_discrepancy_shown_day = day
	_discrepancy_amount = _generate_discrepancy_amount()


func _auto_correct_discrepancy(day: int) -> void:
	if not _discrepancy_active:
		return
	if day <= _discrepancy_shown_day:
		return
	_discrepancy_active = false
	_discrepancy_amount = 0.0


func _generate_discrepancy_amount() -> float:
	var cents: int = randi_range(1, 50)
	var amount: float = float(cents) / 100.0
	if randi() % 2 == 0:
		amount = -amount
	return amount


func _update_renovation_sounds(delta: float) -> void:
	if not _time_system or _time_system.time_scale <= 0.0:
		return
	_renovation_sound_timer -= delta * _time_system.time_scale
	if _renovation_sound_timer > 0.0:
		return
	_renovation_sound_timer = _renovation_sound_interval + randf_range(
		0.0, 120.0
	)
	EventBus.notification_requested.emit(
		"You hear faint sounds from the storefront "
		+ "under renovation... drilling? Or something else."
	)


func _on_mystery_item_inspected(instance_id: String) -> void:
	if instance_id != _mystery_item_instance_id:
		return
	if not _secret_thread_manager:
		return
	_secret_thread_manager.register_clue_found(
		CLUE_EXTRA_DELIVERY, EXTRA_DELIVERY_AWARENESS
	)


func _on_wrong_name_customer_interacted() -> void:
	if not _wrong_name_active:
		return
	if not _secret_thread_manager:
		return
	_wrong_name_active = false
	_secret_thread_manager.register_clue_found(
		CLUE_WRONG_NAME, WRONG_NAME_AWARENESS
	)
	EventBus.notification_requested.emit(
		"The customer looks startled, mutters "
		+ "\"wrong store,\" and hurries out."
	)


func _on_odd_notification_read(
	_notification_id: String,
) -> void:
	if not _secret_thread_manager:
		return
	_secret_thread_manager.register_clue_found(
		CLUE_ODD_NOTIFICATION, ODD_NOTIFICATION_AWARENESS
	)


func _on_discrepancy_noticed(day: int) -> void:
	if not _discrepancy_active:
		return
	if day != _discrepancy_shown_day:
		return
	if not _secret_thread_manager:
		return
	_secret_thread_manager.register_clue_found(
		CLUE_DISCREPANCY, DISCREPANCY_AWARENESS
	)


func _on_renovation_sounds_heard() -> void:
	if _triggered_renovation_sound:
		return
	_triggered_renovation_sound = true
	if not _secret_thread_manager:
		return
	_secret_thread_manager.register_clue_found(
		CLUE_RENOVATION, RENOVATION_AWARENESS
	)


## Serializes moment state for saving.
func get_save_data() -> Dictionary:
	return {
		"triggered_extra_delivery": _triggered_extra_delivery,
		"triggered_wrong_name": _triggered_wrong_name,
		"triggered_odd_notification": _triggered_odd_notification,
		"triggered_discrepancy": _triggered_discrepancy,
		"triggered_renovation_sound": _triggered_renovation_sound,
		"extra_delivery_day": _extra_delivery_day,
		"wrong_name_day": _wrong_name_day,
		"odd_notification_day": _odd_notification_day,
		"discrepancy_day": _discrepancy_day,
		"discrepancy_active": _discrepancy_active,
		"discrepancy_amount": _discrepancy_amount,
		"discrepancy_shown_day": _discrepancy_shown_day,
		"mystery_item_instance_id": _mystery_item_instance_id,
	}


## Restores moment state from saved data.
func load_save_data(data: Dictionary) -> void:
	_triggered_extra_delivery = bool(
		data.get("triggered_extra_delivery", false)
	)
	_triggered_wrong_name = bool(
		data.get("triggered_wrong_name", false)
	)
	_triggered_odd_notification = bool(
		data.get("triggered_odd_notification", false)
	)
	_triggered_discrepancy = bool(
		data.get("triggered_discrepancy", false)
	)
	_triggered_renovation_sound = bool(
		data.get("triggered_renovation_sound", false)
	)
	_extra_delivery_day = int(
		data.get("extra_delivery_day", 0)
	)
	_wrong_name_day = int(
		data.get("wrong_name_day", 0)
	)
	_odd_notification_day = int(
		data.get("odd_notification_day", 0)
	)
	_discrepancy_day = int(
		data.get("discrepancy_day", 0)
	)
	_discrepancy_active = bool(
		data.get("discrepancy_active", false)
	)
	_discrepancy_amount = float(
		data.get("discrepancy_amount", 0.0)
	)
	_discrepancy_shown_day = int(
		data.get("discrepancy_shown_day", 0)
	)
	_mystery_item_instance_id = str(
		data.get("mystery_item_instance_id", "")
	)


func _rand_day_in_range(min_day: int, max_day: int) -> int:
	return randi_range(min_day, max_day)
