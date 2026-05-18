# gdlint:disable=max-file-lines
class_name BetaDayOneController
extends Node

const EVENTS_PATH: String = "res://game/content/beta/events/customer_events.json"
const DAY_PATHS: Dictionary = {
	1: "res://game/content/beta/days/day_01.json",
	2: "res://game/content/beta/days/day_02.json",
}
const TARGET_BETA_DAYS: int = 2
const TARGET_EVENTS_PER_DAY: int = 3
## Mirrors `DataLoader.MAX_JSON_FILE_BYTES`. The beta content loader walks
## res:// paths only (read-only on shipped builds) so the practical exposure
## is content-author error, not user tampering — but matching the project-
## wide cap keeps a runaway content file from being silently parsed.
const MAX_JSON_FILE_BYTES: int = 1048576

## Linear Day-1 objective chain. One source of truth: every gating, prompt,
## time-advance, and close-day check reads from `_stage` and `_objectives`.
## Adding a stage means appending an entry to `_objectives` — gating,
## time-advance, and close-day eligibility all derive from this table.
##
## Tone rule: objective text is grounded retail-shift language only. No
## "odd" / "strange" / "mysterious" / "anomaly" / "secret" — the player
## decides what's weird; the UI doesn't announce it. The console stack
## (BetaHiddenClue) is ambient flavor: always interactable, never the
## active objective, doesn't advance the chain.
## Pre-chain note phase. Used for later-day Vic notes; Day 1 now skips this
## gate and starts directly at STAGE_TALK_TO_CUSTOMER so the tutorial's first
## actionable beat is visible immediately.
const STAGE_VIC_NOTE: StringName = &"vic_note"
const STAGE_TRAINING_TALK_MANAGER: StringName = &"training_talk_manager"
const STAGE_TRAINING_CHECK_REGISTER: StringName = &"training_check_register"
const STAGE_TRAINING_BACK_ROOM: StringName = &"training_back_room_inventory"
const STAGE_TRAINING_STOCK_SHELF: StringName = &"training_stock_shelf"
const STAGE_TRAINING_PRACTICE_CUSTOMER: StringName = &"training_practice_customer"
const STAGE_TRAINING_OPEN_STORE: StringName = &"training_open_store"
const STAGE_TALK_TO_CUSTOMER: StringName = &"talk_to_customer"
const STAGE_STOCK_SHELF: StringName = &"stock_shelf"
const STAGE_BACK_ROOM_INVENTORY: StringName = &"back_room_inventory"
const STAGE_END_DAY: StringName = &"end_day"

## In-game minute at which close-day's time gate unlocks. The chain's
## time costs are sized to land at or past this when the player completes
## every required objective, so the gate is rarely the limiting factor —
## it's a backstop against close-at-9-AM regressions.
const _CLOSE_TIME_MINUTES: float = 17.0 * 60.0  # 5:00 PM

## Day-1 back-room delivery quantity. Single source of truth for both the
## post-pickup HUD readout (`Back Room: 5`) and the shelf-stocking spawn
## count, so the inventory pair stays complementary: pickup sets back-room
## to this value with on-shelves at 0, then stocking flips them.
const _BACKROOM_DELIVERY_QUANTITY: int = 5

const _OBJECTIVE_UNLOCK_GRANTS: Dictionary = {
	"talk_to_customer": ["employee_register_access"],
	"stock_shelf": ["employee_stocking_trained"],
}
const _DAY_ONE_CLOSE_UNLOCK_GRANT: StringName = &"employee_closing_certified"
const _REGISTER_UNLOCK_GRANT: StringName = &"employee_register_access"

## Sub-fixture clutter that's hidden inside the beta scope so the room reads
## as a small store rather than a full retail environment. CartRackLeft /
## CartRackRight stay visible (added to `_BETA_KEEP_ROOT_NODES`) so the
## player has clear shelf landmarks; what stays here is loose-prop noise
## (atmosphere props, release wall, holds, testing stations) that doesn't
## contribute to Day-1 readability.
const _HIDDEN_NOISE_PATHS: Array[String] = [
	"new_console_display",
	"poster_slot",
	"delivery_manifest",
	"release_notes_clipboard",
	"employee_area",
	"StoreAtmosphereProps",
	"new_release_wall",
	"old_gen_shelf",
	"hold_shelf",
	"testing_station",
	"refurb_bench",
]

const _BETA_KEEP_ROOT_NODES: Array[StringName] = [
	&"PlayerController",
	&"PlayerEntrySpawn",
	&"FluorescentKeyLight",
	&"WarmNeonFill",
	&"GreenNeonFill",
	&"CRTDemoSpotlight",
	&"CheckoutLaneSpotlight",
	&"FrontLaneFill",
	&"CheckoutCounterPractical",
	&"BackroomUtilityLight",
	&"Floor",
	&"BackWallBody",
	&"LeftWallBody",
	&"RightWallBody",
	&"Ceiling",
	&"FrontWallLeftBody",
	&"FrontWallRightBody",
	&"EntranceDoor",
	&"NavigationRegion3D",
	&"EntryArea",
	&"RegisterArea",
	&"checkout_counter",
	# Authored fixtures — kept visible so the room reads as a used-game store
	# without a separate primitive-builder. Their slot Interactables are
	# disabled by `_apply_objective_gating`, so player E-presses still resolve
	# only against the beta day-1 critical-path targets.
	&"Checkout",
	&"CartRackLeft",
	&"CartRackRight",
	&"GlassCase",
	&"ConsoleShelf",
	&"AccessoriesBin",
	&"InteriorSignage",
	# Front-of-store display props re-enabled to break up the empty center
	# floor. Their `Interactable` children are disabled by
	# `_apply_objective_gating`, so the mesh renders but E-presses do not
	# resolve during the Day-1 critical path. FrontLaneQueue is pure
	# geometry (no Interactable).
	&"bargain_bin",
	&"featured_display",
	&"FrontLaneQueue",
	&"BetaDayOneController",
	&"BetaDayOneCustomer",
	&"BetaBackroomPickup",
	&"BetaRestockShelf",
	&"BetaDayEndTrigger",
	&"BetaHiddenClue",
	&"ZoneLabels",
	&"ReadabilityProps",
	&"Storefront",
	&"EntranceInterior",
	# §F-PUNCH1 — back-room atmosphere + enclosure. The `back_room` node
	# carries the existing crates / shelf / damaged-bin props so the room
	# reads as "a small storage room" instead of an empty corner. The
	# three Beta*Wall nodes are the partition + doorway authored at the
	# scene root so the back room is enclosed regardless of which subtree
	# the strip walks.
	&"back_room",
	&"BetaBackroomWallSide",
	&"BetaBackroomWallFrontLeft",
	&"BetaBackroomWallFrontRight",
	# Testing zone — kept as a "parked feature" per the comment in
	# retro_games.gd `_apply_day1_quarantine`. The CRT prop, neon panels, and
	# "Coming Soon" Label3D under crt_demo_area read as a deliberate parked
	# feature rather than missing scenery, and the testing-zone signage tests
	# (test_retro_games_interior_signage) require ComingSoonLabel to remain
	# visible.
	&"crt_demo_area",
]

const BetaDebugOverlayScript: GDScript = preload("res://game/scripts/beta/beta_debug_overlay.gd")
const BetaScreenshotHelperScript: GDScript = preload(
	"res://game/scripts/beta/beta_screenshot_helper.gd"
)
const BetaCustomerResultPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_customer_result_panel.gd"
)
const BetaCustomerInventoryEffectsScript: GDScript = preload(
	"res://game/scripts/beta/beta_customer_inventory_effects.gd"
)
const BetaDayTwoPlaceholderPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_day_two_placeholder_panel.gd"
)
const CloseDayConfirmationPanelScene: PackedScene = preload(
	"res://game/scenes/ui/close_day_confirmation_panel.tscn"
)

## Vic's original orientation note, kept for explicit note-panel tests and
## fallback later-day copy. Names the register
## ('Register is ready. First customer usually comes in around opening.')
## and the restock task ('Get a few things on the used shelf before the
## rush.') in plain retail language so both upcoming chain beats are
## primed without being announced as objectives.
const VIC_NOTE_BODY: String = (
	"[b]From Vic[/b]\n\n"
	+ "Morning. I'm out running errands — should be back mid-afternoon.\n\n"
	+ "Register is ready. First customer usually comes in around opening.\n\n"
	+ "Back-room shipment came in last night. Get a few things on the used "
	+ "shelf before the rush.\n\n"
	+ "Keys are under the counter if you need the stockroom.\n\n"
	+ "— V"
)

## Day-2 morning note. Vic is on-site but in the back room with the
## remaining shipment, so the player gets a "you know the drill" framing
## rather than the new-employee orientation Day 1 carried.
const VIC_NOTE_DAY2_BODY: String = (
	"[b]From Vic[/b]\n\n"
	+ "I'm in the back most of the day going through the last of the shipment. "
	+ "Come find me if something comes up.\n\n"
	+ "Register situation's the same as yesterday — you know the drill. "
	+ "We had a few regulars in yesterday so expect some of them back.\n\n"
	+ "Grab the remaining stock from the back room when you have a moment. "
	+ "Used shelf can always use more product.\n\n"
	+ "— V"
)

## Customer-exit walk targets and timings. Tween coordinates are in world
## space and target the +Z entrance door (front wall sits at Z≈10.05; door
## pivot at Z=10). The customer parks at world (5.35, 0, 8.5), and `look_at`
## rotates them to face the exit before leg 1 begins.
const _CUSTOMER_EXIT_LEG_1_TARGET: Vector3 = Vector3(1.5, 0.0, 8.5)
const _CUSTOMER_EXIT_LEG_2_TARGET: Vector3 = Vector3(0.0, 0.0, 10.5)
const _CUSTOMER_EXIT_LEG_1_SECONDS: float = 0.9
const _CUSTOMER_EXIT_LEG_2_SECONDS: float = 1.2
const _CUSTOMER_EXIT_FADE_SECONDS: float = 0.8

## Day-1 objective table. Each entry drives gating, prompt, time advance,
## and the next-stage transition. `target_path` is the scene-relative path
## to the Interactable whose `enabled` flag the gating layer flips on for
## this stage; `time_cost_minutes` is added to TimeSystem when the player
## completes the step.
##
## Strings (not StringNames) inside the dict literals so the table parses
## as a plain Array literal — Godot's GDScript parser rejects nested
## `&"foo"` StringName literals inside typed Array[Dictionary] entries.
## `id` and `stage` are converted to StringName via `_chain_id` / `_chain_stage`
## helpers at lookup sites.
## Time costs land the chain at or past 5:00 PM by completion: 9:00 +
## 60 + 120 + 300 = 17:00 exactly. Even with TimeSystem absent (unit
## tests) the chain still flows because the time gate falls back to "ok"
## when there's no clock to consult.
## §F-I1 — Day-1 chain: customer → back room → stock → close. The order is
## doctrinal (per the latest beta-stabilization spec): the player can't stock
## meaningfully before knowing what's in the back room. Time costs (30/30/60)
## sum to 120 min so the chain finishes well before 5 PM; on transition to
## END_DAY, `_advance_to_next_stage` jumps the clock to 17:00 so the player
## isn't forced to idle from ~11 AM until close.
var _training_objectives: Array[Dictionary] = [
	{
		"id": "talk_to_manager",
		"stage": "training_talk_manager",
		"label": "Talk to the manager.",
		"action": "Talk to manager",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 0,
		"required": true,
	},
	{
		"id": "check_register",
		"stage": "training_check_register",
		"label": "Check the register.",
		"action": "Check register",
		"key": "E",
		"target_path": "BetaDayEndTrigger/Interactable",
		"time_cost_minutes": 0,
		"required": true,
	},
	{
		"id": "check_back_room_inventory",
		"stage": "training_back_room_inventory",
		"label": "Check back room inventory.",
		"action": "Check back room inventory",
		"key": "E",
		"target_path": "BetaBackroomPickup/Interactable",
		"time_cost_minutes": 0,
		"required": true,
	},
	{
		"id": "training_stock_shelf",
		"stage": "training_stock_shelf",
		"label": "Stock the used games shelf.",
		"action": "Stock used games shelf",
		"key": "E",
		"target_path": "BetaRestockShelf/Interactable",
		"time_cost_minutes": 0,
		"required": true,
	},
	{
		"id": "practice_customer",
		"stage": "training_practice_customer",
		"label": "Run a practice customer decision.",
		"action": "Practice customer",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 0,
		"required": true,
	},
	{
		"id": "open_store",
		"stage": "training_open_store",
		"label": "Open the store.",
		"action": "Open the store",
		"key": "E",
		"target_path": "BetaDayEndTrigger/Interactable",
		"time_cost_minutes": 0,
		"required": false,
	},
]

