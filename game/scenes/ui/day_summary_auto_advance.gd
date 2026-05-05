## Auto-advance progress-bar / countdown driver for the DaySummary overlay.
## Owns the timer node, the running/paused/disabled flags, and the bar+label
## refresh logic so the overlay can stay focused on stat-row presentation.
##
## DaySummary holds a single instance and forwards lifecycle events
## (`start(day)`, `pause()`, `resume()`, `stop()`) plus a `triggered` signal it
## listens to in order to fire the auto-advance Continue press.
class_name DaySummaryAutoAdvance
extends RefCounted

signal triggered

const AUTO_ADVANCE_SECONDS: float = 12.0
const FINAL_DAY: int = 30

var _timer: Timer = null
var _bar: ProgressBar = null
var _label: Label = null
var _remaining: float = 0.0
var _running: bool = false
var _paused: bool = false
var _disabled: bool = false


## Wires the helper to its DaySummary nodes. Adds the internal Timer as a
## child of `host`. Must be called once after the overlay's `_ready`.
func setup(host: Node, bar: ProgressBar, label: Label) -> void:
	_bar = bar
	_label = label
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = 0.1
	_timer.timeout.connect(_on_tick)
	host.add_child(_timer)


## Begins the countdown for the current day. The final day disables the bar
## and shows the manual-confirm prompt instead.
func start(day: int) -> void:
	_disabled = day >= FINAL_DAY
	_paused = false
	_running = false
	_remaining = AUTO_ADVANCE_SECONDS
	if _timer != null:
		_timer.stop()
	if _disabled:
		_bar.visible = false
		_label.visible = true
		_label.text = "Confirm to view ending"
		return
	_bar.visible = true
	_bar.value = 1.0
	_label.visible = true
	_label.text = "Auto-advancing in %ds" % int(AUTO_ADVANCE_SECONDS)
	_running = true
	if _timer != null:
		_timer.start()


func pause() -> void:
	if _disabled:
		return
	_paused = true
	_label.text = "Reading… auto-advance paused"


func resume() -> void:
	if _disabled or not _running:
		return
	_paused = false
	var seconds_left: int = int(ceil(_remaining))
	_label.text = "Auto-advancing in %ds" % max(seconds_left, 0)


func stop() -> void:
	_running = false
	if _timer != null:
		_timer.stop()


func _on_tick() -> void:
	if not _running or _paused:
		return
	_remaining = max(0.0, _remaining - _timer.wait_time)
	var ratio: float = (
		_remaining / AUTO_ADVANCE_SECONDS
		if AUTO_ADVANCE_SECONDS > 0.0 else 0.0
	)
	_bar.value = ratio
	var seconds_left: int = int(ceil(_remaining))
	_label.text = "Auto-advancing in %ds" % max(seconds_left, 0)
	if _remaining <= 0.0:
		_running = false
		if _timer != null:
			_timer.stop()
		triggered.emit()
