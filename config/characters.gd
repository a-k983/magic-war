class_name Characters
extends RefCounted
# The starter characters. Only their idle and run sheets are used for now.
# `weapon` is what player.gd fires; `damage` names the Balance property for
# its base damage. `reach` is for melee weapons, 0 = a projectile.

const UNITS_DIR: String = "res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/"

const ROSTER: Array[Dictionary] = [
	{
		"id": "monk", "name": "Monk", "colour": "Black",
		"idle": "Monk/Idle.png", "run": "Monk/Run.png",
		"weapon": "fireball", "weapon_name": "Fireball", "damage": "fireball_damage",
		"cooldown": 0.8, "speed": 500.0, "reach": 0.0,
		"desc": "Hurls a Fireball at the nearest enemy.",
	},
	{
		"id": "warrior", "name": "Warrior", "colour": "Blue",
		"idle": "Warrior/Warrior_Idle.png", "run": "Warrior/Warrior_Run.png",
		"weapon": "cleave", "weapon_name": "Cleave", "damage": "cleave_damage",
		"cooldown": 1.0, "speed": 0.0, "reach": 190.0,
		"desc": "Cleave: a wide sweep that hits all in its arc.",
	},
	{
		"id": "lancer", "name": "Lancer", "colour": "Red",
		"idle": "Lancer/Lancer_Idle.png", "run": "Lancer/Lancer_Run.png",
		"weapon": "thrust", "weapon_name": "Lance Thrust", "damage": "thrust_damage",
		"cooldown": 1.1, "speed": 0.0, "reach": 340.0,
		"desc": "Lance Thrust: a long stab through a whole line.",
	},
	{
		"id": "archer", "name": "Archer", "colour": "Yellow",
		"idle": "Archer/Archer_Idle.png", "run": "Archer/Archer_Run.png",
		"weapon": "arrow", "weapon_name": "Piercing Arrow", "damage": "arrow_damage",
		"cooldown": 0.55, "speed": 720.0, "reach": 0.0,
		"desc": "Piercing Arrow: rapid shots that pass through enemies.",
	},
]

static func by_id(id: String) -> Dictionary:
	for character in ROSTER:
		if character["id"] == id:
			return character
	return ROSTER[0]

# [animation, sheet key, fps] - sheets are one row of square frames.
static func build_frames(character: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var dir: String = UNITS_DIR + character["colour"] + " Units/"
	for entry in [[&"idle", "idle", 8.0], [&"run", "run", 10.0]]:
		var sheet: Texture2D = load(dir + character[entry[1]])
		frames.add_animation(entry[0])
		frames.set_animation_speed(entry[0], entry[2])
		frames.set_animation_loop(entry[0], true)
		var frame_size: int = sheet.get_height()
		for i in sheet.get_width() / frame_size:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
			frames.add_frame(entry[0], atlas)
	return frames
