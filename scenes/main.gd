extends Node2D
# Main: spawns enemies (harder over time), runs the clock, spawns elites,
# triggers win/lose screens.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const BALANCE: Balance = preload("res://config/balance.tres")

@export var spawn_distance: float = 800.0
@export var elite_interval: float = 60.0    # An elite every minute
# A normal run spreads its map's enemy types evenly across the win time.
# Each new wave is tougher than the last. Wave 0 = x1.0, wave 1 = x1.15 enemy
# HP and x1.25 damage to the player.
@export var wave_health_bonus: float = 0.15
# Per-wave damage bonus is in res://config/balance.tres (wave_damage_bonus).
@export var endless_wave_interval: float = 60.0  # Endless: new type every minute

var endless: bool = false                   # Copied from GameData at start
var player: Node2D = null
var elapsed: float = 0.0
var next_elite_at: float = 60.0
var run_over: bool = false
var wave: int = 0                           # How many waves have started (0 = first)
var map: Dictionary = Levels.MAPS[GameData.level_index]
var enemy_order: Array[Dictionary] = []     # Enemy types in wave order (see config/levels.gd)
var enemy_type: Dictionary = {}             # The type spawning now
var wave_interval: float = 60.0             # Seconds per enemy type, set in _ready
var frames_cache: Dictionary = {}           # Enemy type name -> SpriteFrames
var kills: int = 0                          # Enemies killed this run (HUD, top right)

func _ready() -> void:
	endless = GameData.endless
	enemy_order.assign(Levels.endless_enemies() if endless else map["enemies"])
	enemy_type = enemy_order[0]
	wave_interval = endless_wave_interval if endless \
		else BALANCE.win_time_minutes * 60.0 / enemy_order.size()
	$Ground.modulate = map["ground"]
	WindowControls.layout_changed.connect(fit_hud)
	fit_hud()
	show_map_banner()
	player = get_tree().get_first_node_in_group("player")
	$Timer.timeout.connect(_on_spawn_timer_timeout)

	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_leveled_up)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)

	update_damage_bonus()
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
		win_level()
		return
	
	# Clock display, mm:ss. The %02d pads with zeroes: 65s -> 01:05.
	var minutes: int = int(elapsed) / 60
	var seconds: int = int(elapsed) % 60
	$HUD/TimerLabel.text = "%02d:%02d" % [minutes, seconds]

	# Difficulty ramp: spawn faster as time passes. 1.0s at start, floor of
	# 0.25s (reached at ~2.5 min). Harder maps and a stronger player both
	# shorten it further.
	$Timer.wait_time = clamp(1.0 - elapsed * 0.005, 0.25, 1.0) \
		/ (map["spawn"] * (1.0 + levels_gained() * BALANCE.spawn_rate_per_player_level))

	# New wave: everything that spawns from now on is the next type in
	# order, with tougher stats.
	var current_wave: int = int(elapsed / wave_interval)
	if current_wave != wave:
		wave = current_wave
		if endless:
			enemy_type = enemy_order[wave % enemy_order.size()]
		else:
			enemy_type = enemy_order[mini(wave, enemy_order.size() - 1)]
		update_damage_bonus()
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
	update_damage_bonus()
	$LevelUpMenu.open()

func levels_gained() -> int:
	return player.level - 1

func update_damage_bonus() -> void:
	# Every hit the player takes gets stronger with each new enemy type, on
	# harder maps, and as the player levels up — including hits from enemies
	# already on the field.
	player.wave_damage_bonus = wave * BALANCE.wave_damage_bonus + map["damage"] \
		+ levels_gained() * BALANCE.damage_per_player_level

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	$HUD/HPBar.max_value = max_hp
	$HUD/HPBar.value = current_hp

func win_level() -> void:
	run_over = true
	var index: int = GameData.level_index
	GameData.complete_level(index)
	GameData.save_game()
	Audio.stop_music()
	Audio.play("victory", 0.0, 0.0)
	var stats: Dictionary = run_stats()
	if index + 1 < Levels.MAPS.size():
		stats["next_level"] = index + 1
		$GameOverScreen.open("VICTORY!\n%s is yours. %s awaits." % [map["name"],
			Levels.MAPS[index + 1]["name"]], stats)
	else:
		$GameOverScreen.open("VICTORY!\nYou ended the Magic War.", stats)

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
		"weapon": player.character["weapon_name"],
		"spells": $LevelUpMenu.weapon_recap(),
		"upgrades": $LevelUpMenu.upgrades_taken,
		"endless": endless,
		"wave": wave + 1,
	}

