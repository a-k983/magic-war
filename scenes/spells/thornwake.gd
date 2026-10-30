extends Node2D
# Thornwake: brambles sprout along the player's path. Enemies crossing them
# are cut and slowed, so where you run matters. Levels make the patches
# bigger, longer-lasting and sharper.

const BRAMBLE = preload("res://scenes/spells/bramble.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

const STEP: float = 90.0  # Pixels walked between patches

var level: int = 1
var last_drop: Vector2 = Vector2.INF

func set_level(new_level: int) -> void:
	level = new_level

func _process(_delta: float) -> void:
	if last_drop != Vector2.INF and global_position.distance_to(last_drop) < STEP:
		return
	last_drop = global_position
	var patch: Node2D = BRAMBLE.new()
	patch.radius = 58.0 + 10.0 * (level - 1)
	patch.lifetime = 3.0 + 0.5 * (level - 1)
	patch.damage = BALANCE.thornwake_damage + BALANCE.thornwake_damage_per_level * (level - 1)
	patch.global_position = global_position
	get_tree().current_scene.add_child(patch)
