extends Node2D
# Moonreaver: throws crescent blades that fly out and come back to the
# player, cutting through enemies both ways. Levels add damage and, at
# levels 3 and 5, an extra blade per throw.

const BLADE = preload("res://scenes/spells/moonreaver_blade.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

@export var cooldown: float = 2.2

var level: int = 1
var timer: float = 0.5

func set_level(new_level: int) -> void:
	level = new_level

func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	var target: Node2D = get_parent().find_nearest_enemy()
	if target == null:
		return
	timer = cooldown
	var aim: float = global_position.angle_to_point(target.global_position)
	var blades: int = 1 + (level - 1) / 2
	for i in blades:
		var blade: Node2D = BLADE.new()
		blade.direction = Vector2.from_angle(aim + TAU / blades * i)
		blade.damage = BALANCE.moonreaver_damage + BALANCE.moonreaver_damage_per_level * (level - 1)
		blade.thrower = get_parent()
		blade.global_position = global_position
		get_tree().current_scene.add_child(blade)
	Audio.play("fireball_cast", -9.0, 0.15)
