# Six-stage editor guide

The supplied `.tscn` files already contain the required scene structure and script attachments. **You do not need to recreate nodes manually to run the project.** The trees below are the exact instructions if rebuilding it in a fresh Godot project. Complete scripts are in `scripts/`; paste each file unchanged into the script with the same path. Import all files before testing, because systems reference one another.

## 1. Project and folder structure

```text
project.godot
resources/default_rules.tres
scenes/
  Main.tscn
  Arena.tscn
  Player.tscn
  Coin.tscn
  PowerUp.tscn
  Laser.tscn
scripts/
  main.gd                  title/lobby/match/victory, roster and Input Map
  game_ui.gd               native Control-based menus and HUD
  player_profile.gd        typed Resource: ID, physical key, appearance
  game_rules.gd            exported tuning Resource
  player.gd                movement, boundaries, health, input and player signals
  combat.gd                swept player contacts and overlap separation
  effects.gd               effect durations and derived modifiers
  powerup_catalog.gd       powerup IDs, names, symbols, colors and descriptions
  arena.gd                 round simulation, spawn layout, boundaries, laser creation
  pickup.gd                Area2D collection and pickup drawing
  pickup_spawner.gd        capacity, weighted random types and safe locations
  laser.gd                 swept projectile query and hit handling
  animal_skin.gd           eight original geometric animals
  feedback.gd              short generated sounds and particles
tests/
  run_tests.gd             health/effect/combat contracts
  integration.gd           playable systems and round flow
  stress.gd                crowded eight-player simulation
  visual_capture.gd        rendered screenshots
```

Set Project Settings → Display → Window: viewport 1280×720, stretch mode `canvas_items`, stretch aspect `keep`. Use Compatibility rendering. Set Application → Run → Main Scene to `res://scenes/Main.tscn`. The supplied project settings already do this.

**Test:** Godot imports the files without script errors. Run Main and see the title screen.

## 2. Player scene, fresh-press flaps and stomps

```text
Player (CharacterBody2D)       scripts/player.gd
├── CollisionShape2D          CircleShape2D, radius 18
├── Skin (Node2D)             scripts/animal_skin.gd
└── Effects (Node)            scripts/effects.gd
```

Attach `player.gd` to the root, `animal_skin.gd` to Skin and `effects.gd` to Effects. Assign `default_rules.tres` to Player → Rules. The default script value already points to it. Each instance receives a separate `PlayerProfile` from Main. Do not manually duplicate the shared profile resource for gameplay; Arena supplies the correct profile before adding the node.

CharacterBody2D gives scripted, predictable movement against the boundaries. `prepare_step()` updates gravity and effects, consumes a fresh press, and records the position/velocity before movement. `move_step()` uses `move_and_collide()` for boundaries. Arena calls preparation for **all** players before moving any of them. Player's own `_physics_process` is intentionally absent so simulation has one coordinator.

`CombatResolver` is a RefCounted helper instantiated by Arena; **attach it to no node**. It uses the swept relative paths of circular bodies to find a collision normal. A meaningful vertical normal makes the higher player the winner: the lower player takes damage and the higher player bounces upward, regardless of whether the winner was falling, rising or moving sideways. Nearly level contacts remain harmless side bumps. Each unordered pair is processed once and latched until separation. Several position-correction passes release crowded overlaps. Dead players are excluded immediately.

If either player has a Shield, the shield is consumed on the first real body contact and the other player takes one damage, regardless of height. A held overlap cannot consume another charge until the pair separates. A resting player with no Shield is still eliminated immediately by an incoming body; a resting Shield counters that hit first.

The collision circle tracks Tiny/Giant. Ears, beaks and wings are decorative. On growth, the physics loop changes the circle size, keeps the body within the arena and resolves overlaps. New overlaps from growth do not qualify as an ordinary falling stomp unless the full contact criteria are met.

**Test:** Join two players with Q and P. Press Enter; after countdown, tap Q repeatedly. Holding Q produces only the initial flap. Put one player meaningfully above the other and collide; the higher player should continue upward while only the lower player loses health. Test a level side bump for harmless separation, then test with eight players.

## 3. Hazards, health and elimination

The top 136 pixels remain reserved as a clear gameplay margin. The damaging ceiling is at Y=160 (top margin plus boundary thickness), and no in-match top HUD overlays the arena. `GameRules.hud_height` controls this inset.

Surviving any health damage now starts recovery: fall vertically to the floor, remain motionless for `GameRules.damage_rest_seconds` (default 2.0), then launch upward with fresh protection. The rest countdown starts on landing. Input, pickups, player contact and further damage are ignored during recovery; other players pass through the protected body until a real incoming player-body contact reaches the resting state. That contact is a deliberate exposed-floor execution: it eliminates the resting player immediately and bypasses hearts, shield and invincibility. Timed powerups continue expiring. Pause and hit-stop freeze the recovery countdown. The player label shows DOWN while falling and EXPOSED with seconds remaining on the floor. A shield-blocked hit does not start recovery, and lethal hits still eliminate immediately.

