@tool
extends StaticBody2D
# Prop: a building, tree, rock or other piece of scenery. Pick `kind` in
# the inspector — texture, animation, anchoring and collision all come
# from the KINDS table, so placing one is just "add node, choose kind,
# move it". The node's position is where the prop touches the ground.
# @tool = this script also runs in the editor, so props preview there.

const ART := "res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/"
const EXTRA := "res://scenes/assets/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/Extra/"

# Map palette, set by world.gd before any prop builds. Static so every prop
# shares it. Defaults = the first map (and what the editor previews).
static var building_colour: String = "Blue"
static var foliage: Color = Color.WHITE

# kind: [texture, frames in the sheet, base row (y pixel where it meets the
#        ground), footprint size (solid area at the base; ZERO = walk-through)]
const KINDS: Dictionary = {
	"castle": ["Buildings/Blue Buildings/Castle.png", 1, 249, Vector2(270, 90)],
	"house1": ["Buildings/Blue Buildings/House1.png", 1, 173, Vector2(96, 50)],
	"house2": ["Buildings/Blue Buildings/House2.png", 1, 178, Vector2(104, 50)],
	"house3": ["Buildings/Blue Buildings/House3.png", 1, 172, Vector2(100, 50)],
	"tower": ["Buildings/Blue Buildings/Tower.png", 1, 230, Vector2(84, 50)],
	"barracks": ["Buildings/Blue Buildings/Barracks.png", 1, 245, Vector2(160, 70)],
	"archery": ["Buildings/Blue Buildings/Archery.png", 1, 240, Vector2(160, 70)],
	"monastery": ["Buildings/Blue Buildings/Monastery.png", 1, 310, Vector2(130, 80)],
	"tree1": ["Terrain/Resources/Wood/Trees/Tree1.png", 8, 241, Vector2(36, 22)],
	"tree2": ["Terrain/Resources/Wood/Trees/Tree2.png", 8, 249, Vector2(36, 22)],
	"tree3": ["Terrain/Resources/Wood/Trees/Tree3.png", 8, 170, Vector2(30, 18)],
	"tree4": ["Terrain/Resources/Wood/Trees/Tree4.png", 8, 168, Vector2(30, 18)],
	"stump": ["Terrain/Resources/Wood/Trees/Stump 1.png", 1, 240, Vector2(36, 20)],
	"rock1": ["Terrain/Decorations/Rocks/Rock1.png", 1, 51, Vector2(28, 16)],
	"rock2": ["Terrain/Decorations/Rocks/Rock2.png", 1, 52, Vector2(30, 16)],
	"rock3": ["Terrain/Decorations/Rocks/Rock3.png", 1, 52, Vector2(34, 18)],
	"rock4": ["Terrain/Decorations/Rocks/Rock4.png", 1, 52, Vector2(30, 16)],
	"gold_stone": ["Terrain/Resources/Gold/Gold Stones/Gold Stone 4.png", 1, 86, Vector2(50, 26)],
	"gold_stone2": ["Terrain/Resources/Gold/Gold Stones/Gold Stone 2.png", 1, 86, Vector2(46, 24)],
	"bush1": ["Terrain/Decorations/Bushes/Bushe1.png", 8, 79, Vector2.ZERO],
	"bush2": ["Terrain/Decorations/Bushes/Bushe2.png", 8, 79, Vector2.ZERO],
	"bush3": ["Terrain/Decorations/Bushes/Bushe3.png", 8, 79, Vector2.ZERO],
	"sheep": ["Terrain/Resources/Meat/Sheep/Sheep_Idle.png", 6, 84, Vector2.ZERO],
	"sheep_grazing": ["Terrain/Resources/Meat/Sheep/Sheep_Grass.png", 12, 84, Vector2.ZERO],
	"dead_tree": [EXTRA + "Dead Tree/Dead Tree.png", 1, 290, Vector2(130, 60)],
	"goblin_hut": [EXTRA + "Goblin Hut/Goblin Hut.png", 12, 241, Vector2(130, 60)],
	"fish_hut": [EXTRA + "Fish Hut/Fish Hut.png", 8, 179, Vector2(110, 50)],
	"pirate_tower": [EXTRA + "Pirate Tower/Pirate Tower_Ground.png", 1, 179, Vector2(84, 46)],
	"gnome_hut": [EXTRA + "Gnome Buildings/Gnome Hut.png", 1, 148, Vector2(80, 40)],
	"gnome_tower": [EXTRA + "Gnome Buildings/Gnome Tower.png", 1, 230, Vector2(90, 46)],
	"skull_spike1": [EXTRA + "Skull decorations/Skull Spike_01.png", 1, 95, Vector2(22, 14)],
	"skull_spike2": [EXTRA + "Skull decorations/Skull Spike_02.png", 1, 107, Vector2(24, 14)],
	"bones1": [EXTRA + "Skull decorations/Bones_01.png", 1, 49, Vector2.ZERO],
	"bones2": [EXTRA + "Skull decorations/Bones_02.png", 1, 46, Vector2.ZERO],
}