var _day_one_objectives: Array[Dictionary] = [
	{
		"id": "talk_to_customer",
		"stage": "talk_to_customer",
		"label": "Talk to the customer at the register.",
		"action": "Talk to the customer",
		"key": "E",
		"target_path": "BetaDayOneCustomer/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "back_room_inventory",
		"stage": "back_room_inventory",
		"label": "Check the back room delivery.",
		"action": "Check inventory",
		"key": "E",
		"target_path": "BetaBackroomPickup/Interactable",
		"time_cost_minutes": 30,
		"required": true,
	},
	{
		"id": "stock_shelf",
		"stage": "stock_shelf",
		"label": "Stock the Retro Games shelf.",
		"action": "Stock the shelf",
		"key": "E",
		"target_path": "BetaRestockShelf/Interactable",
		"time_cost_minutes": 60,
		"required": true,
	},
	{
		"id": "close_day",
		"stage": "end_day",
		"label": "Close the day at the register.",
		"action": "Close the day",
		"key": "E",
		"target_path": "BetaDayEndTrigger/Interactable",
		"time_cost_minutes": 0,
		"required": false,
	},
]
var _objectives: Array[Dictionary] = _day_one_objectives.duplicate(true)

var _training_event: Dictionary = {
	"id": "training_wrong_platform_practice",
	"day": 0,
	"customer_name": "Practice Customer",
	"title": "TRAINING — CUSTOMER DECISION",
	"body": (
		"A customer bought Goblin Kart for NovaCube, but their kid owns a "
		+ "PrismBox. What do you do?"
	),
	"choices": [
		{
			"id": "clean_exchange",
			"label": "Swap it for the PrismBox copy at the same price.",
			"effects": {},
			"result": {
				"headline": "Clean Exchange",
				"customer_reaction": "The manager nods once. Efficient, not heroic.",
				"store_outcome": "You kept the customer happy without inventing a new policy.",
				"manager_note": "Good. Register problems are easier when the fix is boring.",
				"tone": "positive",
				"consequences": [
					{"label": "Money", "text": "Practice only: no cash changes."},
					{"label": "Inventory", "text": "Real sales will move shelf stock."},
					{"label": "Customer", "text": "Happy enough to leave without a scene."},
					{"label": "Policy", "text": "Clean exchange, clean paper trail."}
				]
			}
		},
		{
			"id": "upsell_bundle",
			"label": "Bundle the PrismBox copy with a discounted used controller.",
			"effects": {},
			"result": {
				"headline": "Bundle Offered",
				"customer_reaction": "The manager watches the drawer, then the shelf.",
				"store_outcome": "You made the ticket bigger, but used extra inventory to do it.",
				"manager_note": (
					"That can be worth it early. Just don't give away half the "
					+ "store every time someone panics."
				),
				"tone": "mixed",
				"consequences": [
					{"label": "Money", "text": "Practice only: no cash changes."},
					{"label": "Inventory", "text": "Real bundles spend more shelf stock."},
					{"label": "Customer", "text": "Helped, with a little pressure."},
					{"label": "Policy", "text": "Allowed, but not your only tool."}
				]
			}
		},
		{
			"id": "refuse_return",
			"label": "Point at the \"opened or sealed, no exchanges\" sign and decline.",
			"effects": {},
			"result": {
				"headline": "Policy Refusal",
				"customer_reaction": "The manager does not look surprised. That is not the same as approval.",
				"store_outcome": "You protected the drawer and probably lost the room.",
				"manager_note": "Policy is a shield, not a personality. Use it when you have to.",
				"tone": "negative",
				"consequences": [
					{"label": "Money", "text": "Practice only: no cash changes."},
					{"label": "Inventory", "text": "No stock moves."},
					{"label": "Customer", "text": "Unhappy customers cost you later."},
					{"label": "Policy", "text": "Technically clean, socially expensive."}
				]
			}
		}
	]
}

var _decision_panel: BetaDecisionCardPanel
var _customer_result_panel: ModalPanel
var _summary_panel: BetaDaySummaryPanel
var _day_two_placeholder_panel: ModalPanel
var _vic_note_panel: BetaManagerNotePanel
var _objective_target_highlight: BetaObjectiveTargetHighlight
var _debug_overlay: CanvasLayer
var _screenshot_helper: CanvasLayer
var _close_day_panel: CanvasLayer
var _events_by_day: Dictionary = {}
var _day_data_by_day: Dictionary = {}
var _day_events: Array[Dictionary] = []
var _current_event_index: int = 0
var _resolved_events_today: int = 0
var _stage: StringName = STAGE_VIC_NOTE
var _active_event: Dictionary = {}
var _pending_result_effects: Dictionary = {}
## Track per-objective completion (one-shot guard). An objective fires
## `_advance_stage` exactly once even if its interactable's interact() is
## called twice (e.g. mid-fade scene churn) — the entry stays in this set
## and subsequent calls early-out.
var _completed_objectives: Dictionary = {}
## §F-L3/L4/L5 — cleaner summary metrics. `_customers_helped_today` ticks
## on every successful customer choice; `_items_stocked_today` ticks on
## restock. Used by `on_beta_day_end_requested` to populate the summary
## payload with grounded retail numbers instead of cryptic system scores.
var _customers_helped_today: int = 0
var _items_stocked_today: int = 0
var _customer_inventory_transactions: Array[Dictionary] = []
## Per-day cash earned from successful customer decisions. Distinct from
## `BetaRunState.daily_cash_delta`, which includes every beta cash effect;
## this tracks gross sales for today only so the day-summary panel can render
## the "Sales" line without counting refunds or no-sale outcomes. Ticked in
## `_on_choice_selected` on positive cash deltas, reset in `_start_day`.
var _sales_today: int = 0
## One-shot guard against double-spawning the day-summary modal. The
## production `DayCycleController` and the beta controller both listen to
## `EventBus.day_close_confirmed`, and any re-emit of that signal — or a
## test fixture invoking `_on_day_close_confirmed` directly — would otherwise
## enqueue a second `BetaDaySummaryPanel` request. ModalQueue dedups by panel
## instance, but the controller's accompanying state mutations (end_day,
## clock pause) are not idempotent. Reset to false on `day_started`.
var _summary_spawned: bool = false
var _objective_target_diagnostic: String = ""
var _reported_invalid_target_paths: Dictionary = {}
var _training_gating_refresh_frames: int = 0
## Captured the first time `_configure_beta_customer` runs so the day-reset
## path can put the customer back at the register after the previous day's
## exit tween moved them to the entrance.
var _initial_customer_position: Vector3 = Vector3.ZERO
var _initial_customer_position_captured: bool = false


func _ready() -> void:
	add_to_group("beta_day_one_controller")
	_apply_beta_only_strip()
	_apply_minimal_scope()
	_configure_beta_customer()
	_suppress_moments_tray()
	_load_content()
	_ensure_panels()
	_connect_panel_signals()
	# Hand the persistent beta HUD surfaces off to the autoload owner.
	# `BetaHUD` spawns the right panel + event log once at boot and keeps
	# them alive across a day-controller teardown; `activate(day)` seeds
	# the right panel from `_objectives` and the current `BetaRunState`.
	BetaHUD.activate(BetaRunState.day)
	# Deferred so the parent StoreController._ready() runs first and connects
	# its EventBus.objective_changed listener before the initial rail payload.
	# Day 1 goes straight to the customer beat; later days can still use the
	# Vic-note gate from `_on_summary_continue`.
	call_deferred("_open_day")
	_print_interactable_debug_list()


func _process(_delta: float) -> void:
	if _training_gating_refresh_frames <= 0:
		return
	_training_gating_refresh_frames -= 1
	_apply_objective_gating()


func _exit_tree() -> void:
	if EventBus.day_close_confirmed.is_connected(_on_day_close_confirmed):
		EventBus.day_close_confirmed.disconnect(_on_day_close_confirmed)
	_free_owned_ui_nodes()


## Opens the current beta day. Day 1 skips the Vic note entirely so the player
## lands at the first actionable tutorial objective without dismissing setup
## screens. Day 2 keeps the note beat, where the reminder has value because
## the player is continuing an existing run.
func _open_day() -> void:
	if BetaRunState.day == 1 and not BetaRunState.preopening_complete:
		_start_preopening_training()
		return
	if BetaRunState.day == 1:
		_start_day(BetaRunState.day)
		return
	_open_vic_note_and_then_start_day()


func _start_preopening_training() -> void:
	_sync_beta_day(1)
	_objectives = _training_objectives.duplicate(true)
	_stage = STAGE_TRAINING_TALK_MANAGER
	_completed_objectives.clear()
	_summary_spawned = false
	_pending_result_effects.clear()
	_active_event = {}
	BetaRunState.carrying_stock = false
	_reset_scene_for_day(1)
	_reset_beta_inventory_overlay()
	_set_clock_to_preopening()
	_apply_customer_profile({"customer_name": "Manager"})
	_update_objective_rail()
	_apply_objective_gating()
	call_deferred("_apply_objective_gating")
	_training_gating_refresh_frames = 5
	BetaHUD.activate(BetaRunState.day)
	EventBus.toast_requested_with_id.emit(
		&"beta_preopening_training_started",
		"Training: talk to the manager.",
		&"info",
		5.0,
	)


func _set_clock_to_preopening() -> void:
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys == null:
		return
	time_sys.set_speed(TimeSystem.SpeedTier.PAUSED)
	time_sys.game_time_minutes = 8.0 * 60.0
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.PRE_OPEN)


## Later-day opening gate: shows Vic's morning note before `_start_day` arms
## the chain interactables. The chain stays at STAGE_VIC_NOTE while the note
## is on screen; dismissal advances to STAGE_TALK_TO_CUSTOMER via
## `_on_vic_note_dismissed`.
func _open_vic_note_and_then_start_day() -> void:
	# Force the rail back into note-phase copy regardless of where the prior
	# day's chain left `_stage`. Without this, Day 2's note would render the
	# rail with Day 1's `STAGE_END_DAY` label ("Close the day at the register.")
	# behind the modal.
	_stage = STAGE_VIC_NOTE
	_update_objective_rail()
	var body: String = VIC_NOTE_DAY2_BODY if BetaRunState.day == 2 else VIC_NOTE_BODY
	_vic_note_panel.show_note(body)


func _on_vic_note_dismissed() -> void:
	EventBus.manager_note_dismissed.emit("vic_day%02d" % BetaRunState.day)
	# Advance past STAGE_VIC_NOTE explicitly so any reader that observes
	# `_stage` between this line and the `_start_day` call sees the
	# customer beat, not the note phase. `_start_day` re-asserts the same
	# value as part of fresh-day reset — the redundancy is intentional
	# (defense against a future refactor that drops the line in either
	# place).
	_stage = STAGE_TALK_TO_CUSTOMER
	# Synchronous, not deferred: the rail signal must fire in the same
	# frame as the dismiss so there is no empty-rail moment between the
	# panel closing and the customer beat appearing.
	_start_day(BetaRunState.day)
	# Vic's note hints at the back-room delivery in plain prose; this
	# emit promotes it to an active player cue so a player who skims the
	# note still notices the delivery is waiting. Routed through the
	# persistent HUD label channel (not toast) because it complements the
	# rail's active beat rather than narrating an event.
	EventBus.notification_requested.emit("Back-room delivery ready for pickup.")


func on_beta_customer_interacted() -> void:
	if _stage == STAGE_TRAINING_TALK_MANAGER:
		EventBus.toast_requested.emit(
			"Morning. Before we unlock the doors, I need to show you how this place works.",
			&"info",
			4.5,
		)
		_complete_current_objective()
		return
	if _stage == STAGE_TRAINING_PRACTICE_CUSTOMER:
		_active_event = _training_event.duplicate(true)
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)
		_decision_panel.show_event(_active_event)
		return
	if _stage != STAGE_TALK_TO_CUSTOMER:
		EventBus.notification_requested.emit("Follow the current objective first.")
		return
	if _active_event.is_empty():
		EventBus.notification_requested.emit("No customer event is available right now.")
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)
	_decision_panel.show_event(_active_event)


