extends Button
# Boost Offer: the button under the Level ribbon. Every so often it offers a
# watch-an-ad x2 boost for a few seconds, rotating Gold -> EXP -> Drops so the
# same one never comes up twice in a row. Timing is in res://config/balance.tres.
# Its countdowns stop whenever the game is paused, like everything in a run.

const BALANCE: Balance = preload("res://config/balance.tres")
const BOOSTS: Array[Dictionary] = [
	{"id": "gold", "name": "Gold"},
	{"id": "xp", "name": "EXP"},
	{"id": "drops", "name": "Drops"},
]

enum State { WAITING, OFFERING, ACTIVE }

var state: State = State.WAITING
var timer: float = BALANCE.boost_first_offer
var boost_index: int = randi() % BOOSTS.size()

func _ready() -> void:
	visible = false
	focus_mode = Control.FOCUS_NONE
	position = Vector2(14, 156)
	custom_minimum_size = Vector2(230, 66)
	add_theme_font_size_override("font_size", 19)
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	timer -= delta
	match state:
		State.WAITING:
			if timer <= 0.0 and Ads.is_available():
				start_offer()
		State.OFFERING:
			if timer <= 0.0:
				wait_for_next_offer()
			else:
				text = "x%d %s: Watch Ad\n%ds left" % [int(BALANCE.boost_multiplier),
					BOOSTS[boost_index]["name"], ceili(timer)]
		State.ACTIVE:
			if timer <= 0.0:
				GameData.active_boost = ""
				disabled = false
				wait_for_next_offer()
			else:
				text = "x%d %s\n%ds" % [int(BALANCE.boost_multiplier),
					BOOSTS[boost_index]["name"], ceili(timer)]

func start_offer() -> void:
	state = State.OFFERING
	timer = BALANCE.boost_offer_seconds
	boost_index = (boost_index + 1) % BOOSTS.size()
	visible = true

func wait_for_next_offer() -> void:
	state = State.WAITING
	timer = BALANCE.boost_offer_gap
	visible = false

func _on_pressed() -> void:
	Ads.show_rewarded(_on_ad_finished)

func _on_ad_finished(rewarded: bool) -> void:
	if not rewarded:
		wait_for_next_offer()
		return
	state = State.ACTIVE
	timer = BALANCE.boost_seconds
	disabled = true
	GameData.active_boost = BOOSTS[boost_index]["id"]
