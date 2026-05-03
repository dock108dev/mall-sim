# gdlint:disable=max-file-lines
## In-game HUD — persistent top bar with cash, day/time, speed, and reputation.
extends CanvasLayer


const _PHASE_KEYS: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: "HUD_PHASE_PRE_OPEN",
	TimeSystem.DayPhase.MORNING_RAMP: "HUD_PHASE_MORNING",
	TimeSystem.DayPhase.MIDDAY_RUSH: "HUD_PHASE_MIDDAY",
	TimeSystem.DayPhase.AFTERNOON: "HUD_PHASE_AFTERNOON",
	TimeSystem.DayPhase.EVENING: "HUD_PHASE_EVENING",
}

const _PHASE_COLORS: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: Color(0.7, 0.75, 0.9),
	TimeSystem.DayPhase.MORNING_RAMP: Color(0.95, 0.85, 0.3),
	TimeSystem.DayPhase.MIDDAY_RUSH: Color(1.0, 1.0, 0.9),
	TimeSystem.DayPhase.AFTERNOON: Color(0.95, 0.65, 0.3),
	TimeSystem.DayPhase.EVENING: Color(0.5, 0.4, 0.8),
}

const _SPEED_LABELS: Dictionary = {
	0.0: "Paused",
	1.0: "Normal",
	3.0: "Fast",
	6.0: "Ultra",
}

const _SPEED_CYCLE: Array[TimeSystem.SpeedTier] = [
	TimeSystem.SpeedTier.PAUSED,
	TimeSystem.SpeedTier.NORMAL,
	TimeSystem.SpeedTier.FAST,
	TimeSystem.SpeedTier.ULTRA,
]

const _TIER_THRESHOLDS: Array[float] = [80.0, 50.0, 25.0, 0.0]
const _TIER_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.0),
	Color(0.3, 0.69, 0.31),
	Color(0.7, 0.7, 0.7),
	Color(0.9, 0.3, 0.25),
]

const _CASH_COUNT_DURATION: float = 0.3
const _CASH_PULSE_DURATION: float = PanelAnimator.FEEDBACK_PULSE_DURATION
const _CASH_INCOME_SCALE: float = 1.15
const _CASH_EXPENSE_SCALE: float = 1.1
const _REP_ARROW_FADE_IN: float = 0.1
const _REP_ARROW_HOLD: float = 1.0
const _REP_ARROW_FADE_OUT: float = 0.4
const _BUILD_MODE_DIM_ALPHA: float = 0.5
const _COUNTER_PULSE_SCALE: float = 1.08
const _COUNTER_PULSE_DURATION: float = PanelAnimator.FEEDBACK_PULSE_DURATION

var _telegraphed_events: Dictionary = {}
var _random_event_telegraph: String = ""

var _current_day: int = 1
var _current_hour: int = Constants.STORE_OPEN_HOUR
var _current_phase: TimeSystem.DayPhase = TimeSystem.DayPhase.PRE_OPEN
var _displayed_cash: float = 0.0
var _target_cash: float = 0.0
var _current_speed: float = 1.0
var _last_reputation: float = ReputationSystemSingleton.DEFAULT_REPUTATION

var _tutorial_step_active: bool = false
var _objective_active: bool = false
var _cash_count_tween: Tween
var _cash_scale_tween: Tween
var _cash_color_tween: Tween
var _rep_arrow_tween: Tween
var _dim_tween: Tween
var _close_day_button: Button
var _hub_back_button: Button
var _items_placed_count: int = 0
var _customers_active_count: int = 0
var _sales_today_count: int = 0
var _counter_scale_tweens: Dictionary = {}
var _counter_color_tweens: Dictionary = {}

# First-person HUD mode — set via `set_fp_mode(true)` by `StorePlayerBody._ready`.
# When enabled, the heavy `TopBar` HBoxContainer is hidden and the four core
# readouts (cash, time, on-shelves, customers, sold-today) are reparented as
# compact corner overlays directly on the HUD CanvasLayer. A bottom-right F4
# key-hint label exposes the close-day affordance without the TopBar button.
var _fp_mode: bool = false
var _fp_orig_indices: Dictionary = {}
var _fp_close_day_hint: Label
## Tracks whether the Day-1 soft-gate ConfirmationDialog pushed CTX_MODAL on
## InputFocus. Mirrors the InventoryPanel / CheckoutPanel modal-focus contract
## so the FP cursor releases while the dialog is up and recaptures on dismiss.
var _confirm_dialog_focus_pushed: bool = false

@onready var _top_bar: HBoxContainer = $TopBar
@onready var _cash_label: Label = $TopBar/CashLabel
@onready var _time_label: Label = $TopBar/TimeLabel
@onready var _items_placed_label: Label = $TopBar/ItemsPlacedLabel
@onready var _customers_label: Label = $TopBar/CustomersLabel
@onready var _sales_today_label: Label = $TopBar/SalesTodayLabel
@onready var _speed_button: Button = $TopBar/SpeedButton
@onready var _reputation_label: Label = $TopBar/ReputationLabel
@onready var _store_label: Label = $TopBar/StoreLabel
@onready var _seasonal_event_label: Label = $SeasonalEventLabel
@onready var _telegraph_card: Label = $TelegraphCard
@onready var _milestones_button: Button = $TopBar/MilestonesButton
@onready var _close_day_preview: CanvasLayer = $CloseDayPreview
@onready var _close_day_confirm_dialog: ConfirmationDialog = (
	$CloseDayConfirmDialog
)


