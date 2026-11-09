extends Control

@onready var tab_container = %TabContainer

@onready var locations_scene = preload("res://scenes/main.tscn")
@onready var map_scene = preload("res://scenes/map.tscn")
@onready var items_scene = preload("res://scenes/items.tscn")
@onready var settings_scene = preload("res://scenes/settings.tscn")
@onready var autotracker_scene = preload("res://scenes/autotracker.tscn")

var current_tab_index = -1

func _ready() -> void:
	get_window().size = Vector2i(1536, 896)
	get_window().min_size = Vector2i(896, 512)
	get_window().title = "PixelForce - OoTMM Tracker"
	
	_setup_tabs()

func _setup_tabs() -> void:
	var locations_content = locations_scene.instantiate()
	var map_content = map_scene.instantiate()
	var items_content = items_scene.instantiate()
	var settings_content = settings_scene.instantiate()
	var autotracker_content = autotracker_scene.instantiate()
	
	tab_container.add_child(locations_content)
	tab_container.add_child(map_content)
	tab_container.add_child(items_content)
	tab_container.add_child(settings_content)
	tab_container.add_child(autotracker_content)
	
	tab_container.set_tab_title(0, "Locations")
	tab_container.set_tab_title(1, "Map")
	tab_container.set_tab_title(2, "Items")
	tab_container.set_tab_title(3, "Settings")
	tab_container.set_tab_title(4, "AutoTracker")
	
	_show_only_tab(0)

func _show_only_tab(tab_index: int) -> void:
	for i in range(tab_container.get_child_count()):
		var child = tab_container.get_child(i)
		child.visible = (i == tab_index)
	
	current_tab_index = tab_index
	
	if tab_index == 1:
		_update_map_with_current_data()

func _on_tab_changed(tab_index: int) -> void:
	_show_only_tab(tab_index)

func _update_map_with_current_data() -> void:
	var locations_tab = tab_container.get_child(0)
	if locations_tab and locations_tab.has_method("get_log_data"):
		var log_info = locations_tab.get_log_data()
		var all_data = locations_tab.get_all_data()
		var worlds_count = locations_tab.get_worlds_count()
		
		var map_tab = tab_container.get_child(1)
		
		if map_tab and map_tab.has_method("update_from_log_data"):
			map_tab.update_from_log_data(log_info, all_data, worlds_count)
