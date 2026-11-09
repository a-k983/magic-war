extends Control
# Loading Screen: the first scene on launch. A battle scene made from the
# game's own art (the heroes facing a monster horde under a twilight sky,
# a fireball flying between them), a big logo and a chunky progress bar,
# while the title screen loads in the background.
# Everything is built in code so it lays itself out for any screen shape.

const NEXT_SCENE := "res://scenes/ui/title_screen.tscn"
const MIN_TIME := 2.0  # Seconds the bar takes to fill at least, so the scene can be seen

const ART := "res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/"
const ENEMY_ART := "res://scenes/assets/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/"

# Who stands on the battlefield: [sheet, fps, x, back row?, scale, faces left?]
# x is a fraction of half the screen width from the centre (minus = left).
const CAST: Array = [
	[ART + "Units/Red Units/Lancer/Lancer_Idle.png", 8.0, -0.62, true, 1.0, false],
	[ART + "Units/Yellow Units/Archer/Archer_Shoot.png", 9.0, -0.80, false, 1.5, false],
	[ART + "Units/Purple Units/Monk/Heal.png", 10.0, -0.50, false, 1.5, false],
	[ART + "Units/Blue Units/Warrior/Warrior_Attack1.png", 9.0, -0.22, false, 1.5, false],
	[ENEMY_ART + "Troll/Troll_Idle.png", 7.0, 0.78, true, 1.05, true],
	[ENEMY_ART + "Minotaur/Minotaur_Idle.png", 8.0, 0.52, false, 1.2, true],
	[ENEMY_ART + "Skull/Skull_Idle.png", 8.0, 0.36, true, 1.3, true],
	[ENEMY_ART + "Torch Goblin/Torch Goblin_Idle.png", 9.0, 0.22, false, 1.5, true],
]

const TIPS: Array[String] = [
	"Tip: spend your gold in the Upgrades shop between runs.",
	"Tip: elites drop extra coins. Hunt them down!",
	"Tip: grab a Super Mode pickup to become invincible for a while.",
	"Tip: rocks won't stop you, but buildings and trees will.",
	"Tip: each hero fights differently. Try them all!",
	"Tip: watch an ad when you fall to fight on from where you died.",
]

const SKY_TOP := Color(0.10, 0.06, 0.24)
const SKY_MID := Color(0.36, 0.18, 0.46)
const SKY_LOW := Color(0.98, 0.56, 0.36)
const GOLD := Color(1.0, 0.8, 0.28)
const DEEP_PURPLE := Color(0.2, 0.07, 0.32)

var elapsed: float = 0.0
var shown: float = 0.0  # What the bar shows, 0..1 (eases toward the real progress)
var finished: bool = false
var tip_index: int = 0

var ui_scale: float = 1.0
var horizon: float = 0.0
var ground: float = 0.0
var logo_home: Vector2 = Vector2.ZERO
var bolt_from: Vector2 = Vector2.ZERO
var bolt_to: Vector2 = Vector2.ZERO
var bolt_time: float = 0.0

var stars: Array = []      # [position (0..1 of the sky), phase, size]
var sparkles: Array = []   # [position, speed, phase, colour, size]

var sky: TextureRect
var fx_back: Control
var fx_front: Control
var clouds: Array[TextureRect] = []
var castle: TextureRect
var towers: Array[TextureRect] = []
var grass: TextureRect
var shade: TextureRect
var actors: Array[AnimatedSprite2D] = []
var bolt_on: bool = false  # Fireball in flight (drawn on fx_front, like fireball.gd draws it)
var boom: AnimatedSprite2D
var logo: VBoxContainer
var bar_frame: PanelContainer
var bar: ProgressBar
var percent_label: Label
var loading_label: Label
var tip_label: Label
var curtain: ColorRect

func _ready() -> void:
	ResourceLoader.load_threaded_request(NEXT_SCENE)
	tip_index = randi() % TIPS.size()
	for i in 60:
		stars.append([Vector2(randf(), randf() * randf()), randf() * TAU, randf_range(1.0, 2.6)])
	for i in 36:
		sparkles.append(new_sparkle(true))
	build()
	resized.connect(lay_out)
	lay_out()

