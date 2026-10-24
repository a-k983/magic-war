extends Node
# WindowControls: fullscreen handling + the Settings menu, active on every
# screen (autoload).
#   - Clicking the window's maximize button goes straight to fullscreen.
#   - F11 or Alt+Enter toggles fullscreen.
#   - Esc opens / closes the Settings menu (fullscreen toggle + shortcut list).
# canvas_items stretch mode (project settings) scales the game to fill the
# screen, so nothing else needs to change.

const WINDOWED_SIZE := Vector2i(1152, 648)  # Size to return to when leaving fullscreen
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

var settings: CanvasLayer

func _ready() -> void:
	# Keep working while the game is paused (level-up / game-over screens).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_on_window_resized)
	settings = SETTINGS_SCENE.instantiate()
	add_child(settings)

func open_settings() -> void:
	settings.open()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.keycode
	if key == KEY_F11 or (key == KEY_ENTER and event.alt_pressed):
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		settings.toggle()
		get_viewport().set_input_as_handled()

func _on_window_resized() -> void:
	# The maximize button just resizes the window — catch that and turn it
	# into real fullscreen (no title bar, no taskbar).
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		set_fullscreen.call_deferred(true)

func is_embedded() -> bool:
	# True when running inside the editor's Game tab (Godot 4.4+), where
	# window size/mode changes are ignored.
	return Engine.has_method("is_embedded_in_editor") and Engine.call("is_embedded_in_editor")

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func set_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	# Back to a normal window, centered at the default size. (Setting the
	# size explicitly stops the OS restoring it "maximized", which would
	# bounce us straight back into fullscreen.)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if OS.has_feature("web"):
		return  # The browser owns the page size; there's no window to move
	var screen_rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_size(WINDOWED_SIZE)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - WINDOWED_SIZE) / 2)
