## Manages the first-day tutorial sequence and contextual tip scheduling.
class_name TutorialSystem
extends Node

enum TutorialStep {
	WELCOME,
	VIEW_BACKROOM,
	PLACE_ITEM,
	SET_PRICE,
	WAIT_FOR_CUSTOMER,
	COMPLETE_SALE,
	VIEW_DAY_SUMMARY,
	FINISHED,
}

const STEP_IDS: Dictionary = {
	TutorialStep.WELCOME: "welcome",
	TutorialStep.VIEW_BACKROOM: "view_backroom",
	TutorialStep.PLACE_ITEM: "place_item",
	TutorialStep.SET_PRICE: "set_price",
	TutorialStep.WAIT_FOR_CUSTOMER: "wait_for_customer",
	TutorialStep.COMPLETE_SALE: "complete_sale",
	TutorialStep.VIEW_DAY_SUMMARY: "view_day_summary",
	TutorialStep.FINISHED: "finished",
}

const STEP_TEXT_KEYS: Dictionary = {
	TutorialStep.WELCOME: "TUTORIAL_WELCOME",
	TutorialStep.VIEW_BACKROOM: "TUTORIAL_VIEW_BACKROOM",
	TutorialStep.PLACE_ITEM: "TUTORIAL_PLACE_ITEM",
	TutorialStep.SET_PRICE: "TUTORIAL_SET_PRICE",
	TutorialStep.WAIT_FOR_CUSTOMER: "TUTORIAL_WAIT_CUSTOMER",
	TutorialStep.COMPLETE_SALE: "TUTORIAL_COMPLETE_SALE",
	TutorialStep.VIEW_DAY_SUMMARY: "TUTORIAL_VIEW_SUMMARY",
	TutorialStep.FINISHED: "",
}

const CONTEXTUAL_TIP_DAYS: int = 3

const CONTEXTUAL_TIP_KEYS: Dictionary = {
	"ordering": "TIP_ORDERING",
	"build_mode": "TIP_BUILD_MODE",
	"reputation": "TIP_REPUTATION",
}

var tutorial_completed: bool = false
var tutorial_active: bool = false
var current_step: TutorialStep = TutorialStep.WELCOME
var _tips_shown: Dictionary = {}
var _welcome_timer: float = 0.0
var _welcome_duration: float = 5.0


func initialize(is_new_game: bool) -> void:
	if tutorial_completed:
		return
	if not is_new_game:
		return
	tutorial_active = true
	current_step = TutorialStep.WELCOME
	GameManager.is_tutorial_active = true
	_connect_signals()
	_emit_current_step()


func _connect_signals() -> void:
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.price_set.connect(_on_price_set)
	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.game_state_changed.connect(
		_on_game_state_changed
	)
	EventBus.day_started.connect(_on_day_started)


## Disconnects step-tracking signals but keeps day_started for contextual tips.
func _disconnect_step_signals() -> void:
	if EventBus.panel_opened.is_connected(_on_panel_opened):
		EventBus.panel_opened.disconnect(_on_panel_opened)
	if EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.disconnect(_on_item_stocked)
	if EventBus.price_set.is_connected(_on_price_set):
		EventBus.price_set.disconnect(_on_price_set)
	if EventBus.customer_entered.is_connected(
		_on_customer_entered
	):
		EventBus.customer_entered.disconnect(
			_on_customer_entered
		)
	if EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.disconnect(_on_item_sold)
	if EventBus.game_state_changed.is_connected(
		_on_game_state_changed
	):
		EventBus.game_state_changed.disconnect(
			_on_game_state_changed
		)


func _process(delta: float) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WELCOME:
		_welcome_timer += delta
		if _welcome_timer >= _welcome_duration:
			_advance_step()


func skip_tutorial() -> void:
	if not tutorial_active:
		return
	tutorial_active = false
	tutorial_completed = true
	GameManager.is_tutorial_active = false
	_disconnect_step_signals()
	EventBus.tutorial_skipped.emit()


func _advance_step() -> void:
	var old_step_id: String = STEP_IDS.get(
		current_step, "unknown"
	)
	EventBus.tutorial_step_completed.emit(old_step_id)

	var next_value: int = current_step + 1
	if next_value >= TutorialStep.FINISHED:
		_complete_tutorial()
		return

	current_step = next_value as TutorialStep
	_emit_current_step()


func _complete_tutorial() -> void:
	current_step = TutorialStep.FINISHED
	tutorial_active = false
	tutorial_completed = true
	GameManager.is_tutorial_active = false
	_disconnect_step_signals()
	EventBus.tutorial_completed.emit()


func _emit_current_step() -> void:
	var step_id: String = STEP_IDS.get(current_step, "unknown")
	EventBus.tutorial_step_changed.emit(step_id)


func _on_panel_opened(panel_name: String) -> void:
	if not tutorial_active:
		return
	if (
		current_step == TutorialStep.VIEW_BACKROOM
		and panel_name == "inventory"
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


func _on_customer_entered(
	_customer_data: Dictionary
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.WAIT_FOR_CUSTOMER:
		_advance_step()


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	if not tutorial_active:
		return
	if current_step == TutorialStep.COMPLETE_SALE:
		_advance_step()


func _on_game_state_changed(
	_old_state: int, new_state: int
) -> void:
	if not tutorial_active:
		return
	if (
		current_step == TutorialStep.VIEW_DAY_SUMMARY
		and new_state == GameManager.GameState.DAY_SUMMARY
	):
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

	# Show build mode tip on day 2 as well, slightly delayed
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


func get_current_step_text() -> String:
	var key: String = STEP_TEXT_KEYS.get(current_step, "")
	if key.is_empty():
		return ""
	return tr(key)


func get_save_data() -> Dictionary:
	var tips_data: Dictionary = {}
	for key: String in _tips_shown:
		tips_data[key] = _tips_shown[key]
	return {
		"tutorial_completed": tutorial_completed,
		"current_step": current_step,
		"tips_shown": tips_data,
	}


func load_save_data(data: Dictionary) -> void:
	tutorial_completed = data.get(
		"tutorial_completed", false
	) as bool
	current_step = int(
		data.get("current_step", TutorialStep.WELCOME)
	) as TutorialStep
	var tips_data: Variant = data.get("tips_shown", {})
	_tips_shown.clear()
	if tips_data is Dictionary:
		var tips_dict: Dictionary = tips_data as Dictionary
		for key: Variant in tips_dict:
			_tips_shown[str(key)] = bool(tips_dict[key])
	if tutorial_completed:
		tutorial_active = false
		GameManager.is_tutorial_active = false
	_ensure_day_started_connected()