func _ready() -> void:
	_store_label.visible = false
	_seasonal_event_label.visible = false
	_telegraph_card.visible = false
	_speed_button.visible = false

	EventBus.objective_changed.connect(_on_objective_payload)
	EventBus.objective_updated.connect(_on_objective_payload)
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.critical_notification_requested.connect(_on_critical_notification_requested)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.seasonal_event_started.connect(
		_on_seasonal_event_started
	)
	EventBus.seasonal_event_ended.connect(
		_on_seasonal_event_ended
	)
	EventBus.event_telegraphed.connect(_on_event_telegraphed)
	EventBus.random_event_telegraphed.connect(_on_random_event_telegraphed)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.store_entered.connect(_on_store_entered_hub)
	EventBus.store_exited.connect(_on_store_exited_hub)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.item_sold.connect(_on_item_sold)
	_milestones_button.pressed.connect(_on_milestones_pressed)
	_speed_button.pressed.connect(_on_speed_button_pressed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed_hud)
	EventBus.tutorial_completed.connect(_on_tutorial_hint_ended)
	EventBus.tutorial_skipped.connect(_on_tutorial_hint_ended)
	EventBus.run_state_changed.connect(_on_run_state_changed)
	EventBus.first_sale_completed.connect(_on_first_sale_completed_hud)

	_create_close_day_button()
	_create_hub_back_button()
	_wire_close_day_preview()
	_wire_close_day_confirm_dialog()

	_update_cash_display(_displayed_cash)
	_update_reputation_display(_last_reputation)
	_update_speed_display(_current_speed)
	_refresh_time_display()
	_seed_counters_from_systems()
	_apply_state_visibility(GameManager.current_state)


func _on_day_started(day: int) -> void:
	_current_day = day
	_random_event_telegraph = ""
	_sales_today_count = 0
	_update_sales_today_display(_sales_today_count)
	_refresh_time_display()
	_refresh_items_placed()
	_refresh_customers_active()
	_apply_state_visibility(GameManager.current_state)


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour
	_refresh_time_display()


func _on_day_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase as TimeSystem.DayPhase
	_refresh_time_display()


func _on_money_changed(
	old_amount: float, new_amount: float
) -> void:
	_target_cash = new_amount
	_animate_cash_count(old_amount, new_amount)
	_pulse_cash_label(new_amount - old_amount)


func _on_speed_changed(new_speed: float) -> void:
	_current_speed = new_speed
	_update_speed_display(new_speed)


func _on_reputation_changed(
	_store_id: String, _old_score: float, new_value: float
) -> void:
	var old_value: float = _last_reputation
	_last_reputation = new_value
	_update_reputation_display(new_value)
	_flash_reputation_label(old_value, new_value)


func _create_close_day_button() -> void:
	_close_day_button = Button.new()
	_close_day_button.name = "CloseDayButton"
	_close_day_button.text = tr("HUD_CLOSE_DAY_LABEL")
	# Wider min-size accommodates the keybinding hint without wrapping in either
	# locale; the keybinding makes the close-day affordance discoverable to a
	# new player after the first-sale objective points at it.
	_close_day_button.custom_minimum_size.x = 160
	_close_day_button.clip_text = false
	_close_day_button.pressed.connect(_on_close_day_pressed)
	_top_bar.add_child(_close_day_button)


func _is_day1_gate_active() -> bool:
	return (
		GameManager.get_current_day() == 1
		and not GameState.get_flag(&"first_sale_complete")
	)


func _on_run_state_changed() -> void:
	if is_instance_valid(_close_day_button):
		_close_day_button.tooltip_text = (
			"You haven't made your first sale yet. You'll be asked to confirm."
			if _is_day1_gate_active()
			else ""
		)


## Pulses the Close Day button once the first sale lands so the affordance
## stands out at the moment the post-sale objective rail points at it.
##
## §F-62 — `is_instance_valid(_close_day_button)` silent return covers the
## window where `EventBus.first_sale_completed` fires while the HUD is mid-
## teardown (run reset, scene swap to mall hub, etc.). The button is created
## in `_create_close_day_button` during `_ready` and lives for the lifetime
## of the HUD; missing instance means we are already shutting down and
## animating it would be wasted work, not a missed signal.
func _on_first_sale_completed_hud(
	_store_id: StringName, _item_id: String, _price: float
) -> void:
	if not is_instance_valid(_close_day_button):
		return
	PanelAnimator.pulse_scale(
		_close_day_button, _COUNTER_PULSE_SCALE, _COUNTER_PULSE_DURATION
	)
	PanelAnimator.flash_color(
		_close_day_button,
		UIThemeConstants.get_positive_color(),
		_COUNTER_PULSE_DURATION
	)


func _on_close_day_pressed() -> void:
	var state := GameManager.current_state
	if state == GameManager.State.STORE_VIEW or state == GameManager.State.GAMEPLAY:
		if _is_day1_gate_active():
			_show_close_day_confirm()
			return
		_open_close_day_preview()


