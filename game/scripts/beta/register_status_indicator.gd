## Passive register-side hint for the back-room and stocking phases.
##
## During STAGE_BACK_ROOM_INVENTORY and STAGE_STOCK_SHELF the active
## interactable is elsewhere in the store (back room, then the used-games
## shelf), so aiming at the register today shows nothing — BetaDayEndTrigger
## is silently disabled and BetaDayOneCustomer is not on the chain. This
## indicator fills the gap with a muted disabled-reason hint that points the
## player back at the current beat.
##
## Always returns `false` from `can_interact`, so E never fires here and the
## HUD always renders the disabled-reason copy. Stays additive: BetaDayOneCustomer
## and BetaDayEndTrigger continue to own STAGE_TALK_TO_CUSTOMER and
## STAGE_END_DAY respectively, and the indicator returns an empty string for
## those stages so the active interactable's prompt is the one the player sees.
class_name RegisterStatusIndicator
extends Interactable


func _ready() -> void:
	display_name = "register"
	prompt_text = ""
	action_verb = "Check"
	interactable_id = &"register_status_hint"
	# Raycast-only: a proximity radius here would compete with the
	# BetaDayEndTrigger's 2.25 m proximity zone and the customer's trigger,
	# stealing focus from the active interactable when the player walks past.
	# The tight CollisionShape3D in the scene means the player must point the
	# reticle at the register face for this hint to surface.
	proximity_radius = 0.0
	super._ready()


func can_interact(_actor: Node = null) -> bool:
	return false


func get_disabled_reason(_actor: Node = null) -> String:
	var ctrl: BetaDayOneController = _controller()
	if ctrl == null:
		return ""
	match ctrl.current_stage():
		BetaDayOneController.STAGE_BACK_ROOM_INVENTORY:
			return "Check the back room first."
		BetaDayOneController.STAGE_STOCK_SHELF:
			return "Stock the shelf before closing up."
		_:
			return ""


## Returns null in unit-test fixtures that don't add a controller to the
## scene (mirrors `hud.gd::_beta_day_one_controller`); production beta path
## always group-registers the controller in `BetaDayOneController._ready`.
## `get_disabled_reason` callers handle the null return by surfacing an
## empty string, which the HUD treats as "no hint" — the graceful
## degradation matches the documented Interactable convention. See §EH-30.
func _controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node is BetaDayOneController:
		return node as BetaDayOneController
	return null