# --- Building ---------------------------------------------------------------

func build() -> void:
	sky = TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([SKY_TOP, SKY_MID, SKY_LOW])
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = gradient
	sky_texture.fill_from = Vector2(0, 0)
	sky_texture.fill_to = Vector2(0, 1)
	sky.texture = sky_texture
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(sky)

	fx_back = add_fx_layer(_draw_fx_back)

	for i in 4:
		var cloud := TextureRect.new()
		cloud.texture = load(ART + "Terrain/Decorations/Clouds/Clouds_0%d.png" % (i * 2 + 1))
		cloud.modulate = Color(1.0, 0.75, 0.85, 0.55)
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cloud)
		clouds.append(cloud)

	# Distant buildings on the horizon, darkened like silhouettes at dusk.
	castle = add_silhouette(load(ART + "Buildings/Purple Buildings/Castle.png"))
	for path in ["Buildings/Purple Buildings/Tower.png", "Buildings/Red Buildings/Tower.png"]:
		towers.append(add_silhouette(load(ART + path)))

	grass = TextureRect.new()
	grass.texture = load(ART + "Terrain/Tileset/Tilemap_color5_single_grazz_tile.png")
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.modulate = Color(0.42, 0.5, 0.42)
	add_child(grass)

	for entry in CAST:
		var actor := AnimatedSprite2D.new()
		actor.sprite_frames = strip_frames(load(entry[0]), entry[1])
		actor.flip_h = entry[5]
		if entry[3]:
			actor.modulate = Color(0.78, 0.74, 0.88)  # Back row: a little hazier
		add_child(actor)
		actor.play()
		actor.frame = randi() % actor.sprite_frames.get_frame_count(&"default")
		actors.append(actor)
	# Back row first so the front row draws over it.
	for i in actors.size():
		if CAST[i][3]:
			move_child(actors[i], grass.get_index() + 1)

	boom = AnimatedSprite2D.new()
	boom.sprite_frames = strip_frames(load(ART + "Particle FX/Explosion_01.png"), 16.0)
	boom.sprite_frames.set_animation_loop(&"default", false)
	boom.visible = false
	boom.animation_finished.connect(func() -> void: boom.visible = false)
	add_child(boom)

	# Darken the bottom so the bar and text stand out.
	shade = TextureRect.new()
	var shade_gradient := Gradient.new()
	shade_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.04, 0.02, 0.08, 0.75)])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = shade_gradient
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(0, 1)
	shade.texture = shade_texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	fx_front = add_fx_layer(_draw_fx_front)
	build_logo()
	build_bar()

	curtain = ColorRect.new()
	curtain.color = Color(0.03, 0.02, 0.06, 0.0)
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)

func build_logo() -> void:
	var font := FontVariation.new()
	font.base_font = get_theme_default_font()
	font.variation_embolden = 1.1
	logo = VBoxContainer.new()
	logo.add_theme_constant_override("separation", -46)
	logo.rotation_degrees = -3.0
	add_child(logo)
	logo.add_child(logo_word("MAGIC", font, 104, GOLD, DEEP_PURPLE))
	logo.add_child(logo_word("WAR", font, 150, Color(1.0, 0.45, 0.26), Color(0.3, 0.04, 0.1)))

