## Full-width KPI strip shown above the hub store cards.
## Displays day number, cash balance, reputation tier label, and milestone
## completion progress. All values are driven by EventBus signals — no polling.
extends PanelContainer

var _current_day: int = 1
var _current_cash: float = 0.0
var _best_reputation: float = 0.0
var _milestones_completed: int = 0
var _milestones_total: int = 1

@onready var _day_label: Label = $MarginContainer/Row/DayLabel
@onready var _cash_label: Label = $MarginContainer/Row/CashLabel
@onready var _rep_label: Label = $MarginContainer/Row/RepLabel
@onready var _milestone_row: HBoxContainer = $MarginContainer/Row/MilestoneRow
@onready var _milestone_bar: ProgressBar = $MarginContainer/Row/MilestoneRow/MilestoneBar
@onready var _milestone_separator: VSeparator = $MarginContainer/Row/Sep3


func _ready() -> void:
	_best_reputation = ReputationSystemSingleton.DEFAULT_REPUTATION
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	EventBus.gameplay_ready.connect(_on_gameplay_ready)
	_try_load_milestone_total()
	_seed_cash_from_economy()
	_refresh_all()


func _on_gameplay_ready() -> void:
	_try_load_milestone_total()
	_seed_cash_from_economy()
	_refresh_all()


func _on_day_started(day: int) -> void:
	_current_day = day
	_day_label.text = "Day %d" % _current_day
	# EconomySystem.initialize() writes player_cash via _apply_state and does
	# not emit money_changed, so a strip that only listens on money_changed
	# would stay at $0 until the first transaction. Seed here so the mall hub
	# KPI matches the in-store HUD cash readout from the first frame.
	_seed_cash_from_economy()


## §F-115 — Snaps the displayed cash to EconomySystem.get_cash() when
## available. Mirrors the §F-103 HUD seeding contract so the mall hub KPI
## strip and the in-store HUD render the same starting cash from the first
## frame after Tier-1 init. Both silent returns are Tier-init test seams
## (autoload-missing GameManager, pre-Tier-1 EconomySystem); production paths
## always have the autoload set, and `_on_money_changed` re-populates the
## label the first time a transaction fires regardless.
func _seed_cash_from_economy() -> void:
	if GameManager == null:
		return
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy == null:
		return
	_current_cash = economy.get_cash()
	_cash_label.text = _format_cash(_current_cash)


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


## Day 1 has no completed milestones by definition; an empty "Progress: ____"
## bar reads as a dead UI element. Hide the row (and its separator) on Day 1
## and show it once the player has shipped their first day, at which point
## milestone progress can begin to accrue.
func _refresh_milestone_bar() -> void:
	var show_row: bool = _current_day > 1
	if _milestone_row != null:
		_milestone_row.visible = show_row
	if _milestone_separator != null:
		_milestone_separator.visible = show_row
	_milestone_bar.value = (
		float(_milestones_completed) / float(_milestones_total)
		if _milestones_total > 0
		else 0.0
	)


func _try_load_milestone_total() -> void:
	if _milestones_total > 1:
		return
	if GameManager == null or GameManager.data_loader == null:
		# Silent return: data_loader is null during pre-gameplay init frames.
		# _on_gameplay_ready() re-polls once all systems are live.
		# See docs/audits/error-handling-report.md §J3.
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
