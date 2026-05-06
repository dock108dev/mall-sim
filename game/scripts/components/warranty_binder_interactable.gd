## Warranty Binder interactable — fires the hidden-thread signal on examine.
##
## Lives on or near the counter; opens onto the warranty claim ledger.
## Examining it emits `warranty_binder_examined` so HiddenThreadSystem can
## bump `paper_trail_score` and credit a Tier 1 awareness trigger.
class_name WarrantyBinderInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Review Binder"
const _DEFAULT_DISPLAY_NAME: String = "Warranty Binder"

## Period-appropriate retail-floor description shown when the player presses E.
## Mundane employee-facing language; no language hinting at suspicious
## significance. The hidden thread surfaces only in the day summary.
@export var description_text: String = (
	"Warranty claim binder — current quarter."
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
	var current_day: int = _resolve_current_day()
	EventBus.warranty_binder_examined.emit(resolved_store_id, current_day)
	EventBus.notification_requested.emit(description_text)


func _resolve_current_day() -> int:
	if GameManager == null:
		return 1
	return maxi(GameManager.get_current_day(), 1)
