class_name BetaHiddenClueInteractable
extends Interactable

const CLUE_ID: StringName = &"day01_backroom_modded_console_hint"


func _ready() -> void:
	display_name = "Odd Console Stack"
	prompt_text = "Inspect"
	action_verb = "Inspect"
	interaction_type = InteractionType.ITEM
	interactable_id = &"backroom_hidden_clue_01"
	super._ready()


func interact(by: Node = null) -> void:
	super.interact(by)
	BetaRunState.mark_hidden_thread_signal(CLUE_ID)
	EventBus.notification_requested.emit(
		"You notice a strange stack of consoles with handwritten tags."
	)
