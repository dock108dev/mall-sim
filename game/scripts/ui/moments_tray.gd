## Manages up to 3 concurrent ambient moment cards during the day phase.
## Listens to moment_displayed / moment_expired on EventBus.
class_name MomentsTray
extends CanvasLayer


const _MomentCardScene: PackedScene = preload(
	"res://game/scenes/ui/moment_card.tscn"
)

@onready var _container: VBoxContainer = $Container


func _ready() -> void:
	EventBus.moment_displayed.connect(_on_moment_displayed)


func _on_moment_displayed(
	moment_id: StringName,
	flavor_text: String,
	duration_seconds: float,
) -> void:
	var card: MomentCard = _MomentCardScene.instantiate() as MomentCard
	_container.add_child(card)
	card.setup(moment_id, flavor_text, duration_seconds)