func spawn_point() -> Vector2:
	return open_spot_near(player.global_position, spawn_distance)

func open_spot_near(center: Vector2, distance: float) -> Vector2:
	# A spot `distance` from `center`, inside the arena and not inside a
	# building/tree. Tries a few random angles before giving up.
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 4  # Obstacles only (see prop.gd)
	var pos: Vector2 = Vector2.ZERO
	for attempt in 8:
		var angle: float = randf() * TAU
		pos = $World.clamp_to_arena(center + Vector2.from_angle(angle) * distance, 80.0)
		query.position = pos
		if space.intersect_point(query, 1).is_empty():
			return pos
	return pos

func _on_spawn_timer_timeout() -> void:
	if run_over or get_tree().get_node_count_in_group("enemies") >= BALANCE.max_enemies:
		return
	spawn_enemy()

func apply_scaling(enemy: CharacterBody2D) -> void:
	# Call after the enemy's base stats are set, before add_child. Tougher
	# with each wave, each map and each level the player has gained.
	# (Damage scales on the player instead — see update_damage_bonus.)
	enemy.max_health = roundi(enemy.max_health * enemy_type["health"] * map["health"]
		* (1.0 + wave * wave_health_bonus)
		* (1.0 + levels_gained() * BALANCE.health_per_player_level))

func get_enemy_frames() -> SpriteFrames:
	var type_name: String = enemy_type["name"]
	if not frames_cache.has(type_name):
		frames_cache[type_name] = build_enemy_frames(enemy_type)
	return frames_cache[type_name]

func build_enemy_frames(type: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var base: String = Levels.ENEMY_PACK_DIR + type["name"] + "/" + type["name"] + "_"
	# [animation name, sheet suffix, fps] — same names/speeds for every enemy.
	for entry in [[&"run", type["run"], 10.0], [&"attack", type["attack"], 12.0]]:
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

func make_enemy() -> CharacterBody2D:
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.custom_frames = get_enemy_frames()
	enemy.ai = enemy_type["ai"]
	enemy.global_position = spawn_point()
	enemy.killed.connect(_on_enemy_killed)
	return enemy

func spawn_enemy() -> void:
	if player == null:
		return
	var enemy: CharacterBody2D = make_enemy()
	enemy.move_speed *= enemy_type["speed"]

	# Enemies get +2 max HP per minute elapsed. Setting it BEFORE
	# add_child works because _ready (health = max_health) runs on add.
	enemy.max_health += int(elapsed / 60.0) * 2
	apply_scaling(enemy)

	add_child(enemy)

func spawn_elite() -> void:
	if player == null:
		return
	# An elite is a regular enemy with cranked stats — no new scene needed.
	var elite: CharacterBody2D = make_enemy()
	elite.coin_drop = BALANCE.coins_per_elite
	# Base elite stats come from res://config/balance.tres.
	elite.max_health = BALANCE.elite_health + int(elapsed / 60.0) * 20
	elite.move_speed = BALANCE.elite_speed * enemy_type["speed"]   # Slower, scarier
	elite.contact_damage = BALANCE.elite_damage
	elite.xp_drop = 10              # Kill reward: a shower of orbs
	# Physically huge. Sheets bigger than the usual 192px frame need less
	# scaling, or a minotaur elite would hide the player completely.
	var frame_height: float = elite.custom_frames.get_frame_texture(&"run", 0).get_height()
	elite.scale = Vector2.ONE * 2.5 * minf(192.0 / frame_height, 1.0)
	apply_scaling(elite)

	add_child(elite)

func fit_hud() -> void:
	# Too narrow for the clock beside the health bar: it drops to the next row.
	var clock: Label = $HUD/TimerLabel
	clock.offset_top = 92.0 if WindowControls.is_narrow() else 26.0
	clock.offset_bottom = clock.offset_top + 60.0

func show_map_banner() -> void:
	# The map's name fades out over the first few seconds of a run.
	var banner := Label.new()
	banner.text = "ENDLESS" if endless else map["name"].to_upper()
	banner.theme_type_variation = &"GoldRibbon"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -220.0
	banner.offset_right = 220.0
	banner.offset_top = 170.0 if WindowControls.is_narrow() else 130.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(banner)
	var tween := banner.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(banner, "modulate:a", 0.0, 1.0)
	tween.tween_callback(banner.queue_free)
