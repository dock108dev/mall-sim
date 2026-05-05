## Captures a single defective sale awaiting an angry-return resolution.
##
## Created by ReturnsSystem.record_defective_sale at the moment of the
## defective sale; the matching angry_return_customer that arrives later
## consumes it through ReturnsSystem.peek_next_return / apply_decision.
##
## Plain Resource so it serializes for save/load and can be built in unit
## tests without instantiating the full ReturnsSystem autoload.
class_name ReturnRecord
extends Resource


@export var item_id: String = ""
@export var store_id: StringName = &""
@export var customer_id: StringName = &""
@export var item_name: String = ""
@export var item_condition: String = ""
@export var sale_price: float = 0.0
@export var defect_reason: String = ""
@export var day_sold: int = 0
@export var resolved: bool = false
@export var resolution: String = ""
