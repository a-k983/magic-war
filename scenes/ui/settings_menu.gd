extends CanvasLayer
# Settings Menu: opened with Esc from any screen, or the title screen's
# Settings button. Shows the fullscreen toggle and the keyboard shortcuts.
# Pauses the game while open, and puts the pause state back exactly as it
# was on close (so the level-up / game-over screens stay paused).
# Created by the WindowControls autoload, which is our parent.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

var was_paused: bool = false

@onready var controls: Node = get_parent()

func _ready() -> void:
	visible = false
	%FullscreenButton.pressed.connect(_on_fullscreen_pressed)
	%ResumeButton.pressed.connect(close)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	# Volume sliders drive the Music / SFX buses set up by the Audio autoload.
	%MusicSlider.value = Audio.get_volume("Music")
	%SfxSlider.value = Audio.get_volume("SFX")
	%MusicSlider.value_changed.connect(_on_music_changed)
	%SfxSlider.value_changed.connect(_on_sfx_changed)
	# Fullscreen can also change via F11 / maximize while we're open.
	get_tree().root.size_changed.connect(refresh)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	was_paused = get_tree().paused
	get_tree().paused = true
	# "Main Menu" only makes sense in the middle of a run.
	var scene: Node = get_tree().current_scene
	%MainMenuButton.visible = scene != null and scene.scene_file_path == GAME_SCENE
	%ResumeButton.text = "Resume" if %MainMenuButton.visible else "Close"
	$CenterContainer/VBoxContainer/TitleLabel.text = \
		"PAUSED" if %MainMenuButton.visible else "SETTINGS"
	# Keyboard shortcuts mean nothing on a phone.
	$CenterContainer/VBoxContainer/Panel/VBoxContainer/Shortcuts.visible = \
		not DisplayServer.is_touchscreen_available()
	refresh()
	visible = true

func close() -> void:
	visible = false
	get_tree().paused = was_paused

func refresh() -> void:
	# When played inside the editor's Game tab, the game is embedded in the
	# editor and can't change its own window — say so instead of a dead button.
	if controls.is_embedded():
		%FullscreenButton.text = "Fullscreen: not in editor"
		%FullscreenButton.disabled = true
		return
	# iPhone Safari blocks fullscreen for web pages entirely; the only way is
	# to install the game to the Home Screen, so explain that instead.
	if OS.has_feature("web_ios") and not controls.is_fullscreen():
		%FullscreenButton.text = "Full screen: Share > Add to Home Screen"
		%FullscreenButton.disabled = true
		return
	%FullscreenButton.disabled = false
	%FullscreenButton.text = "Fullscreen: %s" % ("On" if controls.is_fullscreen() else "Off")

func _on_fullscreen_pressed() -> void:
	controls.set_fullscreen(not controls.is_fullscreen())
	refresh.call_deferred()

func _on_music_changed(value: float) -> void:
	Audio.set_volume("Music", value)

func _on_sfx_changed(value: float) -> void:
	Audio.set_volume("SFX", value)
	Audio.play("coin", -6.0, 0.0)  # Sample so you can hear the new level

func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
