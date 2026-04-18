# Configuration and Deployment

## Project Configuration

Key settings in `project.godot`:

- project name: `Mallcore Sim`
- main scene: `res://game/scenes/bootstrap/boot.tscn`
- renderer/features: Forward Plus with Godot `4.6` project features
- icon: `res://icon.svg`
- GUT plugin enabled: `res://addons/gut/plugin.cfg`
- autoloads: content loading, registry, event bus, game manager, audio,
  settings, environment, camera, staff, reputation, difficulty, unlocks,
  checkout, onboarding, market trends, and tooltips

## Input Actions

Current action groups include movement, interaction, debug toggle, inventory,
camera orbit/zoom/pan, build mode toggle, fixture rotation, time pause, and
panel toggles for orders, staff, and pricing. Use `project.godot` as the source
of truth for exact key and mouse bindings.

## User Data

Runtime persistence uses Godot `user://` paths:

- settings: `user://settings.cfg`
- save index: `user://save_index.cfg`
- saves: `user://save_slot_<n>.json`

`SaveManager` writes saves atomically through a temporary file and caps save
file reads at `10 MiB`.

## Export Presets

`export_presets.cfg` defines:

| Preset | Output path in preset | Notes |
| --- | --- | --- |
| `Windows Desktop` | `exports/windows/MallcoreSim.exe` | x86_64, embedded PCK, built-in code signing disabled. |
| `macOS` | `exports/macos/MallcoreSim.zip` | universal arch, minimum macOS 10.15, built-in code signing disabled. |
| `Linux/X11` | `exports/linux/MallcoreSim.x86_64` | x86_64-style Linux export target. |

The presets exclude docs, tests, GUT, `.aidlc`, `.godot`, Markdown, text files,
and `.gutconfig.json` from exported resources.

## Local Export

From the editor:

1. Open `project.godot`.
2. Confirm export templates are installed for your Godot version.
3. Open Project -> Export.
4. Select the target preset.
5. Export release.

Headless exports can use Godot's `--export-release` with the preset name after
running `bash scripts/godot_import.sh`.

## GitHub Workflows

`.github/workflows/validate.yml` runs on pushes and pull requests to `main`.
It currently includes:

1. `lint-docs` for required-file and repository-shape checks
2. `gut-tests` for headless Godot import and GUT execution
3. `lint-gdscript` for non-blocking `gdtoolkit` linting

`lint-docs` still checks for a root `CLAUDE.md` path. That workflow
configuration is out of sync with the current documentation structure, where
`README.md` is the only root project doc and the rest of the active docs live in
`docs/`.

`.github/workflows/export.yml` runs on tags matching `v*`. It:

1. validates `export_presets.cfg`
2. installs Godot and export templates
3. imports project assets
4. exports Windows and macOS release artifacts
5. uploads short-retention build artifacts
6. creates a GitHub release from tagged builds

The export workflow currently declares `GODOT_VERSION: "4.3"`, while the project
file declares `4.6` features. Treat that mismatch as a release risk to verify
before relying on CI artifacts.
