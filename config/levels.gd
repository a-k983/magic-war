class_name Levels
extends RefCounted
# The four maps, in play order. Each has its own ground and building colour,
# its own scenery and five enemy types no other map uses. Beating a map
# (surviving BALANCE.win_time_minutes) unlocks the next: see GameData.
#
# Map keys:
#   ground        - tint for the grass tile (values above 1 are fine)
#   buildings     - which "<colour> Buildings" folder prop.gd draws from
#   foliage       - tint for trees and bushes
#   trees / rocks - prop kinds to scatter (see KINDS in prop.gd)
#   scatter       - how many [trees, rocks, bushes] to scatter
#   seed          - scatter seed: same map every run
#   health/damage/spawn - difficulty of the map, on top of wave + player level
#   landmarks     - hand-placed scenery as [kind, x, y]. Empty = keep the
#                   props placed by hand in world.tscn.
#
# Enemy keys:
#   name, run, attack - folder and sheet suffixes in the Enemy Pack
#   ai     - which brain enemy.gd runs (every enemy has its own)
#   speed, health - multipliers on the Balance base stats

const ENEMY_PACK_DIR: String = "res://scenes/assets/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/"

const MAPS: Array[Dictionary] = [
	{
		"name": "Greenhollow Vale",
		"blurb": "Farmland under siege. The bones are only the start.",
		"ground": Color(0.55, 0.6, 0.4),
		"buildings": "Blue",
		"foliage": Color.WHITE,
		"trees": ["tree1", "tree2", "tree3", "tree4"],
		"rocks": ["rock1", "rock2", "rock3", "rock4", "stump"],
		"scatter": [40, 30, 70],
		"seed": 7,
		"health": 1.0, "damage": 0.0, "spawn": 1.0,
		"landmarks": [],
		"enemies": [
			{"name": "Skull", "run": "Run", "attack": "Attack", "ai": "march", "speed": 1.0, "health": 1.0},
			{"name": "Gnome", "run": "Run", "attack": "Attack", "ai": "scurry", "speed": 1.1, "health": 0.8},
			{"name": "Spider", "run": "Run", "attack": "Attack", "ai": "pounce", "speed": 0.8, "health": 1.0},
			{"name": "Thief", "run": "Run", "attack": "Attack", "ai": "flank", "speed": 1.2, "health": 1.0},
			{"name": "Lizard", "run": "Run", "attack": "Attack", "ai": "charge", "speed": 0.8, "health": 1.6},
		],
	},
	{
		"name": "Emberwaste",
		"blurb": "Scorched badlands held by goblin raiders.",
		"ground": Color(1.75, 0.8, 0.42),
		"buildings": "Red",
		"foliage": Color(1.5, 0.72, 0.32),
		"trees": ["tree3", "tree4", "dead_tree"],
		"rocks": ["rock2", "rock3", "bones1", "bones2", "gold_stone2"],
		"scatter": [22, 55, 25],
		"seed": 23,
		"health": 1.4, "damage": 0.25, "spawn": 1.1,
		"landmarks": [
			["goblin_hut", -260, -340], ["goblin_hut", 270, -360], ["goblin_hut", -60, -560],
			["tower", -520, -520], ["tower", 520, -540], ["barracks", 0, -760],
			["goblin_hut", 980, 520], ["goblin_hut", 1240, 640], ["goblin_hut", 1100, 860],
			["archery", 1420, 420], ["rock3", 860, 700], ["rock1", 1320, 900],
			["house2", -1120, 780], ["house3", -1300, 930], ["goblin_hut", -940, 980],
			["tower", -1420, 700], ["gold_stone", -1560, -1120], ["gold_stone2", -1450, -1040],
			["gold_stone", -1620, -960], ["castle", 1500, -1320], ["tower", 1230, -1280],
			["tower", 1770, -1280], ["barracks", -320, 1420], ["goblin_hut", 60, 1500],
		],
		"enemies": [
			{"name": "Torch Goblin", "run": "Run", "attack": "Attack", "ai": "arson", "speed": 1.05, "health": 1.0},
			{"name": "Spear Goblin", "run": "Run", "attack": "Attack Fast", "ai": "skirmish", "speed": 1.1, "health": 1.0},
			{"name": "Gnoll", "run": "Walk", "attack": "Throw", "ai": "kite", "speed": 0.95, "health": 0.9},
			{"name": "Panda", "run": "Run", "attack": "Attack", "ai": "slam", "speed": 0.8, "health": 1.8},
			{"name": "Bear", "run": "Run", "attack": "Attack", "ai": "enrage", "speed": 0.6, "health": 2.5},
		],
	},
	{
		"name": "Tidewrack Fen",
		"blurb": "A drowned marsh where the sea came ashore armed.",
		"ground": Color(0.42, 0.95, 1.05),
		"buildings": "Yellow",
		"foliage": Color(0.55, 1.05, 0.95),
		"trees": ["tree1", "tree2"],
		"rocks": ["rock1", "rock4", "stump"],
		"scatter": [28, 24, 90],
		"seed": 41,
		"health": 1.9, "damage": 0.5, "spawn": 1.2,
		"landmarks": [
			["fish_hut", -300, 300], ["fish_hut", -520, 420], ["fish_hut", -160, 520],
			["pirate_tower", -640, 620], ["pirate_tower", 40, 680],
			["fish_hut", 760, -340], ["fish_hut", 980, -470], ["fish_hut", 1180, -300],
			["pirate_tower", 1340, -520], ["house1", 860, -640], ["house3", 1120, -700],
			["monastery", -1180, -760], ["house2", -1440, -640], ["house1", -960, -620],
			["pirate_tower", -1300, -1040], ["castle", 1180, 1360], ["tower", 920, 1400],
			["tower", 1440, 1400], ["fish_hut", 700, 1120], ["fish_hut", -1400, 1200],
			["fish_hut", -1200, 1340], ["pirate_tower", -1560, 1360], ["archery", 100, -1400],
		],
		"enemies": [
			{"name": "Paddle Shark", "run": "Run", "attack": "Attack", "ai": "burrow", "speed": 1.15, "health": 1.0},
			{"name": "Snake", "run": "Run", "attack": "Attack", "ai": "slither", "speed": 1.0, "health": 1.0},
			{"name": "Harpoon Shark", "run": "Run", "attack": "Throw", "ai": "harpoon", "speed": 0.9, "health": 1.1},
			{"name": "Bomb Fish", "run": "Run", "attack": "Shoot", "ai": "lob", "speed": 0.9, "health": 1.0},
			{"name": "Turtle", "run": "Walk", "attack": "Attack", "ai": "shell", "speed": 0.6, "health": 2.5},
		],
	},
	{
		"name": "Hexfall Barrens",
		"blurb": "Cursed ground. Nothing here walks a straight line.",
		"ground": Color(0.95, 0.42, 1.0),
		"buildings": "Black",
		"foliage": Color(0.7, 0.5, 0.95),
		"trees": ["tree3", "tree4", "tree3", "dead_tree"],
		"rocks": ["skull_spike1", "skull_spike2", "bones1", "bones2", "rock3"],
		"scatter": [34, 60, 12],
		"seed": 67,
		"health": 2.5, "damage": 0.75, "spawn": 1.3,
		"landmarks": [
			["castle", 0, 620], ["tower", -240, 650], ["tower", 240, 650],
			["skull_spike2", -130, 300], ["skull_spike2", 130, 300],
			["skull_spike1", -300, 430], ["skull_spike1", 300, 430],
			["monastery", -1220, -300], ["skull_spike2", -1040, -240], ["skull_spike2", -1400, -240],
			["barracks", 1200, -260], ["house3", 1020, -480], ["house2", 1400, -490],
			["tower", 1000, -60], ["tower", 1420, -60], ["gnome_tower", -520, -1120],
			["gnome_hut", -360, -1040], ["gnome_hut", -700, -1040], ["house1", 1260, 1280],
			["house3", 1040, 1400], ["tower", -1380, 1300], ["tower", -1120, 1300],
			["archery", -1250, 1480], ["skull_spike1", 460, -1300], ["skull_spike2", 620, -1380],
		],
		"enemies": [
			{"name": "Giant Bat", "run": "Move", "attack": "Attack", "ai": "swoop", "speed": 1.15, "health": 0.9},
			{"name": "Bumblebee", "run": "Move", "attack": "Attack", "ai": "sting", "speed": 1.3, "health": 0.8},
			{"name": "Imp", "run": "Move", "attack": "Attack_Loop", "ai": "blink", "speed": 0.9, "health": 1.1},
			{"name": "Hex Shaman", "run": "Run", "attack": "Attack", "ai": "hex", "speed": 0.85, "health": 1.2},
			{"name": "Minotaur", "run": "Walk", "attack": "Attack", "ai": "bullrush", "speed": 0.8, "health": 3.0},
		],
	},
]

# Endless mode plays on the first map and cycles through every enemy above,
# a little of each map at a time, so a long run sees the whole bestiary.
static func endless_enemies() -> Array[Dictionary]:
	var order: Array[Dictionary] = []
	for slot in 5:
		for map in MAPS:
			order.append(map["enemies"][slot])
	return order