## Day 1 soft gate: prompt for consent before closing without a first sale.
## Confirm proceeds to the dry-run preview; cancel is a no-op.
##
## The CTX_MODAL push releases the FP cursor while the dialog is up so the
## player can click "Close Anyway" / "Stay Open" without a captured cursor;
## the matching pop fires from the dialog's `confirmed` / `canceled` signals
## (`_on_close_day_confirm_confirmed` / `_on_close_day_confirm_canceled`) so
## hand-off to either the preview or back to gameplay leaves the focus stack
## balanced.
func _show_close_day_confirm() -> void:
	if not is_instance_valid(_close_day_confirm_dialog):
		# Wiring regression — open the preview so the player is not trapped.
		push_warning(
			"HUD._show_close_day_confirm: CloseDayConfirmDialog missing; "
			+ "opening close-day preview directly."
		)
		_open_close_day_preview()
		return
	_push_confirm_dialog_modal_focus()
	_close_day_confirm_dialog.popup_centered()


## Opens the dry-run preview modal. The preview's Confirm button is the only
## path that emits day_close_requested from the in-store HUD; the preview
## script handles the emit itself.
##
## The fallback emit (preview missing) is loud on purpose: hud.tscn ships a
## CloseDayPreview child, so reaching the fallback means the scene was edited
## without the modal. The day still closes — but the wiring regression is
## logged so CI catches it. See docs/audits/error-handling-report.md EH-06.
func _open_close_day_preview() -> void:
	if not is_instance_valid(_close_day_preview):
		push_warning(
			"HUD._open_close_day_preview: CloseDayPreview child missing; "
			+ "skipping preview modal and closing day directly."
		)
		EventBus.day_close_requested.emit()
		return
	_close_day_preview.show_preview()


## §F-68 — `_wire_close_day_preview` / `_wire_close_day_confirm_dialog`:
## the preview and confirm-dialog children ship with `hud.tscn`, but a unit
## test that constructs the HUD without the packed scene (or a future scene
## variant that omits one) would otherwise crash on the connect/setter call.
## `_open_close_day_preview` already escalates with `push_warning` when the
## preview child is missing at click time (see `_open_close_day_preview`),
## so a silently-unwired modal still raises a visible signal at use; an
## extra warning here would double-fire on every test fixture.
func _wire_close_day_preview() -> void:
	if not is_instance_valid(_close_day_preview):
		return
	_close_day_preview.set_snapshot_callback(_get_active_store_snapshot)


func _wire_close_day_confirm_dialog() -> void:
	if not is_instance_valid(_close_day_confirm_dialog):
		return
	_close_day_confirm_dialog.confirmed.connect(_on_close_day_confirm_confirmed)
	_close_day_confirm_dialog.canceled.connect(_on_close_day_confirm_canceled)


## Confirmed → release the dialog's CTX_MODAL frame, then open the preview.
## The preview pushes its own CTX_MODAL when shown so the cursor stays
## released across the hand-off; popping here keeps the stack balanced for
## test harnesses that drive the dialog signals directly.
func _on_close_day_confirm_confirmed() -> void:
	_pop_confirm_dialog_modal_focus()
	_open_close_day_preview()


func _on_close_day_confirm_canceled() -> void:
	_pop_confirm_dialog_modal_focus()


func _push_confirm_dialog_modal_focus() -> void:
	if _confirm_dialog_focus_pushed:
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_confirm_dialog_focus_pushed = true


func _pop_confirm_dialog_modal_focus() -> void:
	if not _confirm_dialog_focus_pushed:
		return
	# Defensive: if the topmost frame is no longer CTX_MODAL, a sibling pushed
	# without going through this contract. Surface it via push_error AND skip
	# the pop so we don't corrupt someone else's frame. Mirrors the InventoryPanel
	# / CheckoutPanel pattern.
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"HUD._pop_confirm_dialog_modal_focus: expected CTX_MODAL on top, "
				+ "got %s — leaving stack untouched to avoid corrupting "
				+ "sibling frame"
			)
			% String(InputFocus.current())
		)
		_confirm_dialog_focus_pushed = false
		return
	InputFocus.pop_context()
	_confirm_dialog_focus_pushed = false


## §F-69 — Empty-array fallback when `InventorySystem` is null mirrors the
## Tier-5 init pattern documented in §J2: the HUD is constructed before the
## five-tier init sequence runs, so the inventory autoload may legitimately
## be null on the first frame and during headless tests. The CloseDayPreview
## consumer renders an empty list ("no items remaining") in that window;
## once the inventory is live the preview reads the live snapshot the next
## time it is opened.
func _get_active_store_snapshot() -> Array:
	var inventory: InventorySystem = GameManager.get_inventory_system()
	if inventory == null:
		return []
	var store_id: StringName = GameManager.get_active_store_id()
	if String(store_id).is_empty():
		var generic: Array = inventory.get_shelf_items()
		return generic
	var typed: Array[ItemInstance] = inventory.get_shelf_items_for_store(
		String(store_id)
	)
	var generic_items: Array = []
	for item: ItemInstance in typed:
		generic_items.append(item)
	return generic_items


func _create_hub_back_button() -> void:
	_hub_back_button = Button.new()
	_hub_back_button.name = "HubBackButton"
	_hub_back_button.text = "← Hub"
	_hub_back_button.custom_minimum_size.x = 80
	_hub_back_button.clip_text = false
	_hub_back_button.visible = false
	_hub_back_button.pressed.connect(_on_hub_back_pressed)
	_top_bar.add_child(_hub_back_button)


func _on_hub_back_pressed() -> void:
	EventBus.exit_store_requested.emit()


