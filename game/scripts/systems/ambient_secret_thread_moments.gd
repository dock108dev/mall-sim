## Handles the 5 guaranteed ambient secret-thread moments.
class_name AmbientSecretThreadMoments
extends RefCounted


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
const WRONG_NAME_LINGER_TIME: float = 8.0

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

var secret_thread_manager: SecretThreadManager
var inventory_system: InventorySystem
var time_system: TimeSystem

var triggered_extra_delivery: bool = false
var triggered_wrong_name: bool = false
var triggered_odd_notification: bool = false
var triggered_discrepancy: bool = false
var triggered_renovation_sound: bool = false

var extra_delivery_day: int = 0
var wrong_name_day: int = 0
var odd_notification_day: int = 0
var discrepancy_day: int = 0

var discrepancy_active: bool = false
var discrepancy_amount: float = 0.0
var discrepancy_shown_day: int = 0

var wrong_name_active: bool = false
var wrong_name_timer: float = 0.0

var renovation_sound_timer: float = 300.0
var renovation_sound_interval: float = 300.0

var mystery_item_instance_id: String = ""


func pick_trigger_days() -> void:
	extra_delivery_day = randi_range(
		EXTRA_DELIVERY_DAY_MIN, EXTRA_DELIVERY_DAY_MAX
	)
	wrong_name_day = randi_range(
		WRONG_NAME_DAY_MIN, WRONG_NAME_DAY_MAX
	)
	odd_notification_day = randi_range(
		ODD_NOTIFICATION_DAY_MIN, ODD_NOTIFICATION_DAY_MAX
	)
	discrepancy_day = randi_range(
		DISCREPANCY_DAY_MIN, DISCREPANCY_DAY_MAX
	)


func on_day_started(day: int) -> void:
	try_extra_delivery(day)
	try_wrong_name_customer(day)
	try_odd_notification(day)
	auto_correct_discrepancy(day)


func on_day_ended(day: int) -> void:
	try_discrepancy(day)


func process_tick(delta: float) -> void:
	if wrong_name_active:
		wrong_name_timer -= delta
		if wrong_name_timer <= 0.0:
			wrong_name_active = false
			EventBus.notification_requested.emit(
				"The customer left without buying anything."
			)
	update_renovation_sounds(delta)


func get_active_discrepancy() -> float:
	if discrepancy_active:
		return discrepancy_amount
	return 0.0


func is_discrepancy_active() -> bool:
	return discrepancy_active


func try_extra_delivery(day: int) -> void:
	if triggered_extra_delivery:
		return
	if day != extra_delivery_day:
		return
	triggered_extra_delivery = true
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
	mystery_def.tags = PackedStringArray(
		["mystery", "uncatalogued"]
	)
	var item: ItemInstance = ItemInstance.create(
		mystery_def, "good", day, 0.0
	)
	item.current_location = "backroom"
	mystery_item_instance_id = item.instance_id
	if inventory_system:
		inventory_system.register_item(item)
	EventBus.notification_requested.emit(
		"A delivery arrived with an extra unmarked package."
	)


func try_wrong_name_customer(day: int) -> void:
	if triggered_wrong_name:
		return
	if day != wrong_name_day:
		return
	triggered_wrong_name = true
	wrong_name_active = true
	wrong_name_timer = WRONG_NAME_LINGER_TIME
	var line: String = WRONG_NAME_LINES[
		randi() % WRONG_NAME_LINES.size()
	]
	EventBus.notification_requested.emit(
		"A customer approaches: \"%s\"" % line
	)


func try_odd_notification(day: int) -> void:
	if triggered_odd_notification:
		return
	if day != odd_notification_day:
		return
	triggered_odd_notification = true
	var message: String = ODD_NOTIFICATIONS[
		randi() % ODD_NOTIFICATIONS.size()
	]
	EventBus.notification_requested.emit(message)


func try_discrepancy(day: int) -> void:
	if triggered_discrepancy:
		return
	if day != discrepancy_day:
		return
	triggered_discrepancy = true
	discrepancy_active = true
	discrepancy_shown_day = day
	discrepancy_amount = _generate_discrepancy_amount()


func auto_correct_discrepancy(day: int) -> void:
	if not discrepancy_active:
		return
	if day <= discrepancy_shown_day:
		return
	discrepancy_active = false
	discrepancy_amount = 0.0


