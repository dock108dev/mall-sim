## Backordered Console interactable — fires hidden-thread signal on examine.
##
## A tagged console unit in the back room that has lingered past its expected
## restock day. Examining it emits `backordered_item_examined` with the live
## days-pending count so HiddenThreadSystem can credit a Tier 1 awareness
## trigger and feed downstream analytics.
class_name BackorderedConsoleInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Inspect Tag"
const _DEFAULT_DISPLAY_NAME: String = "Backordered Console"

@export var description_text: String = (
	"Awaiting stock — supplier pending since last week."
)
## Item id this prop represents. Defaults to a placeholder so unit-test
## fixtures still emit a typed StringName payload.
@export var item_id: StringName = &"backordered_console"
## Game day the item was first marked backordered. Driven by the controller
## or scene author so days_pending is meaningful in playtest. Falls back to
## 1 when unset so the signal payload is always non-negative.
@export var backorder_start_day: int = 1


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
	var current_day: int = _resolve_current_day()
	var days_pending: int = maxi(current_day - backorder_start_day, 0)
	EventBus.backordered_item_examined.emit(
		resolved_store_id, item_id, days_pending
	)
	EventBus.notification_requested.emit(description_text)


func _resolve_current_day() -> int:
	if GameManager == null:
		return 1
	return maxi(GameManager.get_current_day(), 1)
