## Unit tests for ErrorBanner autoload — show/hide behaviour, signal emission,
## Back to Menu button wiring.
extends GutTest

const ErrorBannerScript: GDScript = preload("res://game/autoload/error_banner.gd")

var _banner: Node


func before_each() -> void:
	_banner = ErrorBannerScript.new()
	add_child_autofree(_banner)


func test_banner_hidden_on_ready() -> void:
	assert_false(_banner.is_showing(), "banner should be hidden by default")


func test_show_failure_renders_title_and_reason() -> void:
	_banner.show_failure("Store Failed", "player missing")
	assert_true(_banner.is_showing(), "banner should be visible after show_failure")
	var title_node: Label = _banner._title_label
	var reason_node: Label = _banner._reason_label
	assert_eq(title_node.text, "Store Failed")
	assert_eq(reason_node.text, "player missing")


func test_show_failure_emits_banner_shown() -> void:
	watch_signals(_banner)
	_banner.show_failure("t", "r")
	assert_signal_emitted_with_parameters(_banner, "banner_shown", ["t", "r"])


func test_hide_failure_emits_banner_hidden() -> void:
	watch_signals(_banner)
	_banner.show_failure("t", "r")
	_banner.hide_failure()
	assert_false(_banner.is_showing())
	assert_signal_emitted(_banner, "banner_hidden")


func test_hide_failure_noop_when_already_hidden() -> void:
	watch_signals(_banner)
	_banner.hide_failure()
	assert_signal_not_emitted(_banner, "banner_hidden")


func test_back_button_exists_and_is_visible_when_shown() -> void:
	_banner.show_failure("t", "r")
	var btn: Button = _banner._back_button
	assert_not_null(btn, "Back to Menu button should exist")
	assert_eq(btn.text, "Back to Menu")


func test_back_button_press_emits_request_and_hides_banner() -> void:
	watch_signals(_banner)
	_banner.show_failure("t", "r")
	var btn: Button = _banner._back_button
	btn.emit_signal("pressed")
	assert_signal_emitted(_banner, "back_to_menu_requested")
	assert_false(_banner.is_showing(), "banner should hide after Back pressed")


func test_show_failure_after_audit_fail_surfaces_error() -> void:
	# Simulates the contract: a subsystem calls AuditLog.fail_check and then
	# raises the banner. This is the pattern that replaces silent null-skip
	# returns in scene_loader / store_controller / player_controller.
	watch_signals(_banner)
	AuditLog.fail_check(&"test_null_node", "no node")
	_banner.show_failure("Missing Node", "no node")
	assert_true(_banner.is_showing())
	assert_signal_emitted(_banner, "banner_shown")
