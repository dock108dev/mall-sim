## Interactable 3D node representing the video rental returns bin.
class_name ReturnsBin
extends Interactable

var _count_label: Label3D = null
var _item_count: int = 0


func _ready() -> void:
	interaction_type = InteractionType.RETURNS_BIN
	display_name = "Returns Bin"
	interaction_prompt = "Check Returns"
	add_to_group("returns_bin")
	super._ready()
	_create_count_label()


## Sets the displayed item count (called by VideoRentalStoreController).
func set_item_count(count: int) -> void:
	_item_count = count
	_refresh_label()


func _refresh_label() -> void:
	if not _count_label:
		return
	if _item_count > 0:
		_count_label.text = "%d" % _item_count
		_count_label.visible = true
	else:
		_count_label.visible = false


func _create_count_label() -> void:
	_count_label = Label3D.new()
	_count_label.text = ""
	_count_label.font_size = 48
	_count_label.pixel_size = 0.005
	_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count_label.modulate = Color(1.0, 0.9, 0.3)
	_count_label.position = Vector3(0.0, 0.7, 0.0)
	_count_label.visible = false
	add_child(_count_label)
