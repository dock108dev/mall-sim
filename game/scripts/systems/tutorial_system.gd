## Manages the first-play tutorial sequence and contextual tip scheduling.
class_name TutorialSystem
extends Node

enum TutorialStep {
	WELCOME,
	OPEN_INVENTORY,
	SELECT_ITEM,
	PLACE_ITEM,
	WAIT_FOR_CUSTOMER,
	CUSTOMER_BROWSING,
	CUSTOMER_AT_CHECKOUT,
	COMPLETE_SALE,
	CLOSE_DAY,
	DAY_SUMMARY,
	FINISHED,
}

const STEP_IDS: Dictionary = {
	TutorialStep.WELCOME: "welcome",
	TutorialStep.OPEN_INVENTORY: "open_inventory",
	TutorialStep.SELECT_ITEM: "select_item",
	TutorialStep.PLACE_ITEM: "place_item",
	TutorialStep.WAIT_FOR_CUSTOMER: "wait_for_customer",
	TutorialStep.CUSTOMER_BROWSING: "customer_browsing",
	TutorialStep.CUSTOMER_AT_CHECKOUT: "customer_at_checkout",
	TutorialStep.COMPLETE_SALE: "complete_sale",
	TutorialStep.CLOSE_DAY: "close_day",
	TutorialStep.DAY_SUMMARY: "day_summary",
	TutorialStep.FINISHED: "finished",
}

const STEP_TEXT_KEYS: Dictionary = {
	TutorialStep.WELCOME: "TUTORIAL_WELCOME",
	TutorialStep.OPEN_INVENTORY: "TUTORIAL_OPEN_INVENTORY",
	TutorialStep.SELECT_ITEM: "TUTORIAL_SELECT_ITEM",
	TutorialStep.PLACE_ITEM: "TUTORIAL_PLACE_ITEM",
	TutorialStep.WAIT_FOR_CUSTOMER: "TUTORIAL_WAIT_CUSTOMER",
	TutorialStep.CUSTOMER_BROWSING: "TUTORIAL_CUSTOMER_BROWSING",
	TutorialStep.CUSTOMER_AT_CHECKOUT: "TUTORIAL_CUSTOMER_AT_CHECKOUT",
	TutorialStep.COMPLETE_SALE: "TUTORIAL_COMPLETE_SALE",
	TutorialStep.CLOSE_DAY: "TUTORIAL_CLOSE_DAY",
	TutorialStep.DAY_SUMMARY: "TUTORIAL_DAY_SUMMARY",
	TutorialStep.FINISHED: "",
}

const PROGRESS_PATH: String = "user://tutorial_progress.cfg"
# Hardening: cap the size of the user-controlled progress blob so a planted
# multi-GB file can't wedge boot. See docs/audits/security-report.md §F1.
const MAX_PROGRESS_FILE_BYTES: int = 65536
# Bounds for completed_steps / tips_shown dicts loaded from the cfg. Both keysets
# are small in practice (STEP_COUNT ≈ 10, three contextual tips); a hostile cfg
# with millions of keys would otherwise bloat memory before any validation. See
# docs/audits/security-report.md §F2.
const MAX_PERSISTED_DICT_KEYS: int = 1024
const WELCOME_DURATION: float = 5.0
const CONTEXTUAL_TIP_DAYS: int = 3
const STEP_COUNT: int = TutorialStep.FINISHED
const TUTORIAL_STORE_ID: StringName = &"retro_games"
# Bumped when the TutorialStep enum ordinals change. Persisted progress with a
# different version is treated as incompatible and reset to a fresh tutorial so
# a player's old cfg can't replay the wrong step IDs after a re-sequence.
const SCHEMA_VERSION: int = 2

const CONTEXTUAL_TIP_KEYS: Dictionary = {
	"ordering": "TIP_ORDERING",
	"build_mode": "TIP_BUILD_MODE",
	"reputation": "TIP_REPUTATION",
}

var tutorial_completed: bool = false
var tutorial_active: bool = false
var current_step: TutorialStep = TutorialStep.WELCOME
var _tips_shown: Dictionary = {}
var _completed_steps: Dictionary = {}
var _welcome_timer: float = 0.0


