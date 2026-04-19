## Displays a single ambient moment flavor text card in the moments tray.
class_name MomentCard
extends PanelContainer


var moment_id: StringName = &""

@onready var _label: Label = $Margin/Label
@onready var _progress: ProgressBar = $Progress


func setup(
	p_moment_id: StringName,
	p_flavor_text: String,
	p_duration_seconds: float,
) -> void:
	moment_id = p_moment_id
	if _label:
		_label.text = p_flavor_text
	if _progress:
		_progress.max_value = p_duration_seconds
		_progress.value = p_duration_seconds
	EventBus.moment_expired.connect(_on_moment_expired)


func _on_moment_expired(expired_id: StringName) -> void:
	if expired_id == moment_id:
		queue_free()