func _on_store_entered_hub(_store_id: StringName) -> void:
	if is_instance_valid(_hub_back_button):
		_hub_back_button.visible = (
			GameManager.current_state == GameManager.State.STORE_VIEW
		)


func _on_store_exited_hub(_store_id: StringName) -> void:
	if is_instance_valid(_hub_back_button):
		_hub_back_button.visible = false


func _on_game_state_changed(_old_state: int, new_state: int) -> void:
	_apply_state_visibility(new_state as GameManager.State)


func _apply_state_visibility(state: GameManager.State) -> void:
	match state:
		GameManager.State.MAIN_MENU, GameManager.State.DAY_SUMMARY:
			visible = false
		GameManager.State.MALL_OVERVIEW:
			visible = true
			# KPI strip (mall hub overlay) is the canonical cash display in
			# MALL_OVERVIEW. Hiding the HUD CashLabel here prevents the
			# duplicate "$0.00$0" artifact when both labels render at once.
			_cash_label.visible = false
			_time_label.visible = true
			_milestones_button.visible = true
			_close_day_button.visible = false
			_hub_back_button.visible = false
			_store_label.visible = false
			_items_placed_label.visible = false
			_customers_label.visible = false
			_sales_today_label.visible = false
			# MALL_OVERVIEW retains the reputation label; only STORE_VIEW
			# hides it. Set explicitly to avoid inheriting the hidden state
			# when transitioning from STORE_VIEW.
			_reputation_label.visible = true
			_speed_button.visible = false
			_seasonal_event_label.visible = false
			_telegraph_card.visible = false
		GameManager.State.STORE_VIEW:
			visible = true
			_cash_label.visible = true
			_time_label.visible = true
			# Reputation, customer count, and time-speed controls are not part
			# of the Day 1 in-store HUD: reputation has no live source in the
			# store loop yet, the customer count is redundant with the spawned
			# NPCs, and the speed control surfaces a feature that is not wired
			# up here.
			_reputation_label.visible = false
			_customers_label.visible = false
			_speed_button.visible = false
			# Day 1 quarantine: the centered MilestonesPanel covers store fixtures
			# while the player is still learning the stock-and-sell loop. Hide the
			# button on Day 1 STORE_VIEW; it remains accessible from MALL_OVERVIEW
			# and re-appears in STORE_VIEW on Day 2+.
			_milestones_button.visible = (
				GameManager.get_current_day() > 1
			)
			_close_day_button.visible = true
			_items_placed_label.visible = true
			_sales_today_label.visible = true
			_store_label.visible = false
			_seasonal_event_label.visible = false
			_telegraph_card.visible = false
		_:
			# §J4: PAUSED, LOADING, BUILD, and other intermediate states inherit
			# the current visibility established by the most recent explicit
			# transition (STORE_VIEW / MALL_OVERVIEW → visible; MAIN_MENU /
			# DAY_SUMMARY → hidden). New GameManager.State values must be
			# added explicitly here if they need distinct HUD visibility.
			pass
	# FP mode rewrites the in-store HUD to a compact corner layout. The state
	# branches above tune TopBar children for the desktop manager view; once FP
	# mode is on, any state transition that leaves the HUD visible must re-
	# assert the FP overrides so the heavy TopBar does not leak back in.
	if _fp_mode and visible:
		_apply_fp_visibility_overrides()


func _on_speed_button_pressed() -> void:
	if GameManager.current_state != GameManager.State.GAMEPLAY:
		return
	var next_tier: TimeSystem.SpeedTier = _get_next_speed_tier()
	EventBus.time_speed_requested.emit(int(next_tier))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if GameManager.current_state != GameManager.State.GAMEPLAY:
		return
	if event.is_action("close_day"):
		if _is_day1_gate_active():
			_show_close_day_confirm()
			get_viewport().set_input_as_handled()
			return
		_open_close_day_preview()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("time_speed_1"):
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.NORMAL)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_speed_2"):
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.FAST)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_speed_4"):
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.ULTRA)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_toggle_pause"):
		var tier: TimeSystem.SpeedTier = (
			TimeSystem.SpeedTier.NORMAL
			if _current_speed <= 0.0
			else TimeSystem.SpeedTier.PAUSED
		)
		EventBus.time_speed_requested.emit(tier as int)
		get_viewport().set_input_as_handled()


func _refresh_time_display() -> void:
	var formatted: String = _format_hour_12(_current_hour)
	var phase_key: String = _PHASE_KEYS.get(
		_current_phase, "HUD_PHASE_MORNING"
	)
	var phase_color: Color = _PHASE_COLORS.get(
		_current_phase, Color.WHITE
	)
	_time_label.text = tr("HUD_DAY_FORMAT") % [
		_current_day, formatted
	]
	_time_label.tooltip_text = tr(phase_key)
	_time_label.modulate = phase_color


func _format_hour_12(hour: int) -> String:
	var period: String = tr("HUD_AM") if hour < 12 else tr("HUD_PM")
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:00 %s" % [display_hour, period]


func _update_cash_display(amount: float) -> void:
	_cash_label.text = "$%s" % _format_cash(amount)


func _format_cash(amount: float) -> String:
	var whole: int = int(absf(amount))
	var cents: int = int(absf(amount - float(whole)) * 100.0 + 0.5)
	var groups: PackedStringArray = []
	if whole == 0:
		groups.append("0")
	else:
		while whole > 0:
			var chunk: int = whole % 1000
			whole = int(whole / 1000.0)
			if whole > 0:
				groups.append("%03d" % chunk)
			else:
				groups.append(str(chunk))
		groups.reverse()
	var prefix: String = "-" if amount < 0.0 else ""
	return "%s%s.%02d" % [prefix, ",".join(groups), cents]


