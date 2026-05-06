class_name BetaDay1CustomerInteractable
extends Interactable


func _ready() -> void:
	display_name = "Confused Parent"
	prompt_text = "Talk To"
	action_verb = "Talk"
	interaction_type = InteractionType.CUSTOMER
	interactable_id = &"customer_wrong_console_parent"
	super._ready()


func interact(by: Node = null) -> void:
	super.interact(by)
	get_tree().call_group("beta_day_one_controller", "on_beta_customer_interacted")
