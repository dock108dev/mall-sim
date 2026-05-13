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
## Modal-fade contract: HUD opacity drops to 0.65 over 0.15s when CTX_MODAL
## is on top of the InputFocus stack, restores to 1.0 over 0.15s on pop.
## Calibrated against `ModalDimOverlay.DIM_COLOR.a = 0.4`: the composed
## visible HUD opacity behind a modal is `0.65 × (1 - 0.4) = 0.39`, which
## reads as clearly dimmed but keeps cash and time labels legible. A prior
## pairing of `0.3 × 0.55 = 0.135` rendered the HUD near-black; both values
## must be tuned together or the regression returns.
const _MODAL_DIM_ALPHA: float = 0.65
const _MODAL_DIM_DURATION: float = 0.15
const _COUNTER_PULSE_SCALE: float = 1.08
const _COUNTER_PULSE_DURATION: float = PanelAnimator.FEEDBACK_PULSE_DURATION

## FP-mode HUD typography contract: the top-right cluster (On Shelves,
## Customers, Sold Today) reads as compact secondary info — 14 px at 60 %
## white — so it does not feel like a debug overlay. Cash (top-left) and
## Day/Time (top-center) are primary info — 18 px at 100 % white — so the
## within-HUD hierarchy is parseable at a glance. Both tiers stay visually
## distinct from toast notifications (16 px, brighter) and modal titles
## (20–22 px, full contrast), which the BRAINDUMP layout spec ranks above
## the persistent HUD readouts.
const _FP_STAT_FONT_SIZE: int = 14
const _FP_PRIMARY_FONT_SIZE: int = 18
const _FP_STAT_FONT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const _FP_PRIMARY_FONT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

## Day-1 onboarding zero-state hint copy. Condition A (empty shelves) wins
## over Condition B (no customers): with no stock the player can't attract
## customers anyway, so the actionable hint takes precedence.
const _HINT_STOCK_FLOOR: String = "Stock shelves to open the lane."
const _HINT_AWAITING_CUSTOMER: String = "Waiting for the first customer…"

## §F-C1 — Dim the FP "F4 — Close Day" hint while the beta day-1 chain is
## still incomplete; restore full opacity (and the active-state stylebox)
## once `can_close_day` flips true. Driven from `objective_changed` and
## `hour_changed` so the hint tracks both the chain and the time gate.
const _CLOSE_DAY_HINT_DIM_ALPHA: float = 0.4

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
var _modal_dim_tween: Tween
## True iff the most recent context_changed put CTX_MODAL on top. Drives
## the HUD modal-fade tween — flips only on the boolean transition so an
## intra-modal context_changed (e.g. nested modal stack) does not retrigger
## the fade. Public via `is_modal_dim_active()` for tests and the debug
## overlay; do not mutate from outside the HUD.
var _modal_dim_active: bool = false
var _close_day_button: Button
var _hub_back_button: Button
var _items_placed_count: int = 0
## Cumulative count of customers served (i.e. completed a sale) today. Resets
## on `EventBus.day_started` and increments on `EventBus.customer_purchased`.
## This is intentionally distinct from "active customers in store" — the HUD
## reports the throughput metric the BRAINDUMP Day-1 loop calls for.
var _customers_served_today_count: int = 0
## Currently-active customer count, driven by `customer_spawned` /
## `customer_left`. Distinct from `_customers_served_today_count` (a
## monotonically increasing throughput counter) — this is the live "are
## any shoppers in the store right now?" gauge that drives the zero-state
## hint. Clamped at zero.
var _active_customer_count: int = 0
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
## FP-mode bottom-bar sentence slot. The scene-tree `_zero_state_hint` lives
## at top-center where it would crowd the reparented `_time_label`; in FP
## mode that hint is hidden and its copy is mirrored to this label at
## bottom-center, pairing with `_fp_close_day_hint` on the same row to
## fulfill the BRAINDUMP "bottom-bar = sentence + control hint" spec.
var _fp_sentence_label: Label
## §F-L3 — When set, overrides the InventorySystem-derived "On Shelves"
## count for the beta day-1 loop. -1 means "no override; read from
## inventory as usual." Set via `EventBus.beta_shelf_count_changed`.
var _beta_shelf_count_override: int = -1
## Beta day-1 back-room delivery quantity, mirrored from
## `EventBus.beta_backroom_count_changed`. Has no InventorySystem backing —
## the Day-1 chain is the single writer — so a plain int suffices instead of
## the override sentinel pattern used for `_beta_shelf_count_override`.
var _beta_backroom_count: int = 0

