## Persistent hint banner shown while shelf placement mode is active.
##
## InteractionPrompt is suppressed during placement because `CTX_MODAL`
## remains on the InputFocus stack between inventory close and shelf-slot
## click. This banner is the dedicated channel that survives that gap so the
## player has on-screen guidance about what to do next.
class_name PlacementHintUI
extends PanelContainer


const _DEFAULT_PROMPT: String = "Click a shelf slot to place item — Right-click to cancel"
const _ITEM_PROMPT_FORMAT: String = "Click a shelf slot to place %s — Right-click to cancel"

@onready var _message_label: Label = $Margin/MessageLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.placement_hint_requested.connect(_on_placement_hint_requested)
	EventBus.placement_mode_exited.connect(_on_placement_mode_exited)


## Empty `item_name` is an expected payload — the legacy / test invocation
## path (`enter_placement_mode()` with no arg) does not have an item to name.
## Falling back to a generic prompt is the documented contract, not a silent
## failure. See docs/audits/error-handling-report.md EH-02.
func _on_placement_hint_requested(item_name: String) -> void:
	if item_name.is_empty():
		_message_label.text = _DEFAULT_PROMPT
	else:
		_message_label.text = _ITEM_PROMPT_FORMAT % item_name
	visible = true


func _on_placement_mode_exited() -> void:
	visible = false
