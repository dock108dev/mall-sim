## Verifies the player-facing toast surface enforces the BRAINDUMP copy-
## length rule. Toasts are momentary and must fit a compact 2-line card;
## longer copy reads as a tutorial paragraph (the BRAINDUMP 'Bad' example).
##
## The constant `ToastNotificationUI.MAX_MESSAGE_CHARS` is the contract;
## these tests pin its value and confirm common Day-1 toast call sites
## produce strings that stay within it.
extends GutTest


func test_max_message_chars_constant_is_72() -> void:
	# Locks the cap so a future refactor can't quietly raise it.
	assert_eq(
		ToastNotificationUI.MAX_MESSAGE_CHARS, 72,
		"Toast max length contract must stay at 72 chars"
	)


func test_beta_day1_toasts_fit_under_limit() -> void:
	# Hardcoded sample of the literal Day-1 toast strings (with realistic
	# format-args substituted). Any future Day-1 toast that gets added
	# should be added here so the limit is enforced at test time, not at
	# the first time a player triggers the chain in debug.
	var samples: Array[String] = [
		"Training: talk to the manager.",
		"Shipment checked. 5 items available in back room.",
		"Stocked 5 games on the used games shelf.",
		"Closing time. Wrap up at the register.",
		"Sale complete: +$18",
		"She thanked you and walked off.",
		"Still too early to close. Finish out the shift first.",
	]
	for s: String in samples:
		assert_true(
			s.length() <= ToastNotificationUI.MAX_MESSAGE_CHARS,
			"Day-1 toast '%s' is %d chars, must be <= %d"
			% [s, s.length(), ToastNotificationUI.MAX_MESSAGE_CHARS]
		)
