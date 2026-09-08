class_name PowerupCatalog
extends RefCounted
enum Kind { SHIELD, SPEED, SUPER_FLAP, HEAVY, TINY, GIANT, HEALTH, INVINCIBILITY, RANDOM, LASER }
const NAMES: Array[String] = ["Shield", "Speed", "Super Flap", "Heavy", "Tiny", "Giant", "Health", "Invincible", "Mystery", "Laser"]
const SYMBOLS: Array[String] = ["S", ">>", "^", "H", "-", "+", "+1", "*", "?", "L"]
const COLORS: Array[Color] = [Color("66d9ff"), Color("f7d75c"), Color("79eeac"), Color("b5a6ef"), Color("f8b6df"), Color("ff9768"), Color("ff688b"), Color("fff4b5"), Color("b79aff"), Color("ff5b66")]
const DESCRIPTIONS: Array[String] = ["Block one hit, including the floor or ceiling", "Faster horizontal flight for 5 seconds", "Stronger flaps for 5 seconds", "More gravity and two-damage stomps", "Smaller body for 5 seconds", "Bigger body and two-damage stomps", "Restore one heart, up to five", "Block all damage for 3 seconds", "Gain a random beneficial effect", "Each flap fires a laser for 5 seconds"]
# Heavy has a tradeoff, so Mystery excludes it. Mystery cannot select itself.
const BENEFICIAL: Array[int] = [Kind.SHIELD, Kind.SPEED, Kind.SUPER_FLAP, Kind.TINY, Kind.GIANT, Kind.HEALTH, Kind.INVINCIBILITY, Kind.LASER]
