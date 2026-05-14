## Persistent HUD strip showing the player's current four-slot objective display.
## Registered as an autoload CanvasLayer so it survives scene transitions.
## Content arrives via EventBus.objective_changed or EventBus.objective_updated;
## no text is hardcoded here.
## When optional_hint carries a "goto:<store_id>" prefix, the label displays a
## store-routing prompt and EventBus.hub_store_highlighted is emitted immediately
## so the player can see which card to click.
## Auto-hide and Settings-override logic lives in ObjectiveDirector, not here.
## Visibility is gated by GameManager.State (hidden in MAIN_MENU and
## DAY_SUMMARY) so gameplay overlays do not linger across screen states.
## Under CTX_MODAL the rail stays visible and fades to 0.3 opacity (see
## `_apply_modal_dim`) — the modal-fade contract from ISSUE-002 keeps the
## active objective visible behind the dim overlay.
extends CanvasLayer

## Modal-fade contract: rail opacity drops to 0.65 over 0.15s when CTX_MODAL
## is on top of the InputFocus stack, restores to 1.0 over 0.15s on pop.
## The rail stays `visible = true` under modal context — the fade signals
## de-emphasis without removing the affordance from the player's view.
## Calibrated against `ModalDimOverlay.DIM_COLOR.a = 0.4` so the composed
## visible opacity (0.65 × 0.6 ≈ 0.39) stays legible.
const _MODAL_DIM_ALPHA: float = 0.65
const _MODAL_DIM_DURATION: float = 0.15

## Muted modulate used on the rail's right-side action label when an
## interactable in disabled state is focused in FP mode. Mirrors the
## InteractionPrompt's disabled treatment so the visual contract is
## consistent across the suppress + delegate seam.
const _DISABLED_LABEL_MODULATE: Color = Color(0.78, 0.78, 0.78, 0.7)
const _ACTIVE_LABEL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)

## Step-slot styling. Anchored to BetaModalTheme so the rail's progress
## checklist reads as the same family as the beta modals (decision card,
## day summary, manager note). Slot font_size is applied at runtime via
## `add_theme_font_size_override` so the .tscn does not carry a sub-18pt
## override that would trip the project-theme legibility tripwire.
const _STEP_SLOT_FONT_SIZE: int = 14
const _STEP_PREFIX_COMPLETED: String = "✓ "
const _STEP_FUTURE_ALPHA: float = 0.5
const _STEP_MAX_SLOTS: int = 4

var _auto_hidden: bool = false
var _current_payload: Dictionary = {}
var _show_rail: bool = true
var _tween: Tween
var _modal_dim_tween: Tween
## True iff the most recent context_changed put CTX_MODAL on top. Drives
## the modal-fade tween — flips only on the boolean transition so a nested
## modal context_changed does not retrigger the fade.
var _modal_dim_active: bool = false
## Cached action/hint copy from the most recent objective payload. The rail
## suppresses the right-side chip when the player is carrying stock and no
## interactable is currently focused, so the visible labels can diverge
## from the payload — `_apply_right_side_visibility` re-renders from these
## caches when carry/focus state allows.
var _cached_action: String = ""
var _cached_key: String = ""
## True while an interactable is currently focused by the InteractionRay
## (active OR disabled-state). Drives right-side suppression in concert
## with `_carry_active`. Disabled focus also counts as "no actionable
## prompt" so this flag clears on `interactable_focused_disabled` to keep
## the wrong-target hint from masquerading as an active affordance.
var _interactable_focused_state: bool = false
## True while `BetaRunState.carrying_stock` is set (mirrored via the
## `EventBus.beta_carry_changed` payload). Outside the beta loop the
## carry signal is never emitted, so this stays false and the right side
## renders the cached action/hint as before.
var _carry_active: bool = false
## Mirrors `HUD._fp_mode` via `EventBus.fp_mode_changed`. While FP mode is
## active the rail absorbs the InteractionPrompt's role: when an interactable
## is focused, the rail's right-side chip renders the focused action label
## alongside the cream KeyBadge in place of the cached objective copy. The
## standalone InteractionPrompt suppresses itself for the same period, so
## the player sees one prompt instead of two redundant ones at the bottom.
var _fp_mode_active: bool = false
## Action-label text from the most recent `interactable_focused*` payload.
## Empty when no interactable is focused. The right-side chip routes this
## through to ActionLabel (with the styled KeyBadge for active focus, no
## badge + muted modulate for disabled) only while `_fp_mode_active`.
var _focused_action_text: String = ""
## True iff the most recent focus signal was the active variant (the
## interactable's `can_interact()` returned true). False for disabled-state
## focus or no focus. Drives whether the KeyBadge shows or the disabled
## modulate is applied to the action label.
var _focused_can_interact: bool = false
var _step_slots: Array[Label] = []

