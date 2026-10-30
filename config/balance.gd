class_name Balance
extends Resource
# Game balance knobs in one place. Edit res://config/balance.tres in the
# Inspector (double-click it in the FileSystem dock), then press F5 to play.
# Scripts read these at spawn time:
#   player.gd, enemy.gd, main.gd (win time, elites, waves), lightning/frost/orbit spells.
# Hover a value in the Inspector to see what it does.

@export_group("Win Condition")
## Minutes the player must survive to win a map (and unlock the next one).
## Endless mode ignores it. The map's five enemy types are spread evenly across
## this time, so every map shows all five however long the run is.
@export_range(0.5, 30.0, 0.5) var win_time_minutes: float = 5.0

@export_group("Difficulty Scaling")
## Extra enemy health per player level above 1 (0.08 = +8% each level).
## Each map adds its own multiplier on top (see config/levels.gd).
@export_range(0.0, 0.5, 0.01) var health_per_player_level: float = 0.08
## Extra damage taken per player level above 1 (0.04 = +4% each level).
@export_range(0.0, 0.5, 0.01) var damage_per_player_level: float = 0.04
## Extra spawn rate per player level above 1 (0.03 = 3% more enemies each level).
@export_range(0.0, 0.2, 0.01) var spawn_rate_per_player_level: float = 0.03
## Spawning pauses at this many living enemies, so late runs stay playable.
@export_range(50, 1000, 10) var max_enemies: int = 250

@export_group("Player Speed")
## How fast the player moves at the start of a run (pixels/second).
## Swift Boots (+15%) and the Agility shop upgrade (+5%/level) multiply this.
@export_range(100.0, 600.0, 5.0) var player_speed: float = 280.0

@export_group("Player Damage")
## Fireball damage per hit. Each "Sharper Flames" / "Power" upgrade adds +1.
@export_range(1, 20) var fireball_damage: int = 1
## Chain Lightning damage per strike.
@export_range(1, 20) var lightning_damage: int = 2
## Frost Nova damage per pulse.
@export_range(1, 20) var frost_damage: int = 1
## Arcane Orbit damage per orb hit.
@export_range(1, 20) var orbit_damage: int = 1
## Warrior's Cleave damage per enemy hit.
@export_range(1, 50) var cleave_damage: int = 1
## Lancer's Lance Thrust damage per enemy hit.
@export_range(1, 50) var thrust_damage: int = 1
## Archer's Piercing Arrow damage per enemy hit.
@export_range(1, 50) var arrow_damage: int = 1

@export_group("Level-Up Weapons")
## Highest level for Runeward Circle, Starfall, Moonreaver and Thornwake.
@export_range(1, 10) var weapon_max_level: int = 5
## Runeward Circle: damage per tick at level 1, and extra per level.
@export_range(1, 20) var runeward_damage: int = 1
@export_range(0, 10) var runeward_damage_per_level: int = 1
## Runeward Circle: radius in pixels at level 1, and extra per level.
@export_range(50.0, 400.0, 5.0) var runeward_radius: float = 130.0
@export_range(0.0, 150.0, 5.0) var runeward_radius_per_level: float = 40.0
## Runeward Circle: seconds between damage ticks.
@export_range(0.1, 2.0, 0.05) var runeward_tick: float = 0.5
## Starfall: damage at level 1, and extra per level.
@export_range(1, 50) var starfall_damage: int = 3
@export_range(0, 20) var starfall_damage_per_level: int = 2
## Moonreaver: damage per pass at level 1, and extra per level.
@export_range(1, 50) var moonreaver_damage: int = 2
@export_range(0, 20) var moonreaver_damage_per_level: int = 1
## Thornwake: damage per bramble tick at level 1, and extra per level.
@export_range(1, 50) var thornwake_damage: int = 1
@export_range(0, 20) var thornwake_damage_per_level: int = 1

