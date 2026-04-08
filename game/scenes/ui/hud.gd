## In-game HUD — shows cash, time, and interaction prompts.
extends CanvasLayer

@onready var cash_label: Label = $CashLabel
@onready var time_label: Label = $TimeLabel
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	prompt_label.visible = false


func update_cash(amount: float) -> void:
	cash_label.text = "$%.2f" % amount


func update_time(day: int, hour: int) -> void:
	time_label.text = "Day %d — %d:00" % [day, hour]


func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true


func hide_prompt() -> void:
	prompt_label.visible = false