@onready var _band: ColorRect = $AccentBand
@onready var _margin: MarginContainer = $MarginContainer
@onready var _objective_label: Label = $MarginContainer/ContentColumn/HBoxContainer/ObjectiveLabel
@onready var _action_label: Label = $MarginContainer/ContentColumn/HBoxContainer/ActionLabel
@onready var _hint_label: Label = $MarginContainer/ContentColumn/HBoxContainer/HintLabel
@onready var _key_badge: PanelContainer = $MarginContainer/ContentColumn/HBoxContainer/KeyBadge
@onready var _optional_hint_label: Label = (
	$MarginContainer/ContentColumn/HBoxContainer/OptionalHintLabel
)
@onready var _steps_container: VBoxContainer = $MarginContainer/ContentColumn/StepsContainer


func _ready() -> void:
	EventBus.objective_changed.connect(_on_objective_changed)
	EventBus.objective_updated.connect(_on_objective_updated)
	EventBus.preference_changed.connect(_on_preference_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.arc_unlock_triggered.connect(_on_arc_unlock_triggered)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.interactable_focused.connect(_on_interactable_focused_rail)
	EventBus.interactable_focused_disabled.connect(
		_on_interactable_focused_disabled_rail
	)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused_rail)
	EventBus.beta_carry_changed.connect(_on_beta_carry_changed_rail)
	EventBus.fp_mode_changed.connect(_on_fp_mode_changed)
	# §EH-15 — `InputFocus` is an autoload (project.godot); `context_changed`
	# is owner-declared on input_focus.gd. The `if InputFocus != null` guard
	# at this connect site was a dead defensive pattern — autoloads cannot be
	# null at `_ready()` time. Removed so a signal rename fails parse instead
	# of silently disabling the modal-dim behaviour.
	InputFocus.context_changed.connect(_on_input_focus_changed)
	_band.color = Color.html("#5BB8E8")
	_step_slots = [
		$MarginContainer/ContentColumn/StepsContainer/StepSlot0 as Label,
		$MarginContainer/ContentColumn/StepsContainer/StepSlot1 as Label,
		$MarginContainer/ContentColumn/StepsContainer/StepSlot2 as Label,
		$MarginContainer/ContentColumn/StepsContainer/StepSlot3 as Label,
	]
	for slot: Label in _step_slots:
		slot.add_theme_font_size_override("font_size", _STEP_SLOT_FONT_SIZE)
	visible = false


func _on_game_state_changed(_old_state: int, _new_state: int) -> void:
	_refresh_visibility()


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	_refresh_visibility()
	_apply_modal_dim(new_ctx == InputFocus.CTX_MODAL)


## Fades the rail's direct CanvasItem children to the modal-dim alpha (0.3)
## when a modal owns InputFocus, restoring to full opacity on pop. Boolean-
## transition gated so a nested modal context_changed does not restart the
## tween. CanvasLayer itself has no `modulate`, so the fade walks the
## children (`AccentBand` + `MarginContainer`).
##
## The in-flight `_tween` from `_flash()` (the 1-second new-objective reveal)
## is killed before starting the dim — both tweens animate `_margin.modulate.a`
## and would otherwise race for the final write each frame, leaving the alpha
## at an unstable mid-flight value once the modal-dim tween finishes.
func _apply_modal_dim(modal_now: bool) -> void:
	if modal_now == _modal_dim_active:
		return
	_modal_dim_active = modal_now
	var target: float = _MODAL_DIM_ALPHA if modal_now else 1.0
	if _modal_dim_tween and _modal_dim_tween.is_valid():
		_modal_dim_tween.kill()
	if _tween and _tween.is_valid():
		_tween.kill()
	_modal_dim_tween = create_tween()
	_modal_dim_tween.set_parallel(true)
	for child: Node in get_children():
		if child is CanvasItem:
			_modal_dim_tween.tween_property(
				child, "modulate:a", target, _MODAL_DIM_DURATION
			)


