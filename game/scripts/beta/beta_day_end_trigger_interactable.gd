class_name BetaDayEndTriggerInteractable
extends Interactable


func _ready() -> void:
	display_name = "Shift Clock"
	prompt_text = "End Day"
	action_verb = "End"
	interaction_type = InteractionType.REGISTER
	interactable_id = &"register_day_end"
	super._ready()


func can_interact(_actor: Node = null) -> bool:
	return BetaRunState.is_day1_completed()


func get_disabled_reason(_actor: Node = null) -> String:
	return "Finish the customer decision first."


func interact(by: Node = null) -> void:
	if not can_interact(by):
		return
	super.interact(by)
	get_tree().call_group("beta_day_one_controller", "on_beta_day_end_requested")
