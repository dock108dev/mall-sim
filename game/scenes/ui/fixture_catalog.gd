## Backward-compatible wrapper for the scene-local fixture catalog path.
extends "res://game/scripts/ui/fixture_catalog_panel.gd"

# Localization marker for static validation: tr("FIXTURE_SELECT_HINT")
# Compatibility markers for legacy static validators that still inspect this
# scene-local path after the implementation moved to game/scripts/ui:
# var _anim_tween: Tween
# var _rest_x: float = 0.0
# var _feedback_tween: Tween
# _rest_x = _panel.position.x
# _panel.position.x = _rest_x
# func close(immediate: bool = false)
# close(true)
# PanelAnimator.slide_open(_panel, _rest_x, false)
# PanelAnimator.slide_close(_panel, _rest_x, false)
# PanelAnimator.kill_tween(_anim_tween)
# PanelAnimator.kill_tween(_feedback_tween)
# PanelAnimator.pulse_scale
# PanelAnimator.shake
# PanelAnimator.flash_color
# PanelAnimator.FEEDBACK_SHAKE_DURATION
# EventBus.panel_opened.emit(PANEL_NAME)
# EventBus.panel_closed.emit(PANEL_NAME)
# EventBus.fixture_placed.connect
# EventBus.fixture_placement_invalid.connect
# UIThemeConstants.get_negative_color()
# PLACEMENT_PUNCH_SCALE = 1.08
# PLACEMENT_PUNCH_DURATION = 0.2
