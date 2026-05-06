## Returned Item interactable — fires the hidden-thread signal on examine.
##
## A specific returned camera (or other returned item) sitting in the damaged
## bin that does not match any sale record. Examining it emits
## `returned_item_examined` so HiddenThreadSystem can credit a Tier 1
## awareness trigger.
class_name ReturnedItemInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Inspect Item"
const _DEFAULT_DISPLAY_NAME: String = "Returned Item"

@export var description_text: String = (
	"Return authorization log — receipt missing."
)
## Item id of the suspicious return. Defaults to a placeholder so unit-test
## fixtures still emit a typed StringName payload.
@export var item_id: StringName = &"returned_camera"


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
	EventBus.returned_item_examined.emit(resolved_store_id, item_id)
	EventBus.notification_requested.emit(description_text)