## Starts a new tutorial session or resumes persisted first-play progress.
func initialize(is_new_game: bool) -> void:
	if is_new_game:
		_apply_state({
			"tutorial_completed": false,
			"current_step": TutorialStep.WELCOME,
			"completed_steps": {},
		})
		_save_progress()
		return
	_load_progress()
	if tutorial_completed:
		_ensure_day_started_connected()


func _connect_signals() -> void:
	if not EventBus.gameplay_ready.is_connected(_on_gameplay_ready):
		EventBus.gameplay_ready.connect(_on_gameplay_ready)
	if not EventBus.skip_tutorial_requested.is_connected(skip_tutorial):
		EventBus.skip_tutorial_requested.connect(skip_tutorial)
	if not EventBus.panel_opened.is_connected(_on_panel_opened):
		EventBus.panel_opened.connect(_on_panel_opened)
	if not EventBus.placement_mode_entered.is_connected(
		_on_placement_mode_entered
	):
		EventBus.placement_mode_entered.connect(_on_placement_mode_entered)
	if not EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.connect(_on_item_stocked)
	if not EventBus.customer_entered.is_connected(_on_customer_entered):
		EventBus.customer_entered.connect(_on_customer_entered)
	if not EventBus.customer_item_spotted.is_connected(
		_on_customer_item_spotted
	):
		EventBus.customer_item_spotted.connect(_on_customer_item_spotted)
	if not EventBus.customer_ready_to_purchase.is_connected(
		_on_customer_ready_to_purchase
	):
		EventBus.customer_ready_to_purchase.connect(
			_on_customer_ready_to_purchase
		)
	if not EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.connect(_on_customer_purchased)
	if not EventBus.day_close_requested.is_connected(_on_day_close_requested):
		EventBus.day_close_requested.connect(_on_day_close_requested)
	if not EventBus.day_acknowledged.is_connected(_on_day_acknowledged):
		EventBus.day_acknowledged.connect(_on_day_acknowledged)
	_ensure_day_started_connected()


func _disconnect_step_signals() -> void:
	if EventBus.gameplay_ready.is_connected(_on_gameplay_ready):
		EventBus.gameplay_ready.disconnect(_on_gameplay_ready)
	if EventBus.skip_tutorial_requested.is_connected(skip_tutorial):
		EventBus.skip_tutorial_requested.disconnect(skip_tutorial)
	if EventBus.panel_opened.is_connected(_on_panel_opened):
		EventBus.panel_opened.disconnect(_on_panel_opened)
	if EventBus.placement_mode_entered.is_connected(
		_on_placement_mode_entered
	):
		EventBus.placement_mode_entered.disconnect(_on_placement_mode_entered)
	if EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.disconnect(_on_item_stocked)
	if EventBus.customer_entered.is_connected(_on_customer_entered):
		EventBus.customer_entered.disconnect(_on_customer_entered)
	if EventBus.customer_item_spotted.is_connected(
		_on_customer_item_spotted
	):
		EventBus.customer_item_spotted.disconnect(_on_customer_item_spotted)
	if EventBus.customer_ready_to_purchase.is_connected(
		_on_customer_ready_to_purchase
	):
		EventBus.customer_ready_to_purchase.disconnect(
			_on_customer_ready_to_purchase
		)
	if EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.disconnect(_on_customer_purchased)
	if EventBus.day_close_requested.is_connected(_on_day_close_requested):
		EventBus.day_close_requested.disconnect(_on_day_close_requested)
	if EventBus.day_acknowledged.is_connected(_on_day_acknowledged):
		EventBus.day_acknowledged.disconnect(_on_day_acknowledged)


func _process(delta: float) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WELCOME:
		_welcome_timer += delta
		if _welcome_timer >= WELCOME_DURATION:
			_advance_step()


