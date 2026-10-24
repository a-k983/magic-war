extends Control
# Upgrade Shop: spend coins on permanent upgrades. Data-driven —
# one entry per upgrade, buttons built from the table.

# Each row: the GameData key, display name, effect per level, and
# which button node shows it.
var shop_items: Array = [
	{"id": "max_hp", "name": "Vitality", "desc": "+2 Max HP", "button": "HpButton"},
	{"id": "damage", "name": "Power", "desc": "+1 Damage", "button": "DamageButton"},
	{"id": "move_speed", "name": "Agility", "desc": "+5% Speed", "button": "SpeedButton"},
	{"id": "coin_gain", "name": "Greed", "desc": "+25% Coins", "button": "CoinButton"},
]

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

func refresh() -> void:
	%CoinsLabel.text = "Coins: %d" % GameData.coins
	for item in shop_items:
		var level: int = GameData.meta_upgrades[item["id"]]
		var cost: int = GameData.get_upgrade_cost(item["id"])
		var button: Button = get_button(item["button"])
		button.text = "%s (Lv %d) — %s\nCost: %d coins" % [
			item["name"], level, item["desc"], cost
		]
		# Gray out what you can't afford.
		button.disabled = GameData.coins < cost

func _on_item_pressed(item: Dictionary) -> void:
	if GameData.try_purchase(item["id"]):
		refresh()  # Purchase already saved to disk inside try_purchase

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