Arena contains these four existing nodes; `build_boundaries()` gives each its correct transform and a RectangleShape2D child derived from the arena dimensions:

```text
Boundaries (Node2D)
├── LeftWall (StaticBody2D)
├── RightWall (StaticBody2D)
├── Floor (StaticBody2D)
└── Ceiling (StaticBody2D)
```

They need no separate hazard script. Side walls reverse horizontal direction with no damage. Floor and ceiling each deal one damage; surviving damage starts the recovery described above. A protected or shielded boundary touch still bounces away normally. Player keeps a contact latch per damaging boundary; a new damage event requires real separation of more than 3 pixels. A shield blocks and is consumed by either boundary. The recovery landing cannot deal a second damage hit.

`take_damage()` rejects dead/inactive/protected players, checks invincibility and shield, subtracts health, emits health/damage signals, then marks lethal victims dead before emitting elimination. Body-contact shield counters are resolved by `CombatResolver` before height-based damage. Dead bodies lose collision layers immediately, clear effects and input, then spin/fall/fade for 0.8 seconds. They cannot collect, attack, shoot or revive. The round result is evaluated after the entire simulation step, including projectiles, so a simultaneous final knockout can produce a draw.

**Test:** Starting from three hearts, touch the floor once and see one heart disappear, two seconds of stationary rest, then an automatic upward bounce. Touch the ceiling or take a stomp/laser hit and verify a straight drop followed by the same rest. Tap during recovery and confirm no flaps or lasers are queued. Send another player into an exposed resting player and verify instant elimination. Check protection, shield absorption and harmless side walls. At zero hearts the player fades out; the last survivor gets a victory screen. Enter starts a fresh rematch.

## 4. Coins and safe pickup spawning

```text
Coin (Area2D)                 scripts/pickup.gd; Is Coin = On
└── CollisionShape2D          CircleShape2D, radius 11

PowerUp (Area2D)              scripts/pickup.gd; Is Coin = Off
└── CollisionShape2D          CircleShape2D, radius 19
```

Pickup → Kind chooses the enum type for a hand-placed PowerUp. Dynamic spawns assign it before adding the node. Add a Node2D named PickupSpawner under Arena and attach `pickup_spawner.gd`; the ready scene already contains it. Its Rules Resource is set by Arena. Its Weights array corresponds to `PowerupCatalog.Kind` in enum order.

The spawner checks player radius plus a 60-pixel buffer, other pickup positions, boundary margins, and physical obstacles on the reserved hazard/boundary layers. It skips a spawn after 80 rejected candidates. Each pickup can be claimed once, immediately latches that claim, and defers removal of its monitoring. Its `tree_exiting` callback removes the spawner reference, including when an uncollected pickup is removed externally. Coins and powerups have separate capacity limits.

Three coins restore one health point, capped at five, and subtract three from the local coin counter. The match no longer overlays a per-player top HUD.

Coins and powerups set `origin_position` on entry and move the Area2D itself in `_physics_process()` across the arena. Each spawn starts at the top or bottom safe edge, crosses to the opposite edge, then reverses. The visual drawing stays local to the moving node, so the collection shape follows it. `PickupSpawner.powerup_sweep_speed` controls powerup travel and defaults to 120 pixels per second; `coin_sweep_speed` defaults to 90.

**Test:** For faster manual checks, lower Coin Interval in `default_rules.tres`. Collect two coins and verify no healing; collect a third and see one heart restored. At five hearts the cap holds. Inspect the Remote tree while pickups accumulate: at most ten coins and four powerups. Restore normal timing afterward.

## 5. Modular effects and laser

Effects is a Node component containing one duration entry per catalog enum. It never mutates base rules. Derived multipliers are calculated from the currently active entries. Same-type collections refresh, Tiny/Giant replace one another, and shield is one persistent charge. Health is applied immediately by Player. Mystery selects from the nonrecursive beneficial list. See README for all ten effects and stacking rules.

```text
Laser (Node2D)                scripts/laser.gd
```

Laser is drawn by script and has no collision shape. Its `tick()` casts a ray over the whole distance traveled in a step, checks players and boundary layers, excludes the owner's RID, damages the first player hit and removes the shot. This prevents fast bullets passing through thin targets. Protected opponents still absorb a shot without losing health. Shots already fired continue if the shooter is eliminated; dead players cannot fire new shots. All shots reset on rematch.

Arena creates laser instances in response to `laser_requested`, emitted alongside each fresh flap while the five-second effect is active. It places the shot inside the owner's body and excludes that body from the query, which also allows point-blank hits. Duration is independent of shot count.

**Test:** In the running Remote tree, set a spawned PowerUp's Kind to Laser before collecting it, or use the test scene/script. Collect it; every fresh press should flap and shoot for five seconds. Holding should not generate extra shots. Verify owner immunity, one-damage hits, shield/invincibility blocking and expiry. Test Speed twice to verify refresh, then Tiny followed by Giant to verify replacement. Pause while effects are active and verify their timers stop.

## 6. Main arena, menus and wiring

