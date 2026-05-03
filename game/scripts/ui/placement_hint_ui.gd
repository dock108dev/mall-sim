## Persistent hint banner shown while shelf placement mode is active.
##
## InteractionPrompt is suppressed during placement because `CTX_MODAL`
## remains on the InputFocus stack between inventory close and shelf-slot
## click. This banner is the dedicated channel that survives that gap so the
## player has on-screen guidance about what to do next.
##
## During placement the banner stays in sync with whatever the InteractionRay
## is focusing: while aiming at a ShelfSlot the slot's own state-aware label
## (e.g. "Cartridge Slot — Press E to stock <item>", "Shelf full") is shown,
## and the generic fallback is restored when no slot is in focus.
class_name PlacementHintUI
extends PanelContainer


const _DEFAULT_PROMPT: String = "Walk to a shelf and press E to stock — Right-click to cancel"
const _ITEM_PROMPT_FORMAT: String = (
	"Walk to a shelf and press E to stock %s — Right-click to cancel"
)

var _placement_active: bool = false
var _selected_item_name: String = ""

@onready var _message_label: Label = $Margin/MessageLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.placement_hint_requested.connect(_on_placement_hint_requested)
	EventBus.placement_mode_exited.connect(_on_placement_mode_exited)
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)


## Empty `item_name` is an expected payload — the test invocation path
## (`enter_placement_mode()` with no arg) does not carry an item to name.
## Production callers always pass an item; falling back to a generic prompt
## is the documented contract, not a silent failure. See
## docs/audits/error-handling-report.md EH-02.
func _on_placement_hint_requested(item_name: String) -> void:
	_placement_active = true
	_selected_item_name = item_name
	_show_default_message()
	visible = true


func _on_placement_mode_exited() -> void:
	_placement_active = false
	_selected_item_name = ""
	visible = false


## Mirrors the focused interactable's HUD label into the placement hint
## banner. The InteractionRay still emits `interactable_focused` while
## placement mode is active (raycast resumes after `panel_closed` fires);
## the InteractionPrompt overlay is suppressed by CTX_MODAL but this banner
## must surface the same text so the player still reads slot-specific
## feedback (Stock/Shelf full/Wrong category).
func _on_interactable_focused(action_label: String) -> void:
	if not _placement_active:
		return
	if action_label.is_empty():
		_show_default_message()
		return
	_message_label.text = action_label


func _on_interactable_unfocused() -> void:
	if not _placement_active:
		return
	_show_default_message()


func _show_default_message() -> void:
	if _selected_item_name.is_empty():
		_message_label.text = _DEFAULT_PROMPT
	else:
		_message_label.text = _ITEM_PROMPT_FORMAT % _selected_item_name
