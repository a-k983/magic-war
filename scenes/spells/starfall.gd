extends Node2D
# Starfall: calls falling stars down on random enemies in range. Each star
# marks the ground, then blasts everything nearby. Levels add damage, blast
# size and, at levels 3 and 5, an extra star per volley.

const STRIKE = preload("res://scenes/spells/starfall_strike.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

@export var cooldown: float = 3.0
@export var strike_range: float = 650.0

var level: int = 1
var timer: float = 1.0

func set_level(new_level: int) -> void:
	level = new_level

func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = cooldown
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < strike_range:
			candidates.append(enemy)
	candidates.shuffle()
	for enemy in candidates.slice(0, 1 + (level - 1) / 2):
		var strike: Node2D = STRIKE.new()
		strike.damage = BALANCE.starfall_damage + BALANCE.starfall_damage_per_level * (level - 1)
		strike.radius = 95.0 + 15.0 * (level - 1)
		strike.global_position = enemy.global_position
		get_tree().current_scene.add_child(strike)