func logo_word(text: String, font: Font, font_size: int, fill: Color, edge: Color) -> Label:
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = fill
	settings.outline_size = 30
	settings.outline_color = edge
	settings.shadow_size = 1
	settings.shadow_color = Color(0, 0, 0, 0.45)
	settings.shadow_offset = Vector2(0, 12)
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func build_bar() -> void:
	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 26)
	loading_label.add_theme_constant_override("outline_size", 10)
	add_child(loading_label)

	# Gold-rimmed frame with the bar sunk inside it.
	bar_frame = PanelContainer.new()
	var frame_style := rounded_box(Color(0.12, 0.06, 0.18), 20)
	frame_style.border_color = GOLD
	frame_style.set_border_width_all(4)
	frame_style.set_content_margin_all(6)
	frame_style.shadow_color = Color(0, 0, 0, 0.5)
	frame_style.shadow_size = 8
	frame_style.shadow_offset = Vector2(0, 4)
	bar_frame.add_theme_stylebox_override("panel", frame_style)
	add_child(bar_frame)

	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 26
	bar.add_theme_stylebox_override("background", rounded_box(Color(0.06, 0.03, 0.1), 14))
	var fill := rounded_box(Color(0.66, 0.3, 0.98), 14)
	fill.border_width_top = 6  # Light top edge + dark bottom edge = a glossy bevel
	fill.border_width_bottom = 4
	fill.border_color = Color(0.85, 0.62, 1.0)
	fill.border_blend = true
	bar.add_theme_stylebox_override("fill", fill)
	bar_frame.add_child(bar)

	percent_label = Label.new()
	percent_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent_label.add_theme_font_size_override("font_size", 20)
	percent_label.add_theme_constant_override("outline_size", 8)
	bar.add_child(percent_label)

	tip_label = Label.new()
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override("font_size", 19)
	tip_label.add_theme_constant_override("outline_size", 6)
	tip_label.add_theme_color_override("font_color", Color(0.92, 0.86, 1.0))
	tip_label.text = TIPS[tip_index]
	add_child(tip_label)

