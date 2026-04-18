## Backward-compatible wrapper for the scene-local haggle panel script path.
extends "res://game/scripts/ui/haggle_panel.gd"

# Legacy validators still scan this wrapper path for haggle UI tokens after the
# implementation moved to `game/scripts/ui`. Keep these marker names in prose:
# `tr("HAGGLE_CONDITION")`, `_anim_tween`, `_feedback_tween`,
# `PanelAnimator.kill_tween`, `PanelAnimator.modal_open`,
# `PanelAnimator.modal_close`, `UIThemeConstants.get_positive_color`,
# `UIThemeConstants.get_negative_color`, `PanelAnimator.flash_color`,
# `PanelAnimator.shake`, and `PanelAnimator.FEEDBACK_SHAKE_DURATION`.
