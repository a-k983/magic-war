extends RefCounted
# Spell FX toolbox: shared building blocks for spell visuals. Everything is
# generated in code, so there are no extra image files to manage.
# Use it with:  const FX = preload("res://scenes/spells/spell_fx.gd")

static var _glow: GradientTexture2D = null
static var _additive: CanvasItemMaterial = null
static var _fade: Gradient = null

# A soft white blob: solid in the middle, fading to nothing at the edge.
# Tint it with modulate/color to get a glow of any colour.
static func glow_texture() -> Texture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.4, Color(1, 1, 1, 0.45))
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.width = 64
		_glow.height = 64
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
	return _glow

# Additive blending: colours ADD to what's behind them, so overlapping
# glows get brighter — the classic "light" look.
static func additive_material() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive

# Particle colour-over-lifetime: fully visible, then fade out.
static func fade_ramp() -> Gradient:
	if _fade == null:
		_fade = Gradient.new()
		_fade.set_color(0, Color(1, 1, 1, 1))
		_fade.set_color(1, Color(1, 1, 1, 0))
	return _fade

# A glowing halo of the given colour, `diameter` pixels across.
static func glow_sprite(color: Color, diameter: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = glow_texture()
	sprite.material = additive_material()
	sprite.modulate = color
	sprite.scale = Vector2.ONE * (diameter / 64.0)
	return sprite

# Continuous trail of glowing dots left behind a moving node. Add it as a
# child of the thing that moves.
static func trail(color: Color, amount: int, lifetime: float, size: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = glow_texture()
	p.material = additive_material()
	p.local_coords = false          # Dots stay where they were dropped
	p.amount = amount
	p.lifetime = lifetime
	p.gravity = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 25.0
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	p.color_ramp = fade_ramp()
	return p

# One-shot spray of glowing sparks at a world position. Deletes itself.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12,
		speed: float = 160.0, lifetime: float = 0.4, size: float = 0.25) -> void:
	var p := CPUParticles2D.new()
	p.texture = glow_texture()
	p.material = additive_material()
	p.one_shot = true
	p.explosiveness = 1.0           # All sparks at once, not a stream
	p.amount = amount
	p.lifetime = lifetime
	p.gravity = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	p.color_ramp = fade_ramp()
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

# Plays a one-row sprite sheet of square frames once at a world position,
# then deletes itself.
static func play_sheet(parent: Node, pos: Vector2, sheet: Texture2D,
		fps: float = 16.0, size: float = 1.0) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", false)
	var frame_size: int = sheet.get_height()
	for i in sheet.get_width() / frame_size:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame(&"default", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * size
	parent.add_child(sprite)
	sprite.global_position = pos
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(&"default")