func _generate_discrepancy_amount() -> float:
	var cents: int = randi_range(1, 50)
	var amount: float = float(cents) / 100.0
	if randi() % 2 == 0:
		amount = -amount
	return amount


func update_renovation_sounds(delta: float) -> void:
	if not time_system or time_system.speed_multiplier <= 0.0:
		return
	renovation_sound_timer -= delta * time_system.speed_multiplier
	if renovation_sound_timer > 0.0:
		return
	renovation_sound_timer = renovation_sound_interval + randf_range(
		0.0, 120.0
	)
	EventBus.notification_requested.emit(
		"You hear faint sounds from the storefront "
		+ "under renovation... drilling? Or something else."
	)


func on_mystery_item_inspected(instance_id: String) -> void:
	if instance_id != mystery_item_instance_id:
		return
	if not secret_thread_manager:
		return
	secret_thread_manager.register_clue_found(
		CLUE_EXTRA_DELIVERY, EXTRA_DELIVERY_AWARENESS
	)


func on_wrong_name_customer_interacted() -> void:
	if not wrong_name_active:
		return
	if not secret_thread_manager:
		return
	wrong_name_active = false
	secret_thread_manager.register_clue_found(
		CLUE_WRONG_NAME, WRONG_NAME_AWARENESS
	)
	EventBus.notification_requested.emit(
		"The customer looks startled, mutters "
		+ "\"wrong store,\" and hurries out."
	)


func on_odd_notification_read(
	_notification_id: String,
) -> void:
	if not secret_thread_manager:
		return
	secret_thread_manager.register_clue_found(
		CLUE_ODD_NOTIFICATION, ODD_NOTIFICATION_AWARENESS
	)


func on_discrepancy_noticed(day: int) -> void:
	if not discrepancy_active:
		return
	if day != discrepancy_shown_day:
		return
	if not secret_thread_manager:
		return
	secret_thread_manager.register_clue_found(
		CLUE_DISCREPANCY, DISCREPANCY_AWARENESS
	)


func on_renovation_sounds_heard() -> void:
	if triggered_renovation_sound:
		return
	triggered_renovation_sound = true
	if not secret_thread_manager:
		return
	secret_thread_manager.register_clue_found(
		CLUE_RENOVATION, RENOVATION_AWARENESS
	)


func get_save_data() -> Dictionary:
	return {
		"triggered_extra_delivery": triggered_extra_delivery,
		"triggered_wrong_name": triggered_wrong_name,
		"triggered_odd_notification": triggered_odd_notification,
		"triggered_discrepancy": triggered_discrepancy,
		"triggered_renovation_sound": triggered_renovation_sound,
		"extra_delivery_day": extra_delivery_day,
		"wrong_name_day": wrong_name_day,
		"odd_notification_day": odd_notification_day,
		"discrepancy_day": discrepancy_day,
		"discrepancy_active": discrepancy_active,
		"discrepancy_amount": discrepancy_amount,
		"discrepancy_shown_day": discrepancy_shown_day,
		"mystery_item_instance_id": mystery_item_instance_id,
	}


func apply_state(data: Dictionary) -> void:
	triggered_extra_delivery = bool(
		data.get("triggered_extra_delivery", false)
	)
	triggered_wrong_name = bool(
		data.get("triggered_wrong_name", false)
	)
	triggered_odd_notification = bool(
		data.get("triggered_odd_notification", false)
	)
	triggered_discrepancy = bool(
		data.get("triggered_discrepancy", false)
	)
	triggered_renovation_sound = bool(
		data.get("triggered_renovation_sound", false)
	)
	extra_delivery_day = int(
		data.get("extra_delivery_day", extra_delivery_day)
	)
	wrong_name_day = int(
		data.get("wrong_name_day", wrong_name_day)
	)
	odd_notification_day = int(
		data.get("odd_notification_day", odd_notification_day)
	)
	discrepancy_day = int(
		data.get("discrepancy_day", discrepancy_day)
	)
	discrepancy_active = bool(
		data.get("discrepancy_active", false)
	)
	discrepancy_amount = float(
		data.get("discrepancy_amount", 0.0)
	)
	discrepancy_shown_day = int(
		data.get("discrepancy_shown_day", 0)
	)
	mystery_item_instance_id = str(
		data.get("mystery_item_instance_id", "")
	)
	wrong_name_active = false
	wrong_name_timer = WRONG_NAME_LINGER_TIME
