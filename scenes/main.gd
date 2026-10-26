extends Node2D
# Main: spawns enemies (harder over time), runs the clock, spawns elites,
# triggers win/lose screens.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const BALANCE: Balance = preload("res://config/balance.tres")

const ENEMY_PACK_DIR: String = "res://scenes/assets/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/"
# Spawn order: one wave per entry, a new wave every `wave_interval`
# seconds. Small fry first, building up to the bear as the 9:00 finale.
# A 5-minute run reaches the first 4; the rest are there if the run is
# made longer (after the last entry, the last type keeps coming).
# [folder, run sheet suffix, attack sheet suffix]. Index 0 is the skeleton,
# which uses the frames already baked into enemy.tscn.
const ENEMY_TYPES: Array = [
	["Skull", "Run", "Attack"],             # 0:00
	["Gnome", "Run", "Attack"],             # 1:30
	["Spider", "Run", "Attack"],            # 3:00
	["Thief", "Run", "Attack"],             # 4:30
	["Lizard", "Run", "Attack"],            # 6:00
	["Torch Goblin", "Run", "Attack"],      # 7:30
	["Bear", "Run", "Attack"],              # 9:00
	["Giant Bat", "Move", "Attack"],
	["Bumblebee", "Move", "Attack"],
	["Snake", "Run", "Attack"],
	["Paddle Shark", "Run", "Attack"],
	["Spear Goblin", "Run", "Attack Fast"],
	["Panda", "Run", "Attack"],
]

# Endless mode: all 13 types (as indexes into ENEMY_TYPES), with the ones
# the normal run never reaches mixed in early. After the panda it starts
# over from the skeleton — stats keep scaling with every wave, so the
# second lap is much nastier than the first.
const ENDLESS_ORDER: Array[int] = [
	0,   # Skull
	7,   # Giant Bat
	1,   # Gnome
	9,   # Snake
	2,   # Spider
	8,   # Bumblebee
	3,   # Thief
	10,  # Paddle Shark
	4,   # Lizard
	11,  # Spear Goblin
	5,   # Torch Goblin
	6,   # Bear
	12,  # Panda
]

@export var spawn_distance: float = 800.0
@export var elite_interval: float = 60.0    # An elite every minute
@export var wave_interval: float = 90.0     # New enemy type every 1:30
# Each new wave is tougher than the last. Wave 0 = x1.0, wave 1 = x1.15 enemy
# HP and x1.25 damage to the player, wave 6 (the bear) = x1.9 HP and x2.5 damage.
@export var wave_health_bonus: float = 0.15
# Per-wave damage bonus is in res://config/balance.tres (wave_damage_bonus).
@export var endless_wave_interval: float = 60.0  # Endless: new type every minute

var endless: bool = false                   # Copied from GameData at start
var player: Node2D = null
var elapsed: float = 0.0
var next_elite_at: float = 60.0
var run_over: bool = false
var wave: int = 0                           # How many waves have started (0 = first)
var enemy_type: int = 0                     # Index into ENEMY_TYPES
var frames_cache: Dictionary = {}           # enemy_type -> SpriteFrames
var kills: int = 0                          # Enemies killed this run (HUD, top right)

func _ready() -> void:
	endless = GameData.endless
	player = get_tree().get_first_node_in_group("player")
	$Timer.timeout.connect(_on_spawn_timer_timeout)

	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_leveled_up)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)

	_on_xp_changed(player.xp, player.xp_to_next)
	_on_health_changed(player.max_health, player.max_health)

	Audio.play_music("battle")

	# Touch controls: the pause button opens the Settings menu (which pauses).
	$HUD/PauseButton.pressed.connect(WindowControls.open_settings)

	# Round gold counter.
	GameData.run_coins_changed.connect(_on_run_coins_changed)
	GameData.start_run()

	# Keep the camera inside the arena (plus a strip of the tree line).
	var camera: Camera2D = player.get_node("Camera2D")
	var edge: int = int($World.half_size + 250.0)
	camera.limit_left = -edge
	camera.limit_top = -edge
	camera.limit_right = edge
	camera.limit_bottom = edge

func _process(delta: float) -> void:
	if run_over:
		return
	elapsed += delta
	
	# Survived the full run: victory. (Endless has no finish line.)
	if not endless and elapsed >= BALANCE.win_time_minutes * 60.0:
		run_over = true
		GameData.save_game()
		Audio.stop_music()
		Audio.play("victory", 0.0, 0.0)
		$GameOverScreen.open("VICTORY!\nYou survived the Magic War.", run_stats())
		return
	
	# Clock display, mm:ss. The %02d pads with zeroes: 65s -> 01:05.
	var minutes: int = int(elapsed) / 60
	var seconds: int = int(elapsed) % 60
	$HUD/TimerLabel.text = "%02d:%02d" % [minutes, seconds]

	# Difficulty ramp: spawn faster as time passes. 1.0s at start,
	# floor of 0.25s (reached at ~2.5 min).
	$Timer.wait_time = clamp(1.0 - elapsed * 0.005, 0.25, 1.0)

	# New wave: everything that spawns from now on is the next type in
	# ENEMY_TYPES, with tougher stats.
	var current_wave: int = int(elapsed / (endless_wave_interval if endless else wave_interval))
	if current_wave != wave:
		wave = current_wave
		if endless:
			enemy_type = ENDLESS_ORDER[wave % ENDLESS_ORDER.size()]
		else:
			enemy_type = mini(wave, ENEMY_TYPES.size() - 1)
		# Every hit the player takes gets stronger with each new enemy type —
		# including from enemies already on the field.
		player.wave_damage_bonus = wave * BALANCE.wave_damage_bonus
	if endless:
		$HUD/TimerLabel.text += "  ·  Wave %d" % (wave + 1)

	# Elite alarm.
	if elapsed >= next_elite_at:
		next_elite_at += elite_interval
		spawn_elite()

