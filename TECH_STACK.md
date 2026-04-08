# Tech Stack

## Why Godot 4.x

- **Open source (MIT)** — no license fees, no revenue share, no vendor lock-in
- **GDScript** — high productivity scripting with tight editor integration, no compile step
- **3D capable** — Godot 4's Vulkan renderer handles the mid-complexity 3D scenes this game needs
- **Cross-platform export** — single project exports to macOS, Windows, and Linux with minimal config
- **Lightweight** — small editor binary, fast iteration, no bloated dependency chain
- **Active community** — extensive docs, tutorials, and plugin ecosystem for Godot 4.x

We chose Godot over Unity/Unreal because this is a mid-scope indie project that benefits from fast iteration and zero licensing overhead more than AAA rendering features.

## GDScript Rationale

GDScript over C# or GDExtension because:

- **Faster iteration** — no compilation, instant feedback in editor
- **Lower barrier** — any contributor can read and modify game logic without IDE setup
- **First-class Godot support** — autocompletion, documentation, debugging all work best with GDScript
- **Sufficient performance** — retail sim logic (inventory, economy, AI) is not CPU-bound; GDScript handles it fine
- **Typed GDScript** — we use static typing (`var x: int`, `-> void`) everywhere for safety and speed

If a specific system (pathfinding, large data processing) needs native performance later, we can introduce GDExtension for that module only.

## Desktop-First

macOS is the primary dev platform. Windows is the first export target. Reasons for desktop-first:

- **Input complexity** — keyboard + mouse gives us hover states, right-click context menus, drag-and-drop inventory management, and camera control without fighting touch input
- **Screen real estate** — retail sim UIs (inventory grids, pricing sheets, financial reports) need space
- **No mobile constraints** — we do not need to worry about battery, thermal throttling, or touch-only interaction during core development
- **Simpler testing** — one input mode, one screen size range, predictable performance

Mobile is explicitly not a target right now. If it happens, it will be a separate input/UI layer, not a retrofit.

## Data Format

**JSON** for all content definitions (items, stores, customer profiles, event configs):

- Human-readable and editable without special tools
- Easy to validate with simple scripts in `tools/`
- Git-friendly diffs
- Loaded at runtime via `DataLoader` autoload, parsed into typed Resource objects

JSON files live in `game/content/`. Each content domain has its own subfolder and schema.

Example flow:
```
game/content/items/sports_cards.json
  -> DataLoader parses on boot
  -> Creates ItemDefinition resources
  -> Systems reference items by ID string
```

## What We Do Not Need Yet

- **Networking/multiplayer** — this is a single-player game. No backend, no server, no sync logic.
- **Database** — JSON files and Godot's built-in `ConfigFile`/`ResourceSaver` handle persistence
- **External services** — no analytics, no auth, no cloud saves in the current scope
- **CI/CD beyond linting** — automated exports can come later when we have release candidates

## Build Targets

| Platform | Status       | Export Template | Notes                        |
|----------|-------------|-----------------|------------------------------|
| macOS    | Primary     | macOS universal | Dev + test platform          |
| Windows  | Near-term   | Windows Desktop | Regular export testing       |
| Linux    | Stretch     | Linux/X11       | Should work, not tested yet  |
| Web      | Stretch     | Web/HTML5       | Performance TBD              |
| Mobile   | Not planned | -               | Would need separate UI layer |
