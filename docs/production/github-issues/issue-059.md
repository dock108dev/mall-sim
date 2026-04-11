# Issue 059: Implement main menu with new game, continue, and settings

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `ui`, `tech`, `phase:m2`, `priority:medium`
**Dependencies**: issue-026 (soft — continue button disabled without save system), issue-027 (soft — settings panel placeholder without settings system), issue-087 (GameManager must have DataLoader initialized)

## Why This Matters

The main menu is the first screen the player sees. It sets the tone and provides the entry points into the game.

## Current State

No main menu scene exists. GameManager autoload handles state (`MENU`, `PLAYING`, `PAUSED`, `DAY_SUMMARY`, `LOADING`) but has no menu-specific logic. The game currently boots directly into whatever scene is set as the main scene in project.godot.

## Design

### Menu Flow

```
Title Screen
  +-- New Game → Store Selection → Name Store → Load GameWorld
  +-- Continue → Load latest save → Load GameWorld
  +-- Settings → Settings overlay (issue-027)
  +-- Quit → Confirm dialog → Exit
```

### Title Screen

- Background: Static 2D image of a mall exterior at golden hour (placeholder: solid gradient or simple illustration)
- Game title: "MALLCORE" in a retro mall-style font, centered upper third
- Subtitle: "A Retail Simulator" below title, smaller
- Menu buttons: vertically stacked, centered lower third
- Ambient: Mall exterior ambiance (birds, distant traffic, muzak through doors) — placeholder: silence is fine for M2

### Store Selection Screen

Appears after clicking "New Game":

```
StoreSelectionUI (Control)
  +- Title ("Choose Your First Store")
  +- StoreGrid (GridContainer, 3 columns)
  |    +- StoreCard (PanelContainer) × 5
  |         +- StoreName ("Sports Memorabilia")
  |         +- StoreDescription (one sentence from store definition)
  |         +- StoreIcon (placeholder colored rectangle per store type)
  |         +- LockOverlay (visible if store not yet implemented)
  +- BackButton ("Back")
```

**Store availability for M2**: Only the sports store is playable. Other stores show a lock overlay with text "Coming Soon". Store availability is determined by checking if the store's scene file exists on disk using the `scene_path` field from store_definitions.json:

```gdscript
func _is_store_playable(store_def: StoreDefinition) -> bool:
    return store_def.scene_path != "" and ResourceLoader.exists(store_def.scene_path)
```

If the store definition has no `scene_path` or the file doesn't exist, the card shows as locked. This naturally unlocks stores as their scenes are implemented in later waves.

### Store Naming Screen

After selecting a store:

```
StoreNamingUI (Control)
  +- Title ("Name Your Store")
  +- SuggestionLabel ("Suggestions: Card Shack, The Dugout, Trophy Case")
  +- NameInput (LineEdit, max 30 characters)
  +- StartButton ("Open for Business!") — disabled until name is non-empty
  +- BackButton ("Back")
```

Suggested names come from the store definition's `store_name` field or a hardcoded list per store type.

### Continue Button Logic

- If SaveManager reports no save files exist: Continue button is disabled (grayed out, tooltip: "No saved games")
- If save files exist: Continue loads the most recent auto-save and transitions to GameWorld
- For M2 without save system (issue-026 not complete): Continue button is always disabled

### Settings Button

- Opens a Settings overlay panel (issue-027 provides the implementation)
- If issue-027 is not yet complete: button opens a placeholder panel with "Settings — Coming Soon" text

## Scene Structure

```
MainMenu (Control) — scene root
  +- Background (TextureRect or ColorRect gradient)
  +- TitleContainer (VBoxContainer, centered upper)
  |    +- TitleLabel ("MALLCORE")
  |    +- SubtitleLabel ("A Retail Simulator")
  +- MenuContainer (VBoxContainer, centered lower)
  |    +- NewGameButton
  |    +- ContinueButton
  |    +- SettingsButton
  |    +- QuitButton
  +- StoreSelectionUI (Control, hidden by default)
  +- StoreNamingUI (Control, hidden by default)
  +- SettingsPanel (Control, hidden — placeholder or from issue-027)
  +- QuitConfirmDialog (ConfirmationDialog)
```

## Script: `game/scripts/ui/main_menu.gd`

