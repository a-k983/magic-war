extends Area2D
# Pickup: rare drop from dead enemies. Walk over it to trigger its effect.
#   health - red potion, heals the player
#   magnet - pulls every XP orb and coin on the map to the player
#   nuke   - skull, kills every enemy on screen

# kind -> [texture, on-screen height in pixels]
const ICONS: Dictionary = {
	"health": [preload("res://scenes/pickups/health_potion.svg"), 56.0],
	"magnet": [preload("res://scenes/pickups/magnet.svg"), 56.0],
	# 16x16 pixel art: 64 = exactly 4x, so every pixel stays the same size.
	"nuke": [preload("res://scenes/assets/Items Pack/items/skull.png"), 64.0],
}

const SOUNDS: Dictionary = {"health": "heal", "magnet": "magnet", "nuke": "nuke"}

@export var kind: String = "health"
@export var heal_amount: int = 3

func _ready() -> void:
	var icon: Array = ICONS[kind]
	$Sprite2D.texture = icon[0]
	$Sprite2D.scale = Vector2.ONE * (icon[1] / icon[0].get_height())
	if kind == "nuke":
		# Nearest-neighbour keeps the scaled-up pixel art crisp, not blurry.
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Enemies also touch us — only the player may collect.
	if not body.is_in_group("player"):
		return
	Audio.play(SOUNDS[kind], -2.0, 0.0)
	match kind:
		"health":
			body.heal(heal_amount)
		"magnet":
			for orb in get_tree().get_nodes_in_group("xp_orbs") + get_tree().get_nodes_in_group("coins"):
				orb.attracted = true
		"nuke":
			nuke()
	queue_free()

func nuke() -> void:
	# The visible part of the world: the viewport rect moved into world space.
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if view.has_point(enemy.global_position):
			# false = no pickup roll, or one nuke would shower the map in drops.
			enemy.die(false)
