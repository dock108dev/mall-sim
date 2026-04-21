## Manages the first-play tutorial sequence and contextual tip scheduling.
class_name TutorialSystem
extends Node

enum TutorialStep {
	WELCOME,
	WALK_TO_STORE,
	ENTER_STORE,
	OPEN_INVENTORY,
	PLACE_ITEM,
	OPEN_PRICING,
	SET_PRICE,
	WAIT_FOR_CUSTOMER,
	SALE_COMPLETED,
	END_OF_DAY,
	FINISHED,
}

const STEP_IDS: Dictionary = {
	TutorialStep.WELCOME: "welcome",
	TutorialStep.WALK_TO_STORE: "walk_to_store",
	TutorialStep.ENTER_STORE: "enter_store",
	TutorialStep.OPEN_INVENTORY: "open_inventory",
	TutorialStep.PLACE_ITEM: "place_item",
	TutorialStep.OPEN_PRICING: "open_pricing",
	TutorialStep.SET_PRICE: "set_price",
	TutorialStep.WAIT_FOR_CUSTOMER: "wait_for_customer",
	TutorialStep.SALE_COMPLETED: "sale_completed",
	TutorialStep.END_OF_DAY: "end_of_day",
	TutorialStep.FINISHED: "finished",
}

const STEP_TEXT_KEYS: Dictionary = {
	TutorialStep.WELCOME: "TUTORIAL_WELCOME",
	TutorialStep.WALK_TO_STORE: "TUTORIAL_WALK_TO_STORE",
	TutorialStep.ENTER_STORE: "TUTORIAL_ENTER_STORE",
	TutorialStep.OPEN_INVENTORY: "TUTORIAL_OPEN_INVENTORY",
	TutorialStep.PLACE_ITEM: "TUTORIAL_PLACE_ITEM",
	TutorialStep.OPEN_PRICING: "TUTORIAL_OPEN_PRICING",
	TutorialStep.SET_PRICE: "TUTORIAL_SET_PRICE",
	TutorialStep.WAIT_FOR_CUSTOMER: "TUTORIAL_WAIT_CUSTOMER",
	TutorialStep.SALE_COMPLETED: "TUTORIAL_SALE_COMPLETED",
	TutorialStep.END_OF_DAY: "TUTORIAL_END_OF_DAY",
	TutorialStep.FINISHED: "",
}

const PROGRESS_PATH: String = "user://tutorial_progress.cfg"
const WELCOME_DURATION: float = 5.0
const MOVEMENT_THRESHOLD: float = 5.0
const CONTEXTUAL_TIP_DAYS: int = 3
const STEP_COUNT: int = TutorialStep.FINISHED

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
var _movement_accumulated: float = 0.0


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
	if not EventBus.skip_tutorial_requested.is_connected(
		skip_tutorial
	):
		EventBus.skip_tutorial_requested.connect(skip_tutorial)
	if not EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.connect(_on_store_entered)
	if not EventBus.panel_opened.is_connected(_on_panel_opened):
		EventBus.panel_opened.connect(_on_panel_opened)
	if not EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.connect(_on_item_stocked)
	if not EventBus.price_set.is_connected(_on_price_set):
		EventBus.price_set.connect(_on_price_set)
	if not EventBus.customer_spawned.is_connected(
		_on_customer_spawned
	):
		EventBus.customer_spawned.connect(_on_customer_spawned)
	if not EventBus.customer_purchased.is_connected(
		_on_customer_purchased
	):
		EventBus.customer_purchased.connect(_on_customer_purchased)
	if not EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.connect(_on_day_ended)
	_ensure_day_started_connected()


