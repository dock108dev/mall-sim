## Full-screen red failure banner raised from any subsystem on an unrecoverable
## runtime violation. Pairs with AuditLog.fail_check to surface the failure
## loudly — the "no grey screens" rule from DESIGN.md. Back to Menu routes
## through GameManager.change_scene (the single scene-router owner).
extends CanvasLayer

signal banner_shown(title: String, reason: String)
signal banner_hidden()
signal back_to_menu_requested()

const BANNER_LAYER: int = 256
const _COLOR_BG: Color = Color(0.55, 0.05, 0.05, 0.95)
const _COLOR_CARD: Color = Color(0.15, 0.02, 0.02, 1.0)
const _COLOR_TEXT: Color = Color(1.0, 0.95, 0.95, 1.0)

var _is_visible: bool = false
var _root: Control
var _title_label: Label
var _reason_label: Label
var _back_button: Button


func _ready() -> void:
	layer = BANNER_LAYER
	_build_ui()
	_set_visible(false)


## Raises the banner with the supplied title and reason. Subsystems should pair
## this with `AuditLog.fail_check(<checkpoint>, <reason>)`.
func show_failure(title: String, reason: String) -> void:
	assert(title != "", "ErrorBanner.show_failure: empty title")
	_title_label.text = title
	_reason_label.text = reason
	_set_visible(true)
	banner_shown.emit(title, reason)


## Dismisses the banner without changing scene. Use sparingly — the default
## action is to route back to the main menu via the Back button.
func hide_failure() -> void:
	if not _is_visible:
		return
	_set_visible(false)
	banner_hidden.emit()


## Returns true when the banner is currently rendered.
func is_showing() -> bool:
	return _is_visible


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "ErrorBannerRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg: ColorRect = ColorRect.new()
	bg.color = _COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var card: PanelContainer = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(640, 320)
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = _COLOR_CARD
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", card_style)
	_root.add_child(card)
	card.position = Vector2(-320, -160)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_color_override("font_color", _COLOR_TEXT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	_reason_label = Label.new()
	_reason_label.name = "ReasonLabel"
	_reason_label.add_theme_color_override("font_color", _COLOR_TEXT)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_reason_label)

	_back_button = Button.new()
	_back_button.name = "BackToMenuButton"
	_back_button.text = "Back to Menu"
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(_on_back_pressed)
	vbox.add_child(_back_button)


func _set_visible(value: bool) -> void:
	_is_visible = value
	_root.visible = value


func _on_back_pressed() -> void:
	back_to_menu_requested.emit()
	_set_visible(false)
	banner_hidden.emit()
	# Route back to main menu via the GameManager autoload — it owns
	# scene transitions (see docs/architecture/ownership.md). In unit
	# tests that instantiate ErrorBanner directly (no autoload tree),
	# the signal above is sufficient; skip the scene change then.
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var gm: Node = tree.root.get_node_or_null("GameManager")
	if gm == null:
		return
	assert(gm.has_method("change_scene"), "GameManager missing change_scene")
	var menu_path: String = gm.get("MAIN_MENU_SCENE_PATH")
	assert(menu_path != "", "GameManager.MAIN_MENU_SCENE_PATH empty")
	gm.call("change_scene", menu_path)
