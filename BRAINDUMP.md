# MALLCORE_SIM_ROOM_CAMERA_COLLISION_BRAINDUMP.md
## Where we are now
Movement works.
Room loads.
But the game is still not playable.
The blocker is now:
camera + collision + world text + room readability
---
## What is broken (from current build)
- giant REGISTER / DISPLAY / CUSTOMER ENTRANCE text everywhere
- backwards / mirrored signage visible
- camera inside walls / staring at blank planes
- exterior signage showing during interior gameplay
- cannot rotate/pan camera meaningfully
- movement exists but scene not designed for camera
- walking through walls / outside intended space
This is NOT a systems problem anymore.
This is a **scene + camera + collision problem**.
---
## Target for next pass
Entering Retro Game Store should:
- show a readable interior immediately
- no giant floating text
- no backwards text
- camera sees fixtures clearly
- player cannot leave room bounds
- shelf / display / register are visible and reachable
If that is not true, the pass failed.
---
## Phase 1: Kill giant world text
Disable ALL always-on world labels:
- REGISTER
- DISPLAY
- CUSTOMER ENTRANCE
- storefront signage from interior view
Replace with:
"Display Case – Press E"
"Register – Press E"
Only when near/interacting.
---
## Phase 2: Fix camera (ONE mode only)
Use ONE camera:
Fixed angled interior camera
Requirements:
- outside/front of room looking in
- sees entire playable space
- not inside walls or signs
- roof removed / front cutaway
No camera experiments. No hybrids.
---
## Phase 3: Add collision / bounds
Must not walk through walls.
Add:
- wall collision
- simple floor bounds clamp
Goal:
Player never leaves store footprint.
---
## Phase 4: Rebuild room for camera
BACK WALL  
[Shelf]     [Backroom]
   [Display]
 open floor
[Counter/Register]   [Entrance]
FRONT CUTAWAY (camera side)
Rules:
- front open
- fixtures visible
- nothing blocking view
- scale consistent
---
## Phase 5: Pick movement model
Choose ONE:
A) WASD (with working collision)  
B) Hotspot navigation (fallback)
Do not leave both half-working.
---
## Phase 6: Fix prompts
Keep:
Top HUD + one objective
Remove:
All giant world labels
Use:
Small contextual prompts only
---
## Phase 7: Remove mirrored text
No backwards text anywhere.
Fix or hide:
- backside text rendering
- negative scale issues
- exterior signage leaking into view
---
## Definition of done
"I can walk around a room that looks like a store and nothing is visually broken or confusing."
That’s it.

⸻

What I’d do next (no fluff)

You’re 1–2 solid passes away from something actually playable, but only if you stay disciplined:

Fix in this exact order:

1. Delete/disable all giant 3D text
2. Lock a fixed camera that shows the whole room
3. Add collision bounds so you can’t escape
4. Reposition the room to match the camera

If you try to tweak movement or UI before those 4 → you’ll keep spinning.

⸻

Blunt truth

Right now your game isn’t broken because it’s missing features.

It’s broken because:

the camera is not aligned with the world

Fix that, and suddenly:

* movement will feel right
* prompts will make sense
* placement will be obvious