@onready var _top_bar: HBoxContainer = $TopBar
@onready var _cash_label: Label = $TopBar/CashLabel
@onready var _time_label: Label = $TopBar/TimeLabel
@onready var _items_placed_label: Label = $TopBar/ItemsPlacedLabel
@onready var _back_room_label: Label = $TopBar/BackRoomLabel
@onready var _customers_label: Label = $TopBar/CustomersLabel
@onready var _sales_today_label: Label = $TopBar/SalesTodayLabel
@onready var _speed_button: Button = $TopBar/SpeedButton
@onready var _reputation_label: Label = $TopBar/ReputationLabel
@onready var _store_label: Label = $TopBar/StoreLabel
@onready var _telegraph_card: Label = $TelegraphCard
@onready var _milestones_button: Button = $TopBar/MilestonesButton
@onready var _close_day_preview: CanvasLayer = $CloseDayPreview
@onready var _zero_state_hint: Label = $ZeroStateHint
## §F-L2 — Carry-state label lives on its own CanvasLayer (layer 41) so it
## renders above the ObjectiveRail (layer 40); a child Label of the HUD
## CanvasLayer (layer 30) was occluded by the rail.
@onready var _beta_carry_label: Label = $CarryHUD/BetaCarryLabel


func _ready() -> void:
	_store_label.visible = false
	_telegraph_card.visible = false
	_speed_button.visible = false

	_connect_signals()

	_create_close_day_button()
	_create_hub_back_button()
	_wire_close_day_preview()

	_update_cash_display(_displayed_cash)
	_update_reputation_display(_last_reputation)
	_update_speed_display(_current_speed)
	_refresh_time_display()
	_seed_counters_from_systems()
	_apply_state_visibility(GameManager.current_state)
	_refresh_zero_state_hint()