func on_beta_register_interacted() -> void:
	if _stage == STAGE_TRAINING_CHECK_REGISTER:
		_grant_unlock(_REGISTER_UNLOCK_GRANT)
		EventBus.toast_requested.emit(
			"Register ready. Customers get handled from the checkout lane.",
			&"sale",
			3.0,
		)
		_complete_current_objective()
		return
	if _stage == STAGE_TRAINING_OPEN_STORE:
		_complete_open_store_training_objective()
		_open_store_after_training()
		return
	on_beta_day_end_requested()


func _complete_open_store_training_objective() -> void:
	if _completed_objectives.has(&"open_store"):
		return
	_completed_objectives[&"open_store"] = true
	EventBus.beta_objective_completed.emit(&"open_store")
	EventBus.objective_completed.emit(&"open_store", _objective_completion_label(&"open_store"))


func _open_store_after_training() -> void:
	BetaRunState.preopening_complete = true
	BetaRunState.carrying_stock = false
	EventBus.beta_carry_changed.emit("")
	EventBus.toast_requested_with_id.emit(
		&"beta_training_complete",
		"Training complete. You know enough to open the store.",
		&"sale",
		4.0,
	)
	_start_day(1)


## Required back-room beat. Pressing E on the inventory pickup completes
## the back-room objective and advances the chain. Inspecting the
## console stack flavor object (BetaHiddenClue) is independent — it does
## not satisfy this beat.
func on_beta_backroom_pickup_interacted() -> void:
	if _stage != STAGE_BACK_ROOM_INVENTORY and _stage != STAGE_TRAINING_BACK_ROOM:
		EventBus.notification_requested.emit(_disabled_reason_for_stage(STAGE_BACK_ROOM_INVENTORY))
		return
	var objective_id: StringName = StringName(str(_objective_for_stage(_stage).get("id", "")))
	if _completed_objectives.has(objective_id):
		return
	# §F-L1 — visible feedback: the closed box swaps to its open-base sibling
	# so the floor reads as "the player opened it here." The carry HUD then
	# shows what they're holding.
	_hide_stock_box_in_world()
	BetaRunState.carrying_stock = true
	# Pickup is the moment the back-room delivery becomes the player's stock,
	# so the HUD's "Back Room" counter ticks to the day's delivery quantity
	# in the same frame. On-shelves stays at 0 until the player walks the
	# stock to BetaRestockShelf — the two counters are deliberately
	# complementary, mirroring the BRAINDUMP §3 / §4 stat-update beats.
	EventBus.beta_backroom_count_changed.emit(_BACKROOM_DELIVERY_QUANTITY)
	# The pickup toast and the carry HUD label fire on the same call stack
	# so the back-room item disappears, the toast slides in top-right, and
	# the bottom-left "Carrying:" indicator lights up within a single frame —
	# no visible gap where the box is gone but neither cue has landed. The
	# pickup is a transient *event* confirmation, so it routes through
	# `toast_requested` (auto-dismissing card on layer 45). The persistent
	# carry *state* lives separately on `beta_carry_changed` (layer 41).
	# Toast copy interpolates the delivery quantity from the same const that
	# drives `beta_backroom_count_changed`, so the back-room HUD readout and
	# the toast can never disagree about how many items the player just
	# uncovered.
	(
		EventBus
		. toast_requested
		. emit(
			"Shipment checked. %d items available in back room." % _BACKROOM_DELIVERY_QUANTITY,
			&"info",
			2.5,
		)
	)
	EventBus.beta_carry_changed.emit("Used Games Box")
	_complete_current_objective()


## Optional ambient flavor — the console stack is interactable any time
## the player notices it, but inspecting it does not advance the active
## objective. Per the tone rule: the player decides whether it's
## interesting; the UI never labels it as a quest. The hidden-thread
## signal still records the inspection so consequence pipelines (later
## days) can react.
func on_beta_hidden_clue_interacted() -> void:
	if _completed_objectives.has(&"_flavor_console_stack"):
		# Already inspected today — second press shows the same flavor
		# but we don't double-advance the clock or re-emit signals.
		EventBus.notification_requested.emit("You've already taken a look. Nothing new to see.")
		return
	_completed_objectives[&"_flavor_console_stack"] = true
	BetaRunState.mark_hidden_thread_signal(&"day01_backroom_modded_console_hint")
	EventBus.beta_hidden_clue_inspected.emit(&"day01_backroom_modded_console_hint")
	EventBus.notification_requested.emit(
		"A few old consoles are stacked beside the wall. One is warmer than it should be."
	)
	# Small ambient time tick — inspecting takes a moment but is not on
	# the critical path's time budget.
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys != null:
		time_sys.advance_by_minutes(5.0)


## Required stocking beat. Renamed from the old pickup/place-stock
## two-step into a single "stock the shelf" interaction so the chain
## stays simple and grounded.
func on_beta_restock_interacted() -> void:
	if _stage != STAGE_STOCK_SHELF and _stage != STAGE_TRAINING_STOCK_SHELF:
		EventBus.notification_requested.emit(_disabled_reason_for_stage(STAGE_STOCK_SHELF))
		return
	if not BetaRunState.carrying_stock:
		EventBus.notification_requested.emit(restock_disabled_reason())
		return
	var objective_id: StringName = StringName(str(_objective_for_stage(_stage).get("id", "")))
	if _completed_objectives.has(objective_id):
		return
	# §F-L3 — visible feedback: spawn the day's delivery quantity of boxed-
	# game meshes on the restock shelf's authored ShelfBoard so the player
	# sees what they put up. The carry HUD clears, the on-shelves counter
	# ticks to match, and the back-room counter drains to 0 — the two
	# inventory readouts move complementarily on the same frame.
	var spawned: int = _spawn_visible_shelf_items(_BACKROOM_DELIVERY_QUANTITY)
	BetaRunState.carrying_stock = false
	EventBus.beta_carry_changed.emit("")
	EventBus.beta_shelf_count_changed.emit(spawned)
	EventBus.beta_backroom_count_changed.emit(0)
	EventBus.toast_requested.emit(
		"Stocked %d games on the used games shelf." % spawned, &"sale", 3.0
	)
	_complete_current_objective()


func on_beta_day_end_requested() -> void:
	if _stage != STAGE_END_DAY:
		EventBus.notification_requested.emit(close_day_disabled_reason())
		return
	if _close_day_panel != null and bool(_close_day_panel.get("_focus_pushed")):
		return
	# BRAINDUMP "Close Day 1? Yes / Not Yet" — route through the standalone
	# CloseDayConfirmationPanel via EventBus. The panel is instantiated in
	# `_ensure_panels()`; on confirm it emits `day_close_confirmed`, which
	# our listener in `_connect_panel_signals()` routes to
	# `_on_day_close_confirmed()`. Cancel hides the panel and leaves
	# `_stage` at END_DAY so the player can re-press E to retry.
	#
	# Reason copy interpolates the active day so the prompt reinforces
	# progression ("Day 1" / "Day 2" / …) instead of reading as a generic
	# wrap-up.
	EventBus.day_close_confirmation_requested.emit("Ready to close up Day %d?" % BetaRunState.day)


## Confirm-side of the close-day flow. Runs when the player presses
## "Close Day" on `CloseDayConfirmationPanel` (cancel/"Not Yet" never
## emits this). Guarded so re-emits or the production
## `DayCycleController` listener firing in scenes where both controllers
## live can't double-advance the day or re-show the summary.
func _on_day_close_confirmed() -> void:
	if _stage != STAGE_END_DAY:
		return
	if _completed_objectives.has(&"close_day"):
		return
	# Hard one-shot guard: a re-emit of `day_close_confirmed` (production
	# `DayCycleController` listener firing in scenes where both controllers
	# live, or a direct second invocation) would otherwise call `end_day()`
	# twice — wiping the daily deltas before the second pass reads them —
	# and enqueue a second summary panel request. §EH-39 — push a warning
	# so the duplicate emit surfaces in QA / headless logs; silently
	# eating it would hide a real upstream double-emit bug in any scene
	# where this fires in production.
	if _summary_spawned:
		push_warning(
			(
				(
					"BetaDayOneController: day_close_confirmed re-emitted for "
					+ "day %d after summary already spawned — ignoring duplicate."
				)
				% BetaRunState.day
			)
		)
		return
	_summary_spawned = true
	# Mark the close-day row complete so the Today checklist ticks the
	# fourth bullet before the summary modal fully covers it.
	_completed_objectives[&"close_day"] = true
	# §EH-13 — `beta_objective_completed` is declared in
	# `event_bus.gd:664`; guarding the emit with `has_signal` would
	# silently swallow a rename regression (listener disconnects, no
	# diagnostic). Emit unconditionally so a renamed signal fails at
	# parse time on the EventBus side instead of slipping past CI.
	EventBus.beta_objective_completed.emit(&"close_day")
	# Past-tense companion broadcast for the on-screen event log; see
	# the matching emit in `_complete_current_objective` for the
	# log-vs-rail copy contract.
	EventBus.objective_completed.emit(&"close_day", _objective_completion_label(&"close_day"))
	# Modal lifecycle is the single authority for input focus: `show_summary`
	# routes through `ModalPanel.open()` which pushes CTX_MODAL on `InputFocus`.
	var summary: Dictionary = BetaRunState.end_day()
	summary["events_completed"] = _resolved_events_today
	summary["events_target"] = _day_events.size()
	# §F-L5 — grounded retail metrics for the beta summary. These live
	# alongside the legacy keys (cash/reputation/manager_trust/hidden_thread*)
	# so the panel can prefer the new keys without breaking older readers.
	summary["customers_helped"] = _customers_helped_today
	summary["items_stocked"] = _items_stocked_today
	summary["sales_completed"] = _customers_helped_today
	summary["customer_inventory_transactions"] = (_customer_inventory_transactions.duplicate(true))
	summary["inventory_items_removed"] = _count_inventory_transaction_ops("remove_stock")
	summary["inventory_items_added"] = _count_inventory_transaction_ops("create_item")
	summary["shift_note"] = _build_shift_note()
	# Shelf / back-room inventory at close. Stocking flips the delivery from
	# the back room onto the shelf, so the two values are complementary:
	# items stocked ⇒ shelf=N / backroom=0; pickup-only ⇒ shelf=0 /
	# backroom=delivery quantity; chain not started ⇒ 0 / 0.
	var shelf_remaining: int = _items_stocked_today
	var backroom_remaining: int = 0
	if (
		_completed_objectives.has(&"back_room_inventory")
		and not _completed_objectives.has(&"stock_shelf")
	):
		backroom_remaining = _BACKROOM_DELIVERY_QUANTITY
	summary["shelf_inventory_remaining"] = shelf_remaining
	summary["backroom_inventory_remaining"] = backroom_remaining
	# BRAINDUMP First-Day Flow Step 6 — "rent/sales/profit are shown
	# cleanly." Rent is the fixed daily operating cost (display-only for
	# the beta); sales is gross cash in from successful customer decisions
	# today; profit is sales minus rent.
	summary["rent_paid"] = BetaRunState.DAILY_RENT
	summary["sales_revenue"] = _sales_today
	summary["net_profit"] = _sales_today - BetaRunState.DAILY_RENT
	_grant_unlock(_DAY_ONE_CLOSE_UNLOCK_GRANT)
	_summary_panel.show_summary(summary, BetaRunState.day >= TARGET_BETA_DAYS)


func _on_choice_selected(choice_id: StringName, effects: Dictionary) -> void:
	if _active_event.is_empty():
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
		_pending_result_effects.clear()
		return
	if _stage == STAGE_TRAINING_PRACTICE_CUSTOMER:
		var training_choice: Dictionary = _choice_for_id(choice_id)
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_CUSTOMER_RESULT)
		_pending_result_effects = {}
		_customer_result_panel.call(
			"show_result",
			_build_customer_result_payload(choice_id, {})
		)
		if training_choice.is_empty():
			BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
			_finish_training_customer_choice()
		return
	if _completed_objectives.has(&"talk_to_customer"):
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
		return
	var event_id: StringName = StringName(str(_active_event.get("id", "")))
	var choice: Dictionary = _choice_for_id(choice_id)
	var inventory_transaction: Dictionary = _apply_customer_inventory_effects(choice, effects)
	var resolved_effects: Dictionary = _effects_after_inventory(effects, inventory_transaction)
	BetaRunState.apply_decision_effect(event_id, choice_id, resolved_effects)
	_resolved_events_today += 1
	if choice_id == &"refuse_return":
		BetaRunState.mark_hidden_thread_signal(&"parent_refused_return_risk")
	if _should_show_customer_result(choice_id):
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_CUSTOMER_RESULT)
		_pending_result_effects = resolved_effects.duplicate(true)
		_customer_result_panel.call(
			"show_result", _build_customer_result_payload(choice_id, resolved_effects)
		)
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
	_finish_customer_choice(resolved_effects)


