## Single hold/reservation slip recorded against a store's hold list.
##
## A slip is a small data record describing a customer's reservation of a
## specific inventory unit (matched by serial). Slips have a finite lifetime
## (expiry_day) and a status that walks ACTIVE → FULFILLED / EXPIRED /
## FLAGGED / DISPUTED depending on what happens at the terminal.
##
## Slips are owned by a HoldList resource on the per-store controller. The
## `to_dict` / `from_dict` round trip is used by save/load so the in-memory
## list survives a session restart with stable HOLD-#### identifiers.
class_name HoldSlip
extends Resource


enum Status {
	ACTIVE = 0,
	FULFILLED = 1,
	EXPIRED = 2,
	FLAGGED = 3,
	DISPUTED = 4,
}

enum RequestorTier {
	NORMAL = 0,
	SHADY = 1,
	ANONYMOUS = 2,
}


@export var id: String = ""
@export var customer_name: String = ""
@export var serial: String = ""
@export var item_id: StringName = &""
@export var item_label: String = ""
@export var creation_day: int = 0
@export var expiry_day: int = 0
@export var status: int = Status.ACTIVE
@export var requestor_tier: int = RequestorTier.NORMAL
## Optional narrative thread linkage; populated when a shady customer's hold
## belongs to a known multi-step thread (consumed by HiddenThreadSystem).
@export var thread_id: String = ""


## Returns true when the slip is still ACTIVE (i.e. countable for fulfillment
## conflict detection and re-spawnable as a physical slip prop).
func is_active() -> bool:
	return status == Status.ACTIVE


## Returns true when the slip has been visibly flagged as suspicious (either by
## duplicate detection at intake or by a manual flag at the terminal). Flagged
## slips render with the red emissive material on the hold shelf.
func is_flagged() -> bool:
	return status == Status.FLAGGED


## Returns true when the slip is no longer counted toward conflict detection.
## DISPUTED slips remain visible at the terminal but cannot be fulfilled.
func is_terminal_status() -> bool:
	return (
		status == Status.FULFILLED
		or status == Status.EXPIRED
		or status == Status.DISPUTED
	)


## Serializes the slip to a plain Dictionary for JSON persistence. Keys mirror
## the @export names so a future schema migration is straightforward.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"customer_name": customer_name,
		"serial": serial,
		"item_id": String(item_id),
		"item_label": item_label,
		"creation_day": creation_day,
		"expiry_day": expiry_day,
		"status": status,
		"requestor_tier": requestor_tier,
		"thread_id": thread_id,
	}


## Builds a HoldSlip from a dict produced by `to_dict`. Unknown / missing keys
## fall back to defaults so older saves load forward without crashes.
static func from_dict(data: Dictionary) -> HoldSlip:
	var slip := HoldSlip.new()
	slip.id = str(data.get("id", ""))
	slip.customer_name = str(data.get("customer_name", ""))
	slip.serial = str(data.get("serial", ""))
	slip.item_id = StringName(str(data.get("item_id", "")))
	slip.item_label = str(data.get("item_label", ""))
	slip.creation_day = int(data.get("creation_day", 0))
	slip.expiry_day = int(data.get("expiry_day", 0))
	slip.status = int(data.get("status", Status.ACTIVE))
	slip.requestor_tier = int(data.get("requestor_tier", RequestorTier.NORMAL))
	slip.thread_id = str(data.get("thread_id", ""))
	return slip
