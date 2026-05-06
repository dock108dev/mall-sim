## Register Note interactable — fires the hidden-thread signal on examine.
##
## A handwritten note tucked under the register or taped to the side. Examining
## it emits `register_note_examined` so HiddenThreadSystem can credit a Tier 1
## awareness trigger.
class_name RegisterNoteInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Read Note"
const _DEFAULT_DISPLAY_NAME: String = "Register Note"

@export var description_text: String = (
	"Sticky note — \"hold for pickup, no receipt.\""
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
	EventBus.register_note_examined.emit(resolved_store_id, current_day)
	EventBus.notification_requested.emit(description_text)


func _resolve_current_day() -> int:
	if GameManager == null:
		return 1
	return maxi(GameManager.get_current_day(), 1)
