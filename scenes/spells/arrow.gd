extends Area2D
# Piercing Arrow: the Archer's weapon. Flies straight and passes through
# enemies, hitting up to `pierce` of them before it breaks.

const FX = preload("res://scenes/spells/spell_fx.gd")

var texture: Texture2D
var direction: Vector2 = Vector2.RIGHT
var speed: float = 720.0
var damage: int = 1
var pierce: int = 3
var lifetime: float = 1.3

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	add_child(sprite)
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or pierce <= 0:
		return
	body.take_damage(damage)
	pierce -= 1
	Audio.play("orb_hit", -11.0, 0.15)
	FX.burst(get_parent(), body.global_position, Color(1.0, 0.9, 0.6), 5, 140.0, 0.2, 0.18)
	if pierce <= 0:
		queue_free()
