## Data resource defining a customer archetype and their shopping behavior.
class_name CustomerTypeDefinition
extends Resource

@export var id: String = ""
@export var customer_name: String = ""
@export var description: String = ""
@export var store_types: PackedStringArray = []
@export var budget_range: Array[float] = [0.0, 0.0]
@export var patience: float = 0.5
@export var price_sensitivity: float = 0.5
@export var preferred_categories: PackedStringArray = []
@export var preferred_tags: PackedStringArray = []
@export var preferred_rarities: PackedStringArray = []
@export var condition_preference: String = "good"
@export var browse_time_range: Array[float] = [30.0, 60.0]
@export var purchase_probability_base: float = 0.5
@export var impulse_buy_chance: float = 0.1
@export var visit_frequency: String = "medium"
@export var mood_tags: PackedStringArray = []
@export var spending_range: Array[float] = [0.0, 0.0]
@export var max_price_to_market_ratio: float = 1.0
@export var snack_purchase_probability: float = 0.0
@export var typical_rental_count: Array[int] = []
@export var leaves_if_unavailable: bool = false
@export var dialogue_pool: String = ""
@export var model_path: String = ""
