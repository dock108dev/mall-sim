## Employee Schedule interactable — fires the hidden-thread signal on examine.
##
## The printed shift schedule posted in the employee area. Examining it emits
## `employee_schedule_examined` so HiddenThreadSystem can credit a Tier 1
## awareness trigger and bump `paper_trail_score`.
class_name EmployeeScheduleInteractable
extends Interactable


const _DEFAULT_PROMPT: String = "Read Schedule"
const _DEFAULT_DISPLAY_NAME: String = "Employee Schedule"

@export var description_text: String = (
	"Work schedule — revised June 2005."
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
	EventBus.employee_schedule_examined.emit(resolved_store_id, current_day)
	EventBus.notification_requested.emit(description_text)


func _resolve_current_day() -> int:
	if GameManager == null:
		return 1
	return maxi(GameManager.get_current_day(), 1)
