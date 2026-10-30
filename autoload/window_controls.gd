extends Node
# WindowControls: fullscreen handling + the Settings menu, active on every
# screen (autoload).
#   - Clicking the window's maximize button goes straight to fullscreen.
#   - F11 or Alt+Enter toggles fullscreen.
#   - Esc opens / closes the Settings menu (fullscreen toggle + shortcut list).
#   - Phones and tablets zoom in: see update_zoom.
# canvas_items stretch mode (project settings) scales the game to fill the
# screen, so nothing else needs to change on a computer.

signal layout_changed  # The zoom or orientation changed; screens re-check is_narrow()

const WINDOWED_SIZE := Vector2i(1152, 648)  # Size to return to when leaving fullscreen
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

# The game is laid out for 1152x648. A phone in portrait fits that whole width
# on its narrow screen, so everything looks tiny. On mobile we zoom until the
# screen's short side shows this much of the game instead.
const BASE_SIZE := Vector2(1152, 648)
const MOBILE_PORTRAIT_WIDTH: float = 640.0
const MOBILE_LANDSCAPE_HEIGHT: float = 500.0
const NARROW_WIDTH: float = 900.0  # Narrower than this, menus use their tall layouts

var settings: CanvasLayer
# iPads report themselves as Macs, so a touchscreen is what gives those away.
var mobile: bool = OS.has_feature("mobile") or OS.has_feature("web_android") \
	or OS.has_feature("web_ios") \
	or (OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available())

func _ready() -> void:
	# Keep working while the game is paused (level-up / game-over screens).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_on_window_resized)
	settings = SETTINGS_SCENE.instantiate()
	add_child(settings)
	update_zoom()

func update_zoom() -> void:
	if not mobile:
		return
	var window: Window = get_window()
	var screen := Vector2(window.size)
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	# How much of the game shows before zooming, in game pixels.
	var shown: Vector2 = screen / minf(screen.x / BASE_SIZE.x, screen.y / BASE_SIZE.y)
	var zoom: float = shown.x / MOBILE_PORTRAIT_WIDTH if screen.y > screen.x \
		else shown.y / MOBILE_LANDSCAPE_HEIGHT
	if not is_equal_approx(window.content_scale_factor, zoom):
		window.content_scale_factor = zoom
		layout_changed.emit()

func is_narrow() -> bool:
	# Only ever true on mobile: at the base size the game is 1152 wide or more.
	return get_tree().root.get_visible_rect().size.x < NARROW_WIDTH

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
	update_zoom()
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
