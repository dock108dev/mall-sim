## Confirmation modal shown when the player requests day-close before the
## day's stock→sell loop has been completed (ISSUE-010 / Phase 3).
##
## Listens to `EventBus.day_close_confirmation_requested(reason)`. When the
## player accepts the prompt the panel emits `EventBus.day_close_confirmed`
## which `DayCycleController._on_day_close_confirmed` routes through to the
## standard close path. Cancel is a no-op — the gate stays in place.
##
## Inherits the `ModalPanel` open/close → push/pop CTX_MODAL contract so the
## FP cursor releases for button clicks and the focus stack stays balanced
## across cancel / confirm hand-offs.
class_name CloseDayConfirmationPanel
extends ModalPanel


@onready var _root: Control = $Root
@onready var _reason_label: Label = $Root/Panel/Margin/VBox/ReasonLabel
@onready var _cancel_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/CancelButton
)
@onready var _confirm_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/ConfirmButton
)


func _ready() -> void:
	visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	if not EventBus.day_close_confirmation_requested.is_connected(
		_on_close_confirmation_requested
	):
		EventBus.day_close_confirmation_requested.connect(
			_on_close_confirmation_requested
		)


func _on_close_confirmation_requested(reason: String) -> void:
	show_with_reason(reason)


## Shows the panel with the supplied reason copy. Idempotent — calling while
## already open just refreshes the reason text without pushing a second
## CTX_MODAL frame (ModalPanel.open() guards the duplicate push).
func show_with_reason(reason: String) -> void:
	_reason_label.text = reason
	open()


func _on_cancel_pressed() -> void:
	close()


func _on_confirm_pressed() -> void:
	close()
	EventBus.day_close_confirmed.emit()


## Override: ModalPanel.open() sets the CanvasLayer visible. We also need the
## inner Control toggled so the panel actually renders.
func open() -> void:
	super.open()
	if _root != null:
		_root.visible = true


func close() -> void:
	if _root != null:
		_root.visible = false
	super.close()
