## Full-screen ending overlay triggered when a run concludes.
class_name EndingScreen
extends CanvasLayer


signal dismissed


const FADE_DURATION: float = 1.5
const TEXT_DELAY: float = 0.8
const BODY_DELAY: float = 1.6
const STATS_DELAY: float = 2.0
const BUTTON_DELAY: float = 2.8
const FALLBACK_TITLE: String = "Unknown Ending"
const BGM_FADE: float = 2.0

const CATEGORY_LABELS: Dictionary = {
	"secret": "Secret Ending",
	"bankruptcy": "Bankruptcy",
	"legend": "Success",
	"success": "Success",
	"survival": "Survival",
}

const POSITIVE_CATEGORIES: Array[String] = [
	"secret", "legend", "success",
]

const REPUTATION_TIER_NAMES: Array[String] = [
	"Notorious", "Unremarkable", "Reputable", "Legendary",
]

var _tween: Tween
var _cached_stats: Dictionary = {}

@onready var _background: ColorRect = $Background
@onready var _trophy_texture: TextureRect = (
	$ScrollContainer/Content/VBox/TrophyTexture
)
@onready var _title_label: Label = (
	$ScrollContainer/Content/VBox/TitleLabel
)
@onready var _category_label: Label = (
	$ScrollContainer/Content/VBox/CategoryLabel
)
@onready var _flavor_label: Label = (
	$ScrollContainer/Content/VBox/FlavorLabel
)
@onready var _body_label: Label = (
	$ScrollContainer/Content/VBox/BodyLabel
)
@onready var _stats_container: VBoxContainer = (
	$ScrollContainer/Content/VBox/StatsContainer
)
@onready var _days_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/DaysLabel
)
@onready var _revenue_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/RevenueLabel
)
@onready var _cash_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/CashLabel
)
@onready var _stores_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/StoresLabel
)
@onready var _customers_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/CustomersLabel
)
@onready var _reputation_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/ReputationLabel
)
@onready var _rare_items_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/RareItemsLabel
)
@onready var _threads_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/ThreadsLabel
)
@onready var _assisted_label: Label = (
	$ScrollContainer/Content/VBox/StatsContainer/AssistedLabel
)
@onready var _main_menu_button: Button = (
	$ScrollContainer/Content/VBox/ButtonRow/MainMenuButton
)
@onready var _credits_button: Button = (
	$ScrollContainer/Content/VBox/ButtonRow/CreditsButton
)
@onready var _button_row: HBoxContainer = (
	$ScrollContainer/Content/VBox/ButtonRow
)


func _ready() -> void:
	visible = false
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	EventBus.ending_triggered.connect(_on_ending_triggered)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_ending_triggered(
	ending_id: StringName, stats: Dictionary
) -> void:
	_cached_stats = stats
	initialize(ending_id)


func initialize(ending_id: StringName) -> void:
	var entry: Dictionary = ContentRegistry.get_entry(ending_id)
	if entry.is_empty():
		push_error(
			"EndingScreen: no ContentRegistry entry for '%s'"
			% ending_id
		)
		entry = _build_fallback_entry()

	_title_label.text = str(entry.get("title", FALLBACK_TITLE))
	var category: String = str(
		entry.get("ending_category", "survival")
	)
	_category_label.text = CATEGORY_LABELS.get(
		category, "Survival"
	)

	var flavor: String = str(entry.get("flavor_text", ""))
	_flavor_label.text = flavor
	_flavor_label.visible = not flavor.is_empty()

	_body_label.text = str(entry.get("body", ""))

	_load_trophy(entry)
	_populate_stats(_cached_stats)
	_apply_tone(entry)

	var bgm_id: String = str(entry.get("bgm_id", ""))
	if not bgm_id.is_empty():
		AudioManager.play_bgm(bgm_id, BGM_FADE)

	_animate_in()


func _load_trophy(entry: Dictionary) -> void:
	var trophy_path: String = str(entry.get("trophy_path", ""))
	if trophy_path.is_empty() or not ResourceLoader.exists(trophy_path):
		_trophy_texture.visible = false
		return
	var tex: Texture2D = load(trophy_path) as Texture2D
	if tex:
		_trophy_texture.texture = tex
		_trophy_texture.visible = true
	else:
		_trophy_texture.visible = false


