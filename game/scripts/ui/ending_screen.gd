## Full-screen ending overlay that renders the resolved run outcome.
class_name EndingScreen
extends CanvasLayer


signal dismissed


const CREDITS_SCENE: PackedScene = preload(
	"res://game/scenes/ui/credits_scene.tscn"
)
const FADE_DURATION: float = 0.6
const FALLBACK_TITLE: String = "An Ending"
const FALLBACK_TEXT: String = ""

const CATEGORY_LABELS: Dictionary = {
	"secret": "Secret Ending",
	"bankruptcy": "Bankruptcy",
	"success": "Success",
	"survival": "Survival",
}

const REPUTATION_TIER_NAMES: Array[String] = [
	"Notorious", "Unremarkable", "Reputable", "Legendary",
]

const WARM_BACKGROUND: Color = Color(0.16, 0.12, 0.08, 0.96)
const COOL_BACKGROUND: Color = Color(0.1, 0.11, 0.14, 0.96)
const NEUTRAL_BACKGROUND: Color = Color(0.1, 0.1, 0.15, 0.96)
const WARM_TEXT: Color = Color(0.9, 0.85, 0.72)
const COOL_TEXT: Color = Color(0.66, 0.68, 0.74)
const NEUTRAL_TEXT: Color = Color(0.82, 0.82, 0.82)
const WARM_ACCENT: Color = Color(0.96, 0.79, 0.47)
const COOL_ACCENT: Color = Color(0.76, 0.79, 0.88)
const NEUTRAL_ACCENT: Color = Color(0.88, 0.88, 0.9)

var _tween: Tween
var _cached_stats: Dictionary = {}
var _credits_overlay: CreditsScene

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
	_body_label.visible = false
	_cash_label.visible = false
	_assisted_label.visible = false
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	EventBus.ending_triggered.connect(_on_ending_triggered)
	_ensure_credits_overlay()


func _exit_tree() -> void:
	if is_instance_valid(_credits_overlay):
		_credits_overlay.queue_free()
		_credits_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if is_instance_valid(_credits_overlay) and _credits_overlay.visible:
		return
	var is_key_press: bool = event is InputEventKey and (event as InputEventKey).pressed
	var is_mouse_press: bool = (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
	)
	if event.is_action_pressed("ui_cancel") or is_key_press or is_mouse_press:
		get_viewport().set_input_as_handled()


func initialize(ending_id: StringName) -> void:
	_show_ending(ending_id, _cached_stats)


func _on_ending_triggered(
	ending_id: StringName, stats: Dictionary
) -> void:
	_show_ending(ending_id, stats)


func _show_ending(ending_id: StringName, stats: Dictionary) -> void:
	_cached_stats = stats.duplicate(true)
	var entry: Dictionary = ContentRegistry.get_entry(ending_id)
	if entry.is_empty():
		push_error(
			"EndingScreen: no ContentRegistry entry for '%s'" % ending_id
		)
		entry = _build_fallback_entry()

	_apply_content(entry)
	_populate_stats(_cached_stats)
	_apply_tone(str(entry.get("tone", "neutral")))
	_animate_in()


func _apply_content(entry: Dictionary) -> void:
	_title_label.text = str(entry.get("title", FALLBACK_TITLE))
	var category_id: String = str(
		entry.get("category", entry.get("ending_category", "survival"))
	)
	_category_label.text = CATEGORY_LABELS.get(category_id, "Survival")

	var body_text: String = str(
		entry.get("text", entry.get("flavor_text", FALLBACK_TEXT))
	)
	_flavor_label.text = body_text
	_flavor_label.visible = not body_text.is_empty()
	_body_label.text = ""
	_body_label.visible = false

	_load_trophy(entry)


func _load_trophy(entry: Dictionary) -> void:
	var trophy_path: String = str(entry.get("trophy_path", ""))
	if trophy_path.is_empty() or not ResourceLoader.exists(trophy_path):
		_trophy_texture.texture = null
		_trophy_texture.visible = false
		return
	var texture: Texture2D = load(trophy_path) as Texture2D
	_trophy_texture.texture = texture
	_trophy_texture.visible = texture != null


