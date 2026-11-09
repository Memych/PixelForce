extends Window

var windows: Dictionary = {}

func _ready() -> void:
	var screen_size = DisplayServer.screen_get_size()
	self.position = Vector2i(
		int(screen_size.x / 2.0) - 200,
		int(screen_size.y / 2.0) - 150
	)
	
	$VBox/LocationsBtn.pressed.connect(_on_locations_pressed)
	$VBox/MapBtn.pressed.connect(_on_map_pressed)
	$VBox/ItemsBtn.pressed.connect(_on_items_pressed)
	$VBox/ExitBtn.pressed.connect(_on_exit_pressed)
	
	self.close_requested.connect(_on_launcher_close)

func _on_locations_pressed() -> void:
	_open_window("locations", "res://scenes/main.tscn", "Locations List")

func _on_map_pressed() -> void:
	_open_window("map", "res://scenes/map.tscn", "Map")

func _on_items_pressed() -> void:
	_open_window("items", "res://scenes/items.tscn", "Items Tracker")

func _open_window(id: String, scene_path: String, window_title: String) -> void:
	if windows.has(id) and is_instance_valid(windows[id]):
		windows[id].show()
		windows[id].grab_focus()
		return
		
	if not ResourceLoader.exists(scene_path):
		print("Scene not found: ", scene_path)
		return
		
	var window = Window.new()
	window.title = window_title
	window.borderless = false
	window.size = Vector2i(1200, 800)
	window.unresizable = false
	window.close_requested.connect(_on_window_close.bind(id, window))
	
	var offset = len(windows) * 30
	window.position = self.position + Vector2i(40 + offset, 40 + offset)
	
	var scene = load(scene_path)
	var instance = scene.instantiate()
	window.add_child(instance)
	
	windows[id] = window
	
	get_tree().root.add_child(window)
	window.show()

func _on_window_close(id: String, window: Window) -> void:
	windows.erase(id)
	window.queue_free()

func _on_exit_pressed() -> void:
	for window in windows.values():
		if is_instance_valid(window):
			window.queue_free()
	windows.clear()
	queue_free()
	get_tree().quit()

func _on_launcher_close() -> void:
	_on_exit_pressed()