func _animate_cash_count(
	from_amount: float, to_amount: float
) -> void:
	PanelAnimator.kill_tween(_cash_count_tween)
	_displayed_cash = from_amount
	_cash_count_tween = _cash_label.create_tween()
	_cash_count_tween.tween_method(
		_on_cash_count_step, from_amount, to_amount,
		_CASH_COUNT_DURATION
	)


func _on_cash_count_step(value: float) -> void:
	_displayed_cash = value
	_update_cash_display(value)


func _pulse_cash_label(delta: float) -> void:
	if is_zero_approx(delta):
		return
	PanelAnimator.kill_tween(_cash_scale_tween)
	PanelAnimator.kill_tween(_cash_color_tween)
	var is_income: bool = delta > 0.0
	var target_scale: float = (
		_CASH_INCOME_SCALE if is_income else _CASH_EXPENSE_SCALE
	)
	var pulse_color: Color = (
		UIThemeConstants.get_positive_color() if is_income
		else UIThemeConstants.get_negative_color()
	)
	_cash_scale_tween = PanelAnimator.pulse_scale(
		_cash_label, target_scale, _CASH_PULSE_DURATION
	)
	_cash_color_tween = PanelAnimator.flash_color(
		_cash_label, pulse_color, _CASH_PULSE_DURATION
	)


func _update_speed_display(speed: float) -> void:
	_speed_button.text = _SPEED_LABELS.get(speed, "Normal")
	if speed <= 0.0:
		_speed_button.modulate = Color(1.0, 0.4, 0.4)
	else:
		_speed_button.modulate = Color.WHITE


func _get_next_speed_tier() -> TimeSystem.SpeedTier:
	var current_index: int = -1
	for i: int in range(_SPEED_CYCLE.size()):
		if is_equal_approx(float(_SPEED_CYCLE[i]), _current_speed):
			current_index = i
			break
	if current_index == -1:
		return TimeSystem.SpeedTier.NORMAL
	return _SPEED_CYCLE[(current_index + 1) % _SPEED_CYCLE.size()]


func _update_reputation_display(score: float) -> void:
	_reputation_label.text = _format_reputation(score)
	_reputation_label.add_theme_color_override(
		"font_color", _get_tier_color(score)
	)


func _format_reputation(score: float) -> String:
	var tier_name: String = _get_tier_name(score)
	return tr("HUD_REP_FORMAT") % [score, tier_name]


func _get_tier_name(score: float) -> String:
	if score >= 80.0:
		return tr("HUD_TIER_LEGENDARY")
	if score >= 50.0:
		return tr("HUD_TIER_DESTINATION")
	if score >= 25.0:
		return tr("HUD_TIER_LOCAL_FAV")
	return tr("HUD_TIER_UNKNOWN")


func _get_tier_color(score: float) -> Color:
	for i: int in range(_TIER_THRESHOLDS.size()):
		if score >= _TIER_THRESHOLDS[i]:
			return _TIER_COLORS[i]
	return _TIER_COLORS[_TIER_COLORS.size() - 1]


