## Time-clock interactable. E-key triggers ShiftSystem.clock_in() when the
## player has not yet clocked in for the day, and ShiftSystem.clock_out()
## once the shift is active.
##
## Lives near the store entrance and uses the same Interactable base as every
## other in-store prop, so the existing player interaction-ray pipeline
## dispatches to it without modification.
class_name ClockInInteractable
extends Interactable


const PROMPT_CLOCK_IN: String = "Clock In"
const PROMPT_CLOCK_OUT: String = "Clock Out"
const DISPLAY_NAME: String = "Time Clock"


func _ready() -> void:
	display_name = DISPLAY_NAME
	prompt_text = PROMPT_CLOCK_IN
	action_verb = PROMPT_CLOCK_IN
	super._ready()
	if not EventBus.shift_started.is_connected(_on_shift_state_changed):
		EventBus.shift_started.connect(_on_shift_state_changed)
	if not EventBus.shift_ended.is_connected(_on_shift_ended):
		EventBus.shift_ended.connect(_on_shift_ended)
	_refresh_prompt()


func interact(by: Node = null) -> void:
	if not enabled:
		return
	var shift: Node = get_node_or_null("/root/ShiftSystem")
	if shift == null:
		# §F-120 — ShiftSystem is declared as an autoload in project.godot.
		# Reaching this branch means the autoload was disabled / removed and
		# every clock-in interaction silently no-ops; that's a hard
		# configuration error, not a runtime degradation.
		push_error("ClockInInteractable: ShiftSystem autoload missing")
		return
	if bool(shift.is_clocked_in):
		shift.call("clock_out")
	else:
		shift.call("clock_in")
	_refresh_prompt()
	super.interact(by)


func _on_shift_state_changed(
	_store_id: StringName, _timestamp: float, _late: bool
) -> void:
	_refresh_prompt()


func _on_shift_ended(_store_id: StringName, _hours: float) -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	var shift: Node = get_node_or_null("/root/ShiftSystem")
	if shift != null and bool(shift.is_clocked_in):
		prompt_text = PROMPT_CLOCK_OUT
		action_verb = PROMPT_CLOCK_OUT
	else:
		prompt_text = PROMPT_CLOCK_IN
		action_verb = PROMPT_CLOCK_IN
