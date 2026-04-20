## Spawns floating text labels for sale amounts, expense notifications,
## and CPUParticles2D bursts for special mechanic moments.
class_name VisualFeedback
extends CanvasLayer


const FLOAT_DURATION: float = PanelAnimator.FEEDBACK_FLOAT_DURATION
const FLOAT_DISTANCE: float = 40.0
const FONT_SIZE: int = 22
const EXPENSE_DISPLAY_DURATION: float = 2.0

## Anchor position for floating sale text (top-left area near cash).
const SALE_TEXT_ORIGIN := Vector2(140.0, 50.0)

## Anchor position for expense notifications (below cash area).
const EXPENSE_TEXT_ORIGIN := Vector2(20.0, 130.0)

## Screen-centre position used as default burst origin.
const BURST_ORIGIN := Vector2(960.0, 540.0)

var _expense_label: Label
var _expense_tween: Tween


func _ready() -> void:
	layer = 11
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.rare_pull_occurred.connect(_on_rare_pull_occurred)
	EventBus.refurbishment_completed.connect(_on_refurbishment_completed)
	EventBus.warranty_accepted.connect(_on_warranty_accepted_fx)
	_setup_expense_label()


func _setup_expense_label() -> void:
	_expense_label = Label.new()
	_expense_label.position = EXPENSE_TEXT_ORIGIN
	_expense_label.visible = false
	_expense_label.add_theme_font_size_override(
		"font_size", 16
	)
	add_child(_expense_label)


func _on_item_sold(
	_item_id: String, price: float, _category: String
) -> void:
	_spawn_floating_text(
		"+$%.2f" % price,
		SALE_TEXT_ORIGIN,
		UIThemeConstants.get_positive_color()
	)


func _on_money_changed(
	old_amount: float, new_amount: float
) -> void:
	var delta: float = new_amount - old_amount
	if delta >= 0.0:
		return
	# Show expense notification for deductions (rent, orders, etc.)
	_show_expense_notification(delta)


func _spawn_floating_text(
	text: String, origin: Vector2, color: Color
) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = origin
	label.modulate = color
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.z_index = 100
	add_child(label)

	var tween: Tween = create_tween()
	tween.tween_property(
		label, "position:y",
		origin.y - FLOAT_DISTANCE, FLOAT_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	## Hold full opacity for 60% of duration, then fade in final 40%.
	var fade_delay: float = FLOAT_DURATION * 0.6
	var fade_time: float = FLOAT_DURATION * 0.4
	tween.parallel().tween_interval(fade_delay)
	tween.tween_property(
		label, "modulate:a", 0.0, fade_time
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(label.queue_free)


func _show_expense_notification(delta: float) -> void:
	if _expense_tween and _expense_tween.is_valid():
		_expense_tween.kill()
	_expense_label.text = "-$%.2f" % absf(delta)
	_expense_label.modulate = UIThemeConstants.get_negative_color()
	_expense_label.modulate.a = 1.0
	_expense_label.visible = true

	_expense_tween = create_tween()
	_expense_tween.tween_interval(EXPENSE_DISPLAY_DURATION * 0.6)
	_expense_tween.tween_property(
		_expense_label, "modulate:a", 0.0,
		EXPENSE_DISPLAY_DURATION * 0.4
	)
	_expense_tween.tween_callback(_hide_expense_label)


func _hide_expense_label() -> void:
	_expense_label.visible = false


func _on_rare_pull_occurred(_pack_id: String) -> void:
	_spawn_burst(
		BURST_ORIGIN,
		Color(1.0, 0.82, 0.1, 1.0),  # foil gold
		32, 120.0, 1.5
	)


func _on_refurbishment_completed(
	_item_id: String, _success: bool, _condition: String
) -> void:
	_spawn_burst(
		BURST_ORIGIN,
		Color(0.55, 0.95, 0.55, 1.0),  # sparkle green
		20, 80.0, 1.0
	)


func _on_warranty_accepted_fx(
	_item_id: String, _tier_id: String, _fee: float
) -> void:
	_spawn_burst(
		BURST_ORIGIN,
		Color(0.43, 0.81, 0.35, 1.0),  # success green
		16, 60.0, 0.8
	)


## Spawns a short-lived CPUParticles2D burst then frees it.
func _spawn_burst(
	origin: Vector2,
	color: Color,
	amount: int,
	speed: float,
	lifetime: float
) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = origin
	particles.emitting = true
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.speed_scale = 1.0
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0.0, 200.0)
	particles.color = color
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	add_child(particles)
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.5)
	timer.timeout.connect(particles.queue_free)
