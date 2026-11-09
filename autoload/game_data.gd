extends Node
# GameData: global state that survives scene changes AND game restarts.
# Registered as an "autoload" — Godot creates one instance at launch,
# accessible from anywhere as `GameData`. Think of it as a global module.

const SAVE_PATH: String = "user://savegame.json"
# Where the save actually goes: SAVE_PATH, unless the game was started with
# `-- --save-file=<path>` (test runs use that so they never touch the real save).
var save_path: String = SAVE_PATH
const BALANCE: Balance = preload("res://config/balance.tres")
# "user://" = a per-user writable folder Godot manages for you.
# On Windows it's under %APPDATA%\Godot\. Never save to res:// —
# that's read-only once the game is exported.

signal run_coins_changed(amount: int)

var coins: int = 0
var run_coins: int = 0   # Gold picked up in the current round only
var pending_coins: float = 0.0  # Greed: gold owed minus paid (<= 0 = paid ahead)
var endless: bool = false       # Mode of the run being started (set by the title screen)
var endless_best: float = 0.0   # Longest endless survival, in seconds (saved)
var level_index: int = 0        # Map of the run being started (index into Levels.MAPS)
var levels_unlocked: int = 1    # How many maps can be played; a win adds the next (saved)
var character: String = "warrior"  # Id from Characters.ROSTER (saved)
# Characters the player may pick (saved, shared by both modes). Only ever
# grows: nothing removes an id, and loading merges with what's saved.
var unlocked_characters: Array[String] = []
# Unlocked but not yet celebrated on the hero select screen (saved), so the
# lock-break plays there even if the game was closed in between.
var new_unlocks: Array[String] = []
var active_boost: String = ""   # Ad boost running now: "gold", "xp", "drops" or ""
var shop_from_run: bool = false # Upgrade shop opened from the game-over screen (Back = play again)

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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-file="):
			save_path = arg.trim_prefix("--save-file=")
	for entry in Characters.ROSTER:
		if not entry.has("unlock"):
			unlocked_characters.append(entry["id"])  # Starters
	load_game()

func is_character_unlocked(id: String) -> bool:
	return id in unlocked_characters

func check_endless_unlocks(level: int, seconds: float) -> Array[String]:
	# Called during Endless matches. Unlocks (and saves at once) every
	# character whose milestone this match has reached; returns the new ones.
	var fresh: Array[String] = []
	for entry in Characters.ROSTER:
		var id: String = entry["id"]
		if not is_character_unlocked(id) and Characters.milestone_reached(entry, level, seconds):
			unlocked_characters.append(id)
			new_unlocks.append(id)
			fresh.append(id)
	if not fresh.is_empty():
		save_game()
	return fresh

func start_run() -> void:
	run_coins = 0
	pending_coins = 0.0
	active_boost = ""
	run_coins_changed.emit(run_coins)

func boost_factor(id: String) -> float:
	return BALANCE.boost_multiplier if active_boost == id else 1.0

func is_level_unlocked(index: int) -> bool:
	return index < levels_unlocked

func complete_level(index: int) -> void:
	# Winning a map opens the one after it. Replaying an old map changes nothing.
	levels_unlocked = clampi(maxi(levels_unlocked, index + 2), 1, Levels.MAPS.size())

func add_coins(amount: int) -> void:
	# coin_gain (Greed) meta upgrade: every coin picked up is worth +25% per
	# level. Coins are 1 gold each, so round UP and carry the overpayment as
	# credit until the total reaches the next whole number (at +25%: 2, 1, 1,
	# 1, then repeat = 5 gold per 4 coins). The bonus shows on the first coin,
	# and the total still comes out exact.
	pending_coins += amount * (1.0 + 0.25 * meta_upgrades["coin_gain"]) * boost_factor("gold")
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

func spent_on_upgrades() -> int:
	# Level L cost 10 + 20 + ... + 10L = 5 * L * (L + 1) in total.
	var total: int = 0
	for id in meta_upgrades:
		var level: int = meta_upgrades[id]
		total += 5 * level * (level + 1)
	return total

func reset_upgrades() -> int:
	# Title screen's Reset Upgrades: every upgrade back to 0, every coin spent
	# on them refunded. Returns the refund.
	var refund: int = spent_on_upgrades()
	coins += refund
	for id in meta_upgrades:
		meta_upgrades[id] = 0
	save_game()
	return refund

func save_game() -> void:
	var data: Dictionary = {
		"coins": coins,
		"meta_upgrades": meta_upgrades,
		"endless_best": endless_best,
		"levels_unlocked": levels_unlocked,
		"character": character,
		"unlocked_characters": unlocked_characters,
		"new_unlocks": new_unlocks,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	# File closes automatically when `file` goes out of scope.

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return  # First launch — keep defaults.
	var file := FileAccess.open(save_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		return  # Corrupted file — keep defaults rather than crash.
	coins = int(data.get("coins", 0))
	endless_best = float(data.get("endless_best", 0.0))
	levels_unlocked = clampi(int(data.get("levels_unlocked", 1)), 1, Levels.MAPS.size())
	# Add saved unlocks to the starters; never drop one that's already there.
	for id in data.get("unlocked_characters", []):
		if not is_character_unlocked(str(id)) and Characters.by_id(str(id))["id"] == str(id):
			unlocked_characters.append(str(id))
	for id in data.get("new_unlocks", []):
		if is_character_unlocked(str(id)) and not str(id) in new_unlocks:
			new_unlocks.append(str(id))
	character = Characters.by_id(str(data.get("character", "warrior")))["id"]
	if not is_character_unlocked(character):
		character = "warrior"  # A save from before unlocks existed
	# Merge saved levels into defaults (safe if we add new upgrades later).
	var saved: Dictionary = data.get("meta_upgrades", {})
	for key in meta_upgrades.keys():
		if saved.has(key):
			meta_upgrades[key] = mini(int(saved[key]), MAX_UPGRADE_LEVEL)