## Wires the HUD to EventBus, InputFocus, and button signals. Each connection
## is guarded with `is_connected` so that a second HUD instance entering the
## tree (test fixtures, editor hot-reload) cannot double the handler list on
## any shared autoload signal. Matches the `_connect_signals` pattern in
## `TutorialContextSystem`.
func _connect_signals() -> void:
	if not EventBus.objective_changed.is_connected(_on_objective_payload):
		EventBus.objective_changed.connect(_on_objective_payload)
	if not EventBus.objective_updated.is_connected(_on_objective_payload):
		EventBus.objective_updated.connect(_on_objective_payload)
	if not EventBus.notification_requested.is_connected(_on_notification_requested):
		EventBus.notification_requested.connect(_on_notification_requested)
	if not EventBus.critical_notification_requested.is_connected(
		_on_critical_notification_requested
	):
		EventBus.critical_notification_requested.connect(
			_on_critical_notification_requested
		)
	if not EventBus.reputation_changed.is_connected(_on_reputation_changed):
		EventBus.reputation_changed.connect(_on_reputation_changed)
	if not EventBus.store_opened.is_connected(_on_store_opened):
		EventBus.store_opened.connect(_on_store_opened)
	if not EventBus.store_closed.is_connected(_on_store_closed):
		EventBus.store_closed.connect(_on_store_closed)
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if not EventBus.money_changed.is_connected(_on_money_changed):
		EventBus.money_changed.connect(_on_money_changed)
	if not EventBus.speed_changed.is_connected(_on_speed_changed):
		EventBus.speed_changed.connect(_on_speed_changed)
	if not EventBus.random_event_telegraphed.is_connected(_on_random_event_telegraphed):
		EventBus.random_event_telegraphed.connect(_on_random_event_telegraphed)
	if not EventBus.locale_changed.is_connected(_on_locale_changed):
		EventBus.locale_changed.connect(_on_locale_changed)
	if not EventBus.build_mode_entered.is_connected(_on_build_mode_entered):
		EventBus.build_mode_entered.connect(_on_build_mode_entered)
	if not EventBus.build_mode_exited.is_connected(_on_build_mode_exited):
		EventBus.build_mode_exited.connect(_on_build_mode_exited)
	if not EventBus.store_entered.is_connected(_on_store_entered_hub):
		EventBus.store_entered.connect(_on_store_entered_hub)
	if not EventBus.store_exited.is_connected(_on_store_exited_hub):
		EventBus.store_exited.connect(_on_store_exited_hub)
	if not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)
	if not EventBus.beta_carry_changed.is_connected(_on_beta_carry_changed):
		EventBus.beta_carry_changed.connect(_on_beta_carry_changed)
	if not EventBus.beta_shelf_count_changed.is_connected(_on_beta_shelf_count_changed):
		EventBus.beta_shelf_count_changed.connect(_on_beta_shelf_count_changed)
	if not EventBus.beta_backroom_count_changed.is_connected(
		_on_beta_backroom_count_changed
	):
		EventBus.beta_backroom_count_changed.connect(_on_beta_backroom_count_changed)
	if not EventBus.customer_purchased.is_connected(_on_customer_purchased_hud):
		EventBus.customer_purchased.connect(_on_customer_purchased_hud)
	if not EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.connect(_on_item_sold)
	if not EventBus.customer_spawned.is_connected(_on_customer_spawned_hud):
		EventBus.customer_spawned.connect(_on_customer_spawned_hud)
	if not EventBus.customer_left.is_connected(_on_customer_left_hud):
		EventBus.customer_left.connect(_on_customer_left_hud)
	# Modal opens/closes flip the zero-state hint off/on without changing the
	# underlying stock or customer counts; subscribing to context_changed keeps
	# the gating reactive without polling each frame.
	if not InputFocus.context_changed.is_connected(_on_input_focus_changed):
		InputFocus.context_changed.connect(_on_input_focus_changed)
	if not _milestones_button.pressed.is_connected(_on_milestones_pressed):
		_milestones_button.pressed.connect(_on_milestones_pressed)
	if not _speed_button.pressed.is_connected(_on_speed_button_pressed):
		_speed_button.pressed.connect(_on_speed_button_pressed)
	if not EventBus.game_state_changed.is_connected(_on_game_state_changed):
		EventBus.game_state_changed.connect(_on_game_state_changed)
	if not EventBus.tutorial_step_changed.is_connected(_on_tutorial_step_changed_hud):
		EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed_hud)
	if not EventBus.tutorial_completed.is_connected(_on_tutorial_hint_ended):
		EventBus.tutorial_completed.connect(_on_tutorial_hint_ended)
	if not EventBus.tutorial_skipped.is_connected(_on_tutorial_hint_ended):
		EventBus.tutorial_skipped.connect(_on_tutorial_hint_ended)
	if not EventBus.run_state_changed.is_connected(_on_run_state_changed):
		EventBus.run_state_changed.connect(_on_run_state_changed)
	if not EventBus.first_sale_completed.is_connected(_on_first_sale_completed_hud):
		EventBus.first_sale_completed.connect(_on_first_sale_completed_hud)


func _on_day_started(day: int) -> void:
	_current_day = day
	_random_event_telegraph = ""
	_sales_today_count = 0
	_customers_served_today_count = 0
	_active_customer_count = 0
	_update_sales_today_display(_sales_today_count)
	_update_customers_display(_customers_served_today_count)
	_refresh_time_display()
	_refresh_items_placed()
	_seed_cash_from_economy()
	_apply_state_visibility(GameManager.current_state)
	_refresh_zero_state_hint()


## Snaps the cash display to `EconomySystem.get_cash()` when available.
##
## Day 1 entry path: `EconomySystem.initialize()` writes player_cash via
## `_apply_state` and does not emit `money_changed`, so a HUD that listens
## only on `money_changed` would stay at $0.00 until the first transaction.
## `day_started(1)` fires after Tier-1 init in `apply_pending_session_state`,
## so seeding here guarantees the cash readout reflects starting_cash before
## the player sees the store. The snap (no count-up tween) avoids a
## misleading `0 → starting_cash` crawl every time a new day begins.
##
## §F-103 — Silent return on null EconomySystem matches the
## `_seed_counters_from_systems` Tier-5 init pattern (mirrors §J2 / §F-69):
## unit test fixtures construct the HUD without a world scene and
## `money_changed` is the only path they exercise. The kpi_strip seeding
## helper §F-115 mirrors this pattern.
func _seed_cash_from_economy() -> void:
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy == null:
		return
	var cash: float = economy.get_cash()
	if (
		is_equal_approx(_displayed_cash, cash)
		and is_equal_approx(_target_cash, cash)
	):
		return
	PanelAnimator.kill_tween(_cash_count_tween)
	_displayed_cash = cash
	_target_cash = cash
	_update_cash_display(cash)


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour
	_refresh_time_display()
	_refresh_close_day_hint_state()


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