## Marks every tutorial step complete and permanently disables prompts.
func skip_tutorial() -> void:
	if not tutorial_active:
		return
	_mark_all_steps_complete(true)
	current_step = TutorialStep.FINISHED
	Settings.set_preference(&"tutorial_skip", true)
	Settings.save_settings()
	GameState.set_flag(&"tutorial_skipped", true)
	EventBus.tutorial_skipped.emit()
	_complete_tutorial()


## Returns the localized prompt for the active step, or an empty string.
func get_current_step_text() -> String:
	var key: String = STEP_TEXT_KEYS.get(current_step, "")
	if key.is_empty():
		return ""
	return tr(key)


## Serializes tutorial progress for the save-game payload.
func get_save_data() -> Dictionary:
	var tips_data: Dictionary = {}
	for key: String in _tips_shown:
		tips_data[key] = _tips_shown[key]
	var completed_data: Dictionary = {}
	for key: String in _completed_steps:
		completed_data[key] = _completed_steps[key]
	return {
		"tutorial_completed": tutorial_completed,
		"tutorial_active": tutorial_active,
		"current_step": current_step,
		"completed_steps": completed_data,
		"tips_shown": tips_data,
	}


## Restores tutorial progress from save-game data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)
	_save_progress()


func _advance_step() -> void:
	if not tutorial_active or tutorial_completed:
		return
	var old_step_id: String = STEP_IDS.get(current_step, "unknown")
	_completed_steps[old_step_id] = true
	EventBus.tutorial_step_completed.emit(old_step_id)

	var next_value: int = current_step + 1
	if next_value >= TutorialStep.FINISHED:
		_complete_tutorial()
		return

	current_step = next_value as TutorialStep
	_save_progress()
	_emit_current_step()


func _complete_tutorial(should_save: bool = true) -> void:
	if tutorial_completed and not tutorial_active:
		return
	current_step = TutorialStep.FINISHED
	tutorial_active = false
	tutorial_completed = true
	GameManager.is_tutorial_active = false
	_disconnect_step_signals()
	if should_save:
		_mark_all_steps_complete(false)
		_save_progress()
	EventBus.tutorial_completed.emit()


func _emit_current_step() -> void:
	if not tutorial_active or tutorial_completed:
		return
	var step_id: String = STEP_IDS.get(current_step, "unknown")
	EventBus.tutorial_step_changed.emit(step_id)


func _on_gameplay_ready() -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WELCOME:
		_advance_step()


func _on_panel_opened(panel_name: String) -> void:
	if not tutorial_active:
		return
	if (
		current_step == TutorialStep.OPEN_INVENTORY
		and panel_name == "inventory"
	):
		_advance_step()


## M2 (Select item): the player has chosen an item to stock and entered
## placement mode. The shelf-actions controller is the sole emitter.
func _on_placement_mode_entered() -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.SELECT_ITEM:
		_advance_step()


func _on_item_stocked(_item_id: String, _shelf_id: String) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.PLACE_ITEM:
		_advance_step()


## M4 (Wait for customer): a customer has entered the store. The
## CustomerSystem-side `customer_entered` signal carries the spawn payload.
func _on_customer_entered(_customer_data: Dictionary) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WAIT_FOR_CUSTOMER:
		_advance_step()


