class_name BetaDayOneInteractableBase
extends Interactable


## Shared lookup for beta Day-1 interactables. Test fixtures may omit the
## controller group, so callers treat null as "flow unavailable".
func _controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node is BetaDayOneController:
		return node as BetaDayOneController
	return null
