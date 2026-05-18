class_name BetaHiddenClueInteractable
extends BetaDayOneInteractableBase

const CLUE_ID: StringName = &"day01_backroom_modded_console_hint"


func _ready() -> void:
	# Grounded copy — the player decides whether the stack is interesting.
	# The UI never labels this "odd" / "strange" / "mysterious"; flavor
	# text inside the controller's interact handler does the work.
	display_name = "console stack"
	prompt_text = "Inspect"
	action_verb = "Inspect"
	interaction_type = InteractionType.ITEM
	interactable_id = &"backroom_hidden_clue_01"
	proximity_radius = 2.25
	proximity_facing_dot = 0.4
	super._ready()


func can_interact(_actor: Node = null) -> bool:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return false
	return controller.can_interact_hidden_clue()


func get_disabled_reason(_actor: Node = null) -> String:
	var controller: BetaDayOneController = _controller()
	if controller == null:
		return ""
	return controller.hidden_clue_disabled_reason()


func interact(by: Node = null) -> void:
	if not can_interact(by):
		return
	super.interact(by)
	# Route through the controller so the hidden-thread signal, the
	# notification, and the stage advance all live in one place. The
	# previous `BetaRunState.mark_hidden_thread_signal` direct call is
	# kept inside the controller's handler so the consequence pipeline
	# still sees the signal exactly once per day.
	get_tree().call_group(
		"beta_day_one_controller", "on_beta_hidden_clue_interacted"
	)
