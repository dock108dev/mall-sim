## Hold Shelf interactable — fires the hidden-thread signal on player examine.
##
## Lives behind the counter; emits `hold_shelf_inspected` so HiddenThreadSystem
## can credit the player for noticing the slip backlog. The existing
## RetroGames/HoldList wiring continues to consume the base `interacted`
## signal for slip rendering — this subclass adds the bus-level emission and
## the player-facing description toast.
class_name HoldShelfInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Review Holds"
const _DEFAULT_DISPLAY_NAME: String = "Hold Shelf"

## Period-appropriate retail-floor description shown when the player presses E.
## Reads as mundane employee-facing language so the hidden thread is not
## telegraphed; the consequence text only surfaces in the day summary.
@export var description_text: String = (
	"Hold tags and customer notes — 7 slips."
)


func _ready() -> void:
	if prompt_text.is_empty() or prompt_text == "Use":
		prompt_text = _DEFAULT_PROMPT
	if display_name == "Item":
		display_name = _DEFAULT_DISPLAY_NAME
	super._ready()


func interact(by: Node = null) -> void:
	if not enabled or not can_interact(by):
		return
	super.interact(by)
	var resolved_store_id: StringName = (
		store_id if store_id != &"" else &"retro_games"
	)
	EventBus.hold_shelf_inspected.emit(
		resolved_store_id, _resolve_suspicious_slip_count()
	)
	EventBus.notification_requested.emit(description_text)


## Counts active slips with a SHADY-or-higher requestor tier on the live
## HoldList when the parent controller exposes one. Returns 0 in unit-test
## fixtures where the script is instantiated without a parent retro_games
## scene; the handler treats the count as informational metadata only.
func _resolve_suspicious_slip_count() -> int:
	var holds_node: Node = _find_holds_node()
	if holds_node == null or not holds_node.has_method("get_hold_list"):
		return 0
	var list: Object = holds_node.call("get_hold_list")
	if list == null or not list.has_method("get_slips_by_status"):
		return 0
	var active_slips: Array = list.call("get_slips_by_status")
	var count: int = 0
	for slip: Variant in active_slips:
		if slip == null:
			continue
		var tier_value: int = int(slip.get("requestor_tier"))
		# RequestorTier.SHADY == 2, ANONYMOUS == 3 in HoldSlip; tier >= 2
		# captures both and is forward-compatible with future suspicious tiers.
		if tier_value >= 2:
			count += 1
	return count


func _find_holds_node() -> Node:
	var current: Node = get_parent()
	while current != null:
		if "holds" in current and current.get("holds") != null:
			return current.get("holds")
		current = current.get_parent()
	return null