func _on_run_state_changed() -> void:
	if is_instance_valid(_close_day_button):
		_close_day_button.tooltip_text = ""


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
	if state != GameManager.State.STORE_VIEW and state != GameManager.State.GAMEPLAY:
		return
	if not _beta_close_day_allowed():
		# Beta day-1 has its own gating chain; refuse with the grounded
		# reason so the player understands why F4 / the button did nothing.
		return
	_open_close_day_preview()


## §F-C1 — Returns true when the beta day-1 controller either is absent
## (production gameplay) or reports `can_interact_day_end()`. Otherwise emits
## a refusal toast using the controller's grounded reason and returns false.
## Centralizes the early-close guard so the F4 keybind, the top-bar button,
## and any future trigger all funnel through the same check.
func _beta_close_day_allowed() -> bool:
	if _beta_close_day_allowed_quiet():
		return true
	var reason: String = _beta_close_day_reason()
	if reason.is_empty():
		reason = "Still too early to close. Finish out the shift first."
	EventBus.toast_requested.emit(reason, &"system", 3.0)
	return false


## Non-toasting variant for HUD state updates (dim the F4 hint without
## spamming a toast every time the chain advances). `BetaDayOneController`
## is the typed `class_name` autoload-style controller — the typed access
## (vs. `has_method` + `call`) makes signature renames fail at parse time.
## See §EH-23.
func _beta_close_day_allowed_quiet() -> bool:
	var controller: BetaDayOneController = _beta_day_one_controller()
	if controller == null:
		return true
	return controller.can_interact_day_end()


func _beta_close_day_reason() -> String:
	var controller: BetaDayOneController = _beta_day_one_controller()
	if controller == null:
		return ""
	return controller.close_day_disabled_reason()


## Returns null in unit-test fixtures that don't add the controller to the
## scene tree; production beta path always group-registers the controller in
## `BetaDayOneController._ready` (`beta_day_one_controller.gd`). See §EH-23.
func _beta_day_one_controller() -> BetaDayOneController:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	return node as BetaDayOneController


## Opens the dry-run preview modal. The preview's Confirm button is the only
## path that emits day_close_requested from the in-store HUD; the preview
## script handles the emit itself.
##
## The fallback emit (preview missing) is loud on purpose: hud.tscn ships a
## CloseDayPreview child, so reaching the fallback means the scene was edited
## without the modal. The day still closes — but the wiring regression is
## logged via push_error so CI's stderr `^ERROR:` scan
## (.github/workflows/validate.yml) fails the build instead of letting a
## silently-unwired close-day modal ship. See
## docs/audits/error-handling-report.md §EH-09.
func _open_close_day_preview() -> void:
	if not is_instance_valid(_close_day_preview):
		push_error(
			"HUD._open_close_day_preview: CloseDayPreview child missing; "
			+ "skipping preview modal and closing day directly."
		)
		EventBus.day_close_requested.emit()
		return
	_close_day_preview.show_preview()


## The preview ships with `hud.tscn`, but a unit test that constructs the HUD
## without the packed scene (or a future scene variant that omits it) would
## otherwise crash on the setter call. `_open_close_day_preview` already
## escalates with `push_warning` when the preview child is missing at click
## time, so a silently-unwired modal still raises a visible signal at use.
func _wire_close_day_preview() -> void:
	if not is_instance_valid(_close_day_preview):
		return
	_close_day_preview.set_snapshot_callback(_get_active_store_snapshot)


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
			_back_room_label.visible = false
			_customers_label.visible = false
			_sales_today_label.visible = false
			# MALL_OVERVIEW retains the reputation label; only STORE_VIEW
			# hides it. Set explicitly to avoid inheriting the hidden state
			# when transitioning from STORE_VIEW.
			_reputation_label.visible = true
			_speed_button.visible = false
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
			# BRAINDUMP Rule 3: 'Top Left: Money only'. In beta mode the
			# right-side BetaTodayStatsPanel surfaces On Shelves / Back Room /
			# Sold Today, so the redundant TopBar copies are hidden. Non-beta
			# runs still need them in the TopBar (no right-side panel exists
			# outside the beta loop).
			var stats_panel_active: bool = _beta_mode_active()
			_items_placed_label.visible = not stats_panel_active
			_back_room_label.visible = not stats_panel_active
			_sales_today_label.visible = not stats_panel_active
			_store_label.visible = false
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
	_refresh_zero_state_hint()


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
		get_viewport().set_input_as_handled()
		if not _beta_close_day_allowed():
			return
		_open_close_day_preview()
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
	_refresh_close_day_hint_state()


