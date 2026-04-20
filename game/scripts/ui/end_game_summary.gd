## End-game summary overlay shown when EventBus.game_ended fires.
## Renders: outcome, final cash, days survived, revenue per store, endings unlocked.
class_name EndGameSummary
extends CanvasLayer

@onready var _outcome_label: Label = $Background/VBox/OutcomeLabel
@onready var _cash_label: Label = $Background/VBox/CashLabel
@onready var _days_label: Label = $Background/VBox/DaysLabel
@onready var _per_store_container: VBoxContainer = (
	$Background/VBox/PerStoreContainer
)
@onready var _endings_label: Label = $Background/VBox/EndingsLabel
@onready var _continue_button: Button = $Background/VBox/ContinueButton


func _ready() -> void:
	visible = false
	EventBus.game_ended.connect(_on_game_ended)
	_continue_button.pressed.connect(_on_continue_pressed)


func _on_game_ended(outcome: String, stats: Dictionary) -> void:
	_populate(outcome, stats)
	visible = true


func _populate(outcome: String, stats: Dictionary) -> void:
	_outcome_label.text = "Victory!" if outcome == "win" else "Bankrupt"
	_cash_label.text = "Final Cash: $%.2f" % float(stats.get("final_cash", 0.0))
	_days_label.text = "Days Survived: %d" % int(stats.get("days_survived", 0))

	for child: Node in _per_store_container.get_children():
		child.queue_free()
	var store_rev: Variant = stats.get("items_sold_per_store", {})
	if store_rev is Dictionary:
		for sid: String in (store_rev as Dictionary):
			var lbl := Label.new()
			lbl.text = "  %s: $%.2f" % [
				sid, float((store_rev as Dictionary)[sid])
			]
			_per_store_container.add_child(lbl)

	var endings: Variant = stats.get("endings_unlocked", [])
	if endings is Array and not (endings as Array).is_empty():
		_endings_label.text = "Endings: " + ", ".join(endings as Array)
	else:
		_endings_label.text = "Endings: none"


func _on_continue_pressed() -> void:
	visible = false
	EventBus.ending_requested.emit("arc_outcome")
