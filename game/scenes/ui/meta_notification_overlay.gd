## ISSUE-023: Minimum player-visible surface for ambient moments and secret
## thread advancements. Non-blocking, dismissable cards layered over the mall
## hub. Two stacks — ambient (bottom-left, neutral tint) and secret (bottom-
## right, distinct tint) — so the player can tell them apart at a glance.
##
## Input: MOUSE_FILTER_IGNORE everywhere except the small dismiss button on
## each card, so active store screens retain focus when the hub hosts this
## overlay. Cards auto-expire; the player can also click × to dismiss early.
##
## Suppression: the overlay drops signals while a day-close summary is active
## (between EventBus.day_closed and the next day_started). Boot-time suppression
## is inherent — the overlay lives under the mall hub, which only loads after
## GameManager.mark_boot_completed().
class_name MetaNotificationOverlay
extends CanvasLayer


const AMBIENT_VARIANT: StringName = &"ambient"
const SECRET_VARIANT: StringName = &"secret"
const DEFAULT_DURATION: float = 6.0
const MAX_CARDS_PER_STACK: int = 3

const AMBIENT_TINT: Color = Color(0.85, 0.90, 1.0)
const SECRET_TINT: Color = Color(1.0, 0.80, 0.55)
const AMBIENT_BADGE: String = "Moment"
const SECRET_BADGE: String = "Secret"

var _day_close_active: bool = false
var _hidden_by_store: bool = false

@onready var _ambient_stack: VBoxContainer = $Root/AmbientStack
@onready var _secret_stack: VBoxContainer = $Root/SecretStack


func _ready() -> void:
	_connect_bus_signals()


func _connect_bus_signals() -> void:
	EventBus.ambient_moment_delivered.connect(_on_ambient_moment_delivered)
	EventBus.secret_thread_state_changed.connect(_on_secret_state_changed)
	EventBus.secret_thread_revealed.connect(_on_secret_revealed)
	EventBus.secret_thread_completed.connect(_on_secret_completed)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


# ── Suppression gates ─────────────────────────────────────────────────────────

func is_suppressed() -> bool:
	return _day_close_active or _hidden_by_store


func _on_day_closed(_day: int, _summary: Dictionary) -> void:
	_day_close_active = true


func _on_day_started(_day: int) -> void:
	_day_close_active = false


func _on_store_entered(_store_id: StringName) -> void:
	_hidden_by_store = true
	visible = false


func _on_store_exited(_store_id: StringName) -> void:
	_hidden_by_store = false
	visible = true


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_ambient_moment_delivered(
	_moment_id: StringName,
	_display_type: StringName,
	flavor_text: String,
	_audio_cue_id: StringName,
) -> void:
	if is_suppressed():
		return
	if flavor_text.is_empty():
		return
	_push_card(_ambient_stack, AMBIENT_VARIANT, flavor_text)


func _on_secret_state_changed(
	thread_id: StringName, _old_phase: StringName, new_phase: StringName
) -> void:
	if is_suppressed():
		return
	_push_card(
		_secret_stack, SECRET_VARIANT,
		"%s advanced → %s" % [str(thread_id), str(new_phase)]
	)


func _on_secret_revealed(thread_id: StringName) -> void:
	if is_suppressed():
		return
	_push_card(_secret_stack, SECRET_VARIANT, "%s revealed" % str(thread_id))


func _on_secret_completed(thread_id: StringName, _reward: Dictionary) -> void:
	if is_suppressed():
		return
	_push_card(_secret_stack, SECRET_VARIANT, "%s completed" % str(thread_id))


# ── Card construction ─────────────────────────────────────────────────────────

func _push_card(
	stack: VBoxContainer, variant: StringName, message: String
) -> void:
	while stack.get_child_count() >= MAX_CARDS_PER_STACK:
		var oldest: Node = stack.get_child(0)
		stack.remove_child(oldest)
		oldest.queue_free()

	var card: PanelContainer = _build_card(variant, message)
	stack.add_child(card)

	var timer: SceneTreeTimer = get_tree().create_timer(DEFAULT_DURATION)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free()
	)


func _build_card(variant: StringName, message: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(320.0, 0.0)
	card.set_meta(&"variant", variant)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var badge: Label = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = _badge_text(variant)
	badge.add_theme_color_override("font_color", _tint_for(variant))
	row.add_child(badge)

	var body: Label = Label.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = message
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	var dismiss: Button = Button.new()
	dismiss.text = "×"
	dismiss.flat = true
	dismiss.mouse_filter = Control.MOUSE_FILTER_STOP
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.pressed.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free()
	)
	row.add_child(dismiss)

	return card


func _badge_text(variant: StringName) -> String:
	if variant == SECRET_VARIANT:
		return SECRET_BADGE
	return AMBIENT_BADGE


func _tint_for(variant: StringName) -> Color:
	if variant == SECRET_VARIANT:
		return SECRET_TINT
	return AMBIENT_TINT


# ── Test seams ────────────────────────────────────────────────────────────────

func get_ambient_card_count() -> int:
	return _ambient_stack.get_child_count()


func get_secret_card_count() -> int:
	return _secret_stack.get_child_count()


func get_ambient_stack() -> VBoxContainer:
	return _ambient_stack


func get_secret_stack() -> VBoxContainer:
	return _secret_stack