func _on_customer_result_acknowledged(event_id: StringName, _choice_id: StringName) -> void:
	if _active_event.is_empty():
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
		_pending_result_effects.clear()
		return
	if event_id != StringName(str(_active_event.get("id", ""))):
		BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
		_pending_result_effects.clear()
		return
	var effects: Dictionary = _pending_result_effects.duplicate(true)
	_pending_result_effects.clear()
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
	if _stage == STAGE_TRAINING_PRACTICE_CUSTOMER:
		_finish_training_customer_choice()
		return
	_finish_customer_choice(effects)


func _finish_training_customer_choice() -> void:
	if _completed_objectives.has(&"practice_customer"):
		return
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)
	EventBus.toast_requested.emit(
		"Practice customer complete. The next one counts.",
		&"info",
		3.0,
	)
	_complete_current_objective()


func _finish_customer_choice(effects: Dictionary) -> void:
	if _completed_objectives.has(&"talk_to_customer"):
		return
	# §F-L4 — the customer turns toward the entrance, walks out, and
	# fades at the threshold so the conversation has a visible ending
	# beat. The whole subtree is hidden (not freed) when the tween
	# completes so a future day's reset can re-show them at the register.
	_animate_customer_exit()
	_customers_helped_today += 1
	# Emit the standard sale signals so the HUD's `_sales_today_count` and
	# `_customers_served_today_count` (which read off `item_sold` /
	# `customer_purchased`) tick in the beta path. The beta path bypasses
	# the production checkout pipeline that normally fires these, so the
	# Sold Today readout would otherwise stay at 0 even after a real sale.
	# Guard on a completed inventory transaction so failed customer choices
	# do not tick sale counters or broadcast checkout signals.
	var cash_delta: int = int(effects.get("cash", 0))
	if cash_delta > 0 and _effects_allow_sale_signal(effects):
		_sales_today += cash_delta
		var price: float = float(cash_delta)
		var sale_item: Dictionary = _sale_item_from_effects(effects)
		var item_id: String = str(sale_item.get("item_id", "used_game"))
		var category: String = str(sale_item.get("category", "used_games"))
		EventBus.item_sold.emit(item_id, price, category)
		EventBus.customer_purchased.emit(
			EconomySystem.BETA_COUNTER_ONLY_STORE_ID,
			StringName(item_id),
			price,
			&"beta_customer_01"
		)
	# §F-PUNCH4 — narrate the outcome so the player understands whether a
	# sale happened. Cash delta is the truth; reputation-only choices show
	# a softer message. Toasts (not notifications) so the carry-state
	# notification a moment later doesn't swamp this one in the queue.
	_emit_customer_outcome_toast(effects)
	# The customer step is the first link in the chain; resolving their
	# decision completes that objective and advances to INSPECT_CLUE. The
	# old "skip to END_DAY for last event" branch was the source of the
	# 9 AM close-day bug — every Day 1 has exactly one customer, so it
	# would short-circuit the rest of the loop.
	_complete_current_objective()


func _should_show_customer_result(choice_id: StringName) -> bool:
	if _customer_result_panel == null:
		return false
	if _decision_panel == null or not _decision_panel.visible:
		return false
	var choice: Dictionary = _choice_for_id(choice_id)
	if choice.is_empty():
		return false
	return (choice.get("result", {}) as Dictionary).size() > 0


func _build_customer_result_payload(choice_id: StringName, effects: Dictionary) -> Dictionary:
	var choice: Dictionary = _choice_for_id(choice_id)
	var result: Dictionary = (choice.get("result", {}) as Dictionary).duplicate(true)
	_apply_inventory_result_copy(result, effects)
	return {
		"event_id": StringName(str(_active_event.get("id", ""))),
		"choice_id": choice_id,
		"customer_name": str(_active_event.get("customer_name", "Customer")),
		"event_title": str(_active_event.get("title", "Customer")),
		"choice_label": str(choice.get("label", "")),
		"result": result,
		"effects": effects,
	}


func _choice_for_id(choice_id: StringName) -> Dictionary:
	var choices: Array = _active_event.get("choices", []) as Array
	for choice_variant: Variant in choices:
		if choice_variant is not Dictionary:
			continue
		var choice: Dictionary = choice_variant as Dictionary
		if StringName(str(choice.get("id", ""))) == choice_id:
			return choice
	return {}


func _apply_customer_inventory_effects(choice: Dictionary, effects: Dictionary) -> Dictionary:
	var inventory_payload: Variant = effects.get("inventory", [])
	if not (inventory_payload is Array) and not (inventory_payload is Dictionary):
		return {}
	if inventory_payload is Array and (inventory_payload as Array).is_empty():
		return {}
	if inventory_payload is Dictionary and (inventory_payload as Dictionary).is_empty():
		return {}
	var adapter: RefCounted = (
		BetaCustomerInventoryEffectsScript.new(GameManager.get_inventory_system(), _store_root())
		as RefCounted
	)
	var transaction: Dictionary = adapter.call("apply", effects) as Dictionary
	transaction["choice_id"] = String(choice.get("id", ""))
	transaction["event_id"] = String(_active_event.get("id", ""))
	transaction["requires_inventory_success"] = bool(
		effects.get("requires_inventory_success", choice.get("requires_inventory_success", false))
	)
	_customer_inventory_transactions.append(transaction.duplicate(true))
	return transaction


func _effects_after_inventory(effects: Dictionary, inventory_transaction: Dictionary) -> Dictionary:
	var resolved: Dictionary = effects.duplicate(true)
	if inventory_transaction.is_empty():
		return resolved
	resolved["inventory_transaction"] = inventory_transaction.duplicate(true)
	if bool(inventory_transaction.get("ok", false)):
		return resolved
	if resolved.has("cash"):
		resolved["cash"] = 0
	resolved["inventory_blocked"] = true
	return resolved


func _effects_allow_sale_signal(effects: Dictionary) -> bool:
	var transaction: Dictionary = effects.get("inventory_transaction", {}) as Dictionary
	if transaction.is_empty():
		return true
	if not bool(transaction.get("ok", false)):
		return false
	for applied_variant: Variant in transaction.get("applied", []) as Array:
		if applied_variant is not Dictionary:
			continue
		var applied: Dictionary = applied_variant as Dictionary
		if str(applied.get("op", "")) == "remove_stock":
			return true
	return false


func _sale_item_from_effects(effects: Dictionary) -> Dictionary:
	var transaction: Dictionary = effects.get("inventory_transaction", {}) as Dictionary
	if transaction.is_empty():
		return {"item_id": "used_game", "category": "used_games"}
	for applied_variant: Variant in transaction.get("applied", []) as Array:
		if applied_variant is not Dictionary:
			continue
		var applied: Dictionary = applied_variant as Dictionary
		if str(applied.get("op", "")) != "remove_stock":
			continue
		return {
			"item_id": str(applied.get("definition_id", "used_game")),
			"category": "used_games",
		}
	return {"item_id": "used_game", "category": "used_games"}


func _apply_inventory_result_copy(result: Dictionary, effects: Dictionary) -> void:
	var transaction: Dictionary = effects.get("inventory_transaction", {}) as Dictionary
	if transaction.is_empty() or bool(transaction.get("ok", false)):
		return
	result["store_outcome"] = (
		"The inventory check could not complete that movement, so the "
		+ "register stays unchanged and no stock is moved."
	)
	var failure_text: String = _inventory_failure_text(transaction)
	result["consequences"] = [
		{"label": "Money", "text": "$0 because no inventory changed hands."},
		{
			"label": "Reputation",
			"text": _signed_points_text(int(effects.get("reputation", 0))),
		},
		{"label": "Inventory", "text": failure_text},
		{
			"label": "Policy",
			"text": _signed_points_text(int(effects.get("manager_trust", 0))) + " manager trust",
		},
	]


func _inventory_failure_text(transaction: Dictionary) -> String:
	var failures: Array = transaction.get("failed", []) as Array
	if failures.is_empty():
		return "No inventory movement was applied."
	var first: Dictionary = failures[0] as Dictionary
	match str(first.get("reason", "")):
		"missing_inventory_system":
			return "Inventory is not available yet; no stock movement was recorded."
		"missing_matching_stock":
			return "No matching stocked item was found; no stock movement was recorded."
		"insufficient_quantity":
			return "Not enough matching stock was available; no stock movement was recorded."
		_:
			return "Inventory movement failed; no stock movement was recorded."


