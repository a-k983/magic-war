extends CanvasLayer
# Level-Up Menu: pauses the game, offers 3 random upgrades.
# Spell unlocks are marked "once" and leave the pool after being taken.

var upgrade_pool: Array = [
	{"name": "Sharper Flames", "desc": "Fireball damage +1", "id": "damage"},
	{"name": "Rapid Fire", "desc": "Fire 25% faster", "id": "fire_rate"},
	{"name": "Swift Boots", "desc": "Move speed +15%", "id": "move_speed"},
	{"name": "Blazing Bolts", "desc": "Fireballs fly 30% faster", "id": "projectile_speed"},
	{"name": "Lightning Arc", "desc": "NEW SPELL: zaps random enemies", "id": "unlock_lightning", "once": true},
	{"name": "Frost Nova", "desc": "NEW SPELL: icy blast that slows", "id": "unlock_frost", "once": true},
	{"name": "Arcane Orbit", "desc": "NEW SPELL: orbs circle you", "id": "unlock_orbit", "once": true},
]

var current_choices: Array = []
# What was picked this round, for the game-over recap.
var spells_taken: Array[String] = []        # Spell names, in unlock order
var upgrades_taken: Dictionary = {}         # Upgrade name -> times picked
var buttons: Array = []
var player: Node = null

func _ready() -> void:
	visible = false
	player = get_tree().get_first_node_in_group("player")
	buttons = [%Option1, %Option2, %Option3]
	for i in 3:
		buttons[i].pressed.connect(_on_option_pressed.bind(i))

func open() -> void:
	current_choices = upgrade_pool.duplicate()
	current_choices.shuffle()
	current_choices = current_choices.slice(0, 3)

	for i in 3:
		buttons[i].text = current_choices[i]["name"] + "\n" + current_choices[i]["desc"]

	visible = true
	get_tree().paused = true
	Audio.play("level_up", -3.0, 0.0)

func _on_option_pressed(index: int) -> void:
	var choice: Dictionary = current_choices[index]
	player.apply_upgrade(choice["id"])

	# One-time upgrades (spell unlocks) leave the pool forever.
	if choice.get("once", false):
		upgrade_pool.erase(choice)
		spells_taken.append(choice["name"])
	else:
		upgrades_taken[choice["name"]] = upgrades_taken.get(choice["name"], 0) + 1

	visible = false
	get_tree().paused = false
