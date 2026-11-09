extends Control
# Map Preview: the little living diorama inside each map select box. The
# map's own ground colour, a few of its buildings and trees (in its building
# colour and foliage tint), two of its monsters wandering across, and a soft
# effect for its mood: fireflies, embers, ripples or hex wisps. Kept slow and
# small so it sets the scene without pulling focus.

const PROP = preload("res://scenes/world/prop.gd")
const TILE: Texture2D = preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color5_single_grazz_tile.png")
const SIZE := Vector2(226, 124)

# Per map (same order as Levels.MAPS):
#   props   - [kind, x, y, scale] (x, y = where it meets the ground)
#   walkers - [index into the map's enemies, y, speed, scale, flies?]
#   fx      - "fireflies", "embers", "ripples" or "wisps"
const SCENES: Array[Dictionary] = [
	{
		"props": [["house1", 52, 64, 0.38], ["tree1", 178, 56, 0.36], ["tree2", 206, 82, 0.32],
			["sheep_grazing", 118, 70, 0.42], ["bush1", 24, 112, 0.34], ["rock1", 150, 112, 0.5]],
		"walkers": [[0, 104, 16.0, 0.42, false], [1, 90, -22.0, 0.4, false]],
		"fx": "fireflies",
	},
	{
		"props": [["goblin_hut", 58, 70, 0.3], ["dead_tree", 186, 76, 0.28], ["rock2", 128, 60, 0.55],
			["bones1", 104, 112, 0.6], ["gold_stone2", 210, 116, 0.42]],
		"walkers": [[0, 102, 18.0, 0.42, false], [1, 86, -15.0, 0.34, false]],
		"fx": "embers",
	},
	{
		"props": [["fish_hut", 58, 68, 0.34], ["pirate_tower", 190, 70, 0.34], ["bush2", 126, 60, 0.34],
			["rock4", 22, 112, 0.5]],
		"walkers": [[1, 104, 14.0, 0.42, false], [0, 88, -20.0, 0.4, false]],
		"fx": "ripples",
	},
	{
		"props": [["gnome_tower", 52, 68, 0.3], ["skull_spike2", 150, 66, 0.5], ["tree3", 196, 72, 0.34],
			["skull_spike1", 108, 112, 0.5], ["bones2", 214, 116, 0.6]],
		"walkers": [[2, 104, 15.0, 0.42, false], [0, 40, -26.0, 0.36, true]],
		"fx": "wisps",
	},
]

var index: int = 0           # Which map; set before add_child
var time: float = 0.0
var walkers: Array = []      # [sprite, speed, base y, flies?]
var motes: Array = []        # [position, velocity, phase, size]
var stage: Node2D
var fx: Control

func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map: Dictionary = Levels.MAPS[index]
	var scene: Dictionary = SCENES[index]

	var ground := TextureRect.new()
	ground.texture = TILE
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.size = SIZE
	ground.modulate = map["ground"]
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	# Props and monsters share one y-sorted layer, so whoever stands lower
	# on the box draws in front.
	stage = Node2D.new()
	stage.y_sort_enabled = true
	add_child(stage)
	for entry in scene["props"]:
		stage.add_child(make_prop(entry[0], map, Vector2(entry[1], entry[2]), entry[3]))
	for entry in scene["walkers"]:
		var walker := AnimatedSprite2D.new()
		walker.sprite_frames = run_frames(map["enemies"][entry[0]])
		var frame_size: float = walker.sprite_frames.get_frame_texture(&"default", 0).get_height()
		walker.scale = Vector2.ONE * entry[3] * minf(192.0 / frame_size, 1.0)
		walker.offset = Vector2(0, -frame_size * 0.2)
		walker.flip_h = entry[2] < 0.0
		walker.position = Vector2(randf() * SIZE.x, entry[1])
		walker.play()
		stage.add_child(walker)
		walkers.append([walker, entry[2], float(entry[1]), entry[4]])

	fx = Control.new()
	fx.size = SIZE
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	add_child(fx)
	for i in 14:
		motes.append(new_mote(true))

# A prop's art without its physics body: same sheet, colour and anchoring
# as prop.gd uses in the game.
func make_prop(kind: String, map: Dictionary, spot: Vector2, prop_scale: float) -> Node2D:
	var data: Array = PROP.KINDS[kind]
	var path: String = data[0] if data[0].begins_with("res://") else PROP.ART + data[0]
	var sheet: Texture2D = load(path.replace("Blue Buildings", map["buildings"] + " Buildings"))
	var frame_count: int = data[1]
	var frame_w: float = sheet.get_width() / float(frame_count)
	var offset := Vector2(0, sheet.get_height() / 2.0 - data[2])
	var tint: Color = map["foliage"] if kind.begins_with("tree") or kind.begins_with("bush") else Color.WHITE
	var node: Node2D
	if frame_count == 1:
		var sprite := Sprite2D.new()
		sprite.texture = sheet
		sprite.offset = offset
		node = sprite
	else:
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", 6.0)
		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_w, 0, frame_w, sheet.get_height())
			frames.add_frame(&"default", atlas)
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.offset = offset
		anim.play()
		anim.frame = randi() % frame_count
		node = anim
	node.position = spot
	node.scale = Vector2.ONE * prop_scale
	node.modulate = tint
	return node

