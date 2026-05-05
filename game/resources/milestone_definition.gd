## Data resource defining a progression milestone and its reward.
class_name MilestoneDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var is_visible: bool = true
@export var tier: String = ""
@export var trigger_type: String = ""
@export var trigger_threshold: float = 0.0
@export var trigger_stat_key: String = ""
@export var reward_type: String = ""
@export var reward_value: float = 0.0
@export var unlock_id: String = ""
## Optional minimum in-game day before the milestone may fire. 0 disables the gate.
@export var min_day: int = 0
## Optional minimum manager-trust tier index (0=cold, 1=neutral, 2=warm, 3=trusted).
## 0 disables the gate.
@export var min_manager_trust_tier_index: int = 0
