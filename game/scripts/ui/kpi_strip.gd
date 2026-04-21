## Full-width KPI strip shown above the hub store cards.
## Displays day number, cash balance, reputation tier label, and milestone
## completion progress. All values are driven by EventBus signals — no polling.
extends PanelContainer

@onready var _day_label: Label = $MarginContainer/Row/DayLabel
@onready var _cash_label: Label = $MarginContainer/Row/CashLabel
@onready var _rep_label: Label = $MarginContainer/Row/RepLabel
@onready var _milestone_bar: ProgressBar = $MarginContainer/Row/MilestoneRow/MilestoneBar

var _current_day: int = 1
var _current_cash: float = 0.0
var _best_reputation: float = 0.0
var _milestones_completed: int = 0
var _milestones_total: int = 1


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	EventBus.gameplay_ready.connect(_on_gameplay_ready)
	_try_load_milestone_total()
	_refresh_all()


func _on_gameplay_ready() -> void:
	_try_load_milestone_total()
	_refresh_all()


func _on_day_started(day: int) -> void:
	_current_day = day
	_day_label.text = "Day %d" % _current_day


func _on_day_closed(_day: int, _summary: Dictionary) -> void:
	_refresh_all()


func _on_money_changed(_old: float, new_amount: float) -> void:
	_current_cash = new_amount
	_cash_label.text = _format_cash(_current_cash)


func _on_reputation_changed(_store_id: String, _old: float, new_score: float) -> void:
	if new_score > _best_reputation:
		_best_reputation = new_score
	_rep_label.text = _rep_tier_name(_best_reputation)


func _on_milestone_reached(_milestone_id: StringName) -> void:
	_milestones_completed = mini(_milestones_completed + 1, _milestones_total)
	_refresh_milestone_bar()


func _refresh_all() -> void:
	_day_label.text = "Day %d" % _current_day
	_cash_label.text = _format_cash(_current_cash)
	_rep_label.text = _rep_tier_name(_best_reputation)
	_refresh_milestone_bar()


func _refresh_milestone_bar() -> void:
	_milestone_bar.value = (
		float(_milestones_completed) / float(_milestones_total)
		if _milestones_total > 0
		else 0.0
	)


func _try_load_milestone_total() -> void:
	if _milestones_total > 1:
		return
	if GameManager == null or GameManager.data_loader == null:
		return
	var count: int = GameManager.data_loader.get_all_milestones().size()
	if count > 0:
		_milestones_total = count


static func _rep_tier_name(score: float) -> String:
	if score >= 80.0:
		return "Landmark"
	if score >= 51.0:
		return "Reputable"
	if score >= 25.0:
		return "Local Fav"
	if score >= 10.0:
		return "Known"
	return "Unknown"


static func _format_cash(amount: float) -> String:
	if amount < 0.0:
		return "-$%d" % int(-amount)
	return "$%d" % int(amount)