func run_frames(type: Dictionary) -> SpriteFrames:
	var sheet: Texture2D = load(Levels.ENEMY_PACK_DIR + type["name"] + "/" + type["name"] + "_" + type["run"] + ".png")
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 8.0)
	var side: float = sheet.get_height()
	for i in floori(sheet.get_width() / side):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * side, 0, side, side)
		frames.add_frame(&"default", atlas)
	return frames

func _process(delta: float) -> void:
	time += delta
	for entry in walkers:
		var walker: AnimatedSprite2D = entry[0]
		walker.position.x += entry[1] * delta
		if entry[3]:
			walker.position.y = entry[2] + sin(time * 2.5) * 6.0  # Fliers bob
		# Off one side: come back in from the other.
		if walker.position.x > SIZE.x + 30.0:
			walker.position.x = -30.0
		elif walker.position.x < -30.0:
			walker.position.x = SIZE.x + 30.0
	for mote in motes:
		mote[0] += mote[1] * delta
		if mote[0].y < -8.0 or mote[0].y > SIZE.y + 8.0 or mote[0].x < -8.0 or mote[0].x > SIZE.x + 8.0:
			mote.assign(new_mote(false))
	fx.queue_redraw()

func new_mote(anywhere: bool) -> Array:
	var spot := Vector2(randf() * SIZE.x, randf() * SIZE.y)
	match SCENES[index]["fx"]:
		"fireflies":
			return [spot, Vector2(randf_range(-6, 6), randf_range(-6, 6)), randf() * TAU, randf_range(1.2, 2.2)]
		"embers":
			if not anywhere:
				spot.y = SIZE.y + 4.0
			return [spot, Vector2(randf_range(-5, 5), randf_range(-26, -14)), randf() * TAU, randf_range(1.0, 2.0)]
		"ripples":
			return [spot, Vector2.ZERO, randf() * TAU, randf_range(6.0, 12.0)]
		_:  # wisps
			if not anywhere:
				spot.y = SIZE.y + 4.0
			return [spot, Vector2(randf_range(-4, 4), randf_range(-12, -6)), randf() * TAU, randf_range(1.5, 3.0)]

func _draw_fx() -> void:
	match SCENES[index]["fx"]:
		"fireflies":
			for mote in motes:
				var glow: float = 0.5 + 0.5 * sin(time * 3.0 + mote[2])
				fx.draw_circle(mote[0], mote[3] * 2.4, Color(1.0, 0.95, 0.4, 0.12 * glow))
				fx.draw_circle(mote[0], mote[3], Color(1.0, 0.98, 0.6, 0.35 + 0.55 * glow))
		"embers":
			for mote in motes:
				var flicker: float = 0.5 + 0.5 * sin(time * 9.0 + mote[2])
				fx.draw_circle(mote[0], mote[3], Color(1.0, 0.55 + 0.3 * flicker, 0.15, 0.5 + 0.4 * flicker))
			# Heat haze along the bottom.
			fx.draw_rect(Rect2(0, SIZE.y - 14.0, SIZE.x, 14.0), Color(1.0, 0.45, 0.1, 0.08 + 0.04 * sin(time * 2.0)))
		"ripples":
			for mote in motes:
				# Each ripple grows and fades on its own loop.
				var t: float = fmod(time * 0.35 + mote[2] / TAU, 1.0)
				var r: float = mote[3] * (0.3 + t * 1.4)
				var colour := Color(0.85, 1.0, 1.0, 0.45 * (1.0 - t))
				fx.draw_set_transform(mote[0], 0.0, Vector2(1.0, 0.45))
				fx.draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, colour, 1.2, true)
				fx.draw_set_transform(Vector2.ZERO)
		_:
			for mote in motes:
				var pulse: float = 0.5 + 0.5 * sin(time * 2.0 + mote[2])
				fx.draw_circle(mote[0], mote[3] * 2.6, Color(0.75, 0.35, 1.0, 0.08 * pulse))
				fx.draw_circle(mote[0], mote[3], Color(0.9, 0.6, 1.0, 0.3 + 0.5 * pulse))
			# A slow purple pulse over the whole box: the cursed ground breathing.
			fx.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.5, 0.1, 0.7, 0.05 + 0.04 * sin(time * 1.2)))
