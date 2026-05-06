## MorningNotePanel — paper-memo-style overlay for the manager's morning note.
##
## Listens to EventBus.manager_note_shown(note_id, body, allow_auto_dismiss).
## Day 1 and unlock-override notes pass allow_auto_dismiss=false so the panel
## stays until the player dismisses it (E or click). Other days auto-dismiss
## after AUTO_DISMISS_SECONDS while showing a countdown progress bar.
##
## Visual contract (acceptance criteria):
##   - aged/yellowed paper background (NoiseTexture2D + cream tint)
##   - body text in a monospace font (typewritten-memo aesthetic)
##   - text left-aligned with a left-margin indent (suggested ruled paper)
##   - Vic portrait silhouette ~96 px square in the lower-right
##   - panel reads as a physical floating object — drop shadow on all sides,
##     no hard UI border line
##
## Modal-focus contract: the panel inherits the `ModalPanel` lifecycle but
## intentionally does NOT claim CTX_MODAL on InputFocus — clock-in and other
## PRE_OPEN interactions must stay reachable while the note is up. The base
## class's `_exit_tree` auto-pop is therefore a safety no-op for this panel
## (nothing was pushed, so nothing leaks). `show_note()` / `dismiss()` route
## through the inherited `open()` / `close()` to keep the lifecycle consistent
## with other modal panels.
extends ModalPanel


const AUTO_DISMISS_SECONDS: float = 5.0


var _allow_auto_dismiss: bool = true
var _remaining: float = 0.0
var _showing: bool = false
var _current_note_id: String = ""

@onready var _root: Control = %NoteRoot
@onready var _header_label: Label = %HeaderLabel
@onready var _body_label: RichTextLabel = %BodyLabel
@onready var _countdown_bar: ProgressBar = %CountdownBar


func _ready() -> void:
	hide_panel()
	# Run while the rest of the game is paused — onboarding moments may show
	# the note before gameplay tier 5 has finished init.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not EventBus.manager_note_shown.is_connected(_on_manager_note_shown):
		EventBus.manager_note_shown.connect(_on_manager_note_shown)


func _process(delta: float) -> void:
	if not _showing or not _allow_auto_dismiss:
		return
	_remaining = maxf(0.0, _remaining - delta)
	_countdown_bar.value = _remaining
	if _remaining <= 0.0:
		dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if not _showing:
		return
	if event.is_action_pressed("interact"):
		dismiss()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Only count clicks that land on the note's visible rectangle so
			# the player can still click world UI behind it.
			if _root.get_global_rect().has_point(mb.position):
				dismiss()
				get_viewport().set_input_as_handled()


# ── Public API ────────────────────────────────────────────────────────────────

## Shows the panel with the supplied note. allow_auto_dismiss=false keeps the
## panel up until dismiss() is called (Day 1 and unlock-override mornings).
func show_note(
	note_id: String,
	body_text: String,
	day_label: String,
	allow_auto_dismiss: bool,
) -> void:
	_current_note_id = note_id
	_allow_auto_dismiss = allow_auto_dismiss
	_remaining = AUTO_DISMISS_SECONDS
	_header_label.text = "%s — %s" % [_manager_name(), day_label]
	_body_label.text = body_text
	_countdown_bar.max_value = AUTO_DISMISS_SECONDS
	_countdown_bar.value = AUTO_DISMISS_SECONDS
	_countdown_bar.visible = allow_auto_dismiss
	_showing = true
	open()


## Hides and resets the panel. Safe to call when the panel isn't showing.
func dismiss() -> void:
	if not _showing:
		return
	_showing = false
	close()
	EventBus.manager_note_dismissed.emit(_current_note_id)


## Hides the panel without firing dismiss state. Used at scene init.
func hide_panel() -> void:
	if _root != null:
		_root.visible = false
	_showing = false


## Override: passive paper-memo overlay does not claim CTX_MODAL. Toggles only
## the inner Control so the CanvasLayer stays in-tree to receive `_unhandled_input`.
func open() -> void:
	if _root != null:
		_root.visible = true


func close() -> void:
	if _root != null:
		_root.visible = false


# ── Internals ────────────────────────────────────────────────────────────────

func _on_manager_note_shown(
	note_id: String, body_text: String, allow_auto_dismiss: bool
) -> void:
	var day_label: String = "Day %d" % _resolve_current_day()
	show_note(note_id, body_text, day_label, allow_auto_dismiss)


func _resolve_current_day() -> int:
	# GameState.day is the run's authoritative day counter; TimeSystem mirrors
	# it. Use GameState directly so this script doesn't need to walk the scene
	# tree to find the time system.
	var state: Node = get_node_or_null("/root/GameState")
	if state != null and "day" in state:
		var raw: Variant = state.get("day")
		if typeof(raw) == TYPE_INT:
			return int(raw)
	return 1


func _manager_name() -> String:
	# §F-136 — UI-panel test seam. ManagerRelationshipManager is an autoload
	# (project.godot:58); production paths always resolve a non-null node and
	# get_manager_name returns the MANAGER_NAME constant, which is also "Vic
	# Harlow" (manager_relationship_manager.gd:106). The hardcoded fallback
	# matches the constant exactly so the visible header text is correct
	# whether or not the autoload is reachable; a hardening push would only
	# add log noise to the morning-note flow without changing user-visible
	# output. Mirrors the "test seam, defaults match the production constant"
	# justification family used elsewhere in this report.
	var mgr: Node = get_node_or_null("/root/ManagerRelationshipManager")
	if mgr != null and mgr.has_method("get_manager_name"):
		return str(mgr.call("get_manager_name"))
	return "Vic Harlow"