func _refresh_close_day_hint_state() -> void:
	if not is_instance_valid(_fp_close_day_hint):
		return
	var allowed: bool = _beta_close_day_allowed_quiet()
	var alpha: float = 1.0 if allowed else _CLOSE_DAY_HINT_DIM_ALPHA
	_fp_close_day_hint.modulate = Color(1.0, 1.0, 1.0, alpha)


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


func _on_random_event_telegraphed(message: String) -> void:
	_random_event_telegraph = message
	_refresh_telegraph_card()


func _on_tutorial_step_changed_hud(step_id: String) -> void:
	_tutorial_step_active = not step_id.is_empty()
	if _tutorial_step_active:
		_telegraph_card.visible = false


func _on_tutorial_hint_ended() -> void:
	_tutorial_step_active = false
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
	if _random_event_telegraph.is_empty():
		_telegraph_card.visible = false
		return
	_telegraph_card.text = "[!] Coming: %s" % _random_event_telegraph
	_telegraph_card.visible = true


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
	_update_customers_display(_customers_served_today_count)
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


## Seeds Items Placed / Customers Served Today / Sales Today counters from
## authoritative system getters so save/load and scene reload do not start
## from zero while system state is already populated.
##
## Customers-served-today has no persistent backing system — it is reset on
## `day_started` and incremented on `customer_purchased`. The Day-1 loop never
## reloads mid-day, so seeding from zero matches the contract.
func _seed_counters_from_systems() -> void:
	_refresh_items_placed()
	_update_back_room_display(_beta_backroom_count)
	_update_customers_display(_customers_served_today_count)
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy != null:
		_sales_today_count = economy.get_items_sold_today()
	_update_sales_today_display(_sales_today_count)


func _on_inventory_changed() -> void:
	_refresh_items_placed()


func _refresh_items_placed() -> void:
	# §F-L3 — when the beta override is set, ignore InventorySystem and
	# show the override value. Beta day-1 doesn't push items through the
	# real inventory system; the override exists so the visible
	# stocked-items count matches the player's action.
	if _beta_shelf_count_override >= 0:
		if _beta_shelf_count_override == _items_placed_count:
			return
		var override_delta: int = _beta_shelf_count_override - _items_placed_count
		_items_placed_count = _beta_shelf_count_override
		_update_items_placed_display(_items_placed_count)
		_pulse_counter(_items_placed_label, override_delta > 0)
		_refresh_zero_state_hint()
		return
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
	_refresh_zero_state_hint()


## §F-L2 — Carry HUD wiring. The label lives on its own `CarryHUD`
## CanvasLayer (layer 41) authored in `hud.tscn`, so it renders above the
## ObjectiveRail (layer 40) instead of being occluded by it. Empty text
## hides the label.
func _on_beta_carry_changed(text: String) -> void:
	if not is_instance_valid(_beta_carry_label):
		return
	if text.strip_edges().is_empty():
		_beta_carry_label.text = ""
		_beta_carry_label.visible = false
		return
	_beta_carry_label.text = "Carrying: %s" % text
	_beta_carry_label.visible = true


func _on_beta_shelf_count_changed(count: int) -> void:
	_beta_shelf_count_override = max(0, count)
	_refresh_items_placed()


func _on_beta_backroom_count_changed(count: int) -> void:
	var clamped: int = max(0, count)
	if clamped == _beta_backroom_count:
		return
	var delta: int = clamped - _beta_backroom_count
	_beta_backroom_count = clamped
	_update_back_room_display(_beta_backroom_count)
	_pulse_counter(_back_room_label, delta > 0)


## Tracks live shopper presence so the zero-state hint can flip between the
## "stock the floor" and "waiting for customers" copy. Independent from the
## served-today throughput counter.
func _on_customer_spawned_hud(_customer: Node) -> void:
	_active_customer_count += 1
	_refresh_zero_state_hint()


func _on_customer_left_hud(_customer_data: Dictionary) -> void:
	_active_customer_count = maxi(_active_customer_count - 1, 0)
	_refresh_zero_state_hint()


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	_refresh_zero_state_hint()
	_apply_modal_dim(new_ctx == InputFocus.CTX_MODAL)


