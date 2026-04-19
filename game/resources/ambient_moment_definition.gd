## Definition for a data-driven ambient flavor moment.
class_name AmbientMomentDefinition
extends Resource


var id: String = ""
var name: String = ""
var category: String = "any"
var trigger_category: String = ""
var trigger_value: String = ""
var display_type: StringName = &"toast"
var flavor_text: String = ""
var audio_cue_id: StringName = &""
var scheduling_weight: float = 1.0
var cooldown_days: int = 1
## Optional: only eligible when the active store matches this ID. Empty = any store.
var store_id: String = ""
## Optional: only eligible in this season ("spring","summer","fall","winter"). Empty = any.
var season_id: String = ""
## Optional: only eligible from this day onward. 0 = no minimum.
var min_day: int = 0
## Optional: only eligible up to and including this day. 0 = no maximum.
var max_day: int = 0
## How long the moment card stays visible before auto-dismissing (seconds).
var duration_seconds: float = 8.0
