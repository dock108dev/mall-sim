## Manages the ambient moment display queue, surfacing one card at a time.
## Normal moments arrive via moment_displayed; high-priority moments bypass the
## queue via enqueue_priority() and always display before any pending normals.
##
## The tray self-suspends during day-end so modals don't overlap cards.
class_name MomentsTray
extends CanvasLayer

## Maximum pending cards that can wait in either queue before new ones are
## dropped. Prevents unbounded growth during long idle stretches.
const MAX_QUEUE_DEPTH: int = 8

## Seconds of silence inserted between consecutive card appearances.
const INTER_CARD_PAUSE_SECS: float = 0.35

const _MomentCardScene: PackedScene = preload(
	"res://game/scenes/ui/moment_card.tscn"
)

var _normal_queue: Array[Dictionary] = []
var _priority_queue: Array[Dictionary] = []
var _active_card: MomentCard = null
var _suspended: bool = false
var _cards_shown_today: int = 0
var _total_cards_shown: int = 0

@onready var _container: VBoxContainer = $Container


func _ready() -> void:
	EventBus.moment_displayed.connect(_on_moment_displayed)
	if EventBus.has_signal("day_started"):
		EventBus.day_started.connect(_on_day_started)
	if EventBus.has_signal("day_ended"):
		EventBus.day_ended.connect(_on_day_ended)


# ── public API ───────────────────────────────────────────────────────────────


## Inserts a high-priority card that will show before any normal queued cards.
## Useful for secret-thread revelations and milestone moments.
func enqueue_priority(
	moment_id: StringName,
	flavor_text: String,
	duration_seconds: float,
	character_name: String = "",
	display_type: String = "toast",
) -> void:
	if _priority_queue.size() >= MAX_QUEUE_DEPTH:
		return
	_priority_queue.append({
		"moment_id": moment_id,
		"flavor_text": flavor_text,
		"duration_seconds": duration_seconds,
		"character_name": character_name,
		"display_type": display_type,
	})
	_try_show_next()


## Pauses card display. Any in-progress card finishes; no new cards start.
func suspend() -> void:
	_suspended = true


## Resumes card display and immediately shows the next queued card if any.
func resume() -> void:
	_suspended = false
	_try_show_next()


## Removes all queued cards without showing them. The active card is dismissed.
func clear_queue() -> void:
	_normal_queue.clear()
	_priority_queue.clear()
	_dismiss_active_card()


## Peeks at the moment_id of the next card that will be shown, or &"" if empty.
func peek_next_id() -> StringName:
	if not _priority_queue.is_empty():
		return StringName(str(_priority_queue[0].get("moment_id", "")))
	if not _normal_queue.is_empty():
		return StringName(str(_normal_queue[0].get("moment_id", "")))
	return &""


## Combined pending count across both queues.
func get_queue_depth() -> int:
	return _priority_queue.size() + _normal_queue.size()


## Pending high-priority cards only.
func get_priority_queue_depth() -> int:
	return _priority_queue.size()


## Pending normal cards only.
func get_normal_queue_depth() -> int:
	return _normal_queue.size()


## True when a card is visible on screen.
func has_active_card() -> bool:
	return _active_card != null and is_instance_valid(_active_card)


## True while card display is paused.
func is_suspended() -> bool:
	return _suspended


## Cards displayed during the current game day.
func get_cards_shown_today() -> int:
	return _cards_shown_today


## All cards displayed since the tray was created (session total).
func get_total_cards_shown() -> int:
	return _total_cards_shown


# ── private ──────────────────────────────────────────────────────────────────


func _on_moment_displayed(
	moment_id: StringName,
	flavor_text: String,
	duration_seconds: float,
) -> void:
	if _normal_queue.size() >= MAX_QUEUE_DEPTH:
		return
	_normal_queue.append({
		"moment_id": moment_id,
		"flavor_text": flavor_text,
		"duration_seconds": duration_seconds,
		"character_name": "",
		"display_type": "toast",
	})
	_try_show_next()


func _on_day_started(_day: int) -> void:
	_cards_shown_today = 0
	resume()


func _on_day_ended(_day: int) -> void:
	suspend()


func _try_show_next() -> void:
	if has_active_card() or _suspended:
		return
	if _priority_queue.is_empty() and _normal_queue.is_empty():
		EventBus.moment_queue_empty.emit()
		return
	var entry: Dictionary
	if not _priority_queue.is_empty():
		entry = _priority_queue.pop_front()
	else:
		entry = _normal_queue.pop_front()
	_spawn_card(entry)


func _spawn_card(entry: Dictionary) -> void:
	var card: MomentCard = _MomentCardScene.instantiate() as MomentCard
	_container.add_child(card)
	card.setup(
		StringName(str(entry.get("moment_id", ""))),
		str(entry.get("flavor_text", "")),
		float(entry.get("duration_seconds", 5.0)),
		str(entry.get("character_name", "")),
		str(entry.get("display_type", "toast")),
	)
	card.dismissed.connect(_on_card_dismissed)
	_active_card = card
	_cards_shown_today += 1
	_total_cards_shown += 1


func _on_card_dismissed(_moment_id: StringName) -> void:
	_active_card = null
	if get_queue_depth() > 0 and not _suspended:
		var timer := get_tree().create_timer(INTER_CARD_PAUSE_SECS)
		timer.timeout.connect(_try_show_next)


func _dismiss_active_card() -> void:
	if has_active_card():
		_active_card.queue_free()
		_active_card = null
