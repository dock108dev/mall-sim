## Security Flyer interactable — fires the hidden-thread signal on examine.
##
## Mall security bulletin pinned in the employee area. Examining it emits
## `security_flyer_examined` so HiddenThreadSystem can credit a Tier 1
## awareness trigger.
class_name SecurityFlyerInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Read Bulletin"
const _DEFAULT_DISPLAY_NAME: String = "Security Bulletin"

@export var description_text: String = (
	"Mall security bulletin — case file reference inside."
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
	EventBus.security_flyer_examined.emit(resolved_store_id)
	EventBus.notification_requested.emit(description_text)