func _signed_points_text(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _count_inventory_transaction_ops(op: String) -> int:
	var count: int = 0
	for transaction: Dictionary in _customer_inventory_transactions:
		if not bool(transaction.get("ok", false)):
			continue
		for applied_variant: Variant in transaction.get("applied", []) as Array:
			if applied_variant is not Dictionary:
				continue
			var applied: Dictionary = applied_variant as Dictionary
			if str(applied.get("op", "")) == op:
				count += 1
	return count


func _on_summary_continue() -> void:
	# Pop CTX_MODAL before any state mutation so the InputFocus stack
	# returns to its prior state before the next beta modal opens.
	# Idempotent with the panel's own post-emit `close()` — a second pop is
	# a no-op (`_focus_pushed` is already cleared).
	_summary_panel.close()
	if BetaRunState.day >= TARGET_BETA_DAYS:
		EventBus.notification_requested.emit(
			"15-minute beta loop complete. Returning to main menu."
		)
		GameManager.go_to_main_menu()
		return
	BetaRunState.advance_day()
	GameManager.set_current_day(BetaRunState.day)
	GameState.day = BetaRunState.day
	_day_two_placeholder_panel.call("show_placeholder")


func _on_day_two_placeholder_main_menu() -> void:
	_day_two_placeholder_panel.close()
	GameManager.go_to_main_menu()


func _on_day_two_placeholder_restart() -> void:
	_day_two_placeholder_panel.close()
	GameManager.start_new_game()


## Replay-button handler. Closes the summary so the InputFocus stack pops
## CTX_MODAL before the new run boots, then routes through
## `GameManager.start_new_game()` — the same entry point used by the main
## menu, which calls `begin_new_run()` to reset BetaRunState and swap into a
## fresh GameWorld scene.
func _on_summary_replay() -> void:
	_summary_panel.close()
	GameManager.start_new_game()


## Main-menu button handler. Closes the summary (pops CTX_MODAL) and exits
## to the main menu via `GameManager.go_to_main_menu()`, which clears any
## pending load slot and runs the GAME_OVER → MAIN_MENU transition.
func _on_summary_main_menu() -> void:
	_summary_panel.close()
	GameManager.go_to_main_menu()


func can_interact_customer() -> bool:
	if _stage == STAGE_TRAINING_TALK_MANAGER:
		return true
	if _stage == STAGE_TRAINING_PRACTICE_CUSTOMER:
		return true
	return _stage == STAGE_TALK_TO_CUSTOMER and not _active_event.is_empty()


func customer_disabled_reason() -> String:
	return _disabled_reason_for_stage(STAGE_TALK_TO_CUSTOMER)


func can_interact_restock() -> bool:
	if _stage != STAGE_STOCK_SHELF and _stage != STAGE_TRAINING_STOCK_SHELF:
		return false
	# The stock-shelf stage starts the moment the back-room beat completes,
	# but the shelf is not actually interactable until the player walks the
	# delivery over from the back room. Gating on `carrying_stock` here
	# preserves the prompt-vs-disabled-reason contract: the player still
	# sees the shelf prompt, but the muted disabled copy below tells them
	# why E does not fire.
	return BetaRunState.carrying_stock


func restock_disabled_reason() -> String:
	if (
		(_stage == STAGE_STOCK_SHELF or _stage == STAGE_TRAINING_STOCK_SHELF)
		and not BetaRunState.carrying_stock
	):
		return "Pick up the back room delivery first."
	return _disabled_reason_for_stage(STAGE_STOCK_SHELF)


func can_interact_pickup() -> bool:
	return _stage == STAGE_BACK_ROOM_INVENTORY or _stage == STAGE_TRAINING_BACK_ROOM


func pickup_disabled_reason() -> String:
	return _disabled_reason_for_stage(STAGE_BACK_ROOM_INVENTORY)


## Console stack is ambient flavor — always interactable when the player
## notices it. No stage gating; the prompt is muted post-inspection.
func can_interact_hidden_clue() -> bool:
	return false


func hidden_clue_disabled_reason() -> String:
	return ""


## Belt-and-suspenders: stage flag AND every required objective complete.
## Time-of-day is no longer a gate — once the chain is done the player
## should be able to close immediately. `_pause_time_for_end_day()` halts
## the clock the moment END_DAY is entered so the player isn't forced to
## race a moving 17:00 deadline while walking to the register.
func can_interact_day_end() -> bool:
	if _stage == STAGE_TRAINING_CHECK_REGISTER or _stage == STAGE_TRAINING_OPEN_STORE:
		return true
	return _stage == STAGE_END_DAY and _all_required_objectives_completed()


func day_end_disabled_reason() -> String:
	return close_day_disabled_reason()


## Single source of truth for the close-day prompt's disabled message.
## Reads from the chain so when objectives are added/reordered, this
## message stays correct without per-stage maintenance. Phrased in
## grounded retail-shift language — never "you can't close the day yet,
## the mystery isn't solved."
func close_day_disabled_reason() -> String:
	if _stage == STAGE_TRAINING_CHECK_REGISTER:
		return ""
	if _stage == STAGE_TRAINING_OPEN_STORE:
		return ""
	for entry: Dictionary in _objectives:
		var stage_name: StringName = StringName(str(entry.get("stage", "")))
		if stage_name == STAGE_END_DAY:
			continue
		if not bool(entry.get("required", false)):
			continue
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		if not _completed_objectives.has(entry_id):
			return _prerequisite_reason_for(entry_id)
	return "Day cannot be ended yet."


func _disabled_reason_for_stage(target_stage: StringName) -> String:
	if _stage == target_stage:
		return ""
	if _stage == STAGE_VIC_NOTE:
		return "Read Vic's note first."
	var active: Dictionary = _objective_for_stage(_stage)
	if not active.is_empty():
		return _prerequisite_reason_for(StringName(str(active.get("id", ""))))
	return "Not available right now."


func _prerequisite_reason_for(objective_id: StringName) -> String:
	match objective_id:
		&"talk_to_manager":
			return "Talk to the manager first."
		&"check_register":
			return "Check the register first."
		&"check_back_room_inventory":
			return "Check the back room first."
		&"training_stock_shelf":
			return "Stock the used games shelf first."
		&"practice_customer":
			return "Run the practice customer first."
		&"open_store":
			return "Open the store at the register."
		&"talk_to_customer":
			return "Talk to the customer first."
		&"back_room_inventory":
			return "Check the back room first."
		&"stock_shelf":
			return "Stock the Retro Games shelf before closing."
		&"close_day":
			return "Close day at the register."
		_:
			return "Follow the current objective first."


func _load_content() -> void:
	for day_key: Variant in DAY_PATHS.keys():
		var day: int = int(day_key)
		var day_json: Variant = _load_json(str(DAY_PATHS[day_key]))
		if day_json is Dictionary:
			_day_data_by_day[day] = day_json
	var events_json: Variant = _load_json(EVENTS_PATH)
	if events_json is Dictionary:
		var events: Array = (events_json as Dictionary).get("events", []) as Array
		for event_variant: Variant in events:
			if event_variant is Dictionary:
				var entry: Dictionary = event_variant as Dictionary
				var day: int = int(entry.get("day", 1))
				if not _events_by_day.has(day):
					_events_by_day[day] = []
				var bucket: Array = _events_by_day[day] as Array
				bucket.append(entry)
				_events_by_day[day] = bucket


func _start_day(day: int) -> void:
	_sync_beta_day(day)
	_objectives = _day_one_objectives.duplicate(true)
	# Day N's END_DAY phase pauses the clock via `_pause_time_for_end_day`.
	# Without an unpause + rewind here, Day N+1 inherits that paused state
	# and `_advance_to_open_hour_if_early` returns early because the clock
	# is already past 9 AM. Setting `game_time_minutes` directly mirrors the
	# pattern used in `time_system.advance_to_next_day` (and the time-system
	# tests) without re-entering that helper's day++/day_started side effects.
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys != null:
		time_sys.set_speed(TimeSystem.SpeedTier.NORMAL)
		time_sys.game_time_minutes = 7.0 * 60.0
	# Reset scene-side state that Day N's chain mutated at runtime
	# (customer hidden by exit tween, pickup box opened, floor mat hidden).
	# Must run before `_apply_objective_gating` so the active stage's target
	# parent is visible the moment its Interactable is re-enabled.
	_reset_scene_for_day(day)
	var all_day_events: Array = []
	if _events_by_day.has(day):
		all_day_events = (_events_by_day[day] as Array).duplicate()
	_day_events.clear()
	for event_variant: Variant in all_day_events:
		if event_variant is Dictionary:
			_day_events.append(event_variant as Dictionary)
	if _day_events.size() > TARGET_EVENTS_PER_DAY:
		_day_events = _day_events.slice(0, TARGET_EVENTS_PER_DAY)
	_current_event_index = 0
	_resolved_events_today = 0
	_customers_helped_today = 0
	_items_stocked_today = 0
	_sales_today = 0
	_customer_inventory_transactions.clear()
	_summary_spawned = false
	_completed_objectives.clear()
	_pending_result_effects.clear()
	BetaRunState.carrying_stock = false
	_reset_beta_inventory_overlay()
	# Start at the head of the chain.
	_stage = STAGE_TALK_TO_CUSTOMER
	if not _day_events.is_empty():
		_active_event = _day_events[0]
	else:
		_active_event = {}
	_apply_customer_profile(_active_event)
	# §F-PUNCH3 — Beta day-1 starts at 9 AM (mall open) per spec, not the
	# 7 AM PRE_OPEN default. TimeSystem ships with `_DAY_START_MINUTES =
	# 420.0` (7 AM); jump forward to 540 min so the first chain step
	# happens after the mall opens. Idempotent: only advances if the
	# clock is currently before 9 AM (e.g. fresh game), so a save loaded
	# at 9:30 AM stays put.
	_advance_to_open_hour_if_early()
	_update_objective_rail()
	_apply_objective_gating()
	_emit_opening_day_toast(day)


## Keeps beta and generic day readers aligned without firing `day_started`.
## The world bootstrap and summary-continue path already emit that signal;
## this bridge only updates silent state holders so HUD labels, economy
## transaction days, saves, and beta summary payloads all agree on Day 1+.
func _sync_beta_day(day_number: int) -> void:
	var normalized_day: int = maxi(day_number, 1)
	BetaRunState.day = normalized_day
	GameManager.set_current_day(normalized_day)
	GameState.day = normalized_day


## Day-1 inventory is a beta display overlay: the controller owns the visible
## back-room/shelf counts, and InventorySystem remains out of the scripted
## quantity loop. Reset the overlay at day start so stale shelf/back-room
## counts from the prior beta day cannot bleed into HUD or audit surfaces.
func _reset_beta_inventory_overlay() -> void:
	EventBus.beta_shelf_count_changed.emit(0)
	EventBus.beta_backroom_count_changed.emit(0)
	EventBus.beta_carry_changed.emit("")


func _emit_opening_day_toast(day_number: int) -> void:
	if day_number != 1:
		return
	EventBus.toast_requested_with_id.emit(
		&"beta_day1_started",
		"Day 1 started. Serve your first customer at the register.",
		&"info",
		5.0,
	)


func _advance_to_open_hour_if_early() -> void:
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys == null:
		return
	const _OPEN_TIME_MINUTES: float = 9.0 * 60.0
	var now: float = float(time_sys.game_time_minutes)
	if now >= _OPEN_TIME_MINUTES:
		return
	time_sys.advance_by_minutes(_OPEN_TIME_MINUTES - now)


## Restores the scene-side state Day N mutated at runtime so Day N+1 can
## walk the same chain. The exit tween hid `BetaDayOneCustomer` and faded
## its body alpha; the back-room pickup swapped the closed box for its
## open base and hid both the closed-box mesh and label. Idempotent — Day 1
## sees fresh authored state and the resets are no-ops.
func _reset_scene_for_day(_day_number: int) -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var customer: Node = store.get_node_or_null("BetaDayOneCustomer")
	if customer is Node3D:
		var customer_3d: Node3D = customer as Node3D
		if _initial_customer_position_captured:
			customer_3d.position = _initial_customer_position
		customer_3d.visible = true
		# Body material was duplicated and alpha-tweened to 0 by
		# `_animate_customer_exit`; restore opacity so the silhouette renders
		# again on Day N+1.
		var body: MeshInstance3D = (
			customer_3d.get_node_or_null("CustomerProxy/Body") as MeshInstance3D
		)
		if body != null and body.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = body.material_override as StandardMaterial3D
			var albedo: Color = mat.albedo_color
			albedo.a = 1.0
			mat.albedo_color = albedo
	var floor_mat: Node = store.get_node_or_null("Checkout/BetaCustomerFloorMat")
	if floor_mat is Node3D:
		(floor_mat as Node3D).visible = true
	var pickup: Node = store.get_node_or_null("BetaBackroomPickup")
	if pickup is Node3D:
		var pickup_3d: Node3D = pickup as Node3D
		pickup_3d.visible = true
		var closed: Node = pickup_3d.get_node_or_null("StockBox")
		var open: Node = pickup_3d.get_node_or_null("StockBoxOpen")
		var label: Node = pickup_3d.get_node_or_null("StockBoxLabel")
		if closed is Node3D:
			(closed as Node3D).visible = true
		if open is Node3D:
			(open as Node3D).visible = false
		if label is Node3D:
			(label as Node3D).visible = true
	_reset_restock_shelf_visuals()


## Marks the current stage's objective complete, advances the in-game
## clock by its `time_cost_minutes`, and transitions to the next stage in
## the chain. Idempotent — calling twice for the same objective is a
## no-op (the `_completed_objectives` guard at each call site already
## handles this; keeping the explicit check here too defends against
## external misuse).
func _complete_current_objective() -> void:
	var entry: Dictionary = _objective_for_stage(_stage)
	if entry.is_empty():
		return
	var objective_id: StringName = StringName(str(entry.get("id", "")))
	if objective_id == &"":
		return
	if _completed_objectives.has(objective_id):
		return
	_completed_objectives[objective_id] = true
	# §EH-13 — emit unconditionally; see `on_beta_day_end_requested`.
	EventBus.beta_objective_completed.emit(objective_id)
	# Past-tense, human-readable companion broadcast for the on-screen
	# event log. Distinct copy from the rail label (`entry["label"]`) on
	# purpose — the rail uses imperative present tense ("Talk to the
	# customer …") while the log records what *just happened*. BRAINDUMP's
	# 'Bad' example shows the rail label echoed into the log on start; the
	# completion-only emit avoids that pattern.
	EventBus.objective_completed.emit(objective_id, _objective_completion_label(objective_id))
	_grant_objective_unlocks(objective_id)
	var time_cost: int = int(entry.get("time_cost_minutes", 0))
	if time_cost > 0:
		var time_sys: TimeSystem = GameManager.get_time_system()
		if time_sys != null:
			time_sys.advance_by_minutes(float(time_cost))
	_advance_stage_after(objective_id)


## Advances `_stage` to the entry that follows `completed_id` in
## `_objectives`. Wrapping over the end of the array stays at END_DAY so
## the close-day prompt is the terminal state.
func _advance_stage_after(completed_id: StringName) -> void:
	var idx: int = -1
	for i: int in range(_objectives.size()):
		if StringName(str(_objectives[i].get("id", ""))) == completed_id:
			idx = i
			break
	if idx == -1 or idx + 1 >= _objectives.size():
		_stage = STAGE_END_DAY
	else:
		_stage = StringName(str(_objectives[idx + 1].get("stage", STAGE_END_DAY)))
	if _stage == STAGE_END_DAY:
		_pause_time_for_end_day()
		_start_close_time_watcher()
	_update_objective_rail()
	_apply_objective_gating()


func _grant_objective_unlocks(objective_id: StringName) -> void:
	var grants: Array = _OBJECTIVE_UNLOCK_GRANTS.get(String(objective_id), [])
	for raw_id: Variant in grants:
		_grant_unlock(StringName(str(raw_id)))


func _grant_unlock(unlock_id: StringName) -> void:
	if unlock_id.is_empty():
		return
	UnlockSystemSingleton.grant_unlock(unlock_id)


## §F-FIX1 — When the chain hits END_DAY, freeze the clock so the player
## can walk to the register at their own pace and close on their own E-press.
## Earlier auto-jump-to-17:00 was harmful: TimeSystem auto-`_end_day`s the
## moment `game_time_minutes >= 17:00`, which slammed the player straight
## to the day summary before they could interact with the close-day trigger.
## Spec: "the game intentionally jumps to closing time" — implemented as
## a soft pause; the player's E-press is what ends the day.
func _pause_time_for_end_day() -> void:
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys == null:
		return
	# §EH-14 — `TimeSystem.set_speed` is part of the typed `TimeSystem` class
	# (`game/scripts/systems/time_system.gd:163`); a `has_method` guard would
	# silently turn a rename regression into a failure-to-pause. Drop the
	# guard so any signature drift fails GDScript parse instead.
	time_sys.set_speed(TimeSystem.SpeedTier.PAUSED)


## Surfaces a one-shot "closing time" cue when the chain enters END_DAY.
## Routed through `toast_requested` (auto-dismissing card, top-right) so it
## reads as a transient alert; the persistent cue is the objective rail's
## "Close the day at the register." which already stays visible until the
## player closes out. `_pause_time_for_end_day` freezes the clock right
## before this fires, so the toast lands once and the player isn't racing
## a moving deadline.
func _start_close_time_watcher() -> void:
	EventBus.toast_requested.emit("Closing time. Wrap up at the register.", &"info", 4.0)


## Public read-only accessor for the current stage. Used by the debug
## overlay, day-readiness audit, and tests to inspect chain state without
## reaching into the private `_stage` field.
func current_stage() -> StringName:
	return _stage


func force_start_real_day_for_tests() -> void:
	BetaRunState.preopening_complete = true
	_start_day(1)


## Returns the `_objectives` row whose `stage` matches `target_stage`, or
## an empty dict for unknown stages.
func _objective_for_stage(target_stage: StringName) -> Dictionary:
	for entry: Dictionary in _objectives:
		if StringName(str(entry.get("stage", ""))) == target_stage:
			return entry
	return {}


## Test seam — read-only access to the completion set so GUT tests can
## verify a stage actually flipped its objective complete without poking
## the private dictionary directly.
func is_objective_completed(objective_id: StringName) -> bool:
	return _completed_objectives.has(objective_id)


## Past-tense, human-readable label for the bottom-left event log surface.
## Distinct from the rail's imperative present-tense `_objectives[i].label`
## ("Talk to the customer at the register.") — logging the rail copy on
## completion would echo the active-objective text and reproduce the
## BRAINDUMP 'Bad' pattern. Unknown ids return a generic past-tense fallback.
func _objective_completion_label(objective_id: StringName) -> String:
	match objective_id:
		&"talk_to_manager":
			return "Manager briefing complete."
		&"check_register":
			return "Register checked."
		&"check_back_room_inventory":
			return "Back room inventory checked."
		&"training_stock_shelf":
			return "Training shelf stocked."
		&"practice_customer":
			return "Practice customer complete."
		&"open_store":
			return "Store opened."
		&"talk_to_customer":
			return "Customer served."
		&"back_room_inventory":
			return "Delivery checked."
		&"stock_shelf":
			return "Shelf stocked."
		&"close_day":
			return "Day closed."
		_:
			return "%s completed." % String(objective_id)


## Snapshot of the Day-1 FSM for the debug overlay and the F8 console
## dump. One source of truth: the overlay reads from this dict and the
## state dump prints it, so they can never disagree about what the FSM
## thinks is happening.
func get_state_snapshot() -> Dictionary:
	var current: Dictionary = _objective_for_stage(_stage)
	var time_minutes: float = -1.0
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys != null:
		time_minutes = time_sys.game_time_minutes
	return {
		"day": BetaRunState.day,
		"cash": BetaRunState.cash,
		"carrying_stock": BetaRunState.carrying_stock,
		"stage": String(_stage),
		"active_objective_id": String(current.get("id", "")),
		"active_objective_label": String(current.get("label", "")),
		"completed_objectives": _completed_objectives.duplicate(),
		"can_close_day": _all_required_objectives_completed() and _stage == STAGE_END_DAY,
		"close_day_reason": close_day_disabled_reason() if _stage != STAGE_END_DAY else "ready",
		"objective_target_diagnostic": _objective_target_diagnostic,
		"time_minutes": time_minutes,
		"customers_helped": _customers_helped_today,
		"sales_today": _sales_today,
	}


func _apply_customer_profile(event_data: Dictionary) -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var node: Node = store.get_node_or_null("BetaDayOneCustomer/Interactable")
	if node is Interactable:
		var customer_name: String = str(event_data.get("customer_name", "customer")).strip_edges()
		if customer_name.is_empty():
			customer_name = "customer"
		(node as Interactable).display_name = customer_name.to_lower()


func _update_objective_rail() -> void:
	if _stage == STAGE_VIC_NOTE:
		# `key` is non-empty so StoreReadyContract invariant 10
		# (objective_matches_action) passes the keyboard-shortcut path while
		# the note modal is up and no on-stage Interactable is a focal point.
		# `morning_note_panel._unhandled_input` dismisses on `interact` (E),
		# so this is also the real input the player will press.
		(
			EventBus
			. objective_changed
			. emit(
				{
					"text": "Read Vic's morning note.",
					"action": "",
					"key": "E",
					"steps": _build_steps_payload(),
				}
			)
		)
		return
	var entry: Dictionary = _objective_for_stage(_stage)
	if entry.is_empty():
		EventBus.objective_changed.emit({"hidden": true})
		return
	(
		EventBus
		. objective_changed
		. emit(
			{
				"text": str(entry.get("label", "")),
				"action": str(entry.get("action", "")),
				"key": str(entry.get("key", "E")),
				"steps": _build_steps_payload(),
			}
		)
	)


## Builds the multi-step progress payload for the rail. Each `_objectives`
## row becomes an `{id, text, state}` entry where `state` is "completed" if
## the row's id is in `_completed_objectives`, "active" if its stage matches
## `_stage`, or "future" otherwise. During STAGE_VIC_NOTE every entry is
## "future" (nothing complete, no chain row active yet).
##
## The `id` field lets consumers (`BetaRightPanel`) resolve the source
## objective without reverse-matching on `text`. ObjectiveRail reads `text`
## + `state` only and ignores extra keys, so adding `id` is non-breaking.
func _build_steps_payload() -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for entry: Dictionary in _objectives:
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		var entry_stage: StringName = StringName(str(entry.get("stage", "")))
		var state: String = "future"
		if _completed_objectives.has(entry_id):
			state = "completed"
		elif entry_stage == _stage:
			state = "active"
		(
			steps
			. append(
				{
					"id": String(entry_id),
					"text": str(entry.get("label", "")),
					"state": state,
				}
			)
		)
	return steps


## Disables every Interactable under the store, then re-enables the
## current chain row's `target_path`. Two exceptions:
##   * Close-day requires `_stage == END_DAY` AND all required objectives
##     done — `_pause_time_for_end_day()` is what stops the world from
##     auto-ending at 17:00, so no time gate here.
##   * The console stack stays interactable any time the player notices
##     it (until they've inspected it once today). It is ambient flavor,
##     not a gated objective; gating it would make the mystery feel like
##     a checklist item.
func _apply_objective_gating() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	_refresh_interactable_prompt_copy(store)
	_objective_target_diagnostic = ""
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and _is_descendant_of(node, store):
			(node as Interactable).enabled = false
	_set_interactable_enabled(store, "EntranceDoor/Interactable", false)
	var active_entry: Dictionary = _objective_for_stage(_stage)
	if not active_entry.is_empty():
		var active_path: String = str(active_entry.get("target_path", ""))
		if not _target_path_is_valid(store, active_path):
			_objective_target_diagnostic = ("Invalid objective target path: %s" % active_path)
			_report_invalid_target_path_once(active_path)
			return
	for entry: Dictionary in _objectives:
		var entry_stage: StringName = StringName(str(entry.get("stage", "")))
		var path: String = str(entry.get("target_path", ""))
		if path.is_empty():
			continue
		var is_active: bool = entry_stage == _stage
		if entry_stage == STAGE_END_DAY:
			is_active = is_active and _all_required_objectives_completed()
		_set_interactable_enabled(store, path, is_active)
	_refresh_interactable_prompt_copy(store)
	# Console stack — ambient flavor, always interactable until inspected.
	_set_interactable_enabled(store, "BetaHiddenClue/Interactable", false)
	# Register status indicator — passive disabled-reason hint shown during
	# the back-room and stocking phases. Kept enabled across every stage so
	# the InteractionRay's raycast can still hover it (the rest of the gating
	# sweep above just disabled it). `can_interact()` on the node itself
	# always returns false, so E-presses never resolve here regardless of
	# stage; the only player-visible effect is the muted hint copy.
	_set_interactable_enabled(store, "checkout_counter/RegisterStatusIndicator", true)


func _refresh_interactable_prompt_copy(store: Node) -> void:
	var customer: Interactable = (
		store.get_node_or_null("BetaDayOneCustomer/Interactable") as Interactable
	)
	if customer != null:
		if _stage == STAGE_TRAINING_TALK_MANAGER:
			customer.display_name = "manager"
			customer.prompt_text = "Talk to"
			customer.action_verb = "Talk"
			customer.enabled = true
		elif _stage == STAGE_TRAINING_PRACTICE_CUSTOMER:
			customer.display_name = "practice customer"
			customer.prompt_text = "Run"
			customer.action_verb = "Practice"
			customer.enabled = true
		else:
			customer.display_name = "customer"
			customer.prompt_text = "Talk to"
			customer.action_verb = "Talk"
	var register: Interactable = (
		store.get_node_or_null("BetaDayEndTrigger/Interactable") as Interactable
	)
	if register != null:
		match _stage:
			STAGE_TRAINING_CHECK_REGISTER:
				register.display_name = "register"
				register.prompt_text = "Check"
				register.action_verb = "Check"
				register.enabled = true
			STAGE_TRAINING_OPEN_STORE:
				register.display_name = "store"
				register.prompt_text = "Open"
				register.action_verb = "Open"
				register.enabled = true
			_:
				register.display_name = "day"
				register.prompt_text = "Close"
				register.action_verb = "End"


func _target_path_is_valid(root: Node, path: String) -> bool:
	if path.is_empty():
		return false
	return root.get_node_or_null(path) is Interactable


func _report_invalid_target_path_once(path: String) -> void:
	if _reported_invalid_target_paths.has(path):
		return
	_reported_invalid_target_paths[path] = true
	push_warning(_objective_target_diagnostic)


func _all_required_objectives_completed() -> bool:
	for entry: Dictionary in _objectives:
		if StringName(str(entry.get("stage", ""))) == STAGE_END_DAY:
			continue
		if not bool(entry.get("required", false)):
			continue
		var entry_id: StringName = StringName(str(entry.get("id", "")))
		if not _completed_objectives.has(entry_id):
			return false
	return true


## Builds the end-of-day `shift_note` from the day's completion state. When
## every required chain row was completed the panel gets the grounded
## "you made it through" baseline. When any required row was skipped — only
## reachable if the close-day gate is ever relaxed beyond
## `_all_required_objectives_completed()` — the note names the skipped work
## so the summary cannot read as a clean wrap-up. BRAINDUMP rule: if closing
## early is allowed, the summary must clearly say that the player skipped
## required work.
func _build_shift_note() -> String:
	var skipped_phrases: Array[String] = []
	if not _completed_objectives.has(&"talk_to_customer"):
		skipped_phrases.append("helping the customer at the register")
	if not _completed_objectives.has(&"back_room_inventory"):
		skipped_phrases.append("picking up the back room delivery")
	if not _completed_objectives.has(&"stock_shelf"):
		skipped_phrases.append("restocking the used shelf")
	if skipped_phrases.is_empty():
		return (
			"You made it through your first shift. "
			+ "The store still feels off, but at least the shelves aren't empty."
		)
	return "You closed without %s." % _join_phrases(skipped_phrases)


## Joins phrases as "A", "A and B", or "A, B, and C" so the shift-note copy
## reads as a complete sentence regardless of how many objectives were
## skipped.
func _join_phrases(phrases: Array[String]) -> String:
	var count: int = phrases.size()
	if count == 0:
		return ""
	if count == 1:
		return phrases[0]
	if count == 2:
		return "%s and %s" % [phrases[0], phrases[1]]
	var head: String = ", ".join(phrases.slice(0, count - 1))
	return "%s, and %s" % [head, phrases[count - 1]]


func _ensure_panels() -> void:
	if _decision_panel == null:
		_decision_panel = BetaDecisionCardPanel.new()
		_ui_root().add_child(_decision_panel)
	if _customer_result_panel == null:
		_customer_result_panel = BetaCustomerResultPanelScript.new() as ModalPanel
		_ui_root().add_child(_customer_result_panel)
	if _summary_panel == null:
		_summary_panel = BetaDaySummaryPanel.new()
		_ui_root().add_child(_summary_panel)
	if _day_two_placeholder_panel == null:
		_day_two_placeholder_panel = (
			BetaDayTwoPlaceholderPanelScript.new() as ModalPanel
		)
		_ui_root().add_child(_day_two_placeholder_panel)
	if _vic_note_panel == null:
		_vic_note_panel = BetaManagerNotePanel.new()
		_ui_root().add_child(_vic_note_panel)
	# `BetaRightPanel` and `BetaEventLogPanel` are owned by the `BetaHUD`
	# autoload — see the `BetaHUD.activate(day)` call in `_ready`. They are
	# spawned once at boot and persist across day-controller teardown.
	if _objective_target_highlight == null:
		_objective_target_highlight = BetaObjectiveTargetHighlight.new()
		_objective_target_highlight.name = "BetaObjectiveTargetHighlight"
		_ui_root().add_child(_objective_target_highlight)
	if _debug_overlay == null:
		_debug_overlay = CanvasLayer.new()
		_debug_overlay.set_script(BetaDebugOverlayScript)
		_debug_overlay.name = "BetaDebugOverlay"
		_ui_root().add_child(_debug_overlay)
	if _screenshot_helper == null:
		_screenshot_helper = CanvasLayer.new()
		_screenshot_helper.set_script(BetaScreenshotHelperScript)
		_screenshot_helper.name = "BetaScreenshotHelper"
		_ui_root().add_child(_screenshot_helper)
	if _close_day_panel == null:
		_close_day_panel = (CloseDayConfirmationPanelScene.instantiate() as CanvasLayer)
		_close_day_panel.name = "BetaCloseDayConfirmationPanel"
		_ui_root().add_child(_close_day_panel)
		# BRAINDUMP cancel-button copy: "Not Yet" reads softer than "Cancel"
		# while the chain still treats cancel as a no-op (the player can re-
		# press E to retry). Path matches the .tscn structure: layered
		# Root/Panel/Margin/VBox/ButtonRow.
		var cancel_button: Button = (
			_close_day_panel.get_node_or_null("Root/Panel/Margin/VBox/ButtonRow/CancelButton")
			as Button
		)
		if cancel_button != null:
			cancel_button.text = "Not Yet"


func _connect_panel_signals() -> void:
	if not _decision_panel.choice_selected.is_connected(_on_choice_selected):
		_decision_panel.choice_selected.connect(_on_choice_selected)
	var result_callback := Callable(self, "_on_customer_result_acknowledged")
	if not _customer_result_panel.is_connected(&"result_acknowledged", result_callback):
		_customer_result_panel.connect(&"result_acknowledged", result_callback)
	if not _summary_panel.continue_pressed.is_connected(_on_summary_continue):
		_summary_panel.continue_pressed.connect(_on_summary_continue)
	if not _summary_panel.replay_pressed.is_connected(_on_summary_replay):
		_summary_panel.replay_pressed.connect(_on_summary_replay)
	if not _summary_panel.main_menu_pressed.is_connected(_on_summary_main_menu):
		_summary_panel.main_menu_pressed.connect(_on_summary_main_menu)
	var placeholder_main_menu := Callable(self, "_on_day_two_placeholder_main_menu")
	var placeholder_restart := Callable(self, "_on_day_two_placeholder_restart")
	if not _day_two_placeholder_panel.is_connected(
		&"main_menu_pressed",
		placeholder_main_menu
	):
		_day_two_placeholder_panel.connect(&"main_menu_pressed", placeholder_main_menu)
	if not _day_two_placeholder_panel.is_connected(&"restart_pressed", placeholder_restart):
		_day_two_placeholder_panel.connect(&"restart_pressed", placeholder_restart)
	if not _vic_note_panel.note_dismissed.is_connected(_on_vic_note_dismissed):
		_vic_note_panel.note_dismissed.connect(_on_vic_note_dismissed)
	# Permanent (not ONE_SHOT) — the player may cancel the modal and re-
	# request close-day, so the listener has to survive every cycle.
	if not EventBus.day_close_confirmed.is_connected(_on_day_close_confirmed):
		EventBus.day_close_confirmed.connect(_on_day_close_confirmed)


func _ui_root() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return get_tree().root
	var ui_layer: Node = scene.find_child("UILayer", true, false)
	if ui_layer != null:
		return ui_layer
	return scene


func _free_owned_ui_nodes() -> void:
	_free_owned_ui_node(_decision_panel)
	_decision_panel = null
	_free_owned_ui_node(_customer_result_panel)
	_customer_result_panel = null
	_free_owned_ui_node(_summary_panel)
	_summary_panel = null
	_free_owned_ui_node(_vic_note_panel)
	_vic_note_panel = null
	_free_owned_ui_node(_objective_target_highlight)
	_objective_target_highlight = null
	_free_owned_ui_node(_debug_overlay)
	_debug_overlay = null
	_free_owned_ui_node(_screenshot_helper)
	_screenshot_helper = null
	_free_owned_ui_node(_close_day_panel)
	_close_day_panel = null


func _free_owned_ui_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if (
		node is ModalPanel
		and bool(node.get("_focus_pushed"))
		and InputFocus.current() == InputFocus.CTX_MODAL
	):
		node.call("close")
	node.free()


## §EH-12 — Beta day-1 / customer-events content is shipped under
## `game/content/beta/`. Open failure on a present file or a parse failure
## means a content regression (corrupt JSON, encoding break, or a strip pass
## that left the file in a broken state); both surface as `push_error` so
## CI's stderr `^ERROR:` scan fails the build instead of letting the player
## boot into a customerless Day 1. File-not-found is downgraded to
## `push_warning` because future content strips may legitimately drop the
## Day-2 placeholder ahead of authoring its real beats. The `{}` fallback is
## preserved on every branch so the chain still flows (no events shows up
## as an empty `_day_events` array — the player still gets a playable
## back-room → stock → close-day loop).
## See docs/audits/error-handling-report.md §EH-12.
func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("BetaDayOneController._load_json: missing content file %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error(
			(
				"BetaDayOneController._load_json: cannot open %s (FileAccess err=%d)"
				% [path, FileAccess.get_open_error()]
			)
		)
		return {}
	if file.get_length() > MAX_JSON_FILE_BYTES:
		file.close()
		push_error(
			(
				"BetaDayOneController._load_json: %s exceeds maximum supported size (%d bytes)"
				% [path, MAX_JSON_FILE_BYTES]
			)
		)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("BetaDayOneController._load_json: malformed JSON in %s" % path)
		return {}
	return parsed


func _print_interactable_debug_list() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var rows: Array[String] = []
	for node: Node in tree.get_nodes_in_group("interactable"):
		if node is Interactable:
			var interactable: Interactable = node as Interactable
			rows.append("- %s" % interactable.resolve_interactable_id())
	rows.sort()
	print("[BetaInteractables]\n%s" % "\n".join(rows))


func _apply_minimal_scope() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	for node_path: String in _HIDDEN_NOISE_PATHS:
		var target: Node = store.get_node_or_null(NodePath(node_path))
		if target is Node3D:
			(target as Node3D).visible = false


## Disables `MomentsTray` for the beta loop so the bottom-right corner
## stays clear for the Today checklist. The tray is harmless when empty
## but any ambient scheduler (NPC thoughts, milestone bleed-through)
## that emits `EventBus.moment_displayed` would surface a card on top
## of — or in place of — the checklist. Safe no-op when no tray is
## present (unit tests that don't load `game_world.tscn`).
func _suppress_moments_tray() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group("moments_tray"):
		if node is MomentsTray:
			(node as MomentsTray).disable_for_beta()


func _set_interactable_enabled(root: Node, path: String, enabled: bool) -> void:
	var node: Node = root.get_node_or_null(path)
	if node is Interactable:
		(node as Interactable).enabled = enabled


func _apply_beta_only_strip() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	for child: Node in store.get_children():
		if _is_kept_root_node(child.name):
			continue
		_disable_interactables_in_subtree(child)
		if child is Node3D:
			(child as Node3D).visible = false


func _disable_interactables_in_subtree(node: Node) -> void:
	if node is Interactable:
		(node as Interactable).enabled = false
	for child: Node in node.get_children():
		_disable_interactables_in_subtree(child)


func _is_kept_root_node(node_name: StringName) -> bool:
	return _BETA_KEEP_ROOT_NODES.has(node_name)


## Builds the customer's visible body proxy and resizes the Interactable's
## CollisionShape3D so the visible mesh, the trigger volume, and the world
## position are anchored at the same Node3D origin. The .tscn drives
## BetaDayOneCustomer.position — this method does not move the node.
##
## The body is a single human-scaled CapsuleMesh under `CustomerProxy/Body`
## so the silhouette reads as "a person standing here" from across the
## store. The .tscn-authored `CustomerBody` is freed on first run because
## a duplicate body mesh at the same anchor would z-fight and double the
## visible footprint.
## See §EH-27. `_store_root() == null` is the documented test seam; a
## missing `BetaDayOneCustomer` node is a wiring regression (the node is
## authored in `retro_games.tscn` for the beta) — fail loud.
func _configure_beta_customer() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var customer_node_ref: Node = store.get_node_or_null("BetaDayOneCustomer")
	if not (customer_node_ref is Node3D):
		push_error(
			(
				"BetaDayOneController: `BetaDayOneCustomer` Node3D missing under store "
				+ "root '%s'; beta customer setup skipped." % store.name
			)
		)
		return
	var customer_node: Node3D = customer_node_ref as Node3D

	# Capture the authored register-side position the first time we configure
	# the customer so `_reset_scene_for_day` can put them back here on Day 2
	# after the Day-1 exit tween moved them to the entrance threshold.
	if not _initial_customer_position_captured:
		_initial_customer_position = customer_node.position
		_initial_customer_position_captured = true

	# The .tscn ships a CustomerBody mesh next to our runtime proxy. The
	# runtime proxy is the source of truth for the visible silhouette
	# (human-scaled capsule, warm taupe), so drop the authored mesh to
	# avoid a doubled footprint at the register.
	var legacy_body: Node = customer_node.get_node_or_null("CustomerBody")
	if legacy_body != null:
		legacy_body.queue_free()

	var proxy_root_ref: Node = customer_node.get_node_or_null("CustomerProxy")
	var proxy_root: Node3D
	if proxy_root_ref is Node3D:
		proxy_root = proxy_root_ref as Node3D
	else:
		proxy_root = Node3D.new()
		proxy_root.name = "CustomerProxy"
		customer_node.add_child(proxy_root)

	# Earlier proxy revisions used a separate Torso + Head + Marker. Drop
	# them on hot-reload so the tree converges on the single Body capsule.
	for stale_name: String in ["Torso", "Head", "Marker"]:
		var stale: Node = proxy_root.get_node_or_null(stale_name)
		if stale != null:
			stale.queue_free()

	var body_ref: Node = proxy_root.get_node_or_null("Body")
	if not (body_ref is MeshInstance3D):
		var body_mesh := MeshInstance3D.new()
		body_mesh.name = "Body"
		proxy_root.add_child(body_mesh)
		body_ref = body_mesh
	var body: MeshInstance3D = body_ref as MeshInstance3D
	var body_shape := CapsuleMesh.new()
	body_shape.radius = 0.30
	body_shape.height = 1.78
	body.mesh = body_shape
	# Capsule center at half-height puts the base at floor (Y=0) and the
	# crown at Y≈1.78 — reads as a person standing at the counter from
	# across the store, not a small floating pill.
	body.position = Vector3(0.0, 0.89, 0.0)
	var body_mat := StandardMaterial3D.new()
	# Warm taupe: a human-proxy tone that won't be confused with grey
	# placeholder geometry or with the warm-brown counter trim behind it.
	body_mat.albedo_color = Color(0.62, 0.50, 0.42, 1.0)
	body_mat.roughness = 0.85
	body.material_override = body_mat

	# Resize the Interactable trigger so the screen-center ray hits it from
	# typical approach distances, not just nose-to-chest. The authored shape
	# in the .tscn is a 1.5 m box centered on the node origin (Y=-0.75 to
	# Y=+0.75 — floor + lower legs), which the player's eye-level ray
	# (camera at Y=1.7) flies over until the player is right on top of the
	# customer.
	#
	# The replacement capsule is intentionally LARGER than the visible
	# proxy: ±0.55 m horizontal, Y=0–2.0, so any aim near the customer's
	# silhouette registers a hit. The visible torso/head are still small
	# (matches the brief's "smaller scale, stands at counter") — the trigger
	# just doesn't have to be flattering.
	#
	# Deferred via `call_deferred` so it runs after `Interactable._ready`
	# has finished reparenting the CollisionShape3D into its generated
	# `InteractionArea` (game/scripts/components/interactable.gd:271).
	# Without the defer, our edit would race that reparent depending on
	# sibling tree order; deferring guarantees we touch the post-reparent
	# node and our shape sticks.
	call_deferred("_resize_customer_trigger", customer_node)


## Deferred companion to `_configure_beta_customer`. Runs after
## `Interactable._ready` has reparented the CollisionShape3D into the
## generated `InteractionArea`, so `find_child` resolves the same node
## regardless of sibling _ready ordering. The capsule is sized larger than
## the visible mesh so the screen-center ray reliably hits the trigger at
## the InteractionRay's full 2.5 m range, not just at zero distance.
## See §EH-27. The `is_instance_valid` guard handles the deferred-call
## race where the customer node was freed before this fires. The missing
## `Interactable` / `CollisionShape3D` branches are wiring regressions —
## fail loud so the trigger never silently stays at its tiny default size
## (which makes the customer unhittable from the aisle).
func _resize_customer_trigger(customer_node: Node3D) -> void:
	if not is_instance_valid(customer_node):
		return
	var interactable_node: Node = customer_node.get_node_or_null("Interactable")
	if interactable_node == null:
		push_error(
			(
				"BetaDayOneController: BetaDayOneCustomer is missing its "
				+ "`Interactable` child; customer cannot be aimed at."
			)
		)
		return
	var collision: CollisionShape3D = (
		interactable_node.find_child("CollisionShape3D", true, false) as CollisionShape3D
	)
	if collision == null:
		push_error(
			(
				"BetaDayOneController: BetaDayOneCustomer/Interactable has no "
				+ "CollisionShape3D descendant; trigger resize skipped."
			)
		)
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.0
	collision.shape = capsule
	collision.position = Vector3(0.0, 1.0, 0.0)


func _store_root() -> Node:
	var root: Node = get_parent()
	if root != null:
		return root
	return get_tree().current_scene


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	if node == null or ancestor == null:
		return false
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


# §F-L1/L3/L4 — Visible-feedback helpers ─────────────────────────────────────


## §F-PUNCH4 — Narrates the customer's exit so the player can tell if
## the choice produced a sale. Reads the choice's `cash` effect: positive
## delta → "Sale complete: +$X"; zero or negative → a softer flavor line.
## Negative cash (refunds) currently fall through to the same "no sale"
## copy because there's no Day-1 refund path; a future scene with a
## negative-cash choice can branch here.
func _emit_customer_outcome_toast(effects: Dictionary) -> void:
	var cash_delta: int = int(effects.get("cash", 0))
	if cash_delta > 0:
		# `&"sale"` paints a green left border per the toast visual contract —
		# matches the BRAINDUMP "Sale complete: +$18" example.
		EventBus.toast_requested.emit("Sale complete: +$%d" % cash_delta, &"sale", 3.0)
	else:
		EventBus.toast_requested.emit("She thanked you and walked off.", &"info", 3.0)


## Swaps the BetaBackroomPickup branch from its closed-box state to its
## open-box state on pickup: `StockBox` and `StockBoxLabel` flip invisible
## while the pre-authored `StockBoxOpen` sibling becomes visible. This
## replaces the earlier alpha-fade-to-invisible because a vanishing box
## broke the grounded-retail tone — the floor read as if the box never
## existed. The two-mesh swap leaves a flat opened cardboard base in
## place so the player sees that *they* opened it. Idempotent: skips if
## the closed branch is already invisible.
func _hide_stock_box_in_world() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var pickup: Node = store.get_node_or_null("BetaBackroomPickup")
	if not (pickup is Node3D):
		return
	var pickup_3d: Node3D = pickup as Node3D
	var closed: Node = pickup_3d.get_node_or_null("StockBox")
	var open: Node = pickup_3d.get_node_or_null("StockBoxOpen")
	var label: Node = pickup_3d.get_node_or_null("StockBoxLabel")
	if closed is Node3D:
		(closed as Node3D).visible = false
	if open is Node3D:
		(open as Node3D).visible = true
	if label is Node3D:
		(label as Node3D).visible = false


## Clears beta-only restock shelf props back to the authored empty state.
## Production shelf visuals remain owned by ShelfSlot; these BetaShelfItem
## meshes are display-only feedback for the scripted Day-1 stocking beat.
func _reset_restock_shelf_visuals() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var shelf: Node = store.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	for child: Node in shelf.get_children():
		if String(child.name).begins_with("BetaShelfItem"):
			child.queue_free()
	var overlay: Node = shelf.get_node_or_null("EmptyOverlay")
	if overlay is Node3D:
		(overlay as Node3D).visible = true


## Walks BetaDayOneCustomer from the register out through the entrance
## door before hiding the node, so the register reads as "they thanked
## the player and left" rather than "they popped out of existence."
##
## Path: a two-leg position tween on the parent Node3D — leg 1 swings
## clear of the counter's right edge, leg 2 carries them past the front
## wall threshold. The body's albedo alpha tweens to 0 over the second
## leg so the silhouette dissolves at the door instead of snapping out.
## The customer-spot floor mat hides at leg 2 start so it doesn't sit on
## the floor with no one standing on it.
##
## Tween coordinates are in world space and target the +Z entrance door
## (front wall sits at Z≈10.05; door pivot at Z=10). The customer parks
## at world (5.35, 0, 8.5), and `look_at` rotates them to face the exit
## before leg 1 begins. The Interactable is disabled immediately so the
## player can't re-trigger the prompt while the customer is mid-walk.
func _animate_customer_exit() -> void:
	var store: Node = _store_root()
	if store == null:
		return
	var customer: Node = store.get_node_or_null("BetaDayOneCustomer")
	if customer == null:
		return
	var inter: Node = customer.get_node_or_null("Interactable")
	if inter is Interactable:
		(inter as Interactable).enabled = false
	if not (customer is Node3D):
		return
	var customer_3d: Node3D = customer as Node3D
	if not customer_3d.visible:
		return

	# Face the exit before stepping off the floor mat. `look_at` aims the
	# node's -Z axis at the target; using `start + dir` keeps the resulting
	# basis stable regardless of door distance. Y component is zeroed so
	# the customer doesn't pitch when start and target are at different
	# heights (the door's interactable origin sits above floor).
	var start_pos: Vector3 = customer_3d.global_position
	var face_dir: Vector3 = _CUSTOMER_EXIT_LEG_2_TARGET - start_pos
	face_dir.y = 0.0
	if face_dir.length() > 0.0001:
		face_dir = face_dir.normalized()
		customer_3d.look_at(start_pos + face_dir, Vector3.UP)

	var body: MeshInstance3D = customer_3d.get_node_or_null("CustomerProxy/Body") as MeshInstance3D
	var fade_mat: StandardMaterial3D = null
	if body != null and body.material_override is StandardMaterial3D:
		# Duplicate the override so the fade only affects this instance —
		# `_configure_beta_customer` re-issues a fresh material on day
		# reset, but mutating the shared resource here would still reach
		# the cached subresource between reloads.
		fade_mat = (body.material_override as StandardMaterial3D).duplicate()
		fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		body.material_override = fade_mat

	var floor_mat_node: Node = store.get_node_or_null("Checkout/BetaCustomerFloorMat")

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		customer_3d, "global_position", _CUSTOMER_EXIT_LEG_1_TARGET, _CUSTOMER_EXIT_LEG_1_SECONDS
	)
	if floor_mat_node is Node3D:
		tween.tween_callback(Callable(self, "_hide_customer_floor_mat").bind(floor_mat_node))
	tween.tween_property(
		customer_3d, "global_position", _CUSTOMER_EXIT_LEG_2_TARGET, _CUSTOMER_EXIT_LEG_2_SECONDS
	)
	if fade_mat != null:
		tween.parallel().tween_property(
			fade_mat, "albedo_color:a", 0.0, _CUSTOMER_EXIT_FADE_SECONDS
		)
	tween.tween_callback(Callable(self, "_finalize_customer_exit").bind(customer_3d))


