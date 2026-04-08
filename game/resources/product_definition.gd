## A product is an item placed on a shelf for sale, with pricing and stock info.
class_name ProductDefinition
extends Resource

@export var item_id: String = ""
@export var sell_price: float = 0.0
@export var stock_quantity: int = 0
@export var max_stock: int = 10
@export var shelf_position: Vector3 = Vector3.ZERO
@export var display_facing: String = "front"
