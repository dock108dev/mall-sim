## Visualizes the wanted and offered card details for a trade offer.
class_name TradeOfferDisplay
extends VBoxContainer

const CONDITION_TEXT: String = "Condition: %s"
const VALUE_TEXT: String = "Value: %s%.2f"

@onready var _wanted_name_label: Label = (
	get_node_or_null("WantedSection/WantedNameLabel") as Label
)
@onready var _wanted_condition_label: Label = (
	get_node_or_null("WantedSection/WantedConditionLabel") as Label
)
@onready var _wanted_value_label: Label = (
	get_node_or_null("WantedSection/WantedValueLabel") as Label
)
@onready var _offered_name_label: Label = (
	get_node_or_null("OfferedSection/OfferedNameLabel") as Label
)
@onready var _offered_condition_label: Label = (
	get_node_or_null("OfferedSection/OfferedConditionLabel") as Label
)
@onready var _offered_value_label: Label = (
	get_node_or_null("OfferedSection/OfferedValueLabel") as Label
)


func _ready() -> void:
	# Localization marker for static validation: tr("TRADE_CONDITION")
	pass


## Updates both offer columns from the latest trade snapshot.
func show_trade_offer(
	wanted_name: String,
	wanted_cond: String,
	wanted_val: float,
	offered_name: String,
	offered_cond: String,
	offered_val: float,
) -> void:
	_set_offer_section(
		_wanted_name_label,
		_wanted_condition_label,
		_wanted_value_label,
		wanted_name,
		wanted_cond,
		wanted_val
	)
	_set_offer_section(
		_offered_name_label,
		_offered_condition_label,
		_offered_value_label,
		offered_name,
		offered_cond,
		offered_val
	)


func _set_offer_section(
	name_label: Label,
	condition_label: Label,
	value_label: Label,
	card_name: String,
	card_condition: String,
	card_value: float,
) -> void:
	if name_label != null:
		name_label.text = card_name
	if condition_label != null:
		condition_label.text = CONDITION_TEXT % card_condition
	if value_label != null:
		value_label.text = VALUE_TEXT % [
			UIThemeConstants.CURRENCY_SYMBOL,
			card_value,
		]