## M5 (Customer browsing): a customer has spotted a desirable item on the
## shelves. Emitted by `Customer._evaluate_current_shelf`.
func _on_customer_item_spotted(
	_customer: Customer, _item: ItemInstance,
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.CUSTOMER_BROWSING:
		_advance_step()


## M6 (Customer at checkout): a customer has decided to purchase and arrived
## at the register. CheckoutSystem listens to the same signal.
func _on_customer_ready_to_purchase(_customer_data: Dictionary) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.CUSTOMER_AT_CHECKOUT:
		_advance_step()


## M7 (Complete sale): the transaction has cleared.
func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.COMPLETE_SALE:
		_advance_step()


func _on_day_close_requested() -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.CLOSE_DAY:
		_advance_step()


func _on_day_acknowledged() -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.DAY_SUMMARY:
		_advance_step()


func _on_day_started(day: int) -> void:
	if tutorial_completed and day <= CONTEXTUAL_TIP_DAYS:
		_show_contextual_tip_for_day(day)


func _show_contextual_tip_for_day(day: int) -> void:
	var tip_key: String = ""
	if day == 2:
		tip_key = "ordering"
	elif day == 3:
		tip_key = "reputation"

	if tip_key.is_empty():
		return
	if _tips_shown.get(tip_key, false):
		return

	_tips_shown[tip_key] = true
	var tip_key_str: String = CONTEXTUAL_TIP_KEYS.get(tip_key, "")
	if not tip_key_str.is_empty():
		EventBus.contextual_tip_requested.emit(tr(tip_key_str))

	if day == 2 and not _tips_shown.get("build_mode", false):
		_tips_shown["build_mode"] = true
		var build_tip_key: String = CONTEXTUAL_TIP_KEYS.get(
			"build_mode", ""
		)
		if not build_tip_key.is_empty():
			var resolved_tip: String = tr(build_tip_key)
			get_tree().create_timer(30.0).timeout.connect(
				func() -> void:
					EventBus.contextual_tip_requested.emit(
						resolved_tip
					)
			)


func _ensure_day_started_connected() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "schema_version", SCHEMA_VERSION)
	config.set_value("tutorial", "completed", tutorial_completed)
	config.set_value("tutorial", "current_step", current_step)
	config.set_value("tutorial", "active", tutorial_active)
	var completed_data: Dictionary = {}
	for key: String in _completed_steps:
		completed_data[key] = _completed_steps[key]
	config.set_value("tutorial", "completed_steps", completed_data)
	var tips_data: Dictionary = {}
	for key: String in _tips_shown:
		tips_data[key] = _tips_shown[key]
	config.set_value("tutorial", "tips_shown", tips_data)
	var err: Error = config.save(PROGRESS_PATH)
	if err != OK:
		push_error(
			"Failed to save tutorial progress: %s" % error_string(err)
		)


