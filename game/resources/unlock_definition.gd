## Data resource defining an unlockable reward with its effect type and conditions.
class_name UnlockDefinition
extends Resource

const VALID_EFFECT_TYPES: PackedStringArray = [
	"catalog_expansion",
	"time_extension",
	"info_reveal",
	"vip_spawn",
	"cosmetic_nameplate",
	"cosmetic_badge",
	"fixture_unlock",
	"employee_skill",
]

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: String = ""
@export var effect_target: String = ""
@export var effect_value: float = 0.0
@export var unlock_message: String = ""


func is_valid_effect_type() -> bool:
	return effect_type in VALID_EFFECT_TYPES