## Public read of the current modal-dim state for the debug overlay and
## GUT tests. True iff the rail's CanvasItem children are tweening toward —
## or settled at — the modal-dim alpha.
func is_modal_dim_active() -> bool:
	return _modal_dim_active


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
	_cached_action = str(payload.get("action", payload.get("next_action", "")))
	_cached_key = str(payload.get("key", payload.get("input_hint", "")))
	_apply_right_side_visibility()
	_update_optional_hint(str(payload.get("optional_hint", "")))
	_render_steps(payload.get("steps", []) as Array)
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
	_cached_action = str(payload.get("next_action", payload.get("action", "")))
	_cached_key = str(payload.get("input_hint", payload.get("key", "")))
	_apply_right_side_visibility()
	_update_optional_hint(str(payload.get("optional_hint", "")))
	_render_steps(payload.get("steps", []) as Array)
	_flash()
	_refresh_visibility()


## Renders up to four step slots from the objective payload's `steps` array.
## Each step is `{text: String, state: "completed"|"active"|"future"}`. Empty
## or missing arrays hide the StepsContainer entirely so non-multi-step
## payloads (e.g. ObjectiveDirector emissions outside the beta loop) keep
## the legacy single-line ObjectiveLabel render path with no visual bulk.
##
## State styling is anchored to BetaModalTheme so the rail's progress
## checklist reads as the same visual family as the beta modals:
##   * completed → "✓ " prefix in COLOR_ACCENT (green)
##   * active    → COLOR_TEXT_HEADER (warm gold), full opacity
##   * future    → COLOR_TEXT_MUTED at 0.5 alpha (visually subordinate)
func _render_steps(steps: Array) -> void:
	if steps.is_empty():
		# Blank every slot so a later payload that re-shows the container
		# can't surface ghost text left over from a prior 3- or 4-step
		# render. The container's visibility flag alone hides the slots but
		# leaves Label.text intact — a non-issue while empty, but the next
		# steps payload only writes slots inside its own range and leaves
		# any out-of-range slot showing the old text.
		for slot: Label in _step_slots:
			slot.visible = false
			slot.text = ""
		_steps_container.visible = false
		return
	_steps_container.visible = true
	# Brief: "each objective label appears once" — the rail's main label
	# (`_objective_label`) already carries the active beat text, so an
	# active-state step slot rendering the same string is a visible dup.
	# Skip the active slot when its text matches the main label; the
	# active highlight survives via `_objective_label`'s own styling, and
	# completed/future rows still surface the chain progress.
	var active_label_text: String = _objective_label.text.strip_edges()
	for i: int in range(_step_slots.size()):
		var slot: Label = _step_slots[i]
		if i >= steps.size() or i >= _STEP_MAX_SLOTS:
			slot.visible = false
			slot.text = ""
			continue
		var step: Dictionary = steps[i] as Dictionary
		var step_text: String = str(step.get("text", ""))
		var state: String = str(step.get("state", "future"))
		if state == "active" and step_text.strip_edges() == active_label_text:
			slot.visible = false
			slot.text = ""
			continue
		slot.visible = true
		match state:
			"completed":
				slot.text = _STEP_PREFIX_COMPLETED + step_text
				slot.add_theme_color_override(
					"font_color", BetaModalTheme.COLOR_ACCENT
				)
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			"active":
				slot.text = step_text
				slot.add_theme_color_override(
					"font_color", BetaModalTheme.COLOR_TEXT_HEADER
				)
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			_:
				slot.text = step_text
				slot.add_theme_color_override(
					"font_color", BetaModalTheme.COLOR_TEXT_MUTED
				)
				slot.modulate = Color(1.0, 1.0, 1.0, _STEP_FUTURE_ALPHA)


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


## Tracks `BetaRunState.carrying_stock` via the public `beta_carry_changed`
## signal so the rail does not need a hard dependency on BetaRunState. Empty
## payload = not carrying. Outside the beta loop the signal never emits and
## `_carry_active` stays false, leaving the rail behavior unchanged for
## production gameplay.
func _on_beta_carry_changed_rail(text: String) -> void:
	_carry_active = not text.strip_edges().is_empty()
	_apply_right_side_visibility()


func _on_interactable_focused_rail(action_label_text: String) -> void:
	_interactable_focused_state = true
	_focused_action_text = action_label_text
	_focused_can_interact = true
	_apply_right_side_visibility()