func _load_progress() -> void:
	var config := ConfigFile.new()
	# Pre-validate file size before handing the blob to ConfigFile so a planted
	# oversized user:// file can't wedge boot. See security-report.md §F1.
	if FileAccess.file_exists(PROGRESS_PATH):
		var probe: FileAccess = FileAccess.open(
			PROGRESS_PATH, FileAccess.READ
		)
		if probe and probe.get_length() > MAX_PROGRESS_FILE_BYTES:
			probe.close()
			push_warning(
				(
					"TutorialSystem: '%s' exceeds maximum supported size "
					+ "(%d bytes) — resetting progress"
				)
				% [PROGRESS_PATH, MAX_PROGRESS_FILE_BYTES]
			)
			_apply_state({
				"tutorial_completed": false,
				"current_step": TutorialStep.WELCOME,
				"completed_steps": {},
			})
			return
		if probe:
			probe.close()
	var err: Error = config.load(PROGRESS_PATH)
	if err != OK:
		if FileAccess.file_exists(PROGRESS_PATH):
			push_warning(
				"TutorialSystem: failed to load '%s' — resetting progress"
				% PROGRESS_PATH
			)
		_apply_state({
			"tutorial_completed": false,
			"current_step": TutorialStep.WELCOME,
			"completed_steps": {},
		})
		return
	# §F-85 — Pass 12: a schema_version mismatch means the persisted ordinals
	# predate the current TutorialStep enum and resuming would replay the
	# wrong step IDs (e.g. an old `MOVE_TO_SHELF=1` would land on the new
	# `OPEN_INVENTORY=1`). Treat it the same as a corrupt file (§F-20 already
	# justifies the reset-on-corruption stance for this quality-of-life
	# feature): warn loudly so the player and CI see the version skew, reset
	# to a fresh tutorial, and re-save with the current schema_version so the
	# warning is one-shot rather than every boot.
	var loaded_version: int = int(
		config.get_value("tutorial", "schema_version", 0)
	)
	if loaded_version != SCHEMA_VERSION:
		push_warning(
			(
				"TutorialSystem: '%s' schema_version=%d != %d — "
				+ "resetting progress"
			)
			% [PROGRESS_PATH, loaded_version, SCHEMA_VERSION]
		)
		_apply_state({
			"tutorial_completed": false,
			"current_step": TutorialStep.WELCOME,
			"completed_steps": {},
		})
		_save_progress()
		return
	var data: Dictionary = {
		"tutorial_completed": config.get_value(
			"tutorial", "completed", false
		),
		"current_step": config.get_value(
			"tutorial", "current_step", TutorialStep.WELCOME
		),
		"tutorial_active": config.get_value(
			"tutorial", "active", false
		),
		"completed_steps": config.get_value(
			"tutorial", "completed_steps", {}
		),
		"tips_shown": config.get_value(
			"tutorial", "tips_shown", {}
		),
	}
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	tutorial_completed = bool(
		data.get("tutorial_completed", false)
	)
	# Out-of-range ints from a hand-edited user:// blob are clamped by
	# _resolve_resume_step below.
	current_step = int(
		data.get("current_step", TutorialStep.WELCOME)
	) as TutorialStep

	_completed_steps.clear()
	var completed_data: Variant = data.get("completed_steps", {})
	if completed_data is Dictionary:
		var completed_dict: Dictionary = completed_data as Dictionary
		# Hardening: cap iteration and accept only known step IDs so a hostile
		# cfg can't bloat memory or smuggle arbitrary keys into the state map.
		# See security-report.md §F2.
		var completed_loaded: int = 0
		for key: Variant in completed_dict:
			if completed_loaded >= MAX_PERSISTED_DICT_KEYS:
				push_warning(
					(
						"TutorialSystem: completed_steps dict exceeds %d keys "
						+ "— ignoring remainder"
					)
					% MAX_PERSISTED_DICT_KEYS
				)
				break
			completed_loaded += 1
			var step_key: String = str(key)
			if not STEP_IDS.values().has(step_key):
				continue
			if bool(completed_dict[key]):
				_completed_steps[step_key] = true
	if tutorial_completed:
		current_step = TutorialStep.FINISHED
	else:
		current_step = _resolve_resume_step(current_step)
		tutorial_completed = current_step == TutorialStep.FINISHED

	_tips_shown.clear()
	var tips_data: Variant = data.get("tips_shown", {})
	if tips_data is Dictionary:
		var tips_dict: Dictionary = tips_data as Dictionary
		# Same cardinality + allow-list hardening as completed_steps above.
		# See security-report.md §F2.
		var tips_loaded: int = 0
		for key: Variant in tips_dict:
			if tips_loaded >= MAX_PERSISTED_DICT_KEYS:
				push_warning(
					(
						"TutorialSystem: tips_shown dict exceeds %d keys — "
						+ "ignoring remainder"
					)
					% MAX_PERSISTED_DICT_KEYS
				)
				break
			tips_loaded += 1
			var tip_key: String = str(key)
			if not CONTEXTUAL_TIP_KEYS.has(tip_key):
				continue
			_tips_shown[tip_key] = bool(tips_dict[key])

	_welcome_timer = 0.0

	if tutorial_completed or current_step == TutorialStep.FINISHED:
		tutorial_active = false
		GameManager.is_tutorial_active = false
		_disconnect_step_signals()
		_ensure_day_started_connected()
	else:
		tutorial_active = true
		GameManager.is_tutorial_active = true
		_connect_signals()
		_emit_current_step()


func _resolve_resume_step(saved_step: TutorialStep) -> TutorialStep:
	if saved_step == TutorialStep.FINISHED:
		return saved_step
	for step_index: int in range(STEP_COUNT):
		var step_id: String = STEP_IDS.get(step_index, "")
		if not _completed_steps.get(step_id, false):
			return step_index as TutorialStep
	return TutorialStep.FINISHED


func _mark_all_steps_complete(emit_missing: bool) -> void:
	for step_index: int in range(STEP_COUNT):
		var step_id: String = STEP_IDS.get(step_index, "")
		if step_id.is_empty() or _completed_steps.get(step_id, false):
			continue
		_completed_steps[step_id] = true
		if emit_missing:
			EventBus.tutorial_step_completed.emit(step_id)
