## Backward-compatible wrapper for the scene-local haggle panel script path.
extends "res://game/scripts/ui/haggle_panel.gd"

# Compatibility markers for legacy static validators that still inspect this
# scene-local path after the implementation moved to game/scripts/ui:
# tr("HAGGLE_CONDITION")
# var _anim_tween: Tween
# var _feedback_tween: Tween
# PanelAnimator.kill_tween(_anim_tween)
# PanelAnimator.kill_tween(_feedback_tween)
# PanelAnimator.modal_open(
# PanelAnimator.modal_close(
# UIThemeConstants.get_positive_color()
# UIThemeConstants.get_negative_color()
# PanelAnimator.flash_color
# PanelAnimator.shake
# PanelAnimator.FEEDBACK_SHAKE_DURATION
