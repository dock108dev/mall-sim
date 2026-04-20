## Persistent root gameplay scene: the mall hub.
## Hosts five StorefrontCards and decorative ambient customer sprites over a
## game_world child that owns all runtime systems. Store mechanics are launched
## via slide-out drawers in response to EventBus.storefront_clicked.
class_name MallHub
extends Node

const AMBIENCE_KEY: String = "food_court_murmur"
const DUCK_DB: float = -12.0
const DUCK_DURATION: float = 0.3

@onready var _storefront_row: Control = $HubLayer/ConcourseRoot/StorefrontRow
@onready var _ambient_layer: Node2D = $HubLayer/ConcourseRoot/AmbientCustomers
@onready var _ambience_player: AudioStreamPlayer = $HubAmbiencePlayer

var _duck_tween: Tween = null
var _normal_volume_db: float = -6.0


func _ready() -> void:
	EventBus.storefront_clicked.connect(_on_storefront_clicked)
	EventBus.drawer_opened.connect(_on_drawer_opened)
	EventBus.drawer_closed.connect(_on_drawer_closed)
	_start_hub_ambience()


## Returns the five storefront cards in slot order. Used by tests.
func get_storefront_cards() -> Array[StorefrontCard]:
	var cards: Array[StorefrontCard] = []
	for child: Node in _storefront_row.get_children():
		var card: StorefrontCard = child as StorefrontCard
		if card != null:
			cards.append(card)
	return cards


func _on_storefront_clicked(store_id: StringName) -> void:
	EventBus.enter_store_requested.emit(store_id)


func _start_hub_ambience() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = AudioManager.get_ambient_stream(AMBIENCE_KEY)
	if stream == null:
		return
	_normal_volume_db = _ambience_player.volume_db
	_ambience_player.stream = stream
	_ambience_player.play()


func _on_drawer_opened(_store_id: StringName) -> void:
	if not _ambience_player.playing:
		return
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_property(
		_ambience_player, "volume_db", DUCK_DB, DUCK_DURATION
	)


func _on_drawer_closed(_store_id: StringName) -> void:
	if not _ambience_player.playing:
		return
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_property(
		_ambience_player, "volume_db", _normal_volume_db, DUCK_DURATION
	)


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null
