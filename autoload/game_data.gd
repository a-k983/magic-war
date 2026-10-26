extends Node
# GameData: global state that survives scene changes AND game restarts.
# Registered as an "autoload" — Godot creates one instance at launch,
# accessible from anywhere as `GameData`. Think of it as a global module.

const SAVE_PATH: String = "user://savegame.json"
# "user://" = a per-user writable folder Godot manages for you.
# On Windows it's under %APPDATA%\Godot\. Never save to res:// —
# that's read-only once the game is exported.

signal run_coins_changed(amount: int)

var coins: int = 0
var run_coins: int = 0   # Gold picked up in the current round only
var pending_coins: float = 0.0  # Greed: gold owed minus paid (<= 0 = paid ahead)
var endless: bool = false       # Mode of the run being started (set by the title screen)
var endless_best: float = 0.0   # Longest endless survival, in seconds (saved)

# Meta upgrade levels the player has purchased. Keys must match
# the shop and player code.
var meta_upgrades: Dictionary = {
	"max_hp": 0,       # +2 max HP per level
	"damage": 0,       # +1 fireball damage per level
	"move_speed": 0,   # +5% per level
	"coin_gain": 0,    # +25% coins per level
	# "Luck" upgrades: each replaces a maxed upgrade above and raises one
	# pickup's drop chance per level (amounts in res://config/balance.tres).
	"potion_drop": 0,      # Health potions; unlocks when max_hp is maxed
	"nuke_drop": 0,        # Nukes; unlocks when damage is maxed
	"invincible_drop": 0,  # Super Mode (invincibility); unlocks when move_speed is maxed
	"magnet_drop": 0,      # Magnets; unlocks when coin_gain is maxed
	# Third tier: each unlocks when the Luck upgrade above it is maxed.
	"regen": 0,         # HP regeneration; after potion_drop
	"fire_rate": 0,     # Faster fireballs; after nuke_drop
	"dodge": 0,         # Chance to dodge a hit; after invincible_drop
	"pickup_range": 0,  # Coins/XP fly in from farther; after magnet_drop
}

# No upgrade goes past this level. The shop swaps a maxed upgrade for its
# replacement, if it has one.
const MAX_UPGRADE_LEVEL: int = 10

func _ready() -> void:
	load_game()

func start_run() -> void:
	run_coins = 0
	pending_coins = 0.0
	run_coins_changed.emit(run_coins)

func add_coins(amount: int) -> void:
	# coin_gain (Greed) meta upgrade: every coin picked up is worth +25% per
	# level. Coins are 1 gold each, so round UP and carry the overpayment as
	# credit until the total reaches the next whole number (at +25%: 2, 1, 1,
	# 1, then repeat = 5 gold per 4 coins). The bonus shows on the first coin,
	# and the total still comes out exact.
	pending_coins += amount * (1.0 + 0.25 * meta_upgrades["coin_gain"])
	var gained: int = maxi(ceili(pending_coins - 0.0001), 0)  # 0.0001: float slop
	pending_coins -= gained
	coins += gained
	run_coins += gained
	run_coins_changed.emit(run_coins)

func get_upgrade_cost(id: String) -> int:
	# Escalating prices: level 0->1 costs 10, 1->2 costs 20, etc.
	return 10 * (meta_upgrades[id] + 1)

func is_maxed(id: String) -> bool:
	return meta_upgrades[id] >= MAX_UPGRADE_LEVEL

func try_purchase(id: String) -> bool:
	var cost: int = get_upgrade_cost(id)
	if coins < cost or is_maxed(id):
		return false
	coins -= cost
	meta_upgrades[id] += 1
	save_game()
	return true

func save_game() -> void:
	var data: Dictionary = {
		"coins": coins,
		"meta_upgrades": meta_upgrades,
		"endless_best": endless_best,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	# File closes automatically when `file` goes out of scope.

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return  # First launch — keep defaults.
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		return  # Corrupted file — keep defaults rather than crash.
	coins = int(data.get("coins", 0))
	endless_best = float(data.get("endless_best", 0.0))
	# Merge saved levels into defaults (safe if we add new upgrades later).
	var saved: Dictionary = data.get("meta_upgrades", {})
	for key in meta_upgrades.keys():
		if saved.has(key):
			meta_upgrades[key] = mini(int(saved[key]), MAX_UPGRADE_LEVEL)