func _populate_stats(stats: Dictionary) -> void:
	_days_label.text = "Days Survived: %d" % int(
		stats.get("days_survived", 0)
	)
	_revenue_label.text = "Total Revenue: $%.2f" % float(
		stats.get("cumulative_revenue", 0.0)
	)
	_cash_label.text = "Final Cash: $%.2f" % float(
		stats.get("final_cash", 0.0)
	)
	_stores_label.text = "Stores Owned: %d" % int(
		stats.get("owned_store_count_final", 0)
	)
	_customers_label.text = "Satisfied Customers: %d" % int(
		stats.get("satisfied_customer_count", 0)
	)
	var tier_index: int = clampi(
		int(stats.get("max_reputation_tier", 0)),
		0, REPUTATION_TIER_NAMES.size() - 1
	)
	_reputation_label.text = "Peak Reputation: %s" % (
		REPUTATION_TIER_NAMES[tier_index]
	)
	_rare_items_label.text = "Rare Items Sold: %d" % int(
		stats.get("rare_items_sold", 0)
	)
	_threads_label.text = "Secret Threads Completed: %d" % int(
		stats.get("secret_threads_completed", 0)
	)

	var is_assisted: bool = bool(
		stats.get("used_difficulty_downgrade", false)
	)
	_assisted_label.visible = is_assisted
	if is_assisted:
		_assisted_label.text = "Assisted Run"
	_assisted_label.tooltip_text = (
		"Difficulty was reduced at least once during this playthrough"
	)
	_assisted_label.mouse_filter = Control.MOUSE_FILTER_PASS


func _apply_tone(entry: Dictionary) -> void:
	var bg_hex: String = str(
		entry.get("background_color", "#1a3a5c")
	)
	var accent_hex: String = str(
		entry.get("accent_color", "#f5c842")
	)
	var bg_color: Color = Color.from_string(bg_hex, Color.BLACK)
	var accent_color: Color = Color.from_string(
		accent_hex, Color.WHITE
	)

	_background.color = bg_color
	_title_label.add_theme_color_override(
		"font_color", accent_color
	)

	var category: String = str(
		entry.get("ending_category", "survival")
	)
	var is_positive: bool = category in POSITIVE_CATEGORIES

	if is_positive:
		_category_label.add_theme_color_override(
			"font_color", Color(0.9, 0.85, 0.7)
		)
		_flavor_label.add_theme_color_override(
			"font_color", Color(0.82, 0.8, 0.72)
		)
		_body_label.add_theme_color_override(
			"font_color", Color(0.85, 0.82, 0.75)
		)
		_apply_stats_color(Color(0.8, 0.75, 0.65))
	else:
		_category_label.add_theme_color_override(
			"font_color", Color(0.6, 0.6, 0.7)
		)
		_flavor_label.add_theme_color_override(
			"font_color", Color(0.62, 0.62, 0.68)
		)
		_body_label.add_theme_color_override(
			"font_color", Color(0.65, 0.65, 0.7)
		)
		_apply_stats_color(Color(0.6, 0.6, 0.65))


func _apply_stats_color(color: Color) -> void:
	for child: Node in _stats_container.get_children():
		if child is Label:
			(child as Label).add_theme_color_override(
				"font_color", color
			)


func _build_fallback_entry() -> Dictionary:
	return {
		"title": FALLBACK_TITLE,
		"ending_category": "survival",
		"body": "Your time at the mall has come to an end.",
		"flavor_text": "",
		"background_color": "#1a1a1a",
		"accent_color": "#888888",
	}


func _animate_in() -> void:
	_title_label.modulate = Color(1, 1, 1, 0)
	_category_label.modulate = Color(1, 1, 1, 0)
	_flavor_label.modulate = Color(1, 1, 1, 0)
	_body_label.modulate = Color(1, 1, 1, 0)
	_stats_container.modulate = Color(1, 1, 1, 0)
	_button_row.modulate = Color(1, 1, 1, 0)
	_background.modulate = Color(1, 1, 1, 0)
	_trophy_texture.modulate = Color(1, 1, 1, 0)
	visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(
		_background, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_title_label, "modulate:a", 1.0, 0.6
	).set_delay(TEXT_DELAY).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_category_label, "modulate:a", 1.0, 0.5
	).set_delay(0.2).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_flavor_label, "modulate:a", 1.0, 0.6
	).set_delay(0.2).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_trophy_texture, "modulate:a", 1.0, 0.6
	).set_delay(0.2).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_body_label, "modulate:a", 1.0, 0.8
	).set_delay(0.3).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_stats_container, "modulate:a", 1.0, 0.6
	).set_delay(0.4).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_button_row, "modulate:a", 1.0, 0.5
	).set_delay(0.4).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_CUBIC)


func _on_main_menu_pressed() -> void:
	_fade_out_and(
		func() -> void:
			EventBus.ending_dismissed.emit()
			dismissed.emit()
			GameManager.go_to_main_menu()
	)


func _on_credits_pressed() -> void:
	push_warning(
		"EndingScreen: credits overlay not yet implemented"
	)


func _fade_out_and(callback: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(
		_background, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_title_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_category_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_flavor_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_trophy_texture, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_body_label, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_stats_container, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_button_row, "modulate:a", 0.0, 0.5
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_callback(
		func() -> void:
			visible = false
			_reset_modulates()
			callback.call()
	)


func _reset_modulates() -> void:
	_background.modulate = Color.WHITE
	_title_label.modulate = Color.WHITE
	_category_label.modulate = Color.WHITE
	_flavor_label.modulate = Color.WHITE
	_trophy_texture.modulate = Color.WHITE
	_body_label.modulate = Color.WHITE
	_stats_container.modulate = Color.WHITE
	_button_row.modulate = Color.WHITE
