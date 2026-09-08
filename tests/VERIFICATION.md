# Verification — 2026-09-07

Godot 4.7.2 stable, Windows, Compatibility renderer.

- Project imported and main scene started successfully.
- Rules suite: **29 checks, 0 failures** (health, protection, coin conversion/cap, all derived powerup modifiers, stacking, expiry, stomp classification).
- Damage recovery suite: **16 checks, 0 failures** (vertical drop, full two-second stationary rest starting at landing, protected landing/rest, blocked flap/laser input, pause, upward relaunch, restored fresh input, shield exception and lethal elimination). Existing rules and 212 integration checks also pass with the new recovery mechanic.
- Combat/pickup regression suite: **22 checks, 0 failures** (no damage before contact, higher-player contact wins, harmless level side bump, shield counter in both height orders including a resting shield, unshielded exposed-ground execution in both roster orders, eliminated-body exclusion, vertical powerup and coin travel, lane stability and moving collection shapes).
- Hazard suite: **6 checks, 0 failures** (vertical sweep, fixed lane, moving collider, one-damage contact latch and re-hit after separation).
- Integration suite: **239 checks, 0 failures** (eight-player lobby, unique keys, safe spawns, countdown, fresh-press flaps, laser firing/expiry/hits, pickup placement/caps, vertical coin/powerup/hazard edge starts, floor/ceiling/wall contacts, pause, victory, draw, rematch and lobby return).
- Crowd simulation: **3,600 steps / 60 simulated seconds / eight players**, zero containment failures or final overlaps. Test protection keeps all eight participants available while effects change. Peak four simultaneous laser shots in this seeded run.
- Title, eight-player lobby, arena, pause and victory rendered on Intel Arc 130V using OpenGL 3.3; screenshots in `artifacts/`.
- Audio teardown check passes without leaked-object warnings after allowing the mix thread to finish its last buffer.

No physical multi-person keyboard playtest was performed. Human play is still needed to assess feel, balance, sound preference and the keyboard's simultaneous-key limit. Screenshots are staged render checks, not proof of live human play.