## Disabled-state focus counts as "no actionable target" for the rail's
## right-side chip when not in FP mode — the standalone InteractionPrompt
## still surfaces the muted reason text, and the rail must not advertise an
## active "Press E" chip while the player is looking at a node they cannot
## interact with. In FP mode the InteractionPrompt is suppressed and the
## rail itself renders the muted reason in place of the cached action.
func _on_interactable_focused_disabled_rail(reason: String) -> void:
	_interactable_focused_state = false
	_focused_action_text = reason
	_focused_can_interact = false
	_apply_right_side_visibility()


func _on_interactable_unfocused_rail() -> void:
	_interactable_focused_state = false
	_focused_action_text = ""
	_focused_can_interact = false
	_apply_right_side_visibility()


## Mirrors `HUD._fp_mode` so the rail can absorb the InteractionPrompt's
## role inside the store's first-person camera view. Re-renders the
## right-side chip immediately so a focused interactable that pre-dated the
## FP-mode flip surfaces in the rail without waiting for a fresh focus
## event from the InteractionRay.
func _on_fp_mode_changed(enabled: bool) -> void:
	if _fp_mode_active == enabled:
		return
	_fp_mode_active = enabled
	_apply_right_side_visibility()


## Re-renders the right-side action/hint chip based on cached payload and
## the current carry/focus state. Three rendering modes:
##   * FP-mode + interactable focused: the focused action text replaces the
##     cached objective action, the styled KeyBadge appears for active focus
##     (muted modulate + no badge for disabled focus). Cached HintLabel is
##     suppressed so the player sees one badge, not two.
##   * Beta carry without focus: the chip is suppressed entirely so the
##     prompt doesn't appear over unrelated nodes during navigation to the
##     shelf — the focused-target highlight becomes the sole spatial cue.
##   * Default (cached payload render): ActionLabel + HintLabel reflect the
##     most recent objective_changed/objective_updated payload.
func _apply_right_side_visibility() -> void:
	var fp_focus_active: bool = (
		_fp_mode_active and not _focused_action_text.is_empty()
	)
	if fp_focus_active:
		_action_label.text = _focused_action_text
		_action_label.visible = true
		_action_label.modulate = (
			_ACTIVE_LABEL_MODULATE if _focused_can_interact
			else _DISABLED_LABEL_MODULATE
		)
		_set_hint_text("")
		_key_badge.visible = _focused_can_interact
		return

	# Cached-payload paths: the KeyBadge is owned by the FP focus chip, so
	# clear it here whenever no focused interactable drives the right side.
	_key_badge.visible = false
	_action_label.modulate = _ACTIVE_LABEL_MODULATE
	var suppress: bool = _carry_active and not _interactable_focused_state
	if suppress:
		_action_label.text = ""
		_action_label.visible = false
		_set_hint_text("")
	else:
		_action_label.text = _cached_action
		_action_label.visible = _cached_action != ""
		_set_hint_text(_cached_key)


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


## Re-triggers `_flash()` when the rail transitions from hidden-with-content
## back to visible. Without this, the 1-second alpha tween started inside
## `_on_objective_changed` runs while the rail is invisible (e.g., behind the
## Day-1 morning-note overlay) and finishes silently — the rail then snaps in
## at full opacity with no animation when the gating condition clears. Flashing
## on the hidden→visible edge preserves the "new objective" reveal beat.
##
## Modals do not hide the rail: under CTX_MODAL the rail stays `visible = true`
## and `_apply_modal_dim` fades its children to 0.3 alpha. The signal of
## "modal owns focus" is now de-emphasis, not removal — the player still sees
## the active objective behind the dim overlay.
func _refresh_visibility() -> void:
	var should_show: bool = (
		_show_rail
		and not _auto_hidden
		and not _current_payload.is_empty()
		and _state_allows_rail()
	)
	if should_show and not visible:
		_flash()
	visible = should_show


func _state_allows_rail() -> bool:
	var state: GameManager.State = GameManager.current_state
	return (
		state != GameManager.State.MAIN_MENU
		and state != GameManager.State.DAY_SUMMARY
	)


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
		_:
			_band.color = Color.html("#5BB8E8")  # Hub accent_interact


func _on_store_exited(_store_id: StringName) -> void:
	_band.color = Color.html("#5BB8E8")  # Hub accent_interact