func _notification(what: int) -> void:
	# Phone call, app switch, tab hidden: pause rather than die off-screen.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not run_over \
			and not get_tree().paused:
		WindowControls.open_settings()

func _on_xp_changed(current_xp: int, xp_needed: int) -> void:
	$HUD/XPBar.max_value = xp_needed
	$HUD/XPBar.value = current_xp

func _on_leveled_up(new_level: int) -> void:
	$HUD/LevelLabel.text = "Level %d" % new_level
	$LevelUpMenu.open()

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	$HUD/HPBar.max_value = max_hp
	$HUD/HPBar.value = current_hp

func _on_player_died() -> void:
	run_over = true
	var stats: Dictionary = run_stats()
	if endless:
		# Personal best for endless runs (saved with the rest of GameData).
		stats["best"] = GameData.endless_best
		stats["new_record"] = elapsed > GameData.endless_best
		if stats["new_record"]:
			GameData.endless_best = elapsed
			stats["best"] = elapsed
	GameData.save_game()  # ← new
	Audio.stop_music()
	Audio.play("defeat", 0.0, 0.0)
	var survived: String = format_time(elapsed)
	if endless:
		$GameOverScreen.open("YOU DIED\nEndless: survived %s" % survived, stats)
	else:
		$GameOverScreen.open("YOU DIED\nSurvived %s" % survived, stats)

static func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _on_run_coins_changed(amount: int) -> void:
	$HUD/GoldCounter/GoldLabel.text = str(amount)

func _on_enemy_killed() -> void:
	kills += 1
	$HUD/GoldCounter/KillLabel.text = str(kills)

func run_stats() -> Dictionary:
	# Everything the game-over recap shows.
	return {
		"level": player.level,
		"gold": GameData.run_coins,
		"spells": $LevelUpMenu.spells_taken,
		"upgrades": $LevelUpMenu.upgrades_taken,
		"endless": endless,
		"wave": wave + 1,
	}

func spawn_point() -> Vector2:
	# A spot `spawn_distance` from the player, inside the arena and not
	# inside a building/tree. Tries a few random angles before giving up.
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 4  # Obstacles only (see prop.gd)
	var pos: Vector2 = Vector2.ZERO
	for attempt in 8:
		var angle: float = randf() * TAU
		pos = $World.clamp_to_arena(player.global_position + Vector2.from_angle(angle) * spawn_distance, 80.0)
		query.position = pos
		if space.intersect_point(query, 1).is_empty():
			return pos
	return pos

func _on_spawn_timer_timeout() -> void:
	if run_over:
		return
	spawn_enemy()

func apply_wave_scaling(enemy: CharacterBody2D) -> void:
	# Call after the enemy's base stats are set, before add_child.
	# (Wave damage is applied on the player instead — see _process.)
	enemy.max_health = roundi(enemy.max_health * (1.0 + wave * wave_health_bonus))

func get_enemy_frames() -> SpriteFrames:
	# Skeleton: null tells the enemy to keep its scene's own frames.
	if enemy_type == 0:
		return null
	if not frames_cache.has(enemy_type):
		frames_cache[enemy_type] = build_enemy_frames(ENEMY_TYPES[enemy_type])
	return frames_cache[enemy_type]

func build_enemy_frames(type: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var base: String = ENEMY_PACK_DIR + type[0] + "/" + type[0] + "_"
	# [animation name, sheet suffix, fps] — same names/speeds as the skeleton.
	for entry in [[&"run", type[1], 10.0], [&"attack", type[2], 12.0]]:
		var sheet: Texture2D = load(base + entry[1] + ".png")
		frames.add_animation(entry[0])
		frames.set_animation_speed(entry[0], entry[2])
		frames.set_animation_loop(entry[0], true)
		# Sheets are one row of square frames, so height = frame size.
		var frame_size: int = sheet.get_height()
		for i in sheet.get_width() / frame_size:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
			frames.add_frame(entry[0], atlas)
	return frames

func spawn_enemy() -> void:
	if player == null:
		return
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.custom_frames = get_enemy_frames()
	enemy.global_position = spawn_point()

	# Enemies get +2 max HP per minute elapsed. Setting it BEFORE
	# add_child works because _ready (health = max_health) runs on add.
	enemy.max_health += int(elapsed / 60.0) * 2
	apply_wave_scaling(enemy)
	enemy.killed.connect(_on_enemy_killed)

	add_child(enemy)

func spawn_elite() -> void:
	if player == null:
		return
	# An elite is a regular enemy with cranked stats — no new scene needed.
	var elite: CharacterBody2D = ENEMY_SCENE.instantiate()
	elite.custom_frames = get_enemy_frames()
	elite.global_position = spawn_point()
	elite.coin_drop = BALANCE.coins_per_elite
	# Base elite stats come from res://config/balance.tres.
	elite.max_health = BALANCE.elite_health + int(elapsed / 60.0) * 20
	elite.move_speed = BALANCE.elite_speed   # Slower, scarier
	elite.contact_damage = BALANCE.elite_damage
	elite.xp_drop = 10              # Kill reward: a shower of orbs
	elite.scale = Vector2(2.5, 2.5) # Physically huge
	apply_wave_scaling(elite)
	elite.killed.connect(_on_enemy_killed)

	add_child(elite)