@export_group("Enemy Speed")
## Normal enemy move speed (pixels/second). Compare with Player Speed.
@export_range(50.0, 500.0, 5.0) var enemy_speed: float = 190.0
## Elite (giant) enemy move speed.
@export_range(50.0, 500.0, 5.0) var elite_speed: float = 125.0

@export_group("Enemy Damage")
## Base damage a normal enemy's hit does to the player (before multipliers).
@export_range(1, 20) var enemy_damage: int = 1
## Base damage an elite's hit does to the player.
@export_range(1, 20) var elite_damage: int = 3
## Every hit the player takes is multiplied by this (1.0 = no change).
@export_range(0.25, 5.0, 0.05) var damage_taken_multiplier: float = 1.5
## Extra damage taken per new enemy type (wave). 0.25 = +25% per wave.
@export_range(0.0, 1.0, 0.05) var wave_damage_bonus: float = 0.25
## Seconds between one enemy's hits. Lower = swarms hurt faster.
@export_range(0.1, 3.0, 0.05) var enemy_attack_cooldown: float = 0.6
## Hits within this many seconds of the last one build a swarm streak.
@export_range(0.0, 3.0, 0.05) var streak_window: float = 0.75
## Extra damage per streak step (0.25 = +25% per consecutive hit).
@export_range(0.0, 1.0, 0.05) var streak_bonus: float = 0.25
## Most streak steps that count (8 x 0.25 = up to 3x damage).
@export_range(0, 20) var max_streak: int = 8

@export_group("Enemy Toughness")
## Normal enemy health at the start of a run (+2 per minute, +15% per wave).
@export_range(1, 50) var enemy_health: int = 4
## Elite health at the start of a run (+20 per minute, +15% per wave).
@export_range(1, 500) var elite_health: int = 60

@export_group("Coin Drops")
## Coins a normal enemy drops when it dies. Each coin is worth 1 gold,
## plus the Greed shop bonus (+25% per level).
@export_range(0, 20) var coins_per_enemy: int = 1
## Coins an elite (giant) enemy drops when it dies.
@export_range(0, 100) var coins_per_elite: int = 15

@export_group("Shop Upgrades")
## Extra chance per Potion Luck level that any enemy drops a health potion
## (0.05 = +5% per level, on top of the base ~1.2%). Unlocks once Vitality is maxed.
@export_range(0.0, 0.1, 0.005) var potion_drop_per_level: float = 0.05
## Extra nuke drop chance per Nuke Luck level (base 0.2%). Unlocks once Power is maxed.
@export_range(0.0, 0.02, 0.001) var nuke_drop_per_level: float = 0.002
## Super Mode drop chance per level (no base chance). Unlocks once Agility is maxed.
@export_range(0.0, 0.02, 0.001) var invincible_drop_per_level: float = 0.003
## Seconds of invincibility from one Super Mode pickup.
@export_range(1.0, 20.0, 0.5) var invincible_duration: float = 6.0
## Extra magnet drop chance per Magnet Luck level (base 0.6%). Unlocks once Greed is maxed.
@export_range(0.0, 0.05, 0.001) var magnet_drop_per_level: float = 0.005
## HP healed per second per Regeneration level (0.05 = Lv 10 heals 1 HP every 2s).
## Unlocks once Potion Luck is maxed.
@export_range(0.0, 0.5, 0.01) var regen_per_level: float = 0.05
## Fireball cooldown cut per Rapid Fire level (0.04 = 4% faster each level).
## Unlocks once Nuke Luck is maxed.
@export_range(0.0, 0.09, 0.01) var fire_rate_per_level: float = 0.04
## Chance to dodge a hit per Dodge level (0.03 = Lv 10 dodges 30%).
## Unlocks once Super Mode is maxed.
@export_range(0.0, 0.09, 0.01) var dodge_per_level: float = 0.03
## Coin/XP pickup range bonus per Reach level (0.1 = +10% each level).
## Unlocks once Magnet Luck is maxed.
@export_range(0.0, 0.5, 0.05) var pickup_range_per_level: float = 0.1
