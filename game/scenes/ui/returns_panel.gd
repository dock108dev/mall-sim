## Decision card UI for the post-sale returns and exchanges flow.
##
## Constructed entirely in GDScript so it can be instantiated headlessly in
## tests without a paired .tscn. Driven by a ReturnRecord:
## populate_from_record() builds the layout (archetype label, defect context,
## the four choice buttons) and applies the policy gates documented in the
## issue spec — Deny is greyed out for poor/damaged conditions, Exchange is
## hidden until employee_stocking_trained is granted.
class_name ReturnsPanel
extends CanvasLayer

signal decision_chosen(choice: String)

const PANEL_NAME: String = "returns"

var _active_record: ReturnRecord = null
var _root_panel: PanelContainer = null
var _archetype_label_node: Label = null
var _context_label_node: Label = null
var _choice_buttons: Dictionary = {}
var _choice_visibility: Dictionary = {}
var _choice_enabled: Dictionary = {}
var _is_built: bool = false


func _ready() -> void:
	_build_layout()


## Populates the panel from a ReturnRecord and shows it. Returns false when
## the record is null so callers can fall back without leaking partial state.
func populate_from_record(
	record: ReturnRecord
) -> bool:
	if record == null:
		push_warning("ReturnsPanel: populate_from_record called with null")
		return false
	if not _is_built:
		_build_layout()
	_active_record = record
	var card_data: Dictionary = ReturnsSystem.build_card_data(record)
	_archetype_label_node.text = String(
		card_data.get("archetype_label", "Angry Return")
	)
	_context_label_node.text = String(card_data.get("context", ""))
	var deny_available: bool = bool(card_data.get("deny_available", true))
	var exchange_unlocked: bool = bool(
		card_data.get("exchange_unlocked", false)
	)
	_set_choice_visible(ReturnsSystem.RESOLUTION_REFUND, true)
	_set_choice_visible(
		ReturnsSystem.RESOLUTION_EXCHANGE, exchange_unlocked
	)
	_set_choice_visible(ReturnsSystem.RESOLUTION_DENY, true)
	_set_choice_visible(ReturnsSystem.RESOLUTION_ESCALATE, true)
	_set_choice_enabled(ReturnsSystem.RESOLUTION_REFUND, true)
	_set_choice_enabled(
		ReturnsSystem.RESOLUTION_EXCHANGE, exchange_unlocked
	)
	_set_choice_enabled(ReturnsSystem.RESOLUTION_DENY, deny_available)
	_set_choice_enabled(ReturnsSystem.RESOLUTION_ESCALATE, true)
	_root_panel.visible = true
	return true


## Returns true when the named choice button is currently visible. Tests
## inspect this to verify Exchange-hidden behavior pre-unlock.
func is_choice_visible(choice: String) -> bool:
	return bool(_choice_visibility.get(choice, false))


## Returns true when the named choice button is enabled (not greyed out).
## Tests inspect this to verify the Deny gate for defective conditions.
func is_choice_enabled(choice: String) -> bool:
	return bool(_choice_enabled.get(choice, false))


## Returns the raw button reference for the named choice; null when the
## choice doesn't exist on this panel build.
func get_choice_button(choice: String) -> Button:
	return _choice_buttons.get(choice, null)


## Closes the panel without applying a decision. Used by callers that need to
## tear it down (scene transition, escalation handled elsewhere).
func close_panel() -> void:
	_active_record = null
	if _root_panel != null:
		_root_panel.visible = false


# ── Internals ────────────────────────────────────────────────────────────────