func _disconnect_step_signals() -> void:
	if EventBus.gameplay_ready.is_connected(_on_gameplay_ready):
		EventBus.gameplay_ready.disconnect(_on_gameplay_ready)
	if EventBus.skip_tutorial_requested.is_connected(
		skip_tutorial
	):
		EventBus.skip_tutorial_requested.disconnect(skip_tutorial)
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.panel_opened.is_connected(_on_panel_opened):
		EventBus.panel_opened.disconnect(_on_panel_opened)
	if EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.disconnect(_on_item_stocked)
	if EventBus.price_set.is_connected(_on_price_set):
		EventBus.price_set.disconnect(_on_price_set)
	if EventBus.customer_spawned.is_connected(
		_on_customer_spawned
	):
		EventBus.customer_spawned.disconnect(_on_customer_spawned)
	if EventBus.customer_purchased.is_connected(
		_on_customer_purchased
	):
		EventBus.customer_purchased.disconnect(
			_on_customer_purchased
		)
	if EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.disconnect(_on_day_ended)


func _process(delta: float) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WELCOME:
		_welcome_timer += delta
		if _welcome_timer >= WELCOME_DURATION:
			_advance_step()
	elif current_step == TutorialStep.WALK_TO_STORE:
		_track_movement(delta)


## Marks every tutorial step complete and permanently disables prompts.
func skip_tutorial() -> void:
	if not tutorial_active:
		return
	_mark_all_steps_complete(true)
	current_step = TutorialStep.FINISHED
	Settings.set_preference(&"tutorial_skip", true)
	Settings.save_settings()
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
	var old_step_id: String = STEP_IDS.get(
		current_step, "unknown"
	)
	_completed_steps[old_step_id] = true
	EventBus.tutorial_step_completed.emit(old_step_id)

	var next_value: int = current_step + 1
	if next_value >= TutorialStep.FINISHED:
		_complete_tutorial()
		return

	current_step = next_value as TutorialStep
	_movement_accumulated = 0.0
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


func _track_movement(delta: float) -> void:
	if _movement_accumulated >= MOVEMENT_THRESHOLD:
		_advance_step()
		return
	var input: Vector2 = Input.get_vector(
		"move_left", "move_right",
		"move_forward", "move_back",
	)
	if input.is_zero_approx():
		return
	_movement_accumulated += input.length() * delta * 6.0
	if _movement_accumulated >= MOVEMENT_THRESHOLD:
		_advance_step()


func _on_gameplay_ready() -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WELCOME:
		_advance_step()


func _on_store_entered(_store_id: StringName) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.ENTER_STORE:
		_advance_step()


func _on_panel_opened(panel_name: String) -> void:
	if not tutorial_active:
		return
	if (
		current_step == TutorialStep.OPEN_INVENTORY
		and panel_name == "inventory"
	):
		_advance_step()
	elif (
		current_step == TutorialStep.OPEN_PRICING
		and panel_name == "pricing"
	):
		_advance_step()


func _on_item_stocked(
	_item_id: String, _shelf_id: String
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.PLACE_ITEM:
		_advance_step()


func _on_price_set(
	_item_id: String, _price: float
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.SET_PRICE:
		_advance_step()


func _on_customer_spawned(_customer: Node) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WAIT_FOR_CUSTOMER:
		_advance_step()


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.SALE_COMPLETED:
		_advance_step()


func _on_day_ended(_day: int) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.END_OF_DAY:
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
	current_step = int(
		data.get("current_step", TutorialStep.WELCOME)
	) as TutorialStep

	_completed_steps.clear()
	var completed_data: Variant = data.get("completed_steps", {})
	if completed_data is Dictionary:
		var completed_dict: Dictionary = completed_data as Dictionary
		for key: Variant in completed_dict:
			if bool(completed_dict[key]):
				_completed_steps[str(key)] = true
	if tutorial_completed:
		current_step = TutorialStep.FINISHED
	else:
		current_step = _resolve_resume_step(current_step)
		tutorial_completed = current_step == TutorialStep.FINISHED

	_tips_shown.clear()
	var tips_data: Variant = data.get("tips_shown", {})
	if tips_data is Dictionary:
		var tips_dict: Dictionary = tips_data as Dictionary
		for key: Variant in tips_dict:
			_tips_shown[str(key)] = bool(tips_dict[key])

	_welcome_timer = 0.0
	_movement_accumulated = 0.0

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
