## Dev overlay: samples screen pixels to measure store-accent + alert color budget.
## Design rule: store-accent + alert pixels must stay ≤10% of visible screen.
## Hidden in release builds. Toggle with F2, or call sample() directly.
extends CanvasLayer

const SAMPLE_STRIDE: int = 4
const BUDGET_THRESHOLD: float = 0.10
const SAMPLE_INTERVAL_FRAMES: int = 60

## Store-accent colors from the four-layer palette spec.
const _ACCENT_COLORS: Array[Color] = [
	Color(0.482, 0.294, 0.812, 1.0), # retro_games   #7B4BCF
	Color(0.180, 0.710, 0.659, 1.0), # pocket_creatures #2EB5A8
	Color(0.820, 0.231, 0.180, 1.0), # video_rental   #D13B2E
	Color(0.227, 0.659, 0.847, 1.0), # electronics    #3AA8D8
	Color(0.788, 0.604, 0.169, 1.0), # sports_cards   #C99A2B
]

## Alert colors that count against the budget.
const _ALERT_COLORS: Array[Color] = [
	Color(0.427, 0.812, 0.353, 1.0), # success  #6DCF5A
	Color(0.949, 0.722, 0.110, 1.0), # warning  #F2B81C
	Color(0.898, 0.243, 0.169, 1.0), # error    #E53E2B
	Color(0.357, 0.722, 0.910, 1.0), # info     #5BB8E8
	Color(1.0, 0.176, 0.310, 1.0),   # critical #FF2D4F
	Color(0.561, 0.878, 0.459, 1.0), # money_gain #8FE075
	Color(1.0, 0.706, 0.659, 1.0),   # money_cost #FFB4A8
]

## How close a pixel must be to count (squared Euclidean in linear RGB).
const _MATCH_THRESHOLD_SQ: float = 0.12

var _visible_overlay: bool = false
var _frame_counter: int = 0

@onready var _label: Label = $Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 99
	visible = false


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).physical_keycode == KEY_F2:
			_visible_overlay = not _visible_overlay
			visible = _visible_overlay


func _process(_delta: float) -> void:
	if not _visible_overlay:
		return
	_frame_counter += 1
	if _frame_counter >= SAMPLE_INTERVAL_FRAMES:
		_frame_counter = 0
		var pct: float = sample()
		_label.text = "Accent+Alert: %.1f%%" % (pct * 100.0)
		if pct > BUDGET_THRESHOLD:
			push_warning(
				"AccentBudgetOverlay: accent+alert pixels %.1f%% exceeds 10%% budget" % (pct * 100.0)
			)


## Samples the current viewport and returns the fraction (0.0–1.0) of pixels
## that fall within the store-accent + alert color set.
## Expensive; call infrequently (already rate-limited in _process).
func sample() -> float:
	var image: Image = get_viewport().get_texture().get_image()
	if not image:
		return 0.0
	var width: int = image.get_width()
	var height: int = image.get_height()
	var total_sampled: int = 0
	var matched: int = 0

	for y: int in range(0, height, SAMPLE_STRIDE):
		for x: int in range(0, width, SAMPLE_STRIDE):
			var px: Color = image.get_pixel(x, y)
			total_sampled += 1
			if _is_accent_or_alert(px):
				matched += 1

	if total_sampled == 0:
		return 0.0
	var pct: float = float(matched) / float(total_sampled)
	push_warning("[AccentBudget] sampled %d px, %.1f%% accent+alert" % [total_sampled, pct * 100.0])
	return pct


func _is_accent_or_alert(px: Color) -> bool:
	for c: Color in _ACCENT_COLORS:
		if _color_dist_sq(px, c) <= _MATCH_THRESHOLD_SQ:
			return true
	for c: Color in _ALERT_COLORS:
		if _color_dist_sq(px, c) <= _MATCH_THRESHOLD_SQ:
			return true
	return false


func _color_dist_sq(a: Color, b: Color) -> float:
	var dr: float = a.r - b.r
	var dg: float = a.g - b.g
	var db: float = a.b - b.b
	return dr * dr + dg * dg + db * db