## Fades direct CanvasItem children of the HUD CanvasLayer to the modal-dim
## alpha (0.65) when a modal owns InputFocus, restoring to full opacity on
## pop. Boolean-transition gated so nested modal context_changed events do
## not restart the tween. CanvasLayer itself has no `modulate`, so the fade
## walks the children — this matches the build-mode dim pattern.
func _apply_modal_dim(modal_now: bool) -> void:
	if modal_now == _modal_dim_active:
		return
	_modal_dim_active = modal_now
	var target: float = _MODAL_DIM_ALPHA if modal_now else 1.0
	PanelAnimator.kill_tween(_modal_dim_tween)
	_modal_dim_tween = create_tween()
	_modal_dim_tween.set_parallel(true)
	for child: Node in get_children():
		if child is CanvasItem:
			_modal_dim_tween.tween_property(
				child, "modulate:a", target, _MODAL_DIM_DURATION
			)


## Public read of the current modal-dim state for the debug overlay and
## GUT tests. True iff the HUD's CanvasItem children are tweening toward —
## or settled at — the modal-dim alpha.
func is_modal_dim_active() -> bool:
	return _modal_dim_active


## Day-1 onboarding hint: surfaces the next-action copy when the loop is at
## a zero state (no stock or no customers). Hides itself outside STORE_VIEW
## and while a modal owns focus so it doesn't compete with checkout, the
## inventory panel, or the day-summary screen.
##
## In FP mode the scene-tree top-center `_zero_state_hint` is always hidden
## (its position collides with the reparented `_time_label`) and the same
## copy is mirrored to `_fp_sentence_label` at bottom-center.
func _refresh_zero_state_hint() -> void:
	var hint_text: String = ""
	var should_show: bool = false
	if not _beta_mode_active():
		var state: GameManager.State = GameManager.current_state
		var in_store: bool = (
			state == GameManager.State.STORE_VIEW
			or state == GameManager.State.GAMEPLAY
		)
		if in_store and InputFocus.current() != InputFocus.CTX_MODAL:
			if _items_placed_count <= 0:
				hint_text = _HINT_STOCK_FLOOR
				should_show = true
			elif _active_customer_count <= 0:
				hint_text = _HINT_AWAITING_CUSTOMER
				should_show = true
	if _fp_mode:
		if is_instance_valid(_zero_state_hint):
			_zero_state_hint.visible = false
		if is_instance_valid(_fp_sentence_label):
			_fp_sentence_label.text = hint_text
			_fp_sentence_label.visible = should_show
		return
	if is_instance_valid(_fp_sentence_label):
		_fp_sentence_label.visible = false
	if not is_instance_valid(_zero_state_hint):
		return
	if should_show:
		_zero_state_hint.text = hint_text
	_zero_state_hint.visible = should_show


## Increments the customers-served-today counter when a sale completes.
## Driven by `EventBus.customer_purchased` (sale-confirmed signal) rather
## than a broader customer-departed event so non-sale outcomes (browse,
## walk-out) do not inflate the counter. Resets on `day_started`.
func _on_customer_purchased_hud(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName,
) -> void:
	_customers_served_today_count += 1
	_update_customers_display(_customers_served_today_count)
	_pulse_counter(_customers_label, true)


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	_sales_today_count += 1
	_update_sales_today_display(_sales_today_count)
	_pulse_counter(_sales_today_label, true)


func _update_items_placed_display(count: int) -> void:
	_items_placed_label.text = tr("HUD_PLACED_FORMAT") % count


func _update_back_room_display(count: int) -> void:
	_back_room_label.text = tr("HUD_BACKROOM_FORMAT") % count


func _update_customers_display(count: int) -> void:
	_customers_label.text = tr("HUD_CUST_FORMAT") % count


func _update_sales_today_display(count: int) -> void:
	_sales_today_label.text = tr("HUD_SOLD_FORMAT") % count