```gdscript
extends Control

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var store_selection: Control = $StoreSelectionUI
@onready var store_naming: Control = $StoreNamingUI
@onready var continue_button: Button = $MenuContainer/ContinueButton

func _ready() -> void:
    GameManager.set_state(GameManager.GameState.MENU)
    _check_continue_availability()
    _populate_store_cards()

func _check_continue_availability() -> void:
    # Disable if no save files exist
    # SaveManager may not exist yet (wave-2 dependency)
    var has_saves = false
    if GameManager.has_method("has_save_files"):
        has_saves = GameManager.has_save_files()
    continue_button.disabled = not has_saves

func _populate_store_cards() -> void:
    # DataLoader is accessed via GameManager (initialized in GameManager._ready())
    var stores = GameManager.data_loader.get_all_stores()
    for store_def in stores:
        var card = _create_store_card(store_def)
        store_selection.get_node("StoreGrid").add_child(card)

func _is_store_playable(store_def: StoreDefinition) -> bool:
    return store_def.scene_path != "" and ResourceLoader.exists(store_def.scene_path)

func _on_new_game_pressed() -> void:
    menu_container.visible = false
    store_selection.visible = true

func _on_store_selected(store_id: String) -> void:
    store_selection.visible = false
    store_naming.visible = true
    # Store selected store_id for game initialization

func _on_start_game(store_id: String, store_name_input: String) -> void:
    GameManager.start_new_game(store_id, store_name_input)
    # Use TransitionManager (issue-060) if available, else direct scene change
    if has_node("/root/TransitionManager"):
        TransitionManager.change_scene("res://game/scenes/world/game_world.tscn")
    else:
        get_tree().change_scene_to_file("res://game/scenes/world/game_world.tscn")

func _on_continue_pressed() -> void:
    # SaveManager (issue-026) handles load
    GameManager.save_manager.load_latest()
    get_tree().change_scene_to_file("res://game/scenes/world/game_world.tscn")

func _on_quit_pressed() -> void:
    $QuitConfirmDialog.popup_centered()

func _on_quit_confirmed() -> void:
    get_tree().quit()
```

## GameManager Integration

- `GameManager.start_new_game(store_id, store_name)` — new method that initializes a fresh game session:
  1. Sets state to LOADING
  2. Stores the selected store_id and store_name in session data
  3. Scene transition loads GameWorld, which reads session data to initialize systems
- `GameManager.set_state(GameState.MENU)` — called in main menu `_ready()`
- `GameManager.data_loader` — DataLoader instance, already initialized by GameManager._ready() (see issue-087)
- Scene transitions use TransitionManager (issue-060) if available, fallback to `get_tree().change_scene_to_file()` if not

## Deliverables

- `game/scenes/ui/main_menu.tscn` — main menu scene
- `game/scripts/ui/main_menu.gd` — menu logic script
- Title screen with game title and 4 buttons (New Game, Continue, Settings, Quit)
- Store selection screen populated from DataLoader store definitions (via `GameManager.data_loader`)
- Store naming screen with text input and validation
- Continue button state tied to save file existence
- Quit confirmation dialog
- GameManager.start_new_game() method added
- project.godot main scene set to main menu

## Acceptance Criteria

- Main menu appears on game boot with title and 4 buttons
- "New Game" opens store selection screen
- Store cards are populated from store_definitions.json via GameManager.data_loader
- Unplayable stores (scene_path doesn't exist on disk) show "Coming Soon" lock overlay
- Selecting a playable store opens the naming screen
- Entering a name and clicking start transitions to GameWorld
- "Continue" is disabled when no save files exist
- "Continue" loads latest save and transitions to GameWorld (when save system exists)
- "Settings" opens settings panel or placeholder
- "Quit" shows confirmation dialog before exiting
- Escape key does not crash or cause unexpected behavior on menu
- Back buttons return to previous screen
- Empty store name cannot proceed (start button disabled)
- Store name limited to 30 characters
- Menu state is set in GameManager on menu load

## Test Plan

1. Boot game — verify main menu appears with title and all 4 buttons visible
2. Click "New Game" — verify store selection screen appears, menu buttons hidden
3. Verify store cards populated — sports store selectable, others show "Coming Soon"
4. Click a locked store — verify nothing happens (no crash, no transition)
5. Select sports store → naming screen appears with suggestions
6. Try to start with empty name — verify start button is disabled
7. Enter a name, click start — verify transition to GameWorld scene
8. Return to menu, click "Continue" — verify disabled (no save files)
9. Click "Settings" — verify placeholder or settings panel opens
10. Click "Quit" → confirm dialog appears → confirm → game exits
11. Click "Quit" → confirm dialog → cancel → returns to menu
12. Press Escape on various sub-screens — verify returns to previous screen or does nothing harmful