```text
Main (Node)                  scripts/main.gd
├── UI (CanvasLayer)         scripts/game_ui.gd
└── Arena (runtime instance of Arena.tscn)
    ├── Boundaries (Node2D)
    │   ├── LeftWall (StaticBody2D)
    │   ├── RightWall (StaticBody2D)
    │   ├── Floor (StaticBody2D)
    │   └── Ceiling (StaticBody2D)
    ├── Players (Node2D)     runtime Player.tscn instances
    ├── PickupSpawner (Node2D) scripts/pickup_spawner.gd
    ├── Projectiles (Node2D) runtime Laser.tscn instances
    ├── Feedback (Node2D)    scripts/feedback.gd
    └── Camera2D             fixed arena center, no follow scrolling
```

Attach `arena.gd` to Arena. Main retains a typed Array of PlayerProfile Resources while Arena instances are replaced; no global singleton is necessary. Main creates per-player Input Map actions with `add_action()` and physical `InputEventKey` bindings using `action_add_event()`. Old generated actions are removed before each round, preventing duplicated bindings. No Inspector input assignments are needed.

UI creates native Labels, Buttons, Panels and Containers in code. Main and UI process during pause; Arena explicitly uses Pausable mode. Escape toggles pause. Pausing clears queued flaps. Enter starts/rematches, and unused letters join only in the lobby. Key repeat is ignored. Mouse controls duplicate the lobby and menu commands.

Spawn positions are distributed across eight separated cells with small random jitter; use the default arena dimensions or larger for eight players. Transforms and profiles are assigned before players enter the tree. They stay inactive during countdown, then get 1.2 seconds of spawn protection. Pickups do not spawn until active gameplay. The Camera2D remains centered and scales to arena dimensions; shake is a small temporary offset.

### Collision layers and masks

| Object | Layer numbers | Bitmask value | Mask numbers | Mask value |
|---|---|---:|---|---:|
| Player | 1 | 1 | 2, 3, 4 | 14 |
| Side wall | 2 | 2 | None | 0 |
| Floor | 3 | 4 | None | 0 |
| Ceiling | 4 | 8 | None | 0 |
| PowerUp | 5 | 16 | 1 | 1 |
| Coin | 6 | 32 | 1 | 1 |
| Future hazards | 7 | 64 | As appropriate | — |
| Laser ray | No body layer | — | 1, 2, 3, 4 | 15 |

Player–player contacts deliberately bypass the engine's movement mask and are resolved centrally by CombatResolver. Players remain on layer 1 so pickups and lasers can detect them. Do not add layer 1 to Player's mask without also replacing the custom pair solver. The reserved hazard layer is excluded by spawn queries; implementing a new harmful hazard still requires its damage behavior.

### Signals (all connected in code)

| Emitter | Signal | Consumer |
|---|---|---|
| Player | `player_damaged(player, amount)` | Arena feedback and hit-stop |
| Player | `player_eliminated(player)` | Arena particles/audio and HUD refresh |
| Player | `health_changed(player)`, `coin_collected(player)` | HUD refresh |
| Player | `flapped(player)` | Flap sound |
| Player | `laser_requested(player)` | Arena creates laser |
| Player | `powerup_collected(player, kind)` | HUD refresh |
| Effects | `changed` | HUD refresh |
| Pickup | `body_entered(body)` | Pickup's own handler |
| Pickup | `collected(pickup, player)` | Spawner forwards pickup event |
| Pickup | `tree_exiting` | Spawner drops reference |
| Spawner | `pickup_taken(pickup, player)` | Arena collection particles/audio |
| Laser | `impacted(location, color)` | Arena impact particles |
| Arena | `countdown_changed(text)` | UI countdown |
| Arena | `status_changed` | UI HUD |
| Arena | `round_finished(winner)` | Main victory transition; null winner = draw |
| UI | Menu, appearance and removal signals | Main flow handlers |

**Do not add duplicate connections in the editor. No Autoloads are required.** `game_rules.gd` and `player_profile.gd` extend Resource; `powerup_catalog.gd` and `combat.gd` extend RefCounted. Those four scripts attach to no scene node.

**Test:** Walk through title → lobby → eight joins → appearance changes → remove/rejoin → countdown → match → pause/resume → victory → rematch → lobby. Check the sound toggle. Repeat with two players. Test at smaller window sizes; the fixed 16:9 viewport scales without cutting off controls.

## Verification and extension notes

Run the commands in README. `tests/visual_capture.gd` saves five PNG screenshots into `tests/artifacts/` using Godot's actual renderer. Normal gameplay contains no bots or automated inputs; test scripts supply those only in tests.

To add a skin, extend AnimalSkin's names/colors and drawing, then replace the fixed eight-appearance modulo values with the new count; player count remains capped independently. To replace art, keep Skin's feedback interface (`flap`, facing/effect flags) while changing its drawing implementation. To add a powerup, extend the enum/catalog, duration/effect handling and spawner weights, and add an integration assertion for expiry/stacking.

For the initial version, one arena and short standalone rounds keep the rules easy to test. Human playtests should tune horizontal speed, flap strength and damage protection before adding more hazards or powerups.
