## Pre-run hook executed once before the GUT test suite starts.
## Resets DifficultySystemSingleton to "normal" so that tests which do not
## explicitly set a difficulty tier are not affected by any persisted user
## preference (e.g. a developer who last played on "hard").
extends GutHookScript


func run() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
