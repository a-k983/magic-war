extends Control
# Upgrade Shop: spend coins on permanent upgrades. Data-driven —
# one entry per upgrade, buttons built from the table.

const BALANCE: Balance = preload("res://config/balance.tres")

# Each row: the GameData key, display name, effect per level, and
# which button node shows it. Every upgrade caps at
# GameData.MAX_UPGRADE_LEVEL; an optional "next" entry then takes over
# the same button (with its own icon, if given), and can have a "next" too.
var shop_items: Array = [
	{"id": "max_hp", "name": "Vitality", "desc": "+2 Max HP", "button": "HpButton",
		"next": {"id": "potion_drop", "name": "Potion Luck",
			"desc": "+%s Potion Drops" % pct(BALANCE.potion_drop_per_level),
			"icon": preload("res://scenes/pickups/health_potion.svg"),
			"next": {"id": "regen", "name": "Regeneration",
				"desc": "+%s HP/sec" % str(BALANCE.regen_per_level),
				"icon": pixel_icon("res://scenes/assets/Items Pack/items/heart.png")}}},
	{"id": "damage", "name": "Power", "desc": "+1 Damage", "button": "DamageButton",
		"next": {"id": "nuke_drop", "name": "Nuke Luck",
			"desc": "+%s Nuke Drops" % pct(BALANCE.nuke_drop_per_level),
			"icon": pixel_icon("res://scenes/assets/Items Pack/items/skull.png"),
			"next": {"id": "fire_rate", "name": "Rapid Fire",
				"desc": "+%s Fire Rate" % pct(BALANCE.fire_rate_per_level),
				"icon": pixel_icon("res://scenes/assets/Items Pack/items/arrow_flame.png")}}},
	{"id": "move_speed", "name": "Agility", "desc": "+5% Speed", "button": "SpeedButton",
		"next": {"id": "invincible_drop", "name": "Super Mode",
			"desc": "+%s Drops (%ss invincible)" % [pct(BALANCE.invincible_drop_per_level),
				str(BALANCE.invincible_duration).trim_suffix(".0")],
			"icon": preload("res://scenes/pickups/super_mode.svg"),
			"next": {"id": "dodge", "name": "Dodge",
				"desc": "+%s Dodge Chance" % pct(BALANCE.dodge_per_level),
				"icon": pixel_icon("res://scenes/assets/Items Pack/items/feather_phoenix.png")}}},
	{"id": "coin_gain", "name": "Greed", "desc": "+25% Gold per Coin", "button": "CoinButton",
		"tip": "Every coin you pick up is worth 25% more gold per level (enemies and elites,\n"
			+ "normal and endless runs). Doesn't change how many coins drop.\n"
			+ "Lv 4 = 2 gold per coin, Lv 10 = 3.5.",
		"next": {"id": "magnet_drop", "name": "Magnet Luck",
			"desc": "+%s Magnet Drops" % pct(BALANCE.magnet_drop_per_level),
			"icon": preload("res://scenes/pickups/magnet.svg"),
			"next": {"id": "pickup_range", "name": "Reach",
				"desc": "+%s Pickup Range" % pct(BALANCE.pickup_range_per_level),
				"icon": pixel_icon("res://scenes/assets/Items Pack/items/magnet_horseshoe.png")}}},
]

# 0.05 -> "5%", 0.003 -> "0.3%".
static func pct(per_level: float) -> String:
	return ("%.1f" % (per_level * 100.0)).trim_suffix(".0") + "%"

# Small pixel art blown up to the 64px the other shop icons use, kept crisp.
static func pixel_icon(path: String) -> Texture2D:
	var img: Image = load(path).get_image()
	img.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	Audio.play_music("title")  # Keeps the title tune going (no restart)
	for item in shop_items:
		var button: Button = get_button(item["button"])
		# bind passes the item into the handler — closure style.
		button.pressed.connect(_on_item_pressed.bind(item))
	%BackButton.pressed.connect(_on_back_pressed)
	refresh()

func get_button(name: String) -> Button:
	# Unique-name lookup (%Name), so buttons can move around the layout.
	return get_node("%" + name)

func current_item(item: Dictionary) -> Dictionary:
	# Walk past maxed upgrades to their replacement, if there is one.
	while GameData.is_maxed(item["id"]) and item.has("next"):
		item = item["next"]
	return item

func refresh() -> void:
	%CoinsLabel.text = "Coins: %d" % GameData.coins
	for slot in shop_items:
		var item: Dictionary = current_item(slot)
		var level: int = GameData.meta_upgrades[item["id"]]
		var button: Button = get_button(slot["button"])
		if item.has("icon"):
			button.icon = item["icon"]
		button.tooltip_text = item.get("tip", "")
		if GameData.is_maxed(item["id"]):
			button.text = "%s (MAX) — %s\nMaxed out" % [item["name"], item["desc"]]
			button.disabled = true
			continue
		var cost: int = GameData.get_upgrade_cost(item["id"])
		button.text = "%s (Lv %d) — %s\nCost: %d coins" % [
			item["name"], level, item["desc"], cost
		]
		# Gray out what you can't afford.
		button.disabled = GameData.coins < cost

func _on_item_pressed(slot: Dictionary) -> void:
	if GameData.try_purchase(current_item(slot)["id"]):
		refresh()  # Purchase already saved to disk inside try_purchase

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
