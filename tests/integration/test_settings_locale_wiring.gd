## Integration test — Settings language preference → TranslationServer.set_locale() wiring.
## Verifies: Settings.set_preference(&"language", locale_code) → preference_changed signal
## → TranslationServer.get_locale() reflects the new value.
extends GutTest

const TEST_PATH: String = "user://settings_locale_wiring_test.cfg"

var _settings: Node


func before_each() -> void:
	_settings = Node.new()
	_settings.set_script(preload("res://game/autoload/settings.gd"))
	_settings.settings_path = TEST_PATH
	add_child_autofree(_settings)


func after_each() -> void:
	TranslationServer.set_locale("en")
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


# ── Boot initialization ────────────────────────────────────────────────────────


func test_boot_persisted_language_es_applies_locale() -> void:
	var boot_path: String = "user://settings_locale_wiring_boot_es.cfg"
	var config := ConfigFile.new()
	config.set_value("locale", "language", "es")
	config.save(boot_path)

	var settings: Node = Node.new()
	settings.set_script(preload("res://game/autoload/settings.gd"))
	settings.settings_path = boot_path
	add_child_autofree(settings)

	assert_eq(
		TranslationServer.get_locale(), "es",
		"TranslationServer.get_locale() must be 'es' after Settings._ready() with persisted language='es'"
	)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(boot_path))


func test_boot_missing_language_key_defaults_to_en() -> void:
	var boot_path: String = "user://settings_locale_wiring_boot_no_lang.cfg"
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", false)
	config.save(boot_path)

	var settings: Node = Node.new()
	settings.set_script(preload("res://game/autoload/settings.gd"))
	settings.settings_path = boot_path
	add_child_autofree(settings)

	assert_eq(
		TranslationServer.get_locale(), "en",
		"TranslationServer.get_locale() must be 'en' when no language key is present in settings.cfg"
	)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(boot_path))


func test_boot_empty_language_string_falls_back_to_en() -> void:
	var boot_path: String = "user://settings_locale_wiring_boot_empty_lang.cfg"
	var config := ConfigFile.new()
	config.set_value("locale", "language", "")
	config.save(boot_path)

	var settings: Node = Node.new()
	settings.set_script(preload("res://game/autoload/settings.gd"))
	settings.settings_path = boot_path
	add_child_autofree(settings)

	assert_eq(
		TranslationServer.get_locale(), "en",
		"TranslationServer.get_locale() must be 'en' when language is empty string (empty string guard)"
	)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(boot_path))


# ── Runtime update ─────────────────────────────────────────────────────────────


func test_runtime_set_language_es_updates_translation_server() -> void:
	_settings.set_preference(&"language", "es")

	assert_eq(
		TranslationServer.get_locale(), "es",
		"TranslationServer.get_locale() must return 'es' immediately after set_preference(&\"language\", \"es\")"
	)


func test_runtime_set_language_en_updates_translation_server() -> void:
	# Start from a non-default locale so the idempotency guard does not short-circuit.
	_settings.set_preference(&"language", "es")
	_settings.set_preference(&"language", "en")

	assert_eq(
		TranslationServer.get_locale(), "en",
		"TranslationServer.get_locale() must return 'en' immediately after set_preference(&\"language\", \"en\")"
	)


func test_preference_changed_signal_fires_with_language_key_and_es_value() -> void:
	watch_signals(EventBus)

	_settings.set_preference(&"language", "es")

	assert_signal_emitted(
		EventBus, "preference_changed",
		"EventBus.preference_changed must fire when set_preference(&\"language\", \"es\") is called"
	)
	var params: Array = get_signal_parameters(EventBus, "preference_changed")
	assert_eq(
		StringName(params[0]), &"language",
		"preference_changed signal key must be &\"language\""
	)
	assert_eq(
		params[1] as String, "es",
		"preference_changed signal value must be \"es\""
	)
