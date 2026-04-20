## Boot scene controller that runs synchronous startup checks before opening main menu.
extends Node

@onready var _title_label: Label = $TitleLabel
@onready var _error_panel: PanelContainer = $ErrorPanel
@onready var _error_label: RichTextLabel = $ErrorPanel/MarginContainer/ErrorLabel


func _ready() -> void:
	_error_panel.visible = false
	if GameManager.is_boot_completed():
		push_error("Boot: boot scene entered after boot already completed")
		_transition_to_main_menu()
		return
	call_deferred("initialize")


func initialize() -> void:
	DataLoaderSingleton.load_all()

	var load_errors: Array[String] = DataLoaderSingleton.get_load_errors()
	if not load_errors.is_empty():
		var msg: String = "Content loading failed:\n"
		for err: String in load_errors:
			msg += "  - %s\n" % err
		_show_error(msg)
		return

	if not ContentRegistry.is_ready():
		push_error(
			"Boot: ContentRegistry.is_ready() returned false after DataLoader load"
		)
		_show_error("ContentRegistry failed to initialize — no content loaded.")
		return

	var store_ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	if store_ids.size() < 5:
		push_error("Boot: only %d store IDs registered" % store_ids.size())
		_show_error(
			"Expected at least 5 store IDs, found %d." % store_ids.size()
		)
		return

	Settings.load()
	AudioManager.initialize()
	GameManager.mark_boot_completed()
	_transition_to_main_menu()


func _show_error(message: String) -> void:
	_title_label.visible = false
	_error_panel.visible = true
	_error_label.text = "[b]Boot Error[/b]\n\n%s\n\nCheck the console for details." % message


func _transition_to_main_menu() -> void:
	GameManager.transition_to(GameManager.GameState.MAIN_MENU)