func _flash_reputation_label(
	old_value: float, new_value: float
) -> void:
	if is_equal_approx(old_value, new_value):
		return
	PanelAnimator.kill_tween(_rep_arrow_tween)
	var increased: bool = new_value > old_value
	var color: Color = (
		UIThemeConstants.get_positive_color() if increased
		else UIThemeConstants.get_negative_color()
	)
	var arrow: String = " \u25B2" if increased else " \u25BC"
	var label_text: String = _format_reputation(new_value)
	_reputation_label.text = label_text + arrow
	_rep_arrow_tween = _reputation_label.create_tween()
	_rep_arrow_tween.tween_property(
		_reputation_label,
		"theme_override_colors/font_color", color,
		_REP_ARROW_FADE_IN,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_rep_arrow_tween.tween_interval(_REP_ARROW_HOLD)
	_rep_arrow_tween.tween_callback(func() -> void:
		_reputation_label.text = label_text
	)
	_rep_arrow_tween.tween_property(
		_reputation_label,
		"theme_override_colors/font_color",
		UIThemeConstants.BODY_FONT_COLOR,
		_REP_ARROW_FADE_OUT,
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


## Tracks whether ObjectiveRail currently has visible objective text. Drives the
## telegraph-card priority rule (tutorial > objective > ticker) without owning
## the rail's display surface.
func _on_objective_payload(payload: Dictionary) -> void:
	if payload.get("hidden", false):
		_objective_active = false
	else:
		var text: String = str(
			payload.get("text", payload.get("current_objective", ""))
		)
		_objective_active = not text.strip_edges().is_empty()
	_refresh_telegraph_card()


## §F-54 — HUD forwards `notification_requested` and
## `critical_notification_requested` to `toast_requested` so existing emitters
## (~50 callsites) do not need to be migrated. Empty-message swallow is
## intentional: an empty notification has no UI payload to render and the
## old in-HUD prompt path already used the same convention. The
## `_tutorial_step_active` short-circuit on the non-critical path mirrors the
## prior priority rule (tutorial steps own the foreground); the critical path
## bypasses the rule by design.
##
## ToastNotificationUI is a child of this HUD scene, so when the HUD is
## absent (MAIN_MENU, DAY_SUMMARY) `toast_requested` has no listener and the
## message drops. That mirrors the prior in-HUD prompt path's behavior — the
## reachable failure surface is unchanged by this forwarding shim. See
## docs/audits/error-handling-report.md §F-54.
func _on_notification_requested(message: String) -> void:
	if _tutorial_step_active:
		return
	if message.is_empty():
		return
	EventBus.toast_requested.emit(message, &"system", 0.0)


func _on_critical_notification_requested(message: String) -> void:
	if message.is_empty():
		return
	EventBus.toast_requested.emit(message, &"system", 0.0)


func _on_store_opened(store_id: String) -> void:
	if store_id.is_empty():
		_store_label.visible = false
		return
	var display_name: String = _get_store_display_name(store_id)
	_store_label.text = display_name
	var accent: Color = UIThemeConstants.get_store_accent(
		StringName(store_id)
	)
	_store_label.add_theme_color_override("font_color", accent)
	_store_label.visible = true


func _on_store_closed(_store_id: String) -> void:
	_store_label.visible = false


func _on_seasonal_event_started(event_id: String) -> void:
	_telegraphed_events.erase(event_id)
	_refresh_telegraph_card()
	_refresh_seasonal_event_display()


func _on_seasonal_event_ended(_event_id: String) -> void:
	_refresh_seasonal_event_display()


func _on_event_telegraphed(event_id: String, days_until: int) -> void:
	_telegraphed_events[event_id] = days_until
	_refresh_telegraph_card()


func _on_random_event_telegraphed(message: String) -> void:
	_random_event_telegraph = message
	_refresh_telegraph_card()


func _on_tutorial_step_changed_hud(step_id: String) -> void:
	_tutorial_step_active = not step_id.is_empty()
	if _tutorial_step_active:
		_telegraph_card.visible = false
		_seasonal_event_label.visible = false


func _on_tutorial_hint_ended() -> void:
	_tutorial_step_active = false
	_refresh_seasonal_event_display()
	_refresh_telegraph_card()


func _refresh_telegraph_card() -> void:
	if _tutorial_step_active:
		return
	# Overlay priority: tutorial > objective rail > ticker. The interaction
	# prompt lives on a separate CanvasLayer (layer 60) at the bottom of the
	# screen and does not overlap the top-right telegraph card.
	if _objective_active:
		_telegraph_card.visible = false
		return
	var parts: PackedStringArray = []
	if not _random_event_telegraph.is_empty():
		parts.append(_random_event_telegraph)
	if not _telegraphed_events.is_empty():
		var sys: SeasonalEventSystem = _find_seasonal_event_system()
		for event_id: String in _telegraphed_events:
			var days: int = _telegraphed_events[event_id]
			var display: String = event_id
			if sys:
				for evt: Dictionary in sys.get_announced_events():
					var def: SeasonalEventDefinition = evt.get(
						"definition", null
					) as SeasonalEventDefinition
					if def and def.id == event_id:
						display = def.name
						break
			parts.append("%s in %d day%s" % [
				display, days, "s" if days != 1 else ""
			])
	if parts.is_empty():
		_telegraph_card.visible = false
		return
	_telegraph_card.text = "[!] Coming: %s" % ", ".join(parts)
	_telegraph_card.visible = true


func _refresh_seasonal_event_display() -> void:
	if _tutorial_step_active:
		return
	var sys: SeasonalEventSystem = _find_seasonal_event_system()
	if not sys:
		_seasonal_event_label.visible = false
		return
	var active: Array[Dictionary] = sys.get_active_events()
	if active.is_empty():
		_seasonal_event_label.visible = false
		return
	var names: PackedStringArray = []
	for evt: Dictionary in active:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			names.append(def.name)
	_seasonal_event_label.text = "[S] %s" % ", ".join(names)
	_seasonal_event_label.tooltip_text = _build_seasonal_tooltip(
		active
	)
	_seasonal_event_label.visible = true


func _build_seasonal_tooltip(
	events: Array[Dictionary]
) -> String:
	var lines: PackedStringArray = []
	for evt: Dictionary in events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		var desc: String = def.name
		if not def.description.is_empty():
			desc += ": " + def.description
		lines.append(desc)
	return "\n".join(lines)


func _find_seasonal_event_system() -> SeasonalEventSystem:
	var game_world: Node = get_tree().current_scene
	if not game_world:
		return null
	var sys: Node = game_world.find_child(
		"SeasonalEventSystem", false
	)
	if sys is SeasonalEventSystem:
		return sys as SeasonalEventSystem
	return null


func _get_store_display_name(store_id: String) -> String:
	if not GameManager.data_loader:
		return store_id.capitalize()
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if store_def:
		return store_def.store_name
	return store_id.capitalize()


func _on_milestones_pressed() -> void:
	EventBus.toggle_milestones_panel.emit()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_time_display()
	_update_cash_display(_displayed_cash)
	_update_reputation_display(_last_reputation)
	_update_speed_display(_current_speed)
	_update_items_placed_display(_items_placed_count)
	_update_customers_display(_customers_active_count)
	_update_sales_today_display(_sales_today_count)
	if is_instance_valid(_close_day_button):
		_close_day_button.text = tr("HUD_CLOSE_DAY_LABEL")


func _on_build_mode_entered() -> void:
	_tween_children_alpha(_BUILD_MODE_DIM_ALPHA, Tween.EASE_OUT)


func _on_build_mode_exited() -> void:
	_tween_children_alpha(1.0, Tween.EASE_IN)


func _tween_children_alpha(target: float, tween_ease: int) -> void:
	PanelAnimator.kill_tween(_dim_tween)
	_dim_tween = create_tween()
	for child: Node in get_children():
		if child is CanvasItem:
			_dim_tween.parallel().tween_property(
				child, "modulate:a", target,
				PanelAnimator.BUILD_MODE_TRANSITION
			).set_ease(tween_ease).set_trans(
				Tween.TRANS_CUBIC
			)


## Seeds Items Placed / Customers / Sales Today counters from authoritative
## system getters so save/load and scene reload do not start from zero while
## system state is already populated.
func _seed_counters_from_systems() -> void:
	_refresh_items_placed()
	_refresh_customers_active()
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy != null:
		_sales_today_count = economy.get_items_sold_today()
	_update_sales_today_display(_sales_today_count)


func _on_inventory_changed() -> void:
	_refresh_items_placed()


func _refresh_items_placed() -> void:
	# Silent return: HUD is Tier-5 init (per docs/architecture.md), so
	# inventory_system may legitimately be null on the very first frame and
	# during headless test setup. We re-poll on every inventory_changed
	# signal anyway. See docs/audits/error-handling-report.md §J2.
	var inventory: InventorySystem = GameManager.get_inventory_system()
	if inventory == null:
		return
	var new_count: int = inventory.get_shelf_items().size()
	if new_count == _items_placed_count:
		return
	var delta: int = new_count - _items_placed_count
	_items_placed_count = new_count
	_update_items_placed_display(new_count)
	_pulse_counter(_items_placed_label, delta > 0)


func _on_customer_entered(_data: Dictionary) -> void:
	_customers_active_count += 1
	_update_customers_display(_customers_active_count)
	_pulse_counter(_customers_label, true)


func _on_customer_left(_data: Dictionary) -> void:
	_customers_active_count = maxi(_customers_active_count - 1, 0)
	_update_customers_display(_customers_active_count)
	_pulse_counter(_customers_label, false)


func _refresh_customers_active() -> void:
	# Silent return: HUD is Tier-5 init (per docs/architecture.md), so
	# customer_system may legitimately be null on the first frame and during
	# headless test setup. Re-polls on every customer_entered/left signal.
	# See docs/audits/error-handling-report.md §J2.
	var customers: CustomerSystem = GameManager.get_customer_system()
	if customers == null:
		return
	_customers_active_count = customers.get_active_customer_count()
	_update_customers_display(_customers_active_count)


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	_sales_today_count += 1
	_update_sales_today_display(_sales_today_count)
	_pulse_counter(_sales_today_label, true)


func _update_items_placed_display(count: int) -> void:
	_items_placed_label.text = tr("HUD_PLACED_FORMAT") % count


func _update_customers_display(count: int) -> void:
	_customers_label.text = tr("HUD_CUST_FORMAT") % count


func _update_sales_today_display(count: int) -> void:
	_sales_today_label.text = tr("HUD_SOLD_FORMAT") % count


func _pulse_counter(label: Label, positive: bool) -> void:
	PanelAnimator.kill_tween(_counter_scale_tweens.get(label))
	PanelAnimator.kill_tween(_counter_color_tweens.get(label))
	var color: Color = (
		UIThemeConstants.get_positive_color() if positive
		else UIThemeConstants.get_negative_color()
	)
	_counter_scale_tweens[label] = PanelAnimator.pulse_scale(
		label, _COUNTER_PULSE_SCALE, _COUNTER_PULSE_DURATION
	)
	_counter_color_tweens[label] = PanelAnimator.flash_color(
		label, color, _COUNTER_PULSE_DURATION
	)


## Switches the HUD between the legacy desktop TopBar layout (`enabled = false`)
## and the first-person corner overlay (`enabled = true`).
##
## In FP mode the heavy `TopBar` HBoxContainer is hidden, the five Day-1
## readouts (cash, time, on-shelves, customers, sold-today) are reparented to
## the HUD CanvasLayer with compact anchored offsets, and the close-day
## affordance moves to a bottom-right `F4 — Close Day` hint label. The labels
## remain the same `Label` instances, so every signal handler that already
## drives them (`_on_money_changed`, `_on_hour_changed`,
## `_update_items_placed_display`, `_update_customers_display`,
## `_update_sales_today_display`, etc.) keeps working untouched.
##
## Call from `StorePlayerBody._ready` after the body spawns so the HUD shifts
## into FP layout the moment the player camera is current.
func set_fp_mode(enabled: bool) -> void:
	if _fp_mode == enabled:
		return
	_fp_mode = enabled
	if enabled:
		_enter_fp_mode()
	else:
		_exit_fp_mode()
		_apply_state_visibility(GameManager.current_state)


func _enter_fp_mode() -> void:
	_fp_orig_indices = {
		_cash_label: _cash_label.get_index(),
		_time_label: _time_label.get_index(),
		_items_placed_label: _items_placed_label.get_index(),
		_customers_label: _customers_label.get_index(),
		_sales_today_label: _sales_today_label.get_index(),
	}
	_reparent_to_hud_root(_cash_label)
	_reparent_to_hud_root(_time_label)
	_reparent_to_hud_root(_items_placed_label)
	_reparent_to_hud_root(_customers_label)
	_reparent_to_hud_root(_sales_today_label)
	_apply_fp_anchors(_cash_label, 0.0, 0.0, 8.0, 8.0, 200.0, 36.0)
	_apply_fp_anchors(_time_label, 0.5, 0.5, -150.0, 8.0, 150.0, 36.0)
	_apply_fp_anchors(_items_placed_label, 1.0, 1.0, -200.0, 8.0, -8.0, 36.0)
	_apply_fp_anchors(_customers_label, 1.0, 1.0, -200.0, 40.0, -8.0, 68.0)
	_apply_fp_anchors(_sales_today_label, 1.0, 1.0, -200.0, 72.0, -8.0, 100.0)
	_ensure_fp_close_day_hint()
	_apply_fp_visibility_overrides()


func _exit_fp_mode() -> void:
	if is_instance_valid(_fp_close_day_hint):
		_fp_close_day_hint.hide()
	_restore_from_hud_root(_cash_label)
	_restore_from_hud_root(_time_label)
	_restore_from_hud_root(_items_placed_label)
	_restore_from_hud_root(_customers_label)
	_restore_from_hud_root(_sales_today_label)
	_fp_orig_indices.clear()
	_top_bar.show()


func _reparent_to_hud_root(label: Label) -> void:
	var current_parent: Node = label.get_parent()
	if current_parent == self:
		return
	if current_parent != null:
		current_parent.remove_child(label)
	add_child(label)


func _restore_from_hud_root(label: Label) -> void:
	if label.get_parent() == _top_bar:
		return
	if label.get_parent() != null:
		label.get_parent().remove_child(label)
	_top_bar.add_child(label)
	var idx: int = int(_fp_orig_indices.get(label, _top_bar.get_child_count() - 1))
	idx = clampi(idx, 0, _top_bar.get_child_count() - 1)
	_top_bar.move_child(label, idx)


func _apply_fp_anchors(
	label: Label,
	anchor_left: float,
	anchor_right: float,
	off_left: float,
	off_top: float,
	off_right: float,
	off_bottom: float,
) -> void:
	label.anchor_left = anchor_left
	label.anchor_right = anchor_right
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = off_left
	label.offset_top = off_top
	label.offset_right = off_right
	label.offset_bottom = off_bottom
	# Grow direction is computed from the horizontal anchors so the label
	# stays inside its corner / center band when content forces a wider
	# minimum size: right-anchored labels grow leftward, center-anchored
	# labels grow symmetrically, left-anchored labels grow rightward.
	# Without this, an ultrawide viewport plus a long localized string
	# could push a centered label off the right edge or a right-cluster
	# label off-screen past the viewport edge.
	if is_equal_approx(anchor_left, 0.5) and is_equal_approx(anchor_right, 0.5):
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elif is_equal_approx(anchor_left, 1.0) and is_equal_approx(anchor_right, 1.0):
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		label.grow_horizontal = Control.GROW_DIRECTION_END


func _ensure_fp_close_day_hint() -> void:
	if is_instance_valid(_fp_close_day_hint):
		return
	_fp_close_day_hint = Label.new()
	_fp_close_day_hint.name = "FpCloseDayHint"
	_fp_close_day_hint.text = "F4 — Close Day"
	_fp_close_day_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fp_close_day_hint.anchor_left = 1.0
	_fp_close_day_hint.anchor_right = 1.0
	_fp_close_day_hint.anchor_top = 1.0
	_fp_close_day_hint.anchor_bottom = 1.0
	_fp_close_day_hint.offset_left = -200.0
	_fp_close_day_hint.offset_top = -40.0
	_fp_close_day_hint.offset_right = -8.0
	_fp_close_day_hint.offset_bottom = -8.0
	add_child(_fp_close_day_hint)


func _apply_fp_visibility_overrides() -> void:
	_top_bar.hide()
	_seasonal_event_label.hide()
	_telegraph_card.hide()
	# Hide management-view TopBar children explicitly (not just via the parent
	# `_top_bar.hide()`) so callers reading the per-child `visible` flag observe
	# the FP-mode contract directly. is_visible_in_tree honors the parent, but
	# acceptance criteria are checked against the child's own visibility.
	_milestones_button.hide()
	_reputation_label.hide()
	_speed_button.hide()
	_cash_label.show()
	_time_label.show()
	_items_placed_label.show()
	_customers_label.show()
	_sales_today_label.show()
	if is_instance_valid(_fp_close_day_hint):
		_fp_close_day_hint.show()


## Resets transient display state for test isolation. Called by GUT tests that
## share a single HUD instance across multiple test functions via before_all().
func _reset_for_tests() -> void:
	_telegraphed_events.clear()
	_random_event_telegraph = ""
	_tutorial_step_active = false
	_objective_active = false
	_telegraph_card.visible = false
	_seasonal_event_label.visible = false
	# Clear the modal-focus ownership flag without touching the InputFocus
	# stack — pair with InputFocus._reset_for_tests() in test harnesses.
	_confirm_dialog_focus_pushed = false


func _exit_tree() -> void:
	# Free-on-quit / scene-swap path — release the dialog's CTX_MODAL frame so
	# the stack doesn't leak across tests or scene transitions.
	if _confirm_dialog_focus_pushed:
		_pop_confirm_dialog_modal_focus()
