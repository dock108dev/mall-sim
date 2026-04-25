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

	var focus: Node = _input_focus()
	if focus != null and focus.has_method("push_context"):
		focus.call("push_context", &"modal")
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
		var focus: Node = _input_focus()
		if focus != null and focus.has_method("pop_context"):
			focus.call("pop_context")
		_pushed_focus = false

	_audit_pass(CHECKPOINT_DISMISSED, "store_id=%s" % _current_store)
	card_dismissed.emit()


func _on_return_pressed() -> void:
	var store_id: StringName = _current_store
	dismiss()
	var router: Node = _scene_router()
	if router == null or not router.has_method("route_to"):
		push_error(
			"[FailCard] SceneRouter unavailable; cannot return to mall for %s"
			% store_id
		)
		return
	router.call("route_to", &"mall_hub", {})


func _input_focus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InputFocus")


func _scene_router() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SceneRouter")


func _audit_log() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("AuditLog")


func _audit_pass(checkpoint: StringName, detail: String) -> void:
	var log: Node = _audit_log()
	if log != null and log.has_method("pass_check"):
		log.pass_check(checkpoint, detail)
	else:
		print("AUDIT: PASS %s %s" % [checkpoint, detail])


func _audit_fail(checkpoint: StringName, reason: String) -> void:
	var log: Node = _audit_log()
	if log != null and log.has_method("fail_check"):
		log.fail_check(checkpoint, reason)
	else:
		print("AUDIT: FAIL %s %s" % [checkpoint, reason])
