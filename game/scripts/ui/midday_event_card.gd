## MiddayEventCard — modal decision card shown when a midday beat fires.
##
## Subscribes to EventBus.midday_event_fired, builds a card with the beat's
## title, body, and choice buttons, and emits EventBus.midday_event_resolved
## when the player picks one. Hides itself between beats so it never blocks
## input outside an active decision.
##
## Visual contract:
##   - Card dimensions, border width (2px), corner radius, and font sizes are
##     read from DecisionCardStyle so the customer decision card and this card
##     share the same widget identity.
##   - Header strip uses DecisionCardStyle.STORE_EVENT_HEADER_COLOR (cool/slate
##     blue), distinct from the customer decision card's warm header.
##   - "STORE EVENT" small-caps label appears in the header's top-left.
##   - Choice buttons render a two-line layout: action label (primary) above
##     the consequence preview (smaller, muted color).
##   - No archetype badge and no "likely reasoning" line — those are
##     customer-card-only elements.
extends CanvasLayer


const _STORE_EVENT_LABEL: String = "STORE EVENT"


var _root: Control
var _card_panel: PanelContainer
var _header_panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _choice_box: VBoxContainer
var _active_beat_id: StringName = &""


func _ready() -> void:
	layer = 80
	_build_layout()
	_root.visible = false
	if not EventBus.midday_event_fired.is_connected(_on_midday_event_fired):
		EventBus.midday_event_fired.connect(_on_midday_event_fired)


func is_open() -> bool:
	return _root != null and _root.visible


# ── Layout construction ──────────────────────────────────────────────────────


func _build_layout() -> void:
	_root = Control.new()
	_root.name = "MiddayEventCardRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card_panel = PanelContainer.new()
	_card_panel.add_theme_stylebox_override(
		"panel", DecisionCardStyle.make_card_stylebox()
	)
	_card_panel.custom_minimum_size = Vector2(
		DecisionCardStyle.CARD_WIDTH, DecisionCardStyle.CARD_MIN_HEIGHT
	)
	center.add_child(_card_panel)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 12)
	_card_panel.add_child(card_vbox)

	_header_panel = PanelContainer.new()
	_header_panel.add_theme_stylebox_override(
		"panel",
		DecisionCardStyle.make_header_stylebox(
			DecisionCardStyle.STORE_EVENT_HEADER_COLOR
		),
	)
	card_vbox.add_child(_header_panel)

	var header_label: Label = Label.new()
	header_label.text = _STORE_EVENT_LABEL
	header_label.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_HEADER_TAG
	)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_panel.add_child(header_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_TITLE
	)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_BODY
	)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(_body_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	card_vbox.add_child(_choice_box)


# ── Beat handling ────────────────────────────────────────────────────────────


func _on_midday_event_fired(beat: Dictionary) -> void:
	_active_beat_id = StringName(str(beat.get("id", "")))
	_title_label.text = str(beat.get("title", ""))
	_body_label.text = str(beat.get("body", ""))
	_clear_choices()
	var choices_raw: Variant = beat.get("choices", [])
	if choices_raw is Array:
		var choices: Array = choices_raw as Array
		for index: int in range(choices.size()):
			var entry: Variant = choices[index]
			if entry is not Dictionary:
				# §F-133 — malformed choice entries are a content-authoring
				# regression in midday_events.json. The Pass-16 hardening of
				# MiddayEventSystem._apply_choice_effects (§F-122) catches the
				# same break on the *resolution* side; this card is the
				# *render* side and would otherwise silently drop the
				# malformed choice and only surface the symptom as a missing
				# button on the player's screen. Escalate so the offending
				# beat id is visible in the log alongside the system-side
				# error.
				push_error((
					"MiddayEventCard: malformed choice entry skipped for "
					+ "beat='%s' index=%d (got %s, expected Dictionary); "
					+ "midday_events.json content-authoring regression"
				) % [String(_active_beat_id), index, type_string(typeof(entry))])
				continue
			_add_choice_button(entry as Dictionary, index)
	elif beat.has("choices"):
		push_error((
			"MiddayEventCard: 'choices' field present but not an Array for "
			+ "beat='%s' (got %s); midday_events.json content-authoring "
			+ "regression"
		) % [String(_active_beat_id), type_string(typeof(choices_raw))])
	if _choice_box.get_child_count() == 0:
		_add_dismiss_button()
	_root.visible = true


func _clear_choices() -> void:
	for child: Node in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()


func _add_choice_button(choice: Dictionary, index: int) -> void:
	var button: Button = Button.new()
	button.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_CHOICE_LABEL
	)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 56)

	var label_box: VBoxContainer = VBoxContainer.new()
	label_box.add_theme_constant_override("separation", 2)
	label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.set_anchors_preset(Control.PRESET_FULL_RECT)

	var primary: Label = Label.new()
	primary.text = str(choice.get("label", "Choose"))
	primary.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_CHOICE_LABEL
	)
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(primary)

	var consequence_text: String = str(choice.get("consequence", ""))
	if not consequence_text.is_empty():
		var consequence: Label = Label.new()
		consequence.text = consequence_text
		consequence.add_theme_font_size_override(
			"font_size", DecisionCardStyle.FONT_SIZE_CHOICE_CONSEQUENCE
		)
		consequence.add_theme_color_override(
			"font_color", DecisionCardStyle.CHOICE_CONSEQUENCE_COLOR
		)
		consequence.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_box.add_child(consequence)

	button.add_child(label_box)
	button.pressed.connect(_on_choice_pressed.bind(index))
	_choice_box.add_child(button)


func _add_dismiss_button() -> void:
	var button: Button = Button.new()
	button.text = "OK"
	button.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_CHOICE_LABEL
	)
	button.pressed.connect(_on_choice_pressed.bind(-1))
	_choice_box.add_child(button)


func _on_choice_pressed(index: int) -> void:
	var beat_id: StringName = _active_beat_id
	_active_beat_id = &""
	_root.visible = false
	EventBus.midday_event_resolved.emit(beat_id, index)
