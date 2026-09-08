# Party Jousting

A complete local party-game prototype for **Godot 4.x**, tested with **Godot 4.7.2**. All GDScript, scenes, shapes, menus, particles and synthesized sounds are included. No downloads, Autoloads, add-ons or manual Input Map configuration are needed.

Open `project.godot` in Godot and press **F6 on `scenes/Main.tscn`**, or **F5** to run the configured main scene.

## Play

1. Press Enter or click Play Local.
2. Each of 2–8 players presses an unused letter to join. That letter becomes their only gameplay button. Tap it again in the lobby, or click the animal name, to change appearance. Click Leave to remove a player.
3. Press Enter or click Start Round. Movement starts after 3, 2, 1, GO.
4. **Fresh press = flap. Holding does nothing.** Horizontal movement is automatic. Side walls reverse direction safely. When players collide, the higher player wins the contact and continues upward while the lower player takes damage; nearly level side bumps only push players apart. The first real player-body contact is resolved once, so a hit cannot repeat through a contact latch. A player resting exposed on the floor without an active Shield is instantly eliminated by an incoming player-body hit, regardless of remaining hearts or invincibility.
5. Both the floor and ceiling remove one health. After surviving any damage, you fall straight down and rest motionless on the floor for **two seconds**, then automatically bounce back into play with 0.75 seconds of protection. Flapping, shooting, collection and further damage are disabled throughout recovery. Other players pass through you during recovery. Shields block boundary damage without making you rest.
6. Three coins restore one heart, up to five. Each group of three is consumed even at full health. Coins left over carry through the current round only.
7. Lasers last **five seconds**. During that time **each flap also fires** in your facing direction. A laser hit deals one damage and consumes the projectile, not the five-second ability.
8. Coins and powerups spawn at the top or bottom safe edge of the arena and sweep vertically to the opposite edge, then reverse. Their Area2D collection shapes move with them. Spawn positions keep the sweep clear of the HUD and walls.
9. Escape pauses/resumes. The pause menu can mute sounds or return to the lobby. The last survivor wins; simultaneous final eliminations produce a draw. Enter rematches with the same roster and appearances.

Letters available: Q W E R T Y U I O P A S D F G H J K L Z X C V B N M. Physical key bindings keep positions consistent. The keyboard hardware must support the chosen simultaneous presses; eight-player support cannot remove a keyboard's rollover limit.

## Powerups

| Pickup | Effect | Repeated pickup |
|---|---|---|
| Shield / S | Blocks one hit, including floor or ceiling; on player contact it disappears and damages the colliding player | One charge maximum |
| Speed / >> | 1.65× horizontal speed, 5 s; trailing visual | Refreshes duration |
| Super Flap / ^ | 1.3× flap velocity, 5 s | Refreshes duration |
| Heavy / H | 1.45× gravity, two-damage stomps, 5 s | Refreshes duration |
| Tiny / - | 0.65× collision radius, 5 s | Replaces Giant |
| Giant / + | 1.5× radius, two-damage stomps, 5 s | Replaces Tiny |
| Health / +1 | Immediately restores one heart, capped at five | Instant |
| Invincible / * | Blocks all damage, 3 s | Refreshes duration |
| Mystery / ? | Random beneficial effect; excludes Heavy and Mystery | Uses chosen effect's rule |
| Laser / L | Flaps fire one-damage shots for 5 s | Refreshes duration |

Different effects coexist. Heavy + Giant still deals two stomp damage, not four. Invincibility and damage protection take precedence over shield consumption. No effect can revive an eliminated player. Temporary stats are derived from base rules every physics frame; expiry cannot leave a permanently multiplied stat. Pause and brief hit-stop also freeze effect timers.

First powerup appears about 5 seconds after GO; subsequent pickups appear every 7–12 seconds with at most 4 uncollected powerups. Coins spawn every 2.5 seconds, capped at 10. Crowded placement attempts are skipped safely. Weights are configurable on `Arena/PickupSpawner`.

## Files and tuning

- `scenes/`: Main, Arena, Player, Coin, PowerUp and Laser scenes.
- `scripts/`: separate input/flow, UI, arena, player, combat, effects, catalog, spawning, visual and audio scripts.
- `resources/default_rules.tres`: select this in the FileSystem dock to tune gravity, flap strength, speed, radius, health, boundary bounces, protection, arena size, timers and spawn capacities. `GameRules` exposes comments beside physics values. The same Resource is passed to every gameplay component. `damage_rest_seconds` controls exposed floor rest; `PickupSpawner.powerup_sweep_speed` controls powerup top-to-bottom travel and defaults to 120 pixels/second; `coin_sweep_speed` defaults to 90.
- `docs/EDITOR_GUIDE.md`: six build stages, exact node/script attachments, collision layers, signals, Inspector settings and editor checks.
- `tests/`: executable behavior tests and capture scripts. `tests/artifacts/` contains rendered screenshots.

The existing blank `node_2d.tscn` is retained; Main is now the startup scene. This folder was not a Git repository when development began.

## Verification commands

Replace `godot` with the full path to your Godot executable if it is not on PATH:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/integration.gd
godot --headless --path . --fixed-fps 60 --script tests/recovery.gd
godot --headless --path . --fixed-fps 60 --script tests/stress.gd
godot --path . --resolution 1280x720 --script tests/visual_capture.gd
```

The stress test runs 60 simulated seconds with eight protected test players so all bodies remain available for crowd and effect testing; it does not measure player enjoyment or fairness. The integration tests separately cover real damage, elimination, wins and draws. Render captures use a staged roster/effects setup to inspect layout. Manual multiplayer play is still needed to tune feel and test your keyboard's rollover.

Godot APIs: [CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html), [InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html).
