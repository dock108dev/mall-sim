## Persistent HUD strip showing the player's current four-slot objective display.
## Registered as an autoload CanvasLayer so it survives scene transitions.
## Content arrives via EventBus.objective_changed or EventBus.objective_updated;
## no text is hardcoded here.
## When optional_hint carries a "goto:<store_id>" prefix, the label displays a
## store-routing prompt and EventBus.hub_store_highlighted is emitted immediately
## so the player can see which card to click.
## Auto-hide and Settings-override logic lives in ObjectiveDirector, not here.
## Visibility is also gated by GameManager.State (hidden in MAIN_MENU and
## DAY_SUMMARY) and by the InputFocus modal context (hidden when a modal is on
## top of the stack) so gameplay overlays do not linger across screen states.
extends CanvasLayer

var _auto_hidden: bool = false
var _current_payload: Dictionary = {}
var _show_rail: bool = true
var _tween: Tween

@onready var _band: ColorRect = $AccentBand
@onready var _margin: MarginContainer = $MarginContainer
@onready var _objective_label: Label = $MarginContainer/HBoxContainer/ObjectiveLabel
@onready var _action_label: Label = $MarginContainer/HBoxContainer/ActionLabel
@onready var _hint_label: Label = $MarginContainer/HBoxContainer/HintLabel
@onready var _optional_hint_label: Label = $MarginContainer/HBoxContainer/OptionalHintLabel


func _ready() -> void:
	EventBus.objective_changed.connect(_on_objective_changed)
	EventBus.objective_updated.connect(_on_objective_updated)
	EventBus.preference_changed.connect(_on_preference_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.arc_unlock_triggered.connect(_on_arc_unlock_triggered)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	if InputFocus != null:
		InputFocus.context_changed.connect(_on_input_focus_changed)
	_band.color = Color.html("#5BB8E8")
	visible = false


func _on_game_state_changed(_old_state: int, _new_state: int) -> void:
	_refresh_visibility()


func _on_input_focus_changed(_new_ctx: StringName, _old_ctx: StringName) -> void:
	_refresh_visibility()


func _on_day_started(_day: int) -> void:
	_refresh_visibility()


func _on_arc_unlock_triggered(_unlock_id: String, _day: int) -> void:
	_refresh_visibility()


func _on_objective_changed(payload: Dictionary) -> void:
	if payload.get("hidden", false):
		_auto_hidden = true
		_refresh_visibility()
		return
	_auto_hidden = false
	_current_payload = payload
	_objective_label.text = str(payload.get("text", payload.get("current_objective", "")))
	_action_label.text = str(payload.get("action", payload.get("next_action", "")))
	_set_hint_text(str(payload.get("key", payload.get("input_hint", ""))))
	_update_optional_hint(str(payload.get("optional_hint", "")))
	_flash()
	_refresh_visibility()


func _on_objective_updated(payload: Dictionary) -> void:
	if payload.get("hidden", false):
		_auto_hidden = true
		_refresh_visibility()
		return
	_auto_hidden = false
	_current_payload = payload
	_objective_label.text = str(payload.get("current_objective", payload.get("text", "")))
	_action_label.text = str(payload.get("next_action", payload.get("action", "")))
	_set_hint_text(str(payload.get("input_hint", payload.get("key", ""))))
	_update_optional_hint(str(payload.get("optional_hint", "")))
	_flash()
	_refresh_visibility()


## ObjectiveDirector re-emits the appropriate payload on preference_changed,
## so this handler caches the show flag and triggers a visibility recalc.
func _on_preference_changed(key: String, value: Variant) -> void:
	if key == "show_objective_rail":
		_show_rail = value as bool
		if _show_rail:
			_auto_hidden = false
		_refresh_visibility()


## Sets hint text and hides the chip entirely when the key is empty so days
## without a single-key affordance do not render a stray indicator.
func _set_hint_text(key_text: String) -> void:
	_hint_label.text = key_text
	_hint_label.visible = key_text != ""


## Handles optional_hint display. When the hint starts with "goto:<store_id>",
## the label shows a store-routing prompt and hub_store_highlighted fires so the
## matching card animates immediately. All other hints display as plain text.
func _update_optional_hint(opt: String) -> void:
	if opt.begins_with("goto:"):
		var target_id: StringName = StringName(opt.substr(5))
		var name_text: String = ContentRegistry.get_display_name(target_id)
		_optional_hint_label.text = "→ Go to %s" % name_text
		_optional_hint_label.visible = true
		EventBus.hub_store_highlighted.emit(target_id)
	else:
		_optional_hint_label.text = opt
		_optional_hint_label.visible = opt != ""


## Returns true when the rail currently holds objective content. Used by
## composite readiness audits that need to verify a Day-1 entry surfaced an
## objective without reaching into private state.
func has_active_objective() -> bool:
	return not _current_payload.is_empty()


func _refresh_visibility() -> void:
	visible = (
		_show_rail
		and not _auto_hidden
		and not _current_payload.is_empty()
		and _state_allows_rail()
		and not _modal_active()
	)


func _state_allows_rail() -> bool:
	var state: GameManager.State = GameManager.current_state
	return (
		state != GameManager.State.MAIN_MENU
		and state != GameManager.State.DAY_SUMMARY
	)


## §F-44 — `InputFocus == null` returns false (no modal blocks the rail) on
## purpose: production boot always registers the autoload; the null arm only
## fires under unit-test isolation. Mirrors the test-seam contract used in
## `interaction_prompt.gd` and `StoreController.has_blocking_modal()`.
func _modal_active() -> bool:
	if InputFocus == null:
		return false
	return InputFocus.current() == InputFocus.CTX_MODAL


## Fades the rail in over one second whenever the objective content changes.
func _flash() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_margin.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_margin, "modulate:a", 1.0, 1.0)


## Sets the accent band color to reflect the active store identity.
## Unknown store IDs fall back to the hub default.
func _on_store_entered(store_id: StringName) -> void:
	match store_id:
		&"retro_games":
			_band.color = Color.html("#E8A547")  # CRT Amber
		&"pocket_creatures":
			_band.color = Color.html("#2EB5A8")  # Holo Teal
		&"rentals", &"video_rental":
			_band.color = Color.html("#E04E8C")  # Late-Fee Magenta
		&"electronics", &"consumer_electronics":
			_band.color = Color.html("#3AA8D8")  # CRT Cyan
		&"sports", &"sports_memorabilia":
			_band.color = Color.html("#E85555")  # Grading Crimson
		_:
			_band.color = Color.html("#5BB8E8")  # Hub accent_interact


func _on_store_exited(_store_id: StringName) -> void:
	_band.color = Color.html("#5BB8E8")  # Hub accent_interact
