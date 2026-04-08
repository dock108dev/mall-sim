## Root scene for the playable game world.
extends Node3D


func _ready() -> void:
	GameManager.current_state = GameManager.GameState.PLAYING
	EventBus.day_started.emit(1)
