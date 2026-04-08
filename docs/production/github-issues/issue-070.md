# Issue 070: Implement export builds for macOS and Windows

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `production`, `tech`, `phase:m4plus`, `priority:medium`
**Dependencies**: None

## Why This Matters

Can't ship what you can't build.

## Scope

Configure export presets per BUILD_TARGETS.md. Test macOS universal binary. Test Windows x64 build. Verify save/load works in exported builds. Debug console hidden in release.

## Deliverables

- Export presets in project.godot
- macOS .app in .dmg
- Windows .exe in .zip
- Verified: game runs, saves work, debug hidden
- Version number in window title

## Acceptance Criteria

- macOS build runs on macOS 12+
- Windows build runs on Windows 10+
- Save files in correct user directory
- No debug overlay in release build
