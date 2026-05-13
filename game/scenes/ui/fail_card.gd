## Full-screen failure diagnostic card for StoreDirector FAIL outcomes
## (ISSUE-018, DESIGN.md §1.2 "Fail Loud, Never Grey").
##
## Distinct from ErrorBanner (ISSUE-006) which covers inline null-guards
## inside a running scene. FailCard is raised specifically when
## StoreDirector.enter_store() returns FAIL: the new scene never reached
## READY, so we cover the viewport with the failing invariant, reason, and
## store_id, plus a 'Return to Mall' button that routes back via
## SceneRouter.
##
## Registered as an autoload (.tscn) so StoreDirector can reach it without
## manual wiring. While shown it pushes InputFocus.CTX_MODAL so gameplay
## input halts; dismissing it pops that context back to whatever was on top
## before. AuditLog emits FAIL_CARD_SHOWN / FAIL_CARD_DISMISSED so headless
## CI can verify the card actually appeared on a FAIL path.
extends CanvasLayer

signal card_shown(store_id: StringName, failed_invariant: StringName, reason: String)
signal card_dismissed()

const CHECKPOINT_SHOWN: StringName = &"fail_card_shown"
const CHECKPOINT_DISMISSED: StringName = &"fail_card_dismissed"
const LAYER_INDEX: int = 255

var _is_visible: bool = false
var _pushed_focus: bool = false
var _current_store: StringName = &""

@onready var _root: Control = %FailCardRoot
@onready var _invariant_label: Label = %InvariantLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _store_id_label: Label = %StoreIdLabel
@onready var _return_button: Button = %ReturnToMallButton


func _ready() -> void:
	layer = LAYER_INDEX
	if _root != null:
		_root.visible = false
	if _return_button != null and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)
	_is_visible = false


## Raises the card. `failed_invariant` should be the StringName of the first
## failing StoreReadyContract invariant (or &"" when a pre-contract step
## failed — unknown id, scene load error, etc). `reason` is the human-readable
## summary from StoreReadyResult.reason or StoreDirector's _fail reason.
func show_failure(
	store_id: StringName, failed_invariant: StringName, reason: String
) -> void:
	_current_store = store_id
	if _invariant_label != null:
		var inv_text: String = (
			String(failed_invariant) if failed_invariant != &"" else "precondition"
		)
		_invariant_label.text = "Invariant: " + inv_text
	if _reason_label != null:
		_reason_label.text = reason
	if _store_id_label != null:
		_store_id_label.text = "store_id: " + String(store_id)
	if _root != null:
		_root.visible = true
	_is_visible = true

	# §EH-38 (docs/audits/error-handling-report.md): InputFocus is an autoload
	# (project.godot) and `push_context` is its owner-declared method
	# (input_focus.gd:38). The prior `_input_focus()` walker + `has_method`
	# guard pair was the §EH-13/§EH-15 dead-guard shape — a rename of either
	# would have silently dropped the modal-focus push and shipped a FailCard
	# that the player could click through into the dead store gameplay.
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_pushed_focus = true

	var audit_detail: String = (
		"store_id=%s invariant=%s reason=%s"
		% [store_id, failed_invariant, reason]
	)
	_audit_fail(CHECKPOINT_SHOWN, audit_detail)
	card_shown.emit(store_id, failed_invariant, reason)


## Returns true while the card is on screen.
func is_showing() -> bool:
	return _is_visible


## Hides the card, pops the InputFocus modal context we pushed, and emits
## the DISMISSED audit checkpoint. Does NOT route scenes — caller chooses
## whether to hit 'Return to Mall' or dismiss another way (tests).
func dismiss() -> void:
	if not _is_visible:
		return
	if _root != null:
		_root.visible = false
	_is_visible = false

	if _pushed_focus:
		# §EH-38: typed autoload — mirrors the push_context call in
		# show_failure(). A rename of InputFocus.pop_context now fails GDScript
		# parse instead of silently leaving the modal context on the stack
		# (which would have suppressed all subsequent gameplay input forever).
		InputFocus.pop_context()
		_pushed_focus = false

	_audit_pass(CHECKPOINT_DISMISSED, "store_id=%s" % _current_store)
	card_dismissed.emit()


func _on_return_pressed() -> void:
	var store_id: StringName = _current_store
	dismiss()
	# §EH-38: SceneRouter is an autoload (project.godot) and `route_to` is its
	# owner-declared entry point (scene_router.gd:52). The prior `_scene_router()`
	# walker + has_method("route_to") guard was the §EH-13/§EH-15 dead-guard
	# shape; a rename would have shipped a Return-to-Mall button that pushed
	# the error to the log and silently left the player on a black fail card.
	SceneRouter.route_to(&"mall_hub", {})


func _audit_pass(checkpoint: StringName, detail: String) -> void:
	# §EH-38: AuditLog is an autoload (project.godot) and `pass_check` is its
	# owner-declared method (audit_log.gd:21). The prior `_audit_log()` walker
	# + has_method guard pair was the §EH-13/§EH-15 dead-guard shape and the
	# `print()` fallback below was unreachable in production. A rename now
	# fails GDScript parse rather than silently writing only to stdout
	# (skipping the AuditLog ring buffer that headless CI scans).
	AuditLog.pass_check(checkpoint, detail)


func _audit_fail(checkpoint: StringName, reason: String) -> void:
	# §EH-38: see _audit_pass above for the rationale. fail_check is declared
	# at audit_log.gd:39.
	AuditLog.fail_check(checkpoint, reason)
