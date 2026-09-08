# Party Jousting design

Approved scope: 2–8 local keyboard players; fresh presses flap; automatic horizontal motion; walls reverse direction; both floor and ceiling damage and bounce. Three coins restore one heart (maximum five). Laser lasts five seconds and fires on each flap. No gamepads.

Damage recovery update: nonlethal health damage sends a player vertically to the floor, where they remain motionless for two seconds before an automatic upward recovery bounce. The timer begins on landing and is exported as `damage_rest_seconds`. Flaps, lasers, pickups, further damage and player pair interactions are disabled during recovery. Existing temporary effects continue expiring. Pause/hit-stop freeze the rest timer. Shield absorption does not stun; lethal hits still eliminate. The player label displays the recovery state; the in-match top HUD is intentionally omitted.

Flow: title → letter-key joining/appearance selection → safely distributed spawns → countdown → last-player-standing round → victory/rematch/lobby. Escape pauses. Enter starts or rematches. Lobby cards support removing a player. The assigned letter cycles that player's appearance in the lobby.

CharacterBody2D handles swept movement against static boundaries. A separate combat resolver takes all players' pre-movement positions and velocities, resolves swept circle contacts once per unordered pair, makes the higher body win meaningful vertical contacts, counters with Shield before height damage, and separates overlaps. Player bodies are visible on layer 1 but omit layer 1 from their engine movement mask so contact damage is resolved in exactly one place. Dead players immediately leave combat.

Player owns health, input and movement. Effects owns expiring modifiers; effective stats are recalculated from base values every frame. Tiny/Giant replace each other; repeated timed effects refresh; shield is a single charge and blocks floor/ceiling as well as attacks. Shield consumption grants a short protection window. Health and coins cannot revive eliminated players.

Powerups: Shield, Speed, Super Flap, Heavy (extra stomp damage with weight), Tiny, Giant (larger body and extra stomp damage), Health, Invincibility, Random and Laser. Random chooses a beneficial effect and never recurses. Extra stomp damage does not stack beyond two. Lasers use a swept ray to prevent tunneling, ignore the owner, disappear on the first hit, and deal one damage. Pickups have weighted rarity and safe-position rejection; coin and powerup capacities are separate. Moving HazardBlock nodes use layer 7, sweep vertically, and deal one recovery-aware damage on first contact.

All visuals and audio are original procedural placeholders. Collision size changes only in the physics loop; penetration correction and arena containment handle growth. A short impact freeze pauses simulation timers as well as movement. The scene tree pauses for the menu; the menu itself always processes. Simultaneous final eliminations are a draw.

Implementation is in the existing workspace with ready-to-run scenes and a reconstruction guide. No Autoload, external libraries or assets are required. Headless tests cover combat classification, health/protection, effect expiry, fresh presses, coins, spawning, laser hits and round flow; visual capture validates the rendered arena. Human multiplayer feel remains a playtest task.
