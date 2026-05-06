class_name BetaDay1CustomerInteractable
extends Interactable


func _ready() -> void:
	display_name = "Confused Parent"
	prompt_text = "Talk To"
	action_verb = "Talk"
	interaction_type = InteractionType.CUSTOMER
	interactable_id = &"customer_wrong_console_parent"
	super._ready()


func can_interact(_actor: Node = null) -> bool:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return false
	return controller.can_interact_customer()


func get_disabled_reason(_actor: Node = null) -> String:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return "Customer flow unavailable."
	return controller.customer_disabled_reason()


func interact(by: Node = null) -> void:
	super.interact(by)
	get_tree().call_group("beta_day_one_controller", "on_beta_customer_interacted")


func _controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node is BetaDayOneController:
		return node as BetaDayOneController
	return null
