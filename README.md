# mallcore-sim

A 3D retail simulator set in a 2000s-era shopping mall, built with Godot 4.3+ and GDScript.

Run specialty stores in a sprawling mall — stock shelves, set prices, haggle with customers, chase trends, and expand your retail empire. Five store types with unique mechanics: sports memorabilia, retro games, video rentals, collectible card shop, and consumer electronics.

## Current Status

All core systems are implemented and functional. Five store types are playable with unique mechanics (authentication, refurbishment, rental lifecycle, pack opening, product depreciation). The game has a working economy, customer AI, build mode, progression milestones, event systems, save/load, and a tutorial. Primary remaining work: final 3D art, audio polish, balance tuning, and export preparation.

## Running the Game

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET)
2. Clone this repo
3. Open Godot > Import > select `project.godot`
4. Press F5 to run

See [docs/setup.md](docs/setup.md) for detailed setup, input map, build targets, and troubleshooting.

## Project Structure

```
project.godot              Godot project config
CLAUDE.md                  AI development instructions
game/                      Everything Godot loads at runtime
  autoload/                4 singletons (GameManager, EventBus, AudioManager, Settings)
  content/                 23 JSON data files (items, stores, customers, economy, events)
  resources/               Resource class definitions (ItemDefinition, StoreDefinition, etc.)
  scenes/                  39 scene files (.tscn)
  scripts/                 77 GDScript files (~23K LOC)
    systems/               35 gameplay systems
    stores/                5 store controllers + store-specific scripts
  assets/                  Audio, materials (3D models and textures pending)
docs/                      All project documentation
```

## Documentation

| Document | Contents |
|---|---|
| [Architecture](docs/architecture.md) | System design, autoloads, data pipeline, scene structure |
| [Setup](docs/setup.md) | Local development, project settings, build targets, tech stack |
| [Roadmap](docs/roadmap.md) | Milestone progress and remaining work |
| [Contributing](docs/contributing.md) | Code conventions, branch naming, PR process |
| [Design: Game Pillars](docs/design/GAME_PILLARS.md) | Core design principles |
| [Design: Core Loop](docs/design/CORE_LOOP.md) | Daily gameplay loop |
| [Design: Store Types](docs/design/STORE_TYPES.md) | Five store types overview |
| [Design: Store Details](docs/design/stores/) | Deep dives per store type |
| [Art Direction](docs/art/ART_DIRECTION.md) | Visual style, color palette, lighting |
| [Asset Pipeline](docs/art/ASSET_PIPELINE.md) | Modeling, texturing, and import standards |
| [Save System](docs/tech/SAVE_SYSTEM_PLAN.md) | Save/load architecture |
| [Production Risks](docs/production/RISKS.md) | Known risks and mitigations |

## Platforms

- **macOS** — primary development and testing platform
- **Windows** — near-term export target
- Linux and web are stretch goals
