# Scene Strategy

How mallcore-sim organizes its scene tree, loads content, and transitions between states.

---

## Top-Level Scene Structure

```
root
 +-- Boot (initial scene, loads settings, transitions to MainMenu)
 +-- MainMenu (title screen, save slot selection)
 +-- GameWorld (3D game scene, loaded when playing)
 |    +-- Environment (lighting, skybox, mall exterior shell)
 |    +-- StoreInterior (loaded per store type, swappable sub-scene)
 |    |    +-- Shelves (shelf nodes with interaction areas)
 |    |    +-- DisplayCases (glass case nodes)
 |    |    +-- Register (checkout counter)
 |    |    +-- Backroom (off-screen inventory storage)
 |    +-- CustomerSpawner (manages active customer nodes)
 |    +-- PlayerController (camera, input, interaction raycasts)
 +-- UILayer (CanvasLayer, always on top of 3D)
 |    +-- HUD (cash, time, reputation bar)
 |    +-- Panels (inventory, pricing, catalog -- shown/hidden)
 |    +-- DaySummary (end-of-day overlay)
 |    +-- PauseMenu
 |    +-- Tooltips
 +-- DebugOverlay (CanvasLayer, dev builds only)
```

## Boot Scene

The game always starts at `res://game/scenes/bootstrap/boot.tscn`.

Responsibilities:
- Load user settings from `user://settings.cfg`
- Initialize autoloads (they're already loaded, but Boot verifies them)
- Show a brief splash or loading indicator
- Transition to MainMenu once ready

This scene exists so the game has a consistent entry point regardless of how it's launched. It also prevents the main menu from needing to handle first-time initialization.

## Main Menu

`res://game/scenes/ui/main_menu.tscn`

- Mall exterior background (static 3D render or animated scene)
- Options: New Game, Continue, Settings, Quit
- Continue is grayed out if no save exists
- New Game flows into store type selection, then into GameWorld
- Settings: audio, display, controls
- Transitions to GameWorld via `SceneTree.change_scene_to_packed()`

## Game World

`res://game/scenes/world/game_world.tscn`

This is the primary gameplay scene. It persists for the entire play session. Sub-scenes are loaded and unloaded within it.

### Store Interior Loading

Each store type has its own interior scene:
- `res://game/scenes/stores/sports_memorabilia.tscn`
- `res://game/scenes/stores/retro_games.tscn`
- `res://game/scenes/stores/video_rental.tscn`
- `res://game/scenes/stores/pocket_creatures.tscn`
- `res://game/scenes/stores/consumer_electronics.tscn`

These are loaded as children of the `StoreInterior` node using `load()` and `add_child()`. When the player switches stores (future feature), the current interior is freed and the new one is instanced.

Each store scene contains:
- Pre-placed shelf and display case nodes with defined slots
- Store-specific decorative elements (posters, signage, ambient objects)
- Lighting setup appropriate to the store's aesthetic
- Collision shapes for customer pathfinding

### Player Controller

`res://game/scenes/player/player.tscn`

Not a walking character -- the player is a floating camera with point-and-click interaction.

- Orbits around the store interior (fixed pivot, adjustable angle and zoom)
- Raycasts from mouse position to detect interactive objects (shelves, items, customers, register)
- Handles click and drag for item placement
- Keyboard shortcuts route through here to the appropriate UI panel

### Customer Instances

Customers are instanced from `res://game/scenes/characters/customer.tscn` by the CustomerSpawner (scene does not exist yet — will be created during M1).

- Each customer is a simple 3D model with an AnimationPlayer (walk, browse, idle, leave)
- Navigation uses Godot's NavigationAgent3D for pathfinding within the store
- Customer nodes are freed when they exit the store

## UI Overlay

`res://game/scenes/ui/ui_layer.tscn` (not yet created — HUD exists at `res://game/scenes/ui/hud.tscn`)

A CanvasLayer that sits above the 3D world. All 2D UI lives here.

- **HUD**: Always visible. Shows cash, current time, day number, reputation bar.
- **Panels**: Toggled by keyboard shortcuts or button clicks. Only one major panel open at a time. Panels slide in from screen edges.
  - Inventory panel (left side)
  - Pricing panel (right side)
  - Catalog/ordering panel (bottom or center modal)
- **Day Summary**: Full-screen overlay at end of day. Shows stats, then transitions to ordering phase.
- **Tooltips**: Follow the mouse. Appear on hover over items, shelves, customers.

## Debug Overlay

`res://game/scenes/debug/debug_overlay.tscn`

Only loaded in debug/dev builds (checked via `OS.is_debug_build()`).

- FPS counter
- Current game state
- Active customer count
- Economy snapshot (cash, daily revenue)
- Toggle with F1
- Can inject commands: set cash, set reputation, spawn customer, advance day

## Scene Transitions

All scene transitions go through a lightweight transition manager (autoload):

```gdscript
# TransitionManager.gd (autoload)
func change_scene(scene_path: String, transition: String = "fade") -> void:
    # 1. Play transition-out animation (fade to black)
    # 2. Load new scene
    # 3. Swap scenes
    # 4. Play transition-in animation (fade from black)
```

- Transitions are non-interactive (input blocked during transition)
- Default transition is a quick fade (0.3s out, 0.3s in)
- Loading happens during the black frame for small scenes
- For larger scenes, a loading screen is shown instead

## Key Principles

1. **The GameWorld scene is long-lived.** It loads once per session. Sub-scenes swap within it.
2. **UI is separate from 3D.** CanvasLayer ensures UI is never occluded by 3D geometry.
3. **Stores are self-contained scenes.** Each store scene works in isolation for testing.
4. **Autoloads handle global state.** Scene transitions never lose autoload data.
5. **Debug overlay is opt-in.** Never ships to players in release builds.
