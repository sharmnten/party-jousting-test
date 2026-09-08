# Implementation plan

1. Rules and regression harness: test real health/effect/stomp contracts, then build the rules Resource, effect component and player scene.
2. Arena physics: implement walls, damaging floor/ceiling, swept pair contacts, separation and safe spawns. Test top/side/upward contacts, repeated damage and eight-player placement.
3. Pickups: reusable Area2D scene with coin/powerup variants, safe weighted spawning, timed effects and swept laser scene. Test coin conversion, caps, expiry, owner immunity and pickup spacing.
4. Round flow: title/lobby/countdown/arena/victory, generated physical-key Input Map bindings, pause and rematch. Test lobby limits and key uniqueness, countdown and winner/draw transitions.
5. Feedback and handoff: procedural animals, particles, sounds, health indicators, screen shake and UI. Import/parse project, run behavior tests and smoke simulation, inspect rendered image, write stage-by-stage editor guide.

The user approved inline implementation. Each subsystem is checked as it becomes usable; no extra approval or Git initialization is needed.