func _hide_customer_floor_mat(mat_node: Node) -> void:
	if mat_node is Node3D and is_instance_valid(mat_node):
		(mat_node as Node3D).visible = false


## Tween completion hook for `_animate_customer_exit`. The customer is at
## the exit threshold with alpha at 0; flip `visible` off so the node is
## fully removed from the render path and stops occupying the door.
func _finalize_customer_exit(customer_3d: Node3D) -> void:
	if not is_instance_valid(customer_3d):
		return
	customer_3d.hide()


## Spawns `count` small box meshes on top of `BetaRestockShelf`'s ShelfBoard
## so the player can see what they put up. Returns the actual number
## spawned (clamped by the shelf width). Items spread evenly along the
## board so 5 reads as a row instead of a stack.
##
## `_store_root() == null` is the documented test-fixture seam. The
## missing-`BetaRestockShelf` branch is a scene-wiring regression
## (`retro_games.tscn` ships the node at the root of the store) — fail
## loud so a node rename / accidental delete is caught in CI rather than
## shipping as "Stocked 0 games on the used games shelf." See §EH-26.
func _spawn_visible_shelf_items(count: int) -> int:
	var store: Node = _store_root()
	if store == null:
		return 0
	var shelf: Node = store.get_node_or_null("BetaRestockShelf")
	if shelf == null or not (shelf is Node3D):
		push_error(
			(
				"BetaDayOneController: `BetaRestockShelf` Node3D missing under store root "
				+ "'%s'; visible stock spawn skipped." % store.name
			)
		)
		return 0
	# Clear any prior spawns so re-running the loop on day reset starts
	# from an empty shelf.
	for child: Node in shelf.get_children():
		if String(child.name).begins_with("BetaShelfItem"):
			child.queue_free()
	# Hide the authored empty-shelf overlay so the bare board "lights up"
	# the moment items appear. The overlay is a translucent dark panel
	# flush at the shelf front; toggling it off is the visual handoff
	# from "intentionally empty" to "freshly stocked."
	var overlay: Node = shelf.get_node_or_null("EmptyOverlay")
	if overlay is Node3D:
		(overlay as Node3D).visible = false
	var clamped: int = clampi(count, 0, 8)
	# The shelf board is ~2.2 m wide (transform scale 1.1 along X with
	# unit `shelf_board_wide_mesh`). Lay items from −0.9 m to +0.9 m so
	# they sit centered on the visible board, and lift them onto the
	# board's top face (board sits at local Y=1.1 with thickness ~0.1).
	var span_left: float = -0.9
	var span_right: float = 0.9
	var y_top: float = 1.18
	var z_face: float = 0.0
	var step: float = 0.0
	if clamped > 1:
		step = (span_right - span_left) / float(clamped - 1)
	# BoxMesh size = (width_x, height_y, depth_z). With no rotation the +Z
	# face — the one the player sees from the aisle — is 0.18 m wide ×
	# 0.22 m tall, a portrait-orientation game-case face. The 0.06 m thin
	# edge sits along Z (into the shelf), not toward the player. A dark
	# cartridge-blue albedo with low-energy warm-amber emission reads as a
	# row of game cases catching a soft display light, not glowing cubes.
	for i: int in range(clamped):
		var item: MeshInstance3D = MeshInstance3D.new()
		item.name = "BetaShelfItem%d" % i
		var m: BoxMesh = BoxMesh.new()
		m.size = Vector3(0.18, 0.22, 0.06)
		item.mesh = m
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.38, 0.62, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.42, 0.18, 1.0)
		mat.emission_energy_multiplier = 0.2
		item.material_override = mat
		var x_local: float = span_left + step * float(i) if clamped > 1 else 0.0
		item.position = Vector3(x_local, y_top, z_face)
		(shelf as Node3D).add_child(item)
	_items_stocked_today += clamped
	return clamped
