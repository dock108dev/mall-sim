# Beta Manual QA

## Fresh Launch
- Launch project from clean editor session.
- Confirm boot reaches main menu without error panel.
- Confirm no blocking modal appears automatically.

## New Game
- Start a new run from main menu.
- Confirm transition enters gameplay without freeze.
- Confirm player starts in target beta store area.

## Movement
- Verify mouse look works immediately.
- Verify WASD movement works.
- Verify sprint works.
- Verify player cannot walk through walls/shelves/counter.

## Interaction
- Look at register: prompt appears.
- Look at shelf: prompt appears.
- Look at customer: prompt appears.
- Look at non-interactive prop: no fake prompt appears.

## Day 1 Customer
- Confirm at least one Day 1 customer event becomes available.
- Confirm player can trigger the event by interaction.

## Decision Card
- Confirm decision card opens.
- Confirm at least 3 choices are visible.
- Confirm picking each choice closes or resolves card cleanly.

## State Updates
- Confirm choice updates at least one tracked metric.
- Confirm feedback text explains outcome.
- Confirm no UI soft-lock after choice.

## Day End
- Trigger end-of-day flow.
- Confirm day summary panel appears.
- Confirm summary values are populated.

## Day Advance
- Press continue/advance.
- Confirm day increments.
- Confirm Day 2 placeholder loads without crash.

## Hidden Thread
- Confirm at least one subtle hidden-thread clue can be encountered in Days 1-5.
- Confirm interaction with clue updates hidden-thread tracking.

## Menus / Escape Behavior
- Press Esc in gameplay.
- Confirm pause/menu behavior does not trap cursor or lock movement permanently.
- Close menu and verify movement resumes.

## Restart / Reset
- Quit to menu.
- Start new game again.
- Confirm previous run state is reset for Day 1.

## Known Issues
- `scripts/godot_exec.sh` may require `sh` invocation if execute bit is missing.
- Existing Godot headless runs report resource/ObjectDB leak warnings at exit.
- Prior logs showed intermittent `GameManager.data_loader` freed-instance assignment spam; mitigated in `DataLoader` by defensive assignment path, but regression test still required.
