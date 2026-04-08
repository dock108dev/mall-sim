## Debug overlay — shows FPS, game state, and sample data readout.
## Toggle with F3 (toggle_debug input action).
extends CanvasLayer

@onready var label: Label = $Label

var _visible := false


func _ready() -> void:
	visible = false
	_load_sample_data()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_visible = not _visible
		visible = _visible


func _process(_delta: float) -> void:
	if not _visible:
		return
	var fps := Engine.get_frames_per_second()
	var state_name := GameManager.GameState.keys()[GameManager.current_state]
	label.text = "FPS: %d | State: %s" % [fps, state_name]


func _load_sample_data() -> void:
	# Prove data-driven content works by reading a sample item JSON.
	var path := "res://game/content/items/sports_baseball_card.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Dictionary = json.data
			print("[DebugOverlay] Loaded sample item: %s ($%s)" % [data.get("name", "?"), data.get("base_price", "?")])