## Plays the counter-change feedback animation: a brief scale pulse and a
## same-duration color flash, run in parallel via two independent Tweens.
##
## Two Tweens (instead of `PanelAnimator.pulse_scale` + `PanelAnimator.flash_color`)
## are required: those helpers register themselves under a shared meta key on
## the target node, so calling them back-to-back makes the second helper kill
## the first before it ticks. Two `label.create_tween()` calls bypass the meta
## entirely and animate disjoint properties (`scale` vs. `modulate`), so they
## coexist for the full pulse window.
##
## The scale/modulate identity reset before each pulse covers the rapid-
## successive-update path (multiple sales within the pulse duration): killing
## a mid-flight Tween otherwise leaves the label at an intermediate scale or
## tinted modulate, which over many updates would visibly drift.
func _pulse_counter(label: Label, positive: bool) -> void:
	var prev_scale: Tween = _counter_scale_tweens.get(label) as Tween
	if prev_scale and prev_scale.is_valid():
		prev_scale.kill()
	var prev_color: Tween = _counter_color_tweens.get(label) as Tween
	if prev_color and prev_color.is_valid():
		prev_color.kill()
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	var color: Color = (
		UIThemeConstants.get_positive_color() if positive
		else UIThemeConstants.get_negative_color()
	)
	var dur: float = _COUNTER_PULSE_DURATION
	var scale_tween: Tween = label.create_tween()
	scale_tween.tween_property(
		label, "scale",
		Vector2(_COUNTER_PULSE_SCALE, _COUNTER_PULSE_SCALE),
		dur * 0.4,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(
		label, "scale", Vector2.ONE, dur * 0.6,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_counter_scale_tweens[label] = scale_tween
	var color_tween: Tween = label.create_tween()
	color_tween.tween_property(
		label, "modulate", color, dur * 0.3,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	color_tween.tween_property(
		label, "modulate", Color.WHITE, dur * 0.7,
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_counter_color_tweens[label] = color_tween


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
	EventBus.fp_mode_changed.emit(enabled)


func _enter_fp_mode() -> void:
	_fp_orig_indices = {
		_cash_label: _cash_label.get_index(),
		_time_label: _time_label.get_index(),
		_items_placed_label: _items_placed_label.get_index(),
		_back_room_label: _back_room_label.get_index(),
		_customers_label: _customers_label.get_index(),
		_sales_today_label: _sales_today_label.get_index(),
	}
	_reparent_to_hud_root(_cash_label)
	_reparent_to_hud_root(_time_label)
	_reparent_to_hud_root(_items_placed_label)
	_reparent_to_hud_root(_back_room_label)
	_reparent_to_hud_root(_customers_label)
	_reparent_to_hud_root(_sales_today_label)
	_apply_fp_anchors(_cash_label, 0.0, 0.0, 8.0, 8.0, 200.0, 36.0)
	_apply_fp_anchors(_time_label, 0.5, 0.5, -150.0, 8.0, 150.0, 36.0)
	# Back Room sits directly below On Shelves so the two complementary
	# inventory readouts read as a paired group, with Customers / Sold
	# Today below them.
	_apply_fp_anchors(_items_placed_label, 1.0, 1.0, -200.0, 8.0, -8.0, 36.0)
	_apply_fp_anchors(_back_room_label, 1.0, 1.0, -200.0, 40.0, -8.0, 68.0)
	_apply_fp_anchors(_customers_label, 1.0, 1.0, -200.0, 72.0, -8.0, 100.0)
	_apply_fp_anchors(_sales_today_label, 1.0, 1.0, -200.0, 104.0, -8.0, 132.0)
	_apply_fp_typography()
	_ensure_fp_close_day_hint()
	_ensure_fp_sentence_label()
	_apply_fp_visibility_overrides()
	_refresh_zero_state_hint()


func _exit_fp_mode() -> void:
	if is_instance_valid(_fp_close_day_hint):
		_fp_close_day_hint.hide()
	if is_instance_valid(_fp_sentence_label):
		_fp_sentence_label.hide()
	_clear_fp_typography()
	_restore_from_hud_root(_cash_label)
	_restore_from_hud_root(_time_label)
	_restore_from_hud_root(_items_placed_label)
	_restore_from_hud_root(_back_room_label)
	_restore_from_hud_root(_customers_label)
	_restore_from_hud_root(_sales_today_label)
	_fp_orig_indices.clear()
	_top_bar.show()


## Applies the FP-mode size/color contract: cash + time get the primary
## treatment (18 px, full white), the three top-right stats get the
## secondary treatment (14 px, 60 % white). Theme-color overrides are used
## (not modulate) so the dim does not stack with the modal-fade tween or
## the per-counter pulse — both of which animate `modulate`.
func _apply_fp_typography() -> void:
	for primary: Label in [_cash_label, _time_label]:
		primary.add_theme_font_size_override("font_size", _FP_PRIMARY_FONT_SIZE)
		primary.add_theme_color_override("font_color", _FP_PRIMARY_FONT_COLOR)
	for stat: Label in [
		_items_placed_label, _back_room_label,
		_customers_label, _sales_today_label,
	]:
		stat.add_theme_font_size_override("font_size", _FP_STAT_FONT_SIZE)
		stat.add_theme_color_override("font_color", _FP_STAT_FONT_COLOR)


func _clear_fp_typography() -> void:
	for lbl: Label in [
		_cash_label, _time_label,
		_items_placed_label, _back_room_label,
		_customers_label, _sales_today_label,
	]:
		lbl.remove_theme_font_size_override("font_size")
		lbl.remove_theme_color_override("font_color")


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


## The FP close-day hint is the sole bottom-right "controls block" allowed by
## the BRAINDUMP layout spec. The ObjectiveRail (autoload CanvasLayer at layer
## 40, content strip y ∈ [H−68, H]) carries the per-step input affordance for
## every other action — including "Press I to open the inventory panel" on
## Day 1 — so an always-on Inventory hint here would duplicate the rail's
## key chip. The hint's bottom edge sits at −72 to leave a 4 px gap above
## the rail's 68 px footprint, and the right-cluster x range (W−200..W−8)
## stays clear of the centered InteractionPrompt (W/2 ± 120) at 1280 px wide
## and above. Close-day stays here because no rail step on days other than
## Day 1's terminal step references F4.
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
	_fp_close_day_hint.offset_top = -104.0
	_fp_close_day_hint.offset_right = -8.0
	_fp_close_day_hint.offset_bottom = -72.0
	# clip_text guards against narrow viewports or future longer localized
	# strings pushing the right edge off-screen past the W−8 anchor.
	_fp_close_day_hint.clip_text = true
	add_child(_fp_close_day_hint)


## The FP bottom-bar sentence: pairs with `_fp_close_day_hint` on the same
## bottom row to satisfy the BRAINDUMP `bottom-bar = sentence + control hint`
## spec. Sits above the ObjectiveRail's AccentBand (top edge at y=-148) so
## it does not collide with the rail content on layer 40. Center-anchored
## with symmetric grow direction so a long localized hint stays within the
## viewport on ultrawide aspect ratios. Modulate at 0.85 alpha keeps the
## sentence subdued vs. primary cash/time (full white) but readable over
## the store's brightest and darkest background zones.
func _ensure_fp_sentence_label() -> void:
	if is_instance_valid(_fp_sentence_label):
		return
	_fp_sentence_label = Label.new()
	_fp_sentence_label.name = "FpSentenceLabel"
	_fp_sentence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fp_sentence_label.anchor_left = 0.5
	_fp_sentence_label.anchor_right = 0.5
	_fp_sentence_label.anchor_top = 1.0
	_fp_sentence_label.anchor_bottom = 1.0
	_fp_sentence_label.offset_left = -250.0
	_fp_sentence_label.offset_top = -184.0
	_fp_sentence_label.offset_right = 250.0
	_fp_sentence_label.offset_bottom = -156.0
	_fp_sentence_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fp_sentence_label.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_fp_sentence_label.clip_text = true
	_fp_sentence_label.visible = false
	add_child(_fp_sentence_label)


func _apply_fp_visibility_overrides() -> void:
	_top_bar.hide()
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
	_back_room_label.show()
	_customers_label.show()
	_sales_today_label.show()
	if is_instance_valid(_fp_close_day_hint):
		_fp_close_day_hint.show()
		_refresh_close_day_hint_state()


## Resets transient display state for test isolation. Called by GUT tests that
## share a single HUD instance across multiple test functions via before_all().
func _reset_for_tests() -> void:
	_random_event_telegraph = ""
	_tutorial_step_active = false
	_objective_active = false
	_telegraph_card.visible = false
	_active_customer_count = 0
	_items_placed_count = 0
	if is_instance_valid(_zero_state_hint):
		_zero_state_hint.visible = false
	if is_instance_valid(_fp_sentence_label):
		_fp_sentence_label.visible = false
	PanelAnimator.kill_tween(_modal_dim_tween)
	_modal_dim_tween = null
	_modal_dim_active = false
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 1.0


func _beta_mode_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return not tree.get_nodes_in_group("beta_day_one_controller").is_empty()