@export_enum("castle", "house1", "house2", "house3", "tower", "barracks", "archery",
	"monastery", "tree1", "tree2", "tree3", "tree4", "stump", "rock1", "rock2", "rock3",
	"rock4", "gold_stone", "gold_stone2", "bush1", "bush2", "bush3", "sheep",
	"sheep_grazing", "dead_tree", "goblin_hut", "fish_hut", "pirate_tower", "gnome_hut",
	"gnome_tower", "skull_spike1", "skull_spike2", "bones1", "bones2") var kind: String = "house1":
	set(value):
		kind = value
		if is_node_ready():
			build()

@export var flip: bool = false:
	set(value):
		flip = value
		if is_node_ready():
			build()

func _ready() -> void:
	build()

func build() -> void:
	# Throw away whatever we built last time (matters in the editor, where
	# changing `kind` rebuilds). Built children have no owner, so they are
	# never saved into the scene file.
	for child in get_children():
		if child.owner == null:
			child.free()

	var data: Array = KINDS[kind]
	var path: String = data[0] if data[0].begins_with("res://") else ART + data[0]
	var sheet: Texture2D = load(path.replace("Blue Buildings", building_colour + " Buildings"))
	var frame_count: int = data[1]
	var frame_w: float = sheet.get_width() / float(frame_count)
	var frame_h: float = sheet.get_height()
	# Shift the art up so its base row sits on our origin — that's what
	# makes y-sorting (who's drawn in front) line up with the ground.
	var offset := Vector2(0, frame_h / 2.0 - data[2])
	var tint: Color = foliage if kind.begins_with("tree") or kind.begins_with("bush") else Color.WHITE

	if frame_count == 1:
		var sprite := Sprite2D.new()
		sprite.texture = sheet
		sprite.offset = offset
		sprite.flip_h = flip
		sprite.modulate = tint
		add_child(sprite)
	else:
		# Animated sheet (trees sway, bushes rustle, sheep idle).
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", 8.0)
		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			frames.add_frame(&"default", atlas)
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.offset = offset
		anim.flip_h = flip
		anim.modulate = tint
		add_child(anim)
		anim.play()
		# Random start frame so a grove doesn't sway in perfect lockstep.
		anim.frame = randi() % frame_count

	var footprint: Vector2 = data[3]
	if footprint == Vector2.ZERO:
		collision_layer = 0
		return
	# Layer 1 = everything already collides with it (player, enemies).
	# Layer 3 (value 4) = "obstacles only", used to keep spawns out of props.
	collision_layer = 1 | 4
	var shape := RectangleShape2D.new()
	shape.size = footprint
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, -footprint.y / 2.0)  # Sits on top of the base line
	add_child(collider)
