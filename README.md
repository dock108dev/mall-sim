# mallcore-sim

A 3D retail simulator inspired by 2000s mall culture, built with Godot 4.x.

Run your own stores in a sprawling mall — stock shelves, haggle with customers, chase trends, and expand your retail empire across sports cards, retro games, video rentals, fake monster cards, and electronics.

## Platform Targets

- **macOS** — primary development and testing platform
- **Windows** — near-term export target, tested regularly
- Linux and web are stretch goals, not actively targeted yet

## Current Status

**Scaffolding complete, ready for implementation.**

The project structure, autoload singletons, resource definitions, content pipeline, and scene hierarchy are all in place. No gameplay systems are wired up yet — the next step is building the core player controller and interaction loop inside a single test store.

## Opening the Project

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET)
2. Clone this repo
3. Open Godot, click **Import**, navigate to the repo root, select `project.godot`
4. The project will import assets on first open — this may take a moment
5. Press F5 or click Play to run the default scene

## Directory Overview

```
project.godot              # Godot project config (root level)
game/                      # All game code and assets
  scenes/                  # .tscn scene files organized by feature
  scripts/                 # GDScript files (.gd)
  autoload/                # Singleton scripts (GameManager, EventBus, etc.)
  content/                 # JSON data files (items, stores, customers)
  resources/               # Custom Resource definitions (.tres, .gd)
docs/                      # Design documents, system specs
tools/                     # Editor plugins, build scripts, data validators
reference/                 # Art references, audio specs, design mockups
.github/                   # CI workflows, issue/PR templates
```

The `game/` subfolder contains everything Godot loads at runtime. Docs, tools, and reference material live outside it to keep the game directory clean.

## Contribution Expectations

- Read `CONTRIBUTING.md` before submitting code
- One feature or fix per branch and PR
- All scripts follow GDScript conventions: `snake_case` files, `PascalCase` classes
- No dead code or placeholder scaffolding — if it does not work yet, it should not exist in the tree
- See `ARCHITECTURE.md` for system design and `TASKLIST.md` for what to work on next

## Immediate Next Steps

1. Player controller — basic 3D movement and camera in the mall environment
2. Interaction system — raycasting to detect and interact with objects
3. First playable store — a single sports card shop with shelves, register, stock
4. Inventory UI — grid-based display of store stock and player inventory
5. Customer spawning — basic NPCs that enter, browse, and purchase

See `ROADMAP.md` for the full phased plan and `TASKLIST.md` for granular tasks.
