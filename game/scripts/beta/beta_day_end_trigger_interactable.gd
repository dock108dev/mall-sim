class_name BetaDayEndTriggerInteractable
extends Interactable


func _ready() -> void:
	display_name = "the day"
	prompt_text = "Close"
	action_verb = "End"
	interaction_type = InteractionType.REGISTER
	interactable_id = &"register_day_end"
	proximity_radius = 2.25
	proximity_facing_dot = 0.4
	super._ready()


func can_interact(_actor: Node = null) -> bool:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return false
	return controller.can_interact_day_end()


func get_disabled_reason(_actor: Node = null) -> String:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return "Day-end flow unavailable."
	return controller.day_end_disabled_reason()


func interact(by: Node = null) -> void:
	if not can_interact(by):
		return
	super.interact(by)
	get_tree().call_group("beta_day_one_controller", "on_beta_day_end_requested")


func _controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node is BetaDayOneController:
		return node as BetaDayOneController
	return null