func rounded_box(colour: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box

func add_fx_layer(painter: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(painter)
	add_child(layer)
	return layer

func add_silhouette(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.modulate = Color(0.26, 0.17, 0.36)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

# A sheet of square frames in one row (how all Tiny Swords sheets come).
func strip_frames(sheet: Texture2D, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	var side: float = sheet.get_height()
	for i in floori(sheet.get_width() / side):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * side, 0, side, side)
		frames.add_frame(&"default", atlas)
	return frames

# --- Layout -----------------------------------------------------------------

func lay_out() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var portrait: bool = w < h
	# Portrait phones: size things off the width so the scene fills it.
	ui_scale = clampf(w / 760.0 if portrait else minf(w / 1152.0, h / 648.0), 0.5, 2.0)
	horizon = h * 0.6
	ground = h * 0.77

	sky.position = Vector2.ZERO
	sky.size = Vector2(w, horizon + 4.0)

	for i in clouds.size():
		clouds[i].scale = Vector2.ONE * ui_scale * 0.8
		clouds[i].position.y = h * (0.08 + 0.1 * (i % 2)) + i * 14.0
		if clouds[i].position.x == 0.0:
			clouds[i].position.x = w * (i / 4.0) - 120.0 * ui_scale  # Spread them out at the start

	var tall: float = 256.0 * ui_scale * 0.7
	castle.scale = Vector2.ONE * ui_scale * 0.7
	castle.position = Vector2(w * 0.08, horizon - tall + 18.0 * ui_scale)
	for i in towers.size():
		towers[i].scale = Vector2.ONE * ui_scale * 0.62
		towers[i].position = Vector2(w * (0.74 + 0.12 * i), horizon - 256.0 * ui_scale * 0.62 + 14.0 * ui_scale)

	grass.position = Vector2(0, horizon)
	grass.size = Vector2(w, h - horizon)
	shade.position = Vector2(0, h * 0.55)
	shade.size = Vector2(w, h * 0.45)

	var half: float = w * 0.5
	for i in actors.size():
		var entry: Array = CAST[i]
		var actor := actors[i]
		var frame_size: float = actor.sprite_frames.get_frame_texture(&"default", 0).get_height()
		var s: float = entry[4] * ui_scale * (0.85 if entry[3] else 1.0)
		actor.scale = Vector2(s, s)
		# Tiny Swords characters stand a bit below the middle of their frame.
		actor.offset = Vector2(0, -frame_size * 0.2)
		var feet: float = ground - (34.0 * ui_scale if entry[3] else 0.0)
		actor.position = Vector2(half + entry[2] * half, feet)

	# The fireball flies from the monk to the minotaur.
	bolt_from = actors[2].position + Vector2(40, -70) * ui_scale
	bolt_to = actors[5].position + Vector2(-20, -80) * ui_scale
	boom.scale = Vector2.ONE * ui_scale * 1.4

	logo.scale = Vector2.ONE * ui_scale
	logo.size = logo.get_combined_minimum_size()
	logo.pivot_offset = logo.size * 0.5
	logo_home = Vector2(half - logo.size.x * 0.5, h * 0.22 - logo.size.y * 0.5)
	logo.position = logo_home

	var bar_top: float = h * 0.86
	var bar_width: float = w * 0.84 if portrait else minf(w * 0.62, 620.0 * ui_scale)
	bar_frame.size = Vector2(bar_width, 0)
	bar_frame.position = Vector2(half - bar_width * 0.5, bar_top)
	loading_label.size = Vector2(w, 0)
	loading_label.position = Vector2(0, bar_top - 40.0)
	tip_label.size = Vector2(minf(w - 32.0, 760.0), 0)
	tip_label.position = Vector2(half - tip_label.size.x * 0.5, bar_top + 48.0)

# --- Animation --------------------------------------------------------------

func _process(delta: float) -> void:
	elapsed += delta
	animate_scene(delta)
	if finished:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE, progress)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Background load broke: fall back to a normal (blocking) scene change.
		finished = true
		get_tree().change_scene_to_file(NEXT_SCENE)
		return

	# The bar never runs ahead of the real load, nor of MIN_TIME.
	var target: float = minf(progress[0], elapsed / MIN_TIME)
	shown = move_toward(shown, target, delta * 1.5)
	bar.value = shown * 100.0
	percent_label.text = "%d%%" % roundi(shown * 100.0)
	loading_label.text = "Loading" + ".".repeat(int(elapsed * 3.0) % 4)

	if status == ResourceLoader.THREAD_LOAD_LOADED and shown >= 1.0:
		finished = true
		var next: PackedScene = ResourceLoader.load_threaded_get(NEXT_SCENE)
		var fade := create_tween()
		fade.tween_property(logo, "scale", logo.scale * 1.08, 0.15)
		fade.tween_property(curtain, "color:a", 1.0, 0.35)
		fade.tween_callback(get_tree().change_scene_to_packed.bind(next))

func animate_scene(delta: float) -> void:
	# Logo bobs gently.
	logo.position = logo_home + Vector2(0, sin(elapsed * 2.0) * 6.0 * ui_scale)

	for i in clouds.size():
		var cloud := clouds[i]
		cloud.position.x += (8.0 + i * 4.0) * delta * ui_scale
		var width: float = cloud.texture.get_width() * cloud.scale.x
		if cloud.position.x > size.x:
			cloud.position.x = -width

	# Fireball: fly for 0.9s, burst, rest, repeat.
	bolt_time += delta
	if bolt_time <= 0.9:
		bolt_on = true
	elif bolt_on:
		bolt_on = false
		boom.position = bolt_to
		boom.visible = true
		boom.frame = 0
		boom.play()
	if bolt_time > 1.8:
		bolt_time = 0.0

	# New tip every few seconds (only matters on slow devices).
	if int(elapsed / 3.5) != int((elapsed - delta) / 3.5):
		tip_index = (tip_index + 1) % TIPS.size()
		tip_label.text = TIPS[tip_index]

	for sparkle in sparkles:
		sparkle[0] += sparkle[1] * delta
		if sparkle[0].y < size.y * 0.15:
			sparkle.assign(new_sparkle(false))
	fx_back.queue_redraw()
	fx_front.queue_redraw()

func new_sparkle(anywhere: bool) -> Array:
	var colours := [GOLD, Color(0.8, 0.5, 1.0), Color(0.5, 0.85, 1.0)]
	var y: float = randf_range(size.y * 0.2, size.y) if anywhere else size.y + 10.0
	return [Vector2(randf() * maxf(size.x, 1.0), y), Vector2(randf_range(-12, 12), randf_range(-60, -25)),
		randf() * TAU, colours[randi() % colours.size()], randf_range(2.0, 5.0)]

# Where the fireball is at t (0..1 of its flight): a straight line plus a small arc.
func bolt_point(t: float) -> Vector2:
	return bolt_from.lerp(bolt_to, t) + Vector2(0, -sin(t * PI) * 40.0 * ui_scale)

func teardrop(radius: float, tail: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 13:
		points.append(Vector2.from_angle(deg_to_rad(-120.0 + i * 20.0)) * radius)
	points.append(Vector2(-tail, 0))
	return points

func _draw_fx_back() -> void:
	# Twinkling stars in the upper sky.
	for star in stars:
		var alpha: float = 0.35 + 0.35 * sin(elapsed * 2.5 + star[1])
		var spot := Vector2(star[0].x * size.x, star[0].y * horizon)
		fx_back.draw_circle(spot, star[2] * ui_scale, Color(1, 1, 1, alpha))

	# Slowly turning light rays behind the logo.
	var centre := logo_home + logo.size * ui_scale * 0.5
	var reach: float = size.length()
	for i in 12:
		var angle: float = elapsed * 0.12 + i * TAU / 12.0
		fx_back.draw_colored_polygon(PackedVector2Array([centre,
			centre + Vector2.from_angle(angle) * reach,
			centre + Vector2.from_angle(angle + 0.16) * reach]), Color(1.0, 0.9, 0.75, 0.05))
	for i in 5:
		fx_back.draw_circle(centre, (220.0 - i * 38.0) * ui_scale, Color(1.0, 0.75, 0.55, 0.05))

func _draw_fx_front() -> void:
	# Warm haze where the sky meets the grass, so the horizon isn't a hard line.
	for i in 6:
		var band: float = (6 - i) * 7.0 * ui_scale
		fx_front.draw_rect(Rect2(0, horizon - band * 0.3, size.x, band), Color(SKY_LOW, 0.07))

	# The fireball: a glowing trail, then the same three nested teardrops
	# fireball.gd draws, turned along its arc.
	if bolt_on:
		var t: float = bolt_time / 0.9
		for i in 8:
			fx_front.draw_circle(bolt_point(maxf(t - i * 0.03, 0.0)), (22.0 - i * 2.2) * ui_scale,
				Color(1.0, 0.55, 0.15, 0.25 - i * 0.028))
		var head: Vector2 = bolt_point(t)
		var heading: float = (head - bolt_point(maxf(t - 0.02, 0.0))).angle()
		var flicker: float = sin(elapsed * 40.0)
		fx_front.draw_set_transform(head, heading, Vector2.ONE * ui_scale * 1.3)
		fx_front.draw_colored_polygon(teardrop(16.0, 44.0 + flicker * 7.0), Color(0.92, 0.25, 0.05))
		fx_front.draw_colored_polygon(teardrop(11.5, 28.0 + flicker * 5.0), Color(1.0, 0.6, 0.1))
		fx_front.draw_colored_polygon(teardrop(6.5, 13.0 + flicker * 3.0), Color(1.0, 0.96, 0.65))
		fx_front.draw_set_transform(Vector2.ZERO)

	# Magic sparkles drifting up off the battlefield.
	for sparkle in sparkles:
		var spot: Vector2 = sparkle[0]
		var twinkle: float = 0.5 + 0.5 * sin(elapsed * 6.0 + sparkle[2])
		var colour: Color = sparkle[3]
		colour.a = 0.35 + 0.6 * twinkle
		var r: float = sparkle[4] * ui_scale * (0.7 + 0.5 * twinkle)
		fx_front.draw_colored_polygon(PackedVector2Array([spot + Vector2(0, -r * 2.2),
			spot + Vector2(r * 0.5, 0), spot + Vector2(0, r * 2.2), spot + Vector2(-r * 0.5, 0)]), colour)
		fx_front.draw_colored_polygon(PackedVector2Array([spot + Vector2(-r * 2.2, 0),
			spot + Vector2(0, r * 0.5), spot + Vector2(r * 2.2, 0), spot + Vector2(0, -r * 0.5)]), colour)