func _build_layout() -> void:
	if _is_built:
		return
	_root_panel = PanelContainer.new()
	_root_panel.name = "ReturnsPanelRoot"
	_root_panel.visible = false
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.custom_minimum_size = Vector2(
		DecisionCardStyle.CARD_WIDTH, DecisionCardStyle.CARD_MIN_HEIGHT
	)
	_apply_card_style(_root_panel)
	add_child(_root_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override(
		"margin_left", DecisionCardStyle.CARD_PADDING_PX
	)
	margin.add_theme_constant_override(
		"margin_right", DecisionCardStyle.CARD_PADDING_PX
	)
	margin.add_theme_constant_override(
		"margin_top", DecisionCardStyle.CARD_PADDING_PX
	)
	margin.add_theme_constant_override(
		"margin_bottom", DecisionCardStyle.CARD_PADDING_PX
	)
	_root_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	margin.add_child(vbox)

	_archetype_label_node = Label.new()
	_archetype_label_node.name = "ArchetypeLabel"
	_archetype_label_node.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_TITLE
	)
	vbox.add_child(_archetype_label_node)

	_context_label_node = Label.new()
	_context_label_node.name = "ContextLabel"
	_context_label_node.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_BODY
	)
	_context_label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_context_label_node)

	var choices_box: VBoxContainer = VBoxContainer.new()
	choices_box.name = "ChoicesBox"
	vbox.add_child(choices_box)

	_add_choice_button(
		choices_box, ReturnsSystem.RESOLUTION_REFUND,
		"Accept — full refund"
	)
	_add_choice_button(
		choices_box, ReturnsSystem.RESOLUTION_EXCHANGE,
		"Accept — exchange"
	)
	_add_choice_button(
		choices_box, ReturnsSystem.RESOLUTION_DENY,
		"Deny — policy"
	)
	_add_choice_button(
		choices_box, ReturnsSystem.RESOLUTION_ESCALATE,
		"Escalate to manager"
	)

	_is_built = true


func _add_choice_button(
	parent: VBoxContainer, choice_id: String, label: String
) -> void:
	var button: Button = Button.new()
	button.name = "Choice_%s" % choice_id
	button.text = label
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(_on_choice_pressed.bind(choice_id))
	parent.add_child(button)
	_choice_buttons[choice_id] = button
	_choice_visibility[choice_id] = true
	_choice_enabled[choice_id] = true


func _set_choice_visible(choice_id: String, visible: bool) -> void:
	var button: Button = _choice_buttons.get(choice_id, null)
	if button == null:
		return
	button.visible = visible
	_choice_visibility[choice_id] = visible


func _set_choice_enabled(choice_id: String, enabled: bool) -> void:
	var button: Button = _choice_buttons.get(choice_id, null)
	if button == null:
		return
	button.disabled = not enabled
	_choice_enabled[choice_id] = enabled


func _on_choice_pressed(choice_id: String) -> void:
	# §F-139 — defensive UI guards; the system layer is the loud surface.
	# - _active_record == null: panel was torn down between the click and
	#   the deferred dispatch (race on close_panel + queued button signal).
	# - is_choice_enabled / is_choice_visible: belt-and-braces against a
	#   button whose disabled/visible state was modified after the press
	#   was queued.
	# - apply_decision returning false: every false branch in
	#   ReturnsSystem.apply_decision (lines 222-256) emits its own
	#   push_warning with the offending choice / record context, so the
	#   panel can fail closed without re-logging — the system is the
	#   single observability surface for refund-decision failures.
	if _active_record == null:
		return
	if not is_choice_enabled(choice_id):
		return
	if not is_choice_visible(choice_id):
		return
	if not ReturnsSystem.apply_decision(_active_record, choice_id):
		return
	decision_chosen.emit(choice_id)
	close_panel()


func _apply_card_style(panel: PanelContainer) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = DecisionCardStyle.CARD_ACTIVE_BG_COLOR
	box.border_width_left = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_width_top = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_width_right = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_width_bottom = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_color = DecisionCardStyle.CARD_BORDER_COLOR
	box.corner_radius_top_left = DecisionCardStyle.CARD_CORNER_RADIUS
	box.corner_radius_top_right = DecisionCardStyle.CARD_CORNER_RADIUS
	box.corner_radius_bottom_left = DecisionCardStyle.CARD_CORNER_RADIUS
	box.corner_radius_bottom_right = DecisionCardStyle.CARD_CORNER_RADIUS
	panel.add_theme_stylebox_override("panel", box)
