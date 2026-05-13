class_name BetaRestockInteractable
extends Interactable


func _ready() -> void:
	display_name = "used games shelf"
	prompt_text = "Stock"
	action_verb = "Stock"
	interaction_type = InteractionType.SHELF_SLOT
	interactable_id = &"beta_stock_shelf"
	proximity_radius = 2.25
	proximity_facing_dot = 0.4
	super._ready()


func can_interact(_actor: Node = null) -> bool:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return false
	return controller.can_interact_restock()


func get_disabled_reason(_actor: Node = null) -> String:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return "Restock flow unavailable."
	return controller.restock_disabled_reason()


func interact(by: Node = null) -> void:
	if not can_interact(by):
		return
	super.interact(by)
	get_tree().call_group("beta_day_one_controller", "on_beta_restock_interacted")


func _controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node is BetaDayOneController:
		return node as BetaDayOneController
	return null
