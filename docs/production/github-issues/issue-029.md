# Issue 029: Implement pause menu

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `ui`, `phase:m2`, `priority:medium`
**Dependencies**: issue-026, issue-027

## Why This Matters

Players need to pause, save, adjust settings, and quit cleanly. The pause menu is the escape hatch from gameplay and must work reliably.

## Current State

- Player controller (issue-002) already handles Escape to release mouse cursor
- SaveManager (issue-026) provides `save_game(slot)` and `load_game(slot)`
- Settings scene (issue-027) exists as a standalone panel
- GameManager tracks game state and can transition to `PAUSED` state
- TransitionManager (issue-060) handles scene transitions with fade effects

## Design

### Trigger

Escape key opens the pause menu. If Escape is pressed while the pause menu is open, it closes (resume). This replaces the player controller's current Escape behavior — when pause menu exists, Escape is consumed by the pause menu instead.

Input action: `"pause"` mapped to `KEY_ESCAPE` (added by issue-088).

### Process Mode

The pause menu sets `get_tree().paused = true`. The pause menu node itself must have `process_mode = PROCESS_MODE_ALWAYS` so it continues to receive input while the tree is paused.

```gdscript
# PauseMenu node:
process_mode = Node.PROCESS_MODE_ALWAYS
```

All gameplay nodes use default process mode (`PROCESS_MODE_INHERIT`), so they automatically pause.

### Scene Structure

```
PauseMenu (Control) — process_mode = ALWAYS
  +- DimOverlay (ColorRect — Color(0, 0, 0, 0.5), full screen, mouse_filter = IGNORE)
  +- CenterContainer
  |    +- PanelContainer (theme: dark panel, min_size 300x400)
  |         +- VBoxContainer
  |              +- TitleLabel ("PAUSED", centered, large font)
  |              +- Separator (HSeparator)
  |              +- ResumeButton (Button — "Resume")
  |              +- SettingsButton (Button — "Settings")
  |              +- SaveButton (Button — "Save Game")
  |              +- QuitButton (Button — "Quit to Menu")
  +- SettingsOverlay (Control — hidden, for inline settings panel)
```

### Script: `pause_menu.gd`

```gdscript
extends Control

func _ready() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    $CenterContainer/PanelContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume)
    $CenterContainer/PanelContainer/VBoxContainer/SettingsButton.pressed.connect(_on_settings)
    $CenterContainer/PanelContainer/VBoxContainer/SaveButton.pressed.connect(_on_save)
    $CenterContainer/PanelContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        if visible:
            _resume()
        else:
            _pause()
        get_viewport().set_input_as_handled()

func _pause() -> void:
    visible = true
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    GameManager.set_state(GameManager.State.PAUSED)

func _resume() -> void:
    visible = false
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    GameManager.set_state(GameManager.State.PLAYING)

func _on_resume() -> void:
    _resume()

func _on_settings() -> void:
    # Show settings panel inline (or as overlay)
    $SettingsOverlay.visible = true

func _on_save() -> void:
    SaveManager.save_game(0)  # Auto-save slot
    EventBus.notification_requested.emit("Game saved.")

func _on_quit() -> void:
    _resume()  # Unpause tree first
    # Use TransitionManager if available, otherwise direct scene change
    if has_node("/root/TransitionManager"):
        TransitionManager.transition_to("res://game/scenes/ui/main_menu.tscn")
    else:
        get_tree().change_scene_to_file("res://game/scenes/ui/main_menu.tscn")
```

### Interaction with Other Systems

- **Player controller**: When pause menu is visible, it consumes the Escape input via `_unhandled_input` before the player controller sees it (pause menu is higher in the scene tree or uses `set_input_as_handled`).
- **TimeSystem**: Paused automatically because `get_tree().paused = true` stops all `_process` and `_physics_process` on default-mode nodes.
- **GameManager**: State transitions to `PAUSED` when menu opens, back to `PLAYING` when it closes. GameManager should NOT independently handle pause — the PauseMenu owns this.
- **Day Summary**: If the day summary screen is showing, Escape should NOT open the pause menu. Check `GameManager.state == PLAYING` before pausing.

### Edge Cases

- **Pause during checkout**: If a customer is at the register and the player pauses, the patience timer freezes (because the tree is paused). This is correct behavior.
- **Settings changes while paused**: Audio volume changes should apply immediately (AudioManager should be `PROCESS_MODE_ALWAYS`).
- **Multiple Escape presses**: Debounced by visibility check — pressing Escape while visible resumes instead of stacking.

## Deliverables

- `game/scenes/ui/pause_menu.tscn` — pause menu scene
- `game/scripts/ui/pause_menu.gd` — pause/resume logic, button handlers
- Integration: pause menu added as child of GameWorld (or UI layer)
- Escape key toggles pause menu on/off
- Tree paused/unpaused correctly
- Mouse cursor released on pause, captured on resume

## Acceptance Criteria

- Escape opens pause menu and pauses the game
- Escape while paused closes menu and resumes
- Resume button closes menu and resumes
- Settings button shows settings panel
- Save button triggers SaveManager and shows confirmation notification
- Quit button returns to main menu without crash
- Game time does not advance while paused
- Customers freeze in place while paused
- Mouse cursor is visible while paused
- Pause menu does not open during day summary screen
- No input leaks through to gameplay while paused

## Test Plan

1. During gameplay, press Escape — verify game pauses, menu appears, cursor visible
2. Press Escape again — verify game resumes, menu disappears, cursor captured
3. Click Resume — verify same as pressing Escape
4. Click Save — verify save file created, notification shown
5. Click Quit to Menu — verify transition to main menu without errors
6. Pause while customer is walking — verify customer freezes, resumes movement after unpause
7. Open inventory UI, then press Escape — verify pause menu opens (not just inventory closing)
8. Pause during checkout with customer waiting — verify patience timer is frozen