func _populate_stats(stats: Dictionary) -> void:
	_days_label.text = "Days Survived: %d" % int(stats.get("days_survived", 0))
	_revenue_label.text = "Total Revenue: $%.2f" % float(
		stats.get("cumulative_revenue", 0.0)
	)
	_stores_label.text = "Stores Owned: %d" % int(
		stats.get("owned_store_count_final", 0)
	)
	_customers_label.text = "Satisfied Customers: %d" % int(
		stats.get("satisfied_customer_count", 0)
	)
	_reputation_label.text = "Peak Reputation Tier: %s" % _get_reputation_tier_name(
		int(stats.get("max_reputation_tier", 0))
	)
	_rare_items_label.text = "Rare Items Sold: %d" % int(
		stats.get("rare_items_sold", 0)
	)
	_threads_label.text = "Secret Threads Completed: %d" % int(
		stats.get("secret_threads_completed", 0)
	)

	var assisted_run: bool = _is_assisted_run()
	_assisted_label.visible = assisted_run
	_assisted_label.text = "Assisted Run"
	_assisted_label.tooltip_text = (
		"Difficulty was reduced at least once during this playthrough"
	)
	_assisted_label.mouse_filter = Control.MOUSE_FILTER_PASS


func _get_reputation_tier_name(tier_index: int) -> String:
	var bounded_index: int = clampi(
		tier_index, 0, REPUTATION_TIER_NAMES.size() - 1
	)
	return REPUTATION_TIER_NAMES[bounded_index]


func _is_assisted_run() -> bool:
	var metadata: Dictionary = _get_save_manager_metadata()
	return bool(metadata.get("used_difficulty_downgrade", false))


func _get_save_manager_metadata() -> Dictionary:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var scene_save_manager: SaveManager = current_scene.get_node_or_null(
			"SaveManager"
		) as SaveManager
		if scene_save_manager:
			return scene_save_manager.get_slot_metadata(
				SaveManager.AUTO_SAVE_SLOT
			)

	var transient_save_manager: SaveManager = SaveManager.new()
	var metadata: Dictionary = transient_save_manager.get_slot_metadata(
		SaveManager.AUTO_SAVE_SLOT
	)
	transient_save_manager.free()
	return metadata


func _apply_tone(tone: String) -> void:
	var background_color: Color = NEUTRAL_BACKGROUND
	var text_color: Color = NEUTRAL_TEXT
	var accent_color: Color = NEUTRAL_ACCENT

	match tone:
		"positive":
			background_color = WARM_BACKGROUND
			text_color = WARM_TEXT
			accent_color = WARM_ACCENT
		"negative":
			background_color = COOL_BACKGROUND
			text_color = COOL_TEXT
			accent_color = COOL_ACCENT

	_background.color = background_color
	_title_label.add_theme_color_override("font_color", accent_color)
	_category_label.add_theme_color_override("font_color", text_color)
	_flavor_label.add_theme_color_override("font_color", text_color)
	_apply_stats_color(text_color)


func _apply_stats_color(color: Color) -> void:
	for child: Node in _stats_container.get_children():
		if child is Label:
			(child as Label).add_theme_color_override("font_color", color)


func _build_fallback_entry() -> Dictionary:
	return {
		"title": FALLBACK_TITLE,
		"text": FALLBACK_TEXT,
		"category": "survival",
		"tone": "neutral",
	}


func _animate_in() -> void:
	if is_instance_valid(_credits_overlay):
		_credits_overlay.visible = false
	visible = true
	_reset_modulates()
	_background.modulate.a = 0.0
	_title_label.modulate.a = 0.0
	_category_label.modulate.a = 0.0
	_flavor_label.modulate.a = 0.0
	_stats_container.modulate.a = 0.0
	_button_row.modulate.a = 0.0
	_trophy_texture.modulate.a = 0.0

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(
		_background, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_title_label, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_category_label, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_flavor_label, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_stats_container, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_button_row, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(
		_trophy_texture, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_main_menu_pressed() -> void:
	_fade_out_and(
		func() -> void:
			EventBus.ending_dismissed.emit()
			dismissed.emit()
			GameManager.go_to_main_menu()
	)


func _on_credits_pressed() -> void:
	_ensure_credits_overlay()
	if is_instance_valid(_credits_overlay):
		_credits_overlay.initialize()


func _ensure_credits_overlay() -> void:
	if is_instance_valid(_credits_overlay):
		return
	_credits_overlay = CREDITS_SCENE.instantiate() as CreditsScene
	var parent: Node = get_parent()
	if parent:
		parent.add_child(_credits_overlay)
	else:
		add_child(_credits_overlay)


func _fade_out_and(callback: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	for node: CanvasItem in [
		_background,
		_title_label,
		_category_label,
		_flavor_label,
		_trophy_texture,
		_stats_container,
		_button_row,
	]:
		_tween.tween_property(
			node, "modulate:a", 0.0, FADE_DURATION
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
	_stats_container.modulate = Color.WHITE
	_button_row.modulate = Color.WHITE
