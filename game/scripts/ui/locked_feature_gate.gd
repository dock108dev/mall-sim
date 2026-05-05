## Helper for gating UI features behind UnlockSystem grants.
##
## Centralizes the locked-feature UX contract: when the player attempts to use
## a feature that is not yet unlocked, show a 2-second auto-dismissing label
## explaining that Vic (the manager) has not trained the player on it yet. No
## manual dismiss is required and no further action is implied — repeated
## attempts simply show the same label.
##
## Callers wrap their feature entry-points like:
##
##     if not LockedFeatureGate.try_access(&"employee_tradein_certified", "Trade-in"):
##         return
##     # …feature logic…
##
## or use `is_unlocked` for a non-toasting check.
class_name LockedFeatureGate
extends RefCounted


const LABEL_DURATION_SECONDS: float = 2.0
const TOAST_CATEGORY: StringName = &"locked_feature"
const LABEL_FORMAT: String = "%s — Vic hasn't trained you on this yet."


## Returns true when `unlock_id` has been granted. Otherwise emits an
## auto-dismissing locked-feature toast and returns false. `feature_name` is the
## human-readable label shown to the player.
static func try_access(
	unlock_id: StringName, feature_name: String
) -> bool:
	if is_unlocked(unlock_id):
		return true
	emit_locked_label(feature_name)
	return false


## Returns true when `unlock_id` has been granted by UnlockSystem.
static func is_unlocked(unlock_id: StringName) -> bool:
	return UnlockSystemSingleton.is_unlocked(unlock_id)


## Emits the 2-second auto-dismissing locked-feature label.
static func emit_locked_label(feature_name: String) -> void:
	var label: String = LABEL_FORMAT % feature_name
	EventBus.toast_requested.emit(
		label, TOAST_CATEGORY, LABEL_DURATION_SECONDS
	)
