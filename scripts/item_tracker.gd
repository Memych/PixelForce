extends Node

var checked_items: Dictionary = {}
var item_state_cache: Dictionary = {}
var _mq_state_cache: Dictionary = {}
var current_world: int = 1
var tracker_items: Array = []
var song_event_indices: Dictionary = {}
var song_events_from_log: Dictionary = {}
var _song_events_sync_pending: bool = false
var _last_clocks_mode: String = ""
var _settings_tab_cache: Node = null
var _main_scene_cache: Node = null
var _items_save_timer: Timer = null
var _all_oot_entrances: Array = []
var _all_mm_entrances: Array = []
var _game_entrances_loaded: bool = false
var _widgets_update_pending: bool = false
var _cache_batch_active: bool = false

@onready var world_filter: OptionButton = null
@onready var load_button: Button = null
@onready var save_button: Button = null
@onready var clear_button: Button = null

var item_widgets: Dictionary = {}

func _ready() -> void:
	_items_save_timer = Timer.new()
	_items_save_timer.one_shot = true
	_items_save_timer.wait_time = 0.2
	_items_save_timer.timeout.connect(_save_checked_items)
	add_child(_items_save_timer)
	
	_load_tracker_items()
	_build_location_to_tracker_cache()
	_load_song_event_indices()
	_reset_song_events_to_defaults()
	
	world_filter = get_node_or_null("MainContainer/TopPanel/WorldFilter") as OptionButton
	load_button = get_node_or_null("MainContainer/TopPanel/LoadButton") as Button
	save_button = get_node_or_null("MainContainer/TopPanel/SaveButton") as Button
	clear_button = get_node_or_null("MainContainer/TopPanel/ClearButton") as Button
	
	if world_filter:
		world_filter.item_selected.connect(_on_world_filter_selected)
	if load_button:
		load_button.pressed.connect(_on_load_button_pressed)
		load_button.tooltip_text = "Load spoiler log or tracker save (F1)"
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
		save_button.tooltip_text = "Save tracker state (F2)"
	if clear_button:
		clear_button.pressed.connect(_on_clear_button_pressed)
		clear_button.tooltip_text = "Reset all progress (F3)"
		
	add_to_group("item_tracker")
	call_deferred("_init_node_caches")
	call_deferred("refresh_world_filter_from_settings")
	call_deferred("_create_item_widgets")
	call_deferred("sync_all_tracker_states")

func _request_widgets_update() -> void:
	if _widgets_update_pending:
		return
	_widgets_update_pending = true
	call_deferred("_do_widgets_update")

func _do_widgets_update() -> void:
	_widgets_update_pending = false
	LogicEvaluator.begin_suppress_compute()
	_cache_batch_begin()
	_update_all_widgets()
	_cache_batch_end()
	LogicEvaluator.end_suppress_compute()
	if not LogicEvaluator.is_reach_prepared(current_world):
		LogicEvaluator.request_reach_compute(current_world, _on_reach_ready_for_widgets, false)
	var settings_tab: Node = get_tree().get_first_node_in_group("settings_tab")
	if settings_tab and settings_tab.has_method("refresh_price_visibilities"):
		settings_tab.refresh_price_visibilities()

func _on_reach_ready_for_widgets() -> void:
	_request_widgets_update()

func _cache_game_entrances() -> void:
	if _game_entrances_loaded:
		return
	const ENTRANCES_PATH = "res://data/entrances.json"
	if not FileAccess.file_exists(ENTRANCES_PATH):
		return
		
	var file := FileAccess.open(ENTRANCES_PATH, FileAccess.READ)
	if file == null:
		return
		
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		return
	
	for row: Variant in parsed:
		if not row is Array or row.size() < 4:
			continue
		var codes: Variant = row[3]
		if codes is Array:
			for code: Variant in codes:
				var c: String = str(code).strip_edges()
				if c.begins_with("OOT_"):
					_all_oot_entrances.append(c)
				elif c.begins_with("MM_"):
					_all_mm_entrances.append(c)
	_game_entrances_loaded = true

func _init_node_caches() -> void:
	_settings_tab_cache = get_tree().get_first_node_in_group("settings_tab")
	_main_scene_cache = get_tree().get_first_node_in_group("main_scene")

var _location_to_tracker_cache: Dictionary = {}

func _build_location_to_tracker_cache() -> void:
	_location_to_tracker_cache.clear()
	for item_data: Dictionary in tracker_items:
		var items_array = item_data.get("item", [])
		for entry: Variant in items_array:
			var key_name: String = ""
			if entry is String:
				key_name = entry.strip_edges().to_lower()
			elif entry is Dictionary:
				key_name = str(entry.get("name", "")).strip_edges().to_lower()
			
			if key_name != "" and key_name != "(unknown)":
				if not _location_to_tracker_cache.has(key_name):
					_location_to_tracker_cache[key_name] = []
				_location_to_tracker_cache[key_name].append({"data": item_data, "entry": entry})

func _load_tracker_items() -> void:
	const TRACKER_ITEMS_PATH = "res://data/item_tracker.json"
	tracker_items.clear()
	
	if not FileAccess.file_exists(TRACKER_ITEMS_PATH):
		return
		
	var file := FileAccess.open(TRACKER_ITEMS_PATH, FileAccess.READ)
	if file == null:
		return
		
	var text := file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		tracker_items = parsed

func _create_item_widgets() -> void:
	_clear_all_widgets()
	item_widgets.clear()
	
	for item_data: Dictionary in tracker_items:
		_create_item_widget(item_data)
	
	_cache_item_states()

func _create_item_widget(item_data: Dictionary) -> void:
	var panel_name: String = item_data.get("panel", "")
	var panel: TextureRect = _get_panel_by_name(panel_name)
	if not panel:
		return
		
	var item_name: String = _get_internal_name(item_data)
	if item_name.is_empty():
		return
		
	var x: float = float(item_data.get("x", 0))
	var y: float = float(item_data.get("y", 0))
	var size: float = float(item_data.get("size", 32))
	
	var item_button := TextureButton.new()
	item_button.name = "Item_" + item_name
	item_button.custom_minimum_size = Vector2(size, size)
	item_button.position = Vector2(x, y)
	
	var is_available: bool = _check_item_availability(item_data)
	var item_type: String = str(item_data.get("type", "toggle"))
	
	if item_type == "event_label" or item_type == "event_song":
		var event_id: String = _get_event_id(item_data)
		if event_id.is_empty():
			return
			
		item_name = event_id + ("_label" if item_type == "event_label" else "_song")
		if item_type == "event_label":
			item_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_update_event_label_button(item_button, item_data)
		else:
			item_button.mouse_filter = Control.MOUSE_FILTER_STOP
			item_button.pressed.connect(_on_song_event_pressed.bind(item_name, item_button))
			item_button.gui_input.connect(_on_song_event_input.bind(item_name, item_button))
			_update_song_event_button(item_button, item_data)
			
		panel.add_child(item_button)
		item_widgets[item_name] = {"button": item_button, "data": item_data, "panel": panel_name}
		return
	
	_update_item_button_state(item_button, item_data, is_available)
	item_button.pressed.connect(_on_item_pressed.bind(item_name, item_button, false))
	item_button.gui_input.connect(_on_item_input.bind(item_name, item_button))
		
	panel.add_child(item_button)
	item_widgets[item_name] = {"button": item_button, "data": item_data, "panel": panel_name}

func _update_event_label_button(button: TextureButton, item_data: Dictionary) -> void:
	var is_available: bool = _check_item_availability(item_data)
	var image_path: String = str(item_data.get("image", "")).strip_edges()
	var has_real_icon: bool = is_available and not image_path.is_empty() and ResourceLoader.exists(image_path)

	if has_real_icon:
		button.texture_normal = load(image_path)
		button.tooltip_text = str(item_data.get("name", ""))
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		var placeholder_path: String = str(item_data.get("placeholder", "")).strip_edges()
		if not placeholder_path.is_empty() and ResourceLoader.exists(placeholder_path):
			button.texture_normal = load(placeholder_path)
		else:
			button.texture_normal = null
		button.tooltip_text = ""
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	button.modulate = Color(1, 1, 1, 1)

func _update_song_event_button(button: TextureButton, item_data: Dictionary) -> void:
	if item_data.get("type") != "event_song":
		return
		
	var is_available: bool = _check_item_availability(item_data)
	if not is_available:
		var placeholder_path: String = str(item_data.get("placeholder", "")).strip_edges()
		if not placeholder_path.is_empty() and ResourceLoader.exists(placeholder_path):
			button.texture_normal = load(placeholder_path)
		else:
			button.texture_normal = null
		button.modulate = Color(1, 1, 1, 1)
		button.tooltip_text = ""
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
		
	var event_id: String = _get_event_id(item_data)
	var songs: Array = _get_event_songs(item_data)
	if songs.is_empty():
		button.texture_normal = null
		return
		
	var is_shuffle_enabled: bool = _is_song_event_shuffle_enabled(item_data)
	var current_index: int
	
	if is_shuffle_enabled:
		current_index = _get_song_event_index(event_id, current_world)
		if current_index < 0 or current_index >= songs.size():
			current_index = _get_default_song_index(item_data)
			if current_index >= songs.size():
				current_index = 0
			_set_song_event_index(event_id, current_world, current_index)
	else:
		current_index = _get_default_song_index(item_data)
		if current_index >= songs.size():
			current_index = 0
			
	var song_data: Dictionary = songs[current_index]
	var song_image: String = str(song_data.get("image", ""))
	
	if not song_image.is_empty() and ResourceLoader.exists(song_image):
		button.texture_normal = load(song_image)
	else:
		var placeholder: String = str(item_data.get("placeholder", ""))
		if not placeholder.is_empty() and ResourceLoader.exists(placeholder):
			button.texture_normal = load(placeholder)
		else:
			button.texture_normal = null
			
	button.tooltip_text = str(song_data.get("name", ""))
	button.modulate = Color(1, 1, 1, 1)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_song_event_pressed(_item_name: String, _button: TextureButton) -> void:
	pass

func _on_song_event_input(event: InputEvent, item_name: String, button: TextureButton) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	
	var widget_data: Dictionary = item_widgets.get(item_name, {})
	var item_data: Dictionary = widget_data.get("data", {})
	if item_data.is_empty() or item_data.get("type") != "event_song":
		return
	
	if not _is_song_event_shuffle_enabled(item_data):
		return
	
	var event_id: String = _get_event_id(item_data)
	var songs: Array = _get_event_songs(item_data)
	if songs.is_empty():
		return
	
	var current_index: int = _get_song_event_index(event_id, current_world)
	if current_index < 0:
		current_index = _get_default_song_index(item_data)
		
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		current_index = (current_index + 1) % songs.size()
		_set_song_event_index(event_id, current_world, current_index)
		_update_song_event_button(button, item_data)
		_save_song_event_indices()
		LogicEvaluator.invalidate_reachability()
		_update_all_widgets()
		
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		current_index = (current_index - 1 + songs.size()) % songs.size()
		_set_song_event_index(event_id, current_world, current_index)
		_update_song_event_button(button, item_data)
		_save_song_event_indices()
		LogicEvaluator.invalidate_reachability()
		_update_all_widgets()

func _save_song_event_indices() -> void:
	const PATH = "user://song_event_indices.json"
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(song_event_indices, "\t"))
		file.close()

func _load_song_event_indices() -> void:
	const PATH = "user://song_event_indices.json"
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		song_event_indices = parsed

func _get_progressive_image(item_data: Dictionary, current_level: int) -> String:
	var images_array: Array = item_data.get("images", [])
	if images_array.is_empty():
		return str(item_data.get("image", ""))

	if current_level < 1 or current_level > images_array.size():
		return str(item_data.get("image", ""))

	var img_data: Variant = images_array[current_level - 1]
	if img_data is Dictionary:
		var settings_tab: Node = _settings_tab_cache
		if settings_tab and settings_tab.has_method("get_setting_value"):
			if img_data.has("hide_if") and img_data["hide_if"] is Dictionary:
				if _evaluate_simple_cond(img_data["hide_if"], settings_tab):
					return ""
			if img_data.has("show_if") and img_data["show_if"] is Dictionary:
				if not _evaluate_simple_cond(img_data["show_if"], settings_tab):
					return ""
			if img_data.has("variants") and img_data["variants"] is Array:
				for variant: Variant in img_data["variants"]:
					if variant is Dictionary and variant.has("if") and variant["if"] is Dictionary:
						if _evaluate_simple_cond(variant["if"], settings_tab):
							return str(variant.get("image", ""))
				return str(img_data.get("image", ""))
		return str(img_data.get("image", ""))
	elif img_data is String:
		return img_data

	return ""

func _get_mq_dungeons() -> Array:
	var value: Variant = _get_setting_value_for_world("mqDungeons")
	return value.duplicate() if value is Array else []

func _cache_mq_state() -> void:
	_mq_state_cache[current_world] = _get_mq_dungeons()

func _item_has_mq_tag_in(item_data: Dictionary, changed_mq: Array) -> bool:
	var tags: Variant = item_data.get("mq_reset", [])
	if tags is String:
		tags = [tags]
	if tags is Array:
		for tag: Variant in tags:
			if changed_mq.has(str(tag)):
				return true
	return false

func _get_effective_images(item_data: Dictionary) -> Array:
	var images_array: Array = item_data.get("images", [])
	var settings_tab: Node = _settings_tab_cache
	var result: Array = []
	
	for img_data: Variant in images_array:
		if img_data is Dictionary:
			if img_data.has("if"):
				if settings_tab and not _evaluate_simple_cond(img_data["if"], settings_tab):
					continue
			result.append(img_data)
		elif img_data is String:
			result.append(img_data)
	return result

func _get_default_song_index(item_data: Dictionary) -> int:
	if item_data.has("default_index"):
		return int(item_data["default_index"])
	if item_data.has("dafault_index"):
		return int(item_data["dafault_index"])
	return 0

func _get_event_songs(item_data: Dictionary) -> Array:
	return item_data.get("songs", [])

func _get_event_id(item_data: Dictionary) -> String:
	return str(item_data.get("event_id", ""))

func _get_game_for_event(item_data: Dictionary) -> String:
	var cond: Variant = item_data.get("cond", {})
	if cond is Dictionary and cond.has("games"):
		var games: Variant = cond["games"]
		if games is Array:
			if games.has("oot"): return "oot"
			if games.has("mm"): return "mm"
	return ""

func _is_song_event_shuffle_enabled(item_data: Dictionary) -> bool:
	var game: String = _get_game_for_event(item_data)
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab or not settings_tab.has_method("get_setting_value"):
		return false
	if game == "oot":
		return settings_tab.get_setting_value("songEventsShuffleOot") == true
	elif game == "mm":
		return settings_tab.get_setting_value("songEventsShuffleMm") == true
	return false

func _get_song_event_index(event_id: String, world: int) -> int:
	var key: String = str(world) + "_" + event_id
	return song_event_indices.get(key, -1)

func _set_song_event_index(event_id: String, world: int, index: int) -> void:
	var key: String = str(world) + "_" + event_id
	song_event_indices[key] = index

func _apply_song_events_from_log() -> void:
	_reset_song_events_to_defaults()
	for world_key: Variant in song_events_from_log.keys():
		var world: int = int(world_key)
		var events: Variant = song_events_from_log[world_key]
		if not events is Dictionary:
			continue

		for item_data: Dictionary in tracker_items:
			if str(item_data.get("type", "")) != "event_song":
				continue
			var event_id: String = _get_event_id(item_data)
			if event_id.is_empty() or not events.has(event_id):
				continue

			var songs: Array = _get_event_songs(item_data)
			if songs.is_empty():
				continue

			var log_song_name: String = str(events[event_id]).strip_edges()
			var found: int = -1
			for i: int in range(songs.size()):
				if str(songs[i].get("name", "")).strip_edges() == log_song_name:
					found = i
					break

			if found >= 0:
				_set_song_event_index(event_id, world, found)

func _reset_song_events_to_defaults() -> void:
	for item_data: Dictionary in tracker_items:
		if item_data.get("type") != "event_song":
			continue
		var event_id: String = _get_event_id(item_data)
		if event_id.is_empty():
			continue
		var default_idx: int = _get_default_song_index(item_data)
		for w: int in range(1, 10):
			_set_song_event_index(event_id, w, default_idx)

func sync_song_events() -> void:
	var settings_tab: Node = _settings_tab_cache
	var any_shuffle_enabled: bool = false
	if settings_tab and settings_tab.has_method("get_setting_value"):
		any_shuffle_enabled = settings_tab.get_setting_value("songEventsShuffleOot") == true or settings_tab.get_setting_value("songEventsShuffleMm") == true
	
	if any_shuffle_enabled and not song_events_from_log.is_empty():
		_apply_song_events_from_log()
	else:
		_reset_song_events_to_defaults()
	_update_all_widgets()

func on_song_events_loaded(log_events: Dictionary) -> void:
	song_events_from_log = log_events.duplicate(true)
	_request_song_events_sync()

func _request_song_events_sync() -> void:
	if _song_events_sync_pending:
		return
	_song_events_sync_pending = true
	call_deferred("_do_song_events_sync")

func _do_song_events_sync() -> void:
	_song_events_sync_pending = false
	sync_song_events()

func set_worlds_count(count: int) -> void:
	if count < 1:
		count = 1
	if not world_filter:
		call_deferred("set_worlds_count", count)
		return

	var prev_selected: int = world_filter.selected
	world_filter.clear()
	for i: int in range(1, count + 1):
		world_filter.add_item("World " + str(i), i - 1)

	if prev_selected >= 0 and prev_selected < world_filter.item_count:
		world_filter.select(prev_selected)
	else:
		world_filter.select(0)

	current_world = world_filter.selected + 1
	_update_all_widgets()

func _sync_world_filter_from_main() -> void:
	var main_node: Node = _main_scene_cache
	if main_node and main_node.has_method("get_worlds_count"):
		var count: int = int(main_node.get_worlds_count())
		if count > 0:
			set_worlds_count(count)
			return
	refresh_world_filter_from_settings()

func _update_item_button_state(button: TextureButton, item_data: Dictionary, is_available: bool) -> void:
	var item_name: String = _get_internal_name(item_data)
	
	if _is_auto_checked(item_data):
		set_item_checked(item_name, current_world, true)
		is_available = true
	elif item_data.get("always_checked", false):
		if is_available:
			set_item_checked(item_name, current_world, true)
			
	var item_type: String = str(item_data.get("type", "toggle"))
	if item_type == "event_song":
		_update_song_event_button(button, item_data)
		return
	if item_type == "event_label":
		_update_event_label_button(button, item_data)
		return
		
	var image_path: String = str(item_data.get("image", " "))
	var placeholder_path: String = str(item_data.get("placeholder", " "))
	
	_remove_number_labels(button)
	button.modulate = Color(1, 1, 1, 1)
	button.tooltip_text = _get_display_name(item_data)
	
	var special_key: String = ""
	var special_locked: bool = false

	if is_available:
		special_key = _get_item_active_special_condition(item_data)
		special_locked = not special_key.is_empty()
		if special_locked:
			set_item_checked(item_name, current_world, _is_special_condition_met(special_key))
	
	if not is_available:
		if not placeholder_path.is_empty() and ResourceLoader.exists(placeholder_path):
			var placeholder_tex = load(placeholder_path)
			button.texture_normal = placeholder_tex
			button.texture_disabled = placeholder_tex
		else:
			button.modulate = Color(0.3, 0.3, 0.3, 1)
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	elif item_type == "count":
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var current_count: int = get_item_count(item_name, current_world)
		var max_val: int = _get_max_value(item_data)

		if current_count > max_val:
			current_count = max_val
			set_item_count(item_name, current_count, current_world)

		var is_maxed: bool = current_count >= max_val
		if current_count > 0 and not image_path.is_empty() and ResourceLoader.exists(image_path):
			button.texture_normal = load(image_path)
		else:
			button.texture_normal = null
			
		if max_val > 1:
			_add_number_labels(button, current_count, is_maxed)
		
	elif item_type == "progressive":
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var min_level: int = _get_effective_min_level(item_data)
		var max_level: int = _get_effective_max_level(item_data)
		var current_level: int = get_item_count(item_name, current_world)
		var needs_save: bool = false
		
		if current_level < min_level:
			current_level = min_level
			needs_save = true
		elif current_level > max_level:
			current_level = max_level
			needs_save = true
		elif current_level > 0 and not _is_level_valid(item_data, current_level):
			var next_valid: int = current_level + 1
			while next_valid <= max_level and not _is_level_valid(item_data, next_valid):
				next_valid += 1
			current_level = next_valid if next_valid <= max_level else 0
			needs_save = true
			
		if needs_save:
			set_item_count(item_name, current_level, current_world)
		
		if current_level > 0:
			var img_path: String = _get_progressive_image(item_data, current_level)
			if not img_path.is_empty() and ResourceLoader.exists(img_path):
				button.texture_normal = load(img_path)
			else:
				button.texture_normal = null
			
			var display_values: Array = item_data.get("display_values", [])
			if not display_values.is_empty() and current_level <= display_values.size() and max_level > 1:
				var display_count: int = int(display_values[current_level - 1])
				_add_number_labels(button, display_count, current_level == max_level)
		else:
			button.texture_normal = null
	
	elif item_type == "bottle":
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		var is_checked: bool = is_item_checked(item_name, current_world)
		var contents: Array = _get_bottle_contents(item_data)
		var content_index: int = get_bottle_content_index(item_name, current_world)

		if not contents.is_empty():
			if content_index < 0 or content_index >= contents.size():
				content_index = 0
				set_bottle_content_index(item_name, content_index, current_world)

			var content: Dictionary = contents[content_index]
			if is_checked:
				var content_image: String = str(content.get("image", image_path))
				if not content_image.is_empty() and ResourceLoader.exists(content_image):
					button.texture_normal = load(content_image)
				else:
					button.texture_normal = null
				button.tooltip_text = str(content.get("name", item_name))
			else:
				button.texture_normal = null
				button.tooltip_text = item_name
		else:
			if is_checked and not image_path.is_empty() and ResourceLoader.exists(image_path):
				button.texture_normal = load(image_path)
			else:
				button.texture_normal = null
			button.tooltip_text = item_name
	
	elif item_type == "song":
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		var progressive_song: bool = _is_song_progressive(item_data)
		var effective_max: int = _get_song_effective_max(item_data)
		var current_count: int = _get_song_count(item_name, current_world, effective_max)

		if current_count != get_item_count(item_name, current_world):
			set_item_count(item_name, current_count, current_world)
		if current_count > effective_max:
			current_count = effective_max
			set_item_count(item_name, current_count, current_world)

		if not _is_song_notes_mode() and not progressive_song and current_count > 0 and current_count < effective_max:
			current_count = 0
			set_item_count(item_name, current_count, current_world)

		if current_count > 0:
			var song_image: String = _get_song_image_for_count(item_data, current_count)
			if song_image.is_empty():
				song_image = image_path
			if not song_image.is_empty() and ResourceLoader.exists(song_image):
				button.texture_normal = load(song_image)
			else:
				button.texture_normal = null
		else:
			button.texture_normal = null

		if _is_song_notes_mode() and current_count > 0 and current_count < effective_max:
			_add_number_labels(button, current_count, false)

	elif item_type == "toggle":
		var is_checked: bool = is_item_checked(item_name, current_world)
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		if special_locked:
			if is_checked and not image_path.is_empty() and ResourceLoader.exists(image_path):
				var key_tex = load(image_path)
				button.texture_normal = key_tex
				button.texture_disabled = key_tex
			else:
				button.texture_normal = null
				button.texture_disabled = null
		else:
			if is_checked and not image_path.is_empty() and ResourceLoader.exists(image_path):
				button.texture_normal = load(image_path)
			else:
				button.texture_normal = null
		button.modulate = Color(1, 1, 1, 1)
		button.tooltip_text = _get_display_name(item_data)

func _looks_like_world_dictionary(value: Dictionary) -> bool:
	if value.is_empty():
		return false
	for k: Variant in value:
		if typeof(k) == TYPE_INT:
			return true
		if typeof(k) == TYPE_STRING and str(k).is_valid_int():
			return true
	return false

func _get_internal_name(item_data: Dictionary) -> String:
	if item_data.has("id") and str(item_data["id"]) != "":
		return str(item_data["id"]).strip_edges()
	var raw_name: Variant = item_data.get("name", "")
	if raw_name is String:
		return raw_name.strip_edges()
	if raw_name is Dictionary:
		var default_name: String = str(raw_name.get("default", "")).strip_edges()
		if not default_name.is_empty():
			return default_name
		var variants: Array = raw_name.get("variants", [])
		if not variants.is_empty() and variants[0] is Dictionary:
			return str(variants[0].get("name", "")).strip_edges()
	return str(raw_name).strip_edges()

func _get_display_name(item_data: Dictionary) -> String:
	var raw_name: Variant = item_data.get("name", "")
	if raw_name is String:
		return raw_name
	if raw_name is Dictionary:
		var variants: Array = raw_name.get("variants", [])
		if variants is Array:
			for variant: Variant in variants:
				if variant is Dictionary and variant.has("if"):
					if _evaluate_item_condition(variant["if"]):
						return str(variant.get("name", raw_name.get("default", "")))
		return str(raw_name.get("default", ""))
	return str(raw_name)

func _get_setting_value_for_world(key: String, world: int = -1) -> Variant:
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab or not settings_tab.has_method("get_setting_value"):
		return null

	var value: Variant = settings_tab.get_setting_value(key)
	var check_world: int = world if world > 0 else current_world
	
	if typeof(value) == TYPE_DICTIONARY and _looks_like_world_dictionary(value):
		if value.has(check_world):
			return value[check_world]
		if value.has(str(check_world)):
			return value[str(check_world)]
		return null
	return value

func _check_item_availability(item_data: Dictionary) -> bool:
	if _is_auto_checked(item_data):
		return true
	if not _check_item_cond_only(item_data):
		return false
	return _check_count_requirements(item_data)

func _check_item_cond_only(item_data: Dictionary) -> bool:
	if _is_auto_checked(item_data):
		return true
	if not item_data.has("cond"):
		return true
	return _evaluate_item_condition(item_data["cond"])

func _check_count_requirements(item_data: Dictionary) -> bool:
	if not item_data.has("requires_count"):
		return true

	for req: Variant in item_data["requires_count"]:
		if not req is Dictionary:
			continue
		if req.has("if") and not _evaluate_item_condition(req["if"]):
			continue

		var min_count: int = int(req.get("min", 1))
		var names: Array = []
		if req.has("item"):
			names.append(str(req["item"]))
		if req.has("items") and req["items"] is Array:
			for req_name: Variant in req["items"]:
				names.append(str(req_name))

		if names.is_empty():
			continue

		var mode: String = str(req.get("mode", "any"))
		if mode == "all":
			for req_name: String in names:
				if get_item_count(req_name, current_world) < min_count:
					return false
		else:
			var ok: bool = false
			for req_name: String in names:
				if get_item_count(req_name, current_world) >= min_count:
					ok = true
					break
			if not ok:
				return false
	return true

func _reset_items_failing_count_requirements() -> bool:
	var changed: bool = false
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		if not item_data.has("requires_count") or _is_auto_checked(item_data) or not _check_item_cond_only(item_data):
			continue
		if _check_count_requirements(item_data):
			continue

		var item_type: String = item_data.get("type", "toggle")
		if item_type == "count" or item_type == "progressive" or item_type == "song":
			if get_item_count(item_name, current_world) != 0:
				set_item_count(item_name, 0, current_world)
				changed = true
		else:
			if is_item_checked(item_name, current_world):
				set_item_checked(item_name, current_world, false)
				changed = true
	return changed

func _get_tracker_item_match(item_data: Dictionary, clean_name: String) -> Variant:
	var target_name: String = clean_name.strip_edges().to_lower()
	for entry: Variant in item_data.get("item", []):
		if entry is String:
			if entry.strip_edges().to_lower() == target_name:
				return entry
		elif entry is Dictionary:
			var entry_name: String = str(entry.get("name", "")).strip_edges().to_lower()
			if entry_name != target_name:
				continue
			if entry.has("if"):
				if _evaluate_item_condition(entry["if"]):
					return entry
			else:
				return entry
	return null

func _tracker_item_matches_name(item_data: Dictionary, clean_name: String) -> bool:
	return _get_tracker_item_match(item_data, clean_name) != null

func _is_auto_checked(item_data: Dictionary) -> bool:
	if not item_data.has("auto_check_setting"):
		return false
	var setting_key: String = item_data["auto_check_setting"]
	var target_val: Variant = item_data["auto_check_value"]
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab: return false
	
	var current_val: Variant = _get_setting_value_for_world(setting_key)
	if current_val == null: return false
	
	var val_to_check: Variant = current_val
	if typeof(current_val) == TYPE_DICTIONARY:
		val_to_check = current_val.get(current_world, [])
		
	if typeof(val_to_check) == TYPE_ARRAY:
		return target_val in val_to_check
	elif typeof(val_to_check) == TYPE_STRING:
		return val_to_check == target_val
	return false

func _sync_bottle_from_location(clean_name: String, pressed: bool, world: int) -> bool:
	var groups: Dictionary = {}
	for data: Dictionary in tracker_items:
		if data.get("type", "") != "bottle" or not data.has("bottle_group") or not _check_item_availability(data):
			continue

		var match_entry: Variant = _get_tracker_item_match(data, clean_name)
		if match_entry == null or not (match_entry is Dictionary) or not match_entry.has("bottle_content"):
			continue

		var group_name: String = str(data["bottle_group"])
		if not groups.has(group_name):
			groups[group_name] = str(match_entry["bottle_content"])

	if groups.is_empty():
		return false

	for group_name: String in groups:
		var content_id: String = str(groups[group_name])
		var slots: Array = _get_bottle_slots(group_name)
		if slots.is_empty():
			continue

		if pressed:
			var target: Dictionary = {}
			for slot: Dictionary in slots:
				if not is_item_checked(slot["name"], world):
					target = slot
					break
			if not target.is_empty():
				set_item_checked(target["name"], world, true)
				set_bottle_content_index(target["name"], _get_bottle_content_index_by_id(target["data"], content_id), world)
		else:
			var target: Dictionary = {}
			for slot: Dictionary in slots:
				if is_item_checked(slot["name"], world):
					if _get_bottle_content_id(slot["data"], get_bottle_content_index(slot["name"], world)) == content_id:
						target = slot
						break
			if target.is_empty():
				for slot: Dictionary in slots:
					if is_item_checked(slot["name"], world):
						target = slot
						break
			if not target.is_empty():
				set_item_checked(target["name"], world, false)

		for slot: Dictionary in slots:
			var btn: TextureButton = item_widgets.get(slot["name"], {}).get("button")
			if btn:
				_update_item_button_state(btn, slot["data"], true)
		return true
	return false

func sync_auto_checked_items() -> void:
	var changed: bool = false
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		if _is_auto_checked(item_data) and not is_item_checked(item_name, current_world):
			set_item_checked(item_name, current_world, true)
			changed = true
	if changed:
		_request_widgets_update()
		request_save_checked_items()

func clear_auto_checked_items(changed_key: String) -> void:
	var changed: bool = false
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		if item_data.get("auto_check_setting") == changed_key:
			if not _is_auto_checked(item_data) and is_item_checked(item_name, current_world):
				set_item_checked(item_name, current_world, false)
				changed = true
	if changed:
		_request_widgets_update()
		request_save_checked_items()

func _is_special_condition_key(key: String) -> bool:
	var settings_tab: Node = _settings_tab_cache
	if settings_tab and settings_tab.has_method("get_setting_type") and settings_tab.get_setting_type(key) == "special_cond":
		return true

	var value: Variant = _get_setting_value_for_world(key)
	if value is Dictionary and value.has("count"):
		return value.has("stones") or value.has("medallions") or value.has("remains") or value.has("skullsGold") or \
			   value.has("skullsSwamp") or value.has("skullsOcean") or value.has("fairiesWF") or value.has("fairiesSH") or \
			   value.has("fairiesGB") or value.has("fairiesST") or value.has("fairyTown") or value.has("masksRegular") or \
			   value.has("masksTransform") or value.has("masksOot") or value.has("triforce") or value.has("coinsRed") or \
			   value.has("coinsGreen") or value.has("coinsBlue") or value.has("coinsYellow")
	return false

func _get_special_condition_score(requirements: Dictionary) -> int:
	var tag_regular: Dictionary = {}
	var tag_fulfill: Dictionary = {}

	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		var item_type: String = str(item_data.get("type", "toggle"))
		if not _check_item_availability(item_data):
			continue

		var fulfills: Variant = item_data.get("special_fulfills", {})
		if fulfills is Dictionary and not fulfills.is_empty():
			var is_active: bool = false
			if item_type == "count" or item_type == "song":
				is_active = get_item_count(item_name, current_world) > 0
			elif item_type == "progressive":
				is_active = get_item_count(item_name, current_world) > _get_effective_min_level(item_data)
			else:
				is_active = is_item_checked(item_name, current_world)

			if is_active:
				for tag: Variant in fulfills:
					var tag_str: String = str(tag)
					var fulfill_value: Variant = fulfills[tag]
					var fulfill_score: int = 0
					if typeof(fulfill_value) in [TYPE_INT, TYPE_FLOAT]:
						fulfill_score = int(fulfill_value)
					elif typeof(fulfill_value) == TYPE_STRING:
						var settings_tab: Node = _settings_tab_cache
						if settings_tab and settings_tab.has_method("get_setting_value"):
							var setting_value: Variant = settings_tab.get_setting_value(fulfill_value)
							if typeof(setting_value) in [TYPE_INT, TYPE_FLOAT]:
								fulfill_score = int(setting_value)

					if fulfill_score > int(tag_fulfill.get(tag_str, 0)):
						tag_fulfill[tag_str] = fulfill_score

		var tags: Variant = item_data.get("special_tags", [])
		if tags is String:
			tags = [tags]
		if not tags is Array or tags.is_empty():
			continue

		var item_score: int = 0
		if item_type == "count" or item_type == "song":
			item_score = get_item_count(item_name, current_world)
		elif item_type == "progressive":
			item_score = get_item_count(item_name, current_world) - _get_effective_min_level(item_data)
			if item_score < 0: item_score = 0
		else:
			item_score = 1 if is_item_checked(item_name, current_world) else 0

		if item_score <= 0:
			continue

		var contribution: int = 1
		var contribution_value: Variant = item_data.get("special_contribution", 1)
		if typeof(contribution_value) in [TYPE_INT, TYPE_FLOAT]:
			contribution = int(contribution_value)
		item_score *= contribution

		for tag: Variant in tags:
			var tag_str: String = str(tag)
			if bool(requirements.get(tag_str, false)):
				tag_regular[tag_str] = int(tag_regular.get(tag_str, 0)) + item_score
				break

	var all_tags: Dictionary = {}
	for t: String in tag_regular: all_tags[t] = true
	for t: String in tag_fulfill: all_tags[t] = true

	var score: int = 0
	for t: String in all_tags:
		if not bool(requirements.get(t, false)):
			continue
		score += max(int(tag_regular.get(t, 0)), int(tag_fulfill.get(t, 0)))
	return score

func _is_special_condition_met(key: String) -> bool:
	var raw_value: Variant = _get_setting_value_for_world(key)
	if raw_value is bool:
		return raw_value
	if raw_value is Dictionary:
		var requirements: Dictionary = raw_value
		var required_count: int = int(requirements.get("count", 0))
		if required_count <= 0:
			return true
		return _get_special_condition_score(requirements) >= required_count
	return false

func _get_item_active_special_condition(item_data: Dictionary) -> String:
	var special_key: String = str(item_data.get("special_condition", "")).strip_edges()
	if special_key.is_empty():
		return ""
	if item_data.has("special_condition_if") and not _evaluate_item_condition(item_data["special_condition_if"]):
		return ""
	return special_key

func _replace_placeholder(data: Variant, placeholder: String, replacement: String) -> void:
	if data is Dictionary:
		for key: Variant in data:
			if typeof(data[key]) == TYPE_STRING and data[key] == placeholder:
				data[key] = replacement
			elif data[key] is Dictionary or data[key] is Array:
				_replace_placeholder(data[key], placeholder, replacement)
	elif data is Array:
		for i: int in range(data.size()):
			if typeof(data[i]) == TYPE_STRING and data[i] == placeholder:
				data[i] = replacement
			elif data[i] is Dictionary or data[i] is Array:
				_replace_placeholder(data[i], placeholder, replacement)

func _evaluate_item_condition(condition: Variant, visited_macros: Dictionary = {}) -> bool:
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab:
		return false
		
	if condition is Dictionary:
		if condition.has("macro"):
			var macro_name: String = str(condition["macro"]).strip_edges()
			var param_val: String = str(condition.get("param", "")).strip_edges()
			return LogicEvaluator.evaluate_macro(macro_name, current_world, param_val)

		if condition.has("and"):
			for sub_cond: Variant in condition["and"]:
				if not _evaluate_item_condition(sub_cond, visited_macros):
					return false
			return true
		elif condition.has("or"):
			for sub_cond: Variant in condition["or"]:
				if _evaluate_item_condition(sub_cond, visited_macros):
					return true
			return false
		elif condition.has("not"):
			return not _evaluate_item_condition(condition["not"], visited_macros)
		elif condition.has("name"):
			var display_name: String = str(condition["name"]).strip_edges()
			var required_count: int = condition.get("count", 1)
			var internal_name: String = _get_internal_name_by_display_name(display_name)
			if internal_name.is_empty():
				return false
			if display_name.begins_with("Stray Fairy (") and not condition.has("count"):
				var is_temple_fairy: bool = (
					display_name.contains("Woodfall") or 
					display_name.contains("Snowhead") or 
					display_name.contains("Great Bay") or 
					display_name.contains("Stone Tower")
				)
				if is_temple_fairy:
					var fairy_req = _get_setting_value_for_world("strayFairyRewardCount")
					if fairy_req != null:
						required_count = int(fairy_req)
			var current_count: int = get_item_count(internal_name, current_world)
			if is_item_checked(internal_name, current_world):
				current_count = max(current_count, 1)
			return current_count >= required_count
		elif condition.has("setting"):
			var setting_key: String = str(condition["setting"])
			var expected_value: Variant = condition.get("value", true)
			var operator: String = str(condition.get("operator", "=="))
			var actual_value: Variant = _get_setting_value_for_world(setting_key)
			
			if operator != "==":
				var actual_num: float = float(actual_value) if actual_value != null else 0.0
				var expected_num: float = float(expected_value) if expected_value != null else 0.0
				match operator:
					"<": return actual_num < expected_num
					">": return actual_num > expected_num
					"<=": return actual_num <= expected_num
					">=": return actual_num >= expected_num
					"!=": return actual_num != expected_num
					_: return _compare_item_values(actual_value, expected_value, settings_tab)
			else:
				return _compare_item_values(actual_value, expected_value, settings_tab)
		elif condition.has("bottle_group"):
			return _check_has_usable_bottle(str(condition["bottle_group"]), condition.get("exclude_content", ""), current_world)
		elif condition.has("bottle_content"):
			return _check_bottle_content_exists(str(condition["bottle_content"]), current_world)
		elif condition.has("location_item"):
			var target_item: String = str(condition["location_item"]).strip_edges().to_lower()
			var main_node: Node = get_tree().get_first_node_in_group("main_scene")
			if not main_node or not main_node.has_method("get_all_data"):
				return false
			for data: Dictionary in main_node.get_all_data():
				if int(data.get("world", 1)) != current_world:
					continue
				var item_name: String = str(data.get("item", "")).strip_edges().to_lower()
				if item_name == target_item and bool(data.get("checked", false)):
					return true
			return false
		elif condition.has("location"):
			var main_node: Node = get_tree().get_first_node_in_group("main_scene")
			return main_node.is_location_checked(str(condition["location"]), current_world) if main_node and main_node.has_method("is_location_checked") else false
		elif condition.has("entrance"):
			var entrance_val: Variant = condition["entrance"]
			var ent_list: Array = []
			if typeof(entrance_val) == TYPE_STRING:
				ent_list.append({"code": entrance_val})
			elif typeof(entrance_val) == TYPE_ARRAY:
				for c: Variant in entrance_val:
					ent_list.append({"code": str(c)} if c is String else c)
			elif typeof(entrance_val) == TYPE_DICTIONARY:
				ent_list.append(entrance_val)

			for ent: Dictionary in ent_list:
				var c: String = str(ent.get("code", "")).strip_edges()
				if c.is_empty(): continue
				if not LogicEvaluator.is_code_reachable_in_current_marker(c, current_world):
					continue
				var l: Dictionary = ent.get("logic", {})
				if not l.is_empty() and not _evaluate_item_condition(l, visited_macros):
					continue
				return true
			return false
		
		elif condition.has("entrance_unshuffled"):
			return LogicEvaluator.evaluate_entrance_unshuffled(
				condition["entrance_unshuffled"],
				current_world
			)
		
		elif condition.has("entrance_prefix"):
			var prefix: String = str(condition["entrance_prefix"]).strip_edges()
			
			if _all_oot_entrances.is_empty() and _all_mm_entrances.is_empty():
				_cache_game_entrances()
				
			var entrances_to_check: Array = []
			if prefix == "OOT_":
				entrances_to_check = _all_oot_entrances
			elif prefix == "MM_":
				entrances_to_check = _all_mm_entrances
				
			for c: String in entrances_to_check:
				if LogicEvaluator.is_code_reachable_in_current_marker(c, current_world):
					return true
			return false
		elif condition.has("song_event"):
			var event_id: String = str(condition["song_event"]).strip_edges()
			if event_id.is_empty():
				return true
			var song_idx: int = get_song_event_song_index(event_id, current_world)
			if song_idx < 0:
				return false
			
			var is_mm: bool = false
			for item_data: Dictionary in tracker_items:
				if str(item_data.get("type", "")) == "event_song" and str(item_data.get("event_id", "")).strip_edges() == event_id:
					var games: Variant = item_data.get("cond", {}).get("games", [])
					if games is Array:
						for g: Variant in games:
							if str(g) == "mm": is_mm = true; break
							elif str(g) == "oot": is_mm = false; break
					break
			
			var macros_array: Array = LogicEvaluator.SONG_MACROS_MM_ARR if is_mm else LogicEvaluator.SONG_MACROS_OOT_ARR
			if song_idx < 0 or song_idx >= macros_array.size():
				return false
			var required_macro: String = macros_array[song_idx]
			return _evaluate_item_condition({"macro": required_macro}, visited_macros)
		elif condition.has("special_condition"):
			return _is_special_condition_met(str(condition["special_condition"]).strip_edges())
		elif condition.has("game"):
			return LogicEvaluator.is_game_reachable(str(condition["game"]), current_world)
		else:
			for key: Variant in condition:
				var expected_value: Variant = condition[key]
				var actual_value: Variant = _get_setting_value_for_world(str(key))
				if not _compare_item_values(actual_value, expected_value, settings_tab):
					return false
			return true
			
	elif condition is Array:
		for sub_cond: Variant in condition:
			if _evaluate_item_condition(sub_cond, visited_macros):
				return true
		return false
		
	return true

func _get_internal_name_by_display_name(display_name: String) -> String:
	var target: String = display_name.strip_edges().to_lower()
	for data: Dictionary in tracker_items:
		var raw_name: Variant = data.get("name", "")
		if raw_name is String and raw_name.strip_edges().to_lower() == target:
			return _get_internal_name(data)
		elif raw_name is Dictionary:
			if str(raw_name.get("default", "")).strip_edges().to_lower() == target:
				return _get_internal_name(data)
			var variants: Array = raw_name.get("variants", [])
			for v: Variant in variants:
				if v is Dictionary and str(v.get("name", "")).strip_edges().to_lower() == target:
					return _get_internal_name(data)
	return ""

func _compare_item_values(actual_value: Variant, expected_value: Variant, _settings_tab: Node) -> bool:
	var match_found: bool = false
	if typeof(expected_value) == TYPE_ARRAY:
		if expected_value.is_empty():
			if typeof(actual_value) == TYPE_ARRAY:
				match_found = actual_value.is_empty()
			elif typeof(actual_value) == TYPE_DICTIONARY:
				var all_empty: bool = true
				for p_key: Variant in actual_value:
					if typeof(actual_value[p_key]) == TYPE_ARRAY and not (actual_value[p_key] as Array).is_empty():
						all_empty = false
						break
				match_found = all_empty
			else:
				match_found = false
		else:
			if typeof(actual_value) == TYPE_ARRAY:
				for item: Variant in actual_value:
					for exp_item: Variant in expected_value:
						if _is_equal_safe(item, exp_item):
							match_found = true
							break
					if match_found: break
			else:
				for exp_item: Variant in expected_value:
					if _is_equal_safe(actual_value, exp_item):
						match_found = true
						break
	elif typeof(expected_value) == TYPE_DICTIONARY:
		if expected_value.has("not"):
			var not_val: Variant = expected_value["not"]
			var is_in: bool = false
			if typeof(not_val) == TYPE_ARRAY:
				if typeof(actual_value) == TYPE_ARRAY:
					for actual_item: Variant in actual_value:
						for not_item: Variant in not_val:
							if _is_equal_safe(actual_item, not_item):
								is_in = true
								break
						if is_in: break
				else:
					for not_item: Variant in not_val:
						if _is_equal_safe(actual_value, not_item):
							is_in = true
							break
			else:
				if typeof(actual_value) == TYPE_ARRAY:
					for actual_item: Variant in actual_value:
						if _is_equal_safe(actual_item, not_val):
							is_in = true
							break
				else:
					is_in = _is_equal_safe(actual_value, not_val)
			match_found = not is_in
		elif expected_value.has("eq"):
			match_found = _is_equal_safe(actual_value, _get_setting_value_for_world(str(expected_value["eq"])))
		else:
			match_found = _evaluate_item_condition(expected_value)
	else:
		match_found = _is_equal_safe(actual_value, expected_value)
	return match_found

func _is_equal_safe(a: Variant, b: Variant) -> bool:
	if typeof(a) == typeof(b):
		return a == b
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if (typeof(a) == TYPE_BOOL and typeof(b) in [TYPE_INT, TYPE_FLOAT]) or (typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) == TYPE_BOOL):
		return bool(a) == bool(b)
	return str(a) == str(b)

func _get_max_value(item_data: Dictionary) -> int:
	var settings_tab: Node = _settings_tab_cache
	if item_data.has("max_conditions"):
		var conditions: Array = item_data["max_conditions"]
		if conditions is Array and settings_tab and settings_tab.has_method("get_setting_value"):
			for cond_data: Variant in conditions:
				if cond_data is Dictionary and cond_data.has("if"):
					if _evaluate_item_condition(cond_data["if"]):
						var cond_max: Variant = cond_data.get("max", 9999)
						if typeof(cond_max) in [TYPE_INT, TYPE_FLOAT]:
							return int(cond_max)
						elif typeof(cond_max) == TYPE_STRING:
							var setting_value: Variant = settings_tab.get_setting_value(cond_max)
							if typeof(setting_value) in [TYPE_INT, TYPE_FLOAT]:
								return int(setting_value)
						return 9999
	var max_setting: Variant = item_data.get("max", 9999)
	var shared_key: String = item_data.get("shared_key", "")
	if not shared_key.is_empty() and settings_tab and settings_tab.has_method("get_setting_value"):
		if settings_tab.get_setting_value(shared_key) == true and item_data.has("shared_max"):
			max_setting = item_data["shared_max"]
	if typeof(max_setting) == TYPE_STRING:
		if settings_tab and settings_tab.has_method("get_setting_value"):
			var setting_value: Variant = settings_tab.get_setting_value(max_setting)
			if setting_value != null:
				if typeof(setting_value) in [TYPE_INT, TYPE_FLOAT]:
					return int(setting_value)
				elif setting_value is Dictionary:
					if setting_value.has(current_world):
						var world_val: Variant = setting_value[current_world]
						if typeof(world_val) in [TYPE_INT, TYPE_FLOAT]:
							return int(world_val)
		return _get_default_max_for_setting(max_setting)
	if typeof(max_setting) in [TYPE_INT, TYPE_FLOAT]:
		return int(max_setting)
	return 9999

func _get_default_max_for_setting(setting_key: String) -> int:
	match setting_key:
		"triforcePieces":
			return 30
		"triforceGoal":
			return 20
		"coinsRed", "coinsGreen", "coinsBlue", "coinsYellow":
			return 0
		_:
			return 9999

func reset_triforce_progress() -> void:
	var changed: bool = false
	
	var worlds_count: int = 1
	if _main_scene_cache and _main_scene_cache.has_method("get_worlds_count"):
		worlds_count = int(_main_scene_cache.get_worlds_count())
	elif world_filter and world_filter.item_count > 0:
		worlds_count = world_filter.item_count
		
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		var tags: Variant = item_data.get("special_tags", [])
		if tags is String:
			tags = [tags]
			
		var is_triforce_item: bool = false
		if tags is Array and tags.has("triforce"):
			is_triforce_item = true
		else:
			var cond: Variant = item_data.get("cond", {})
			if cond is Dictionary and cond.get("goal") == "triforce3":
				is_triforce_item = true
				
		if is_triforce_item:
			var item_type: String = str(item_data.get("type", "toggle"))
			for w: int in range(1, worlds_count + 1):
				if item_type == "count":
					if get_item_count(item_name, w) != 0:
						set_item_count(item_name, 0, w)
						changed = true
				elif item_type == "toggle":
					if is_item_checked(item_name, w):
						set_item_checked(item_name, w, false)
						changed = true
						
	if changed:
		_request_widgets_update()
		request_save_checked_items()

func _evaluate_simple_cond(cond: Dictionary, _settings_tab: Node) -> bool:
	for key: Variant in cond:
		if not _is_equal_safe(_get_setting_value_for_world(str(key)), cond[key]):
			return false
	return true

func _is_level_valid(item_data: Dictionary, absolute_level: int) -> bool:
	var images_array: Array = item_data.get("images", [])
	if images_array.is_empty():
		return item_data.has("image") and str(item_data["image"]) != ""
	if absolute_level < 1 or absolute_level > images_array.size():
		return false
	var img_data: Variant = images_array[absolute_level - 1]
	if img_data is Dictionary and img_data.has("if"):
		var settings_tab: Node = _settings_tab_cache
		return settings_tab and settings_tab.has_method("get_setting_value") and _evaluate_simple_cond(img_data["if"], settings_tab)
	return true

func _get_effective_max_level(item_data: Dictionary) -> int:
	var base_max: int = _get_dynamic_max_level(item_data)
	while base_max > 0 and not _is_level_valid(item_data, base_max):
		base_max -= 1
	return base_max

func _get_effective_min_level(item_data: Dictionary) -> int:
	var base_min: int = _get_dynamic_min_level(item_data)
	if base_min == 0: return 0
	var max_level: int = _get_dynamic_max_level(item_data)
	while base_min <= max_level and not _is_level_valid(item_data, base_min):
		base_min += 1
	return base_min

func _get_dynamic_min_level(item_data: Dictionary) -> int:
	if not item_data.has("min_conditions"):
		return 0
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab: return 0
	for cond_data: Dictionary in item_data["min_conditions"]:
		if cond_data.has("if") and _evaluate_simple_cond(cond_data["if"], settings_tab):
			return int(cond_data.get("min", 0))
	return 0

func _get_bound_setting_keys(item_data: Dictionary) -> Array:
	var keys: Array = []
	for cond: Dictionary in item_data.get("min_conditions", []):
		if cond.has("if") and cond["if"] is Dictionary:
			keys.append_array(cond["if"].keys())
	for cond: Dictionary in item_data.get("max_conditions", []):
		if cond.has("if") and cond["if"] is Dictionary:
			keys.append_array(cond["if"].keys())
	for img_data: Variant in item_data.get("images", []):
		if img_data is Dictionary:
			if img_data.has("if") and img_data["if"] is Dictionary:
				keys.append_array(img_data["if"].keys())
			for cond_key: String in ["hide_if", "show_if"]:
				if img_data.has(cond_key) and img_data[cond_key] is Dictionary:
					keys.append_array(img_data[cond_key].keys())
			if img_data.has("variants") and img_data["variants"] is Array:
				for variant: Variant in img_data["variants"]:
					if variant is Dictionary and variant.has("if") and variant["if"] is Dictionary:
						keys.append_array(variant["if"].keys())
	return keys

func reset_progressive_bounds(changed_key: String) -> void:
	var changed: bool = false
	var shared_keys_to_reset: Array = []
	var settings_tab: Node = _settings_tab_cache

	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		if item_data.get("type") != "progressive":
			continue
		if changed_key in _get_bound_setting_keys(item_data):
			var shared_key: String = item_data.get("shared_key", "")
			if not shared_key.is_empty() and settings_tab and settings_tab.has_method("get_setting_value"):
				if settings_tab.get_setting_value(shared_key) == true and not shared_keys_to_reset.has(shared_key):
					shared_keys_to_reset.append(shared_key)

			var min_level: int = _get_effective_min_level(item_data)
			if get_item_count(item_name, current_world) != min_level:
				set_item_count(item_name, min_level, current_world)
				changed = true

	if not shared_keys_to_reset.is_empty():
		for item_name: String in item_widgets:
			var item_data: Dictionary = item_widgets[item_name]["data"]
			if item_data.get("type") != "progressive":
				continue
			if item_data.get("shared_key", "") in shared_keys_to_reset:
				var min_level: int = _get_effective_min_level(item_data)
				if get_item_count(item_name, current_world) != min_level:
					set_item_count(item_name, min_level, current_world)
					changed = true

	if changed:
		_request_widgets_update()
		request_save_checked_items()

func reset_progressive_groups(changed_key: String) -> void:
	var changed: bool = false
	for item_name: String in item_widgets:
		var data: Dictionary = item_widgets[item_name]["data"]
		if not data.has("progressive_group"):
			continue
		var setting_key: String = _get_progressive_setting_for_item(data)
		var shared_key: String = data.get("shared_key", "")
		if setting_key == changed_key or shared_key == changed_key:
			if is_item_checked(item_name, current_world):
				set_item_checked(item_name, current_world, false)
				changed = true
	if changed:
		_request_widgets_update()
		request_save_checked_items()

func _get_dynamic_max_level(item_data: Dictionary) -> int:
	var default_max: int = item_data.get("default_max", 0)
	if default_max == 0: default_max = item_data.get("max", 0)
	if default_max == 0: default_max = item_data.get("images", []).size()
	if default_max == 0 and item_data.has("image") and str(item_data["image"]) != "":
		default_max = 1
	if not item_data.has("max_conditions"):
		return default_max
		
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab: return default_max
	for cond_data: Dictionary in item_data["max_conditions"]:
		if cond_data.has("if") and _evaluate_simple_cond(cond_data["if"], settings_tab):
			return int(cond_data.get("max", default_max))
	return default_max

func _is_song_notes_mode() -> bool:
	var settings_tab: Node = _settings_tab_cache
	return settings_tab and settings_tab.has_method("get_setting_value") and settings_tab.get_setting_value("songs") == "notes"

func _get_song_progressive_setting(item_data: Dictionary) -> String:
	return str(item_data.get("progressive_setting", "")).strip_edges()

func _is_song_progressive(item_data: Dictionary) -> bool:
	var setting_key: String = _get_song_progressive_setting(item_data)
	if setting_key.is_empty():
		return false
	var settings_tab: Node = _settings_tab_cache
	return settings_tab and settings_tab.has_method("get_setting_value") and str(settings_tab.get_setting_value(setting_key)) == "progressive"

func _get_song_progressive_levels(item_data: Dictionary) -> int:
	return int(item_data.get("progressive_levels", 2))

func _get_song_progressive_note_threshold(item_data: Dictionary) -> int:
	return int(item_data.get("progressive_note_threshold", 6))

func _get_song_effective_max(item_data: Dictionary) -> int:
	if _is_song_progressive(item_data) and not _is_song_notes_mode():
		return _get_song_progressive_levels(item_data)
	return _get_song_max(item_data)

func _get_song_image_for_count(item_data: Dictionary, current_count: int) -> String:
	if current_count <= 0:
		return ""
	if _is_song_progressive(item_data):
		var images: Array = item_data.get("progressive_images", [])
		if images is Array and images.size() >= 2:
			if _is_song_notes_mode():
				return str(images[1]) if current_count >= _get_song_progressive_note_threshold(item_data) else str(images[0])
			else:
				return str(images[1]) if current_count >= 2 else str(images[0])
	return str(item_data.get("image", ""))

func _get_song_max(item_data: Dictionary) -> int:
	if item_data.has("notes"): return int(item_data["notes"])
	if item_data.has("max"): return int(item_data["max"])
	return 1

func _get_song_count(item_name: String, world: int, max_notes: int) -> int:
	var raw: Variant = checked_items.get(str(world) + "_" + item_name, 0)
	return max_notes if typeof(raw) == TYPE_BOOL and raw else int(raw)

func _on_item_pressed(item_name: String, _button: TextureButton, is_right_click: bool = false) -> void:
	_cache_batch_begin()
	_on_item_pressed_inner(item_name, _button, is_right_click)
	_cache_batch_end()

func _on_item_pressed_inner(item_name: String, _button: TextureButton, is_right_click: bool = false) -> void:
	var lock_data: Dictionary = item_widgets.get(item_name, {}).get("data", {})
	if not _get_item_active_special_condition(lock_data).is_empty():
		return
	var item_data: Dictionary = item_widgets.get(item_name, {}).get("data", {})
	if not _check_item_availability(item_data) or _is_auto_checked(item_data) or item_data.get("always_checked", false):
		return
		
	if item_data.get("type", "") == "bottle":
		if is_right_click:
			var contents: Array = _get_bottle_contents(item_data)
			if not contents.is_empty():
				var content_index: int = get_bottle_content_index(item_name, current_world)
				set_bottle_content_index(item_name, (content_index + 1) % contents.size(), current_world)
		else:
			set_item_checked(item_name, current_world, not is_item_checked(item_name, current_world))
		var bottle_button: TextureButton = item_widgets.get(item_name, {}).get("button")
		if bottle_button:
			_update_item_button_state(bottle_button, item_data, _check_item_availability(item_data))
		request_save_checked_items()
		return
	
	var settings_tab: Node = _settings_tab_cache
	if item_data.has("progressive_group"):
		var setting_key: String = _get_progressive_setting_for_item(item_data)
		var progressive_mode: String = _get_progressive_mode_by_key(setting_key)
		
		var item_modes: Array = item_data.get("progressive_modes", [])
		var actual_mode: String = progressive_mode
		if actual_mode in ["ascending", "descending"]:
			actual_mode = "progressive"
		
		var equip_settings: Array = [
			"progressiveChildSwordsOot", "progressiveChildSwordsMm",
			"progressiveSwordsOot", "progressiveSwordsMm",
			"progressiveGFSOot", "progressiveGFSMm",
			"progressiveShieldsOot", "progressiveShieldsMm",
			"progressiveShieldsShared"
		]
		
		if setting_key in equip_settings:
			if not item_modes.is_empty() and not item_modes.has(actual_mode):
				_toggle_single_item_with_shared(item_name, not is_right_click)
			elif progressive_mode == "separate" or progressive_mode.is_empty():
				_toggle_single_item_with_shared(item_name, not is_right_click)
			else:
				_handle_equipment_progressive_click(item_data, is_right_click)
			request_save_checked_items()
			return
		
		if item_modes.is_empty() or item_modes.has(actual_mode):
			if progressive_mode == "progressive":
				progressive_mode = "ascending"
			var shared_key: String = item_data.get("shared_key", "")
			var is_shared: bool = not shared_key.is_empty() and settings_tab and settings_tab.has_method("get_setting_value") and settings_tab.get_setting_value(shared_key) == true
			
			if progressive_mode == "separate":
				var target_index: int = item_data.get("progressive_index", -1)
				if target_index != -1:
					_toggle_progressive_index(target_index, not is_right_click, is_shared, shared_key, item_data.get("progressive_group"))
			else:
				_handle_progressive_click(item_data, is_right_click)
			request_save_checked_items()
			return
			
	var items_to_toggle: Array = _get_linked_items(item_data)
	for target_name: String in items_to_toggle:
		var target_data: Dictionary = item_widgets.get(target_name, {}).get("data", {})
		var target_type: String = target_data.get("type", "toggle")
		
		if target_type == "count":
			var current_count: int = get_item_count(target_name, current_world)
			var max_val: int = _get_max_value(target_data)
			if is_right_click:
				if current_count > 0: set_item_count(target_name, current_count - 1, current_world)
			else:
				if current_count < max_val: set_item_count(target_name, current_count + 1, current_world)
				
		elif target_type == "progressive":
			var current_level: int = get_item_count(target_name, current_world)
			var min_level: int = _get_effective_min_level(target_data)
			var max_level: int = _get_effective_max_level(target_data)
			
			if is_right_click:
				var next_level: int = current_level - 1
				while next_level > 0 and not _is_level_valid(target_data, next_level):
					next_level -= 1
				set_item_count(target_name, max(next_level, min_level) if min_level > 0 else next_level, current_world)
			else:
				var next_level: int = current_level + 1
				while next_level <= max_level and not _is_level_valid(target_data, next_level):
					next_level += 1
				if next_level <= max_level:
					set_item_count(target_name, next_level, current_world)
						
		elif target_type == "song":
			var progressive_song: bool = _is_song_progressive(target_data)
			var effective_max: int = _get_song_effective_max(target_data)
			var current_count: int = _get_song_count(target_name, current_world, effective_max)

			if _is_song_notes_mode():
				set_item_count(target_name, clamp(current_count + (-1 if is_right_click else 1), 0, effective_max), current_world)
			else:
				if progressive_song:
					set_item_count(target_name, clamp(current_count + (-1 if is_right_click else 1), 0, effective_max), current_world)
				else:
					set_item_count(target_name, 0 if is_right_click else effective_max, current_world)
		else:
			set_item_checked(target_name, current_world, not is_right_click)
					
	var clicked_widget: Dictionary = item_widgets.get(item_name, {})
	if not clicked_widget.is_empty():
		var cbtn: TextureButton = clicked_widget.get("button")
		var cdata: Dictionary = clicked_widget.get("data", {})
		if cbtn and not cdata.is_empty():
			_update_item_button_state(cbtn, cdata, _check_item_availability(cdata))

	_reset_items_failing_count_requirements()
	_request_widgets_update()
	request_save_checked_items()

func _handle_progressive_click(item_data: Dictionary, is_right_click: bool) -> void:
	var group_name: Variant = item_data.get("progressive_group")
	var shared_key: String = item_data.get("shared_key", "")
	var is_shared: bool = not shared_key.is_empty() and _settings_tab_cache and _settings_tab_cache.has_method("get_setting_value") and _settings_tab_cache.get_setting_value(shared_key) == true

	var progressive_mode: String = "ascending"
	var setting_key: String = _get_progressive_setting_for_item(item_data)
	if not setting_key.is_empty() and _settings_tab_cache and _settings_tab_cache.has_method("get_setting_value"):
		var mode_val: Variant = _settings_tab_cache.get_setting_value(setting_key)
		if mode_val != null:
			progressive_mode = str(mode_val)
	if progressive_mode == "progressive":
		progressive_mode = "ascending"

	var group_items: Array = []
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if not data.has("progressive_index"):
			continue
		
		var match_group: bool = false
		if is_shared:
			match_group = data.get("shared_key", "") == shared_key
		else:
			match_group = data.get("progressive_group", "") == group_name
		
		if not match_group:
			continue
		
		var item_setting_key: String = _get_progressive_setting_for_item(data)
		var item_progressive_mode: String = "ascending"
		if not item_setting_key.is_empty() and _settings_tab_cache and _settings_tab_cache.has_method("get_setting_value"):
			var item_mode_val: Variant = _settings_tab_cache.get_setting_value(item_setting_key)
			if item_mode_val != null:
				item_progressive_mode = str(item_mode_val)
		if item_progressive_mode == "progressive":
			item_progressive_mode = "ascending"
		
		if item_progressive_mode != progressive_mode:
			continue
		
		var item_modes: Array = data.get("progressive_modes", [])
		var actual_mode: String = progressive_mode
		if actual_mode in ["ascending", "descending"]:
			actual_mode = "progressive"
		if not item_modes.is_empty() and not item_modes.has(actual_mode):
			continue
			
		group_items.append({"name": widget_name, "index": data.get("progressive_index", 0), "data": data})

	var unique_items: Dictionary = {}
	for item: Dictionary in group_items:
		unique_items[item["name"]] = item
	group_items = unique_items.values()
	group_items.sort_custom(func(a: Dictionary, b: Dictionary): return a["index"] < b["index"])

	var anchor_index: int = -1
	if group_name == "clocks" and progressive_mode != "separate":
		if progressive_mode == "ascending":
			anchor_index = 1
		elif progressive_mode == "descending":
			var max_idx: int = 0
			for item_info: Dictionary in group_items:
				if item_info["index"] > max_idx:
					max_idx = item_info["index"]
			anchor_index = max_idx

	var available_indices: Array = []
	for item_info: Dictionary in group_items:
		var idx: int = item_info["index"]
		if idx in available_indices:
			continue
		var has_available: bool = false
		for other_info: Dictionary in group_items:
			if other_info["index"] == idx and _check_item_availability(other_info["data"]):
				has_available = true
				break
		if has_available:
			available_indices.append(idx)
			
	available_indices.sort()
	if progressive_mode == "descending":
		available_indices.reverse()
	if available_indices.is_empty():
		return

	var target_index: int = -1
	if not is_right_click:
		for idx: int in available_indices:
			if idx == anchor_index:
				continue
			var idx_all_checked: bool = true
			for item_info: Dictionary in group_items:
				if item_info["index"] == idx and _check_item_availability(item_info["data"]):
					if not is_item_checked(item_info["name"], current_world):
						idx_all_checked = false
						break
			if not idx_all_checked:
				target_index = idx
				break
	else:
		for i: int in range(available_indices.size() - 1, -1, -1):
			var idx: int = available_indices[i]
			if idx == anchor_index:
				continue
			var idx_has_checked: bool = false
			for item_info: Dictionary in group_items:
				if item_info["index"] == idx and _check_item_availability(item_info["data"]):
					if is_item_checked(item_info["name"], current_world):
						idx_has_checked = true
						break
			if idx_has_checked:
				target_index = idx
				break

	if target_index != -1:
		_toggle_progressive_index(target_index, not is_right_click, is_shared, shared_key, str(group_name))
	request_save_checked_items()

func sync_progressive_mode(_changed_key: String) -> void:
	if _changed_key != "progressiveClocks" and _changed_key != "clocks" and _changed_key != "clocksMm":
		return
	var progressive_mode: String = _get_clocks_progressive_mode()
	if progressive_mode == "separate":
		_last_clocks_mode = ""
		return
	if progressive_mode == _last_clocks_mode:
		return
	var old_anchor: int = _anchor_for_mode(_last_clocks_mode)
	_last_clocks_mode = progressive_mode
	_set_clock_checked(old_anchor, current_world, false)
	_set_clock_checked(_anchor_for_mode(progressive_mode), current_world, true)
	request_save_checked_items()
	_update_all_widgets()

func _anchor_for_mode(mode: String) -> int:
	if mode == "ascending": return 1
	if mode == "descending": return 6
	return -1

func _get_clocks_progressive_mode() -> String:
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab or settings_tab.get_setting_value("clocksMm") != true:
		return "separate"
	var mode: String = str(settings_tab.get_setting_value("progressiveClocks"))
	return "ascending" if mode == "progressive" else mode

func _set_clock_checked(index: int, world: int, checked: bool) -> void:
	if index == -1:
		return
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if data.get("progressive_group") == "clocks" and int(data.get("progressive_index", -1)) == index:
			if _check_item_availability(data):
				set_item_checked(widget_name, world, checked)

func sync_all_tracker_states() -> void:
	_cache_batch_begin()
	sync_auto_checked_items()
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		if not _check_item_availability(item_data) and item_data.get("type", "toggle") == "toggle":
			if is_item_checked(item_name, current_world):
				set_item_checked(item_name, current_world, false)
	sync_progressive_mode("clocks")
	_reset_items_failing_count_requirements()
	_update_all_widgets()
	request_save_checked_items()
	_cache_item_states()
	_cache_mq_state()
	_cache_batch_end()

func _get_state_reset_keys(item_data: Dictionary) -> Array:
	var keys: Array = []
	if item_data.has("cond"):
		_collect_dependency_keys_from_condition(item_data["cond"], keys)
	for req: Variant in item_data.get("requires_count", []):
		if req is Dictionary and req.has("if"):
			_collect_dependency_keys_from_condition(req["if"], keys)
	if item_data.has("auto_check_setting"):
		_add_dependency_key(keys, str(item_data["auto_check_setting"]))
	if str(item_data.get("type", "")) == "song":
		_add_dependency_key(keys, "songs")
	var progressive_setting: String = str(item_data.get("progressive_setting", "")).strip_edges()
	if not progressive_setting.is_empty():
		_add_dependency_key(keys, progressive_setting)
	if str(item_data.get("shared_key", "")) == "sharedNutsSticks":
		_add_dependency_key(keys, "sticksNutsUpgradesInitial")
	
	var tags: Variant = item_data.get("special_tags", [])
	if tags is String:
		tags = [tags]
	if tags is Array and tags.has("triforce"):
		_add_dependency_key(keys, "goal")
		_add_dependency_key(keys, "triforcePieces")
		_add_dependency_key(keys, "triforceGoal")
		_add_dependency_key(keys, "triforceSharedMulti")
		
	var cond: Variant = item_data.get("cond", {})
	if cond is Dictionary and cond.get("goal") == "triforce3":
		_add_dependency_key(keys, "goal")
		_add_dependency_key(keys, "triforceSharedMulti")
	
	return keys

func _toggle_progressive_index(target_index: int, set_checked: bool, is_shared: bool, shared_key: String, current_group: String) -> void:
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if data.get("progressive_index") != target_index:
			continue
		var item_shared_key: String = data.get("shared_key", "")
		var item_group: String = data.get("progressive_group", "")
		var should_toggle: bool = (is_shared and item_shared_key == shared_key) or (not is_shared and item_group == current_group)
		
		if should_toggle and _check_item_availability(data):
			set_item_checked(widget_name, current_world, set_checked)
			var target_button: TextureButton = item_widgets.get(widget_name, {}).get("button")
			if target_button:
				_update_item_button_state(target_button, data, true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return

		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner != null and (focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox):
			return

		if key_event.keycode == KEY_F1 or key_event.keycode == KEY_F2 or key_event.keycode == KEY_F3:
			return
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_5:
			return

		get_viewport().set_input_as_handled()
		return

func _on_item_input(event: InputEvent, item_name: String, button: TextureButton) -> void:
	var lock_data: Dictionary = item_widgets.get(item_name, {}).get("data", {})
	if not _get_item_active_special_condition(lock_data).is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_on_item_pressed(item_name, button, true)

func _remove_number_labels(button: TextureButton) -> void:
	var children_to_remove: Array = []
	for child: Node in button.get_children():
		if child is TextureRect and child.name.begins_with("digit"):
			children_to_remove.append(child)
	for child: Node in children_to_remove:
		child.free()

func _add_number_labels(button: TextureButton, count: int, is_maxed: bool) -> void:
	if count <= 0:
		return
	var digits: Array = []
	var temp_count: int = count
	while temp_count > 0:
		digits.push_front(temp_count % 10)
		temp_count /= 10
	if digits.is_empty():
		digits.push_front(0)
	if digits.size() > 4:
		digits = digits.slice(0, 4)
		
	var button_size: Vector2 = button.size
	var digit_width: float = 8
	var start_x: float = button_size.x - (digits.size() * digit_width)
	
	for i: int in range(digits.size()):
		var digit: int = digits[i]
		var suffix: String = "_max" if is_maxed else ""
		var digit_path: String = "res://images/numbers/" + str(digit) + suffix + ".png"
		if ResourceLoader.exists(digit_path):
			var digit_rect := TextureRect.new()
			digit_rect.name = "digit_" + str(i)
			digit_rect.texture = load(digit_path) as Texture2D
			digit_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			digit_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			digit_rect.custom_minimum_size = Vector2(digit_width, 12)
			digit_rect.position = Vector2(start_x + (i * digit_width), button_size.y - 12)
			digit_rect.size_flags_horizontal = Control.SIZE_SHRINK_END
			digit_rect.size_flags_vertical = Control.SIZE_SHRINK_END
			button.add_child(digit_rect)

func _clear_all_widgets() -> void:
	var panels: Array = [
		get_collectibles_panel(), get_equipment_panel(), get_items_panel(),
		get_masks_panel(), get_songs_panel(), get_rusty_keys_panel(),
		get_dungeons_panel(), get_souls_panel(), get_song_events_panel()
	]
	for panel: TextureRect in panels:
		if panel:
			for child: Node in panel.get_children():
				if child is TextureButton:
					child.queue_free()

func _get_panel_by_name(panel_name: String) -> TextureRect:
	match panel_name:
		"collectible": return get_collectibles_panel()
		"equipment": return get_equipment_panel()
		"items": return get_items_panel()
		"masks": return get_masks_panel()
		"songs": return get_songs_panel()
		"rusty_keys": return get_rusty_keys_panel()
		"dungeons": return get_dungeons_panel()
		"souls": return get_souls_panel()
		"song_events": return get_song_events_panel()
		_: return null

func _get_shared_group_id(item_data: Dictionary) -> String:
	var shared_key: String = str(item_data.get("shared_key", ""))
	if shared_key.is_empty():
		return ""
	return shared_key + "::" + str(item_data.get("shared_group", shared_key))

func _load_checked_items() -> void:
	checked_items.clear()
	const CHECKED_ITEMS_PATH = "user://checked_items_tracker.json"
	if not FileAccess.file_exists(CHECKED_ITEMS_PATH):
		return
	var file := FileAccess.open(CHECKED_ITEMS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		checked_items = parsed

func _save_checked_items() -> void:
	const CHECKED_ITEMS_PATH = "user://checked_items_tracker.json"
	var file := FileAccess.open(CHECKED_ITEMS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(checked_items, "\t", false))
	file.close()

func load_checked_items(items: Dictionary) -> void:
	checked_items = items.duplicate(true)
	_sync_world_filter_from_main()
	sync_all_tracker_states()

func set_item_checked(item_name: String, world: int = 1, checked: bool = true) -> void:
	var actual_world = world
	if _is_triforce_shared(item_name):
		actual_world = 1
	var key: String = str(actual_world) + "_" + item_name.strip_edges()
	if checked_items.get(key, false) != checked:
		checked_items[key] = checked
		_mark_logic_dirty(item_name, actual_world)   # <- world

func _get_display_name_by_internal_name(internal_name: String) -> String:
	for data in tracker_items:
		if _get_internal_name(data) == internal_name:
			var raw_name: Variant = data.get("name", "")
			if raw_name is String:
				return raw_name
			elif raw_name is Dictionary:
				return str(raw_name.get("default", ""))
			return str(raw_name)
	return ""

var _batch_depth: int = 0
var _pending_item_changes: Dictionary = {}

func _cache_batch_begin() -> void:
	_batch_depth += 1
	_cache_batch_active = true
	LogicEvaluator.begin_batch()

func _cache_batch_end() -> void:
	_batch_depth -= 1
	if _batch_depth < 0:
		_batch_depth = 0
	_cache_batch_active = _batch_depth > 0
	if _batch_depth == 0 and not _pending_item_changes.is_empty():
		var full_reset: bool = _pending_item_changes.has("__all__")
		if full_reset:
			LogicEvaluator.invalidate_reachability()
		else:
			var by_world: Dictionary = {}
			for composite_key: String in _pending_item_changes:
				var sep: int = composite_key.find("|")
				var w_str: String = composite_key.substr(0, sep)
				var internal_name: String = composite_key.substr(sep + 1)
				var w: int = int(w_str) if w_str.is_valid_int() else -1
				var dn: String = _get_display_name_by_internal_name(internal_name)
				if dn.is_empty():
					continue
				if not by_world.has(w):
					by_world[w] = []
				if not by_world[w].has(dn):
					by_world[w].append(dn)
			for w: int in by_world:
				LogicEvaluator.invalidate_item_smart(by_world[w], w)
		_pending_item_changes.clear()
	LogicEvaluator.end_batch()

func _mark_logic_dirty(changed_item_internal_name: String = "", world: int = -1) -> void:
	var effective_world: int = world
	if not changed_item_internal_name.is_empty() and _is_triforce_shared(changed_item_internal_name):
		effective_world = -1

	if _cache_batch_active:
		if changed_item_internal_name.is_empty():
			_pending_item_changes["__all__"] = true
		else:
			_pending_item_changes[str(effective_world) + "|" + changed_item_internal_name] = true
		return

	if changed_item_internal_name.is_empty():
		LogicEvaluator.invalidate_reachability()
		return
	var display_name = _get_display_name_by_internal_name(changed_item_internal_name)
	if display_name.is_empty():
		LogicEvaluator.invalidate_reachability()
		return
	LogicEvaluator.invalidate_item_smart([display_name], effective_world)

func is_item_checked(item_name: String, world: int = 1) -> bool:
	var actual_world = world
	if _is_triforce_shared(item_name):
		actual_world = 1
	return checked_items.get(str(actual_world) + "_" + item_name.strip_edges(), false)

func toggle_item_checked(item_name: String, world: int = 1) -> void:
	var actual_world = world
	if _is_triforce_shared(item_name):
		actual_world = 1
	var key: String = str(actual_world) + "_" + item_name.strip_edges()
	checked_items[key] = not checked_items.get(key, false)
	_mark_logic_dirty(item_name, actual_world)

func get_item_count(item_name: String, world: int = 1) -> int:
	var actual_world = world
	if _is_triforce_shared(item_name):
		actual_world = 1
	return int(checked_items.get(str(actual_world) + "_" + item_name.strip_edges(), 0))

func set_item_count(item_name: String, count: int, world: int = 1) -> void:
	var actual_world = world
	if _is_triforce_shared(item_name):
		actual_world = 1
	var key: String = str(actual_world) + "_" + item_name.strip_edges()
	if checked_items.get(key, 0) != count:
		checked_items[key] = count
		_mark_logic_dirty(item_name, actual_world)

func _on_world_filter_selected(index: int) -> void:
	current_world = index + 1
	LogicEvaluator.invalidate_setting_cache(["smallKeyRingOot", "smallKeyRingMm", "silverRupeePouches", "openDungeonsOot", "openDungeonsMm", "ganonTrials", "clearStateDungeonsMm", "mmPreActivatedOwls", "mqDungeons", "jpLayouts"])
	sync_all_tracker_states()

func _update_all_widgets() -> void:
	for item_name: String in item_widgets:
		var widget_info: Dictionary = item_widgets[item_name]
		var button: TextureButton = widget_info.get("button")
		var item_data: Dictionary = widget_info.get("data")
		if button and item_data:
			var item_type: String = str(item_data.get("type", "toggle"))
			if item_type == "event_song":
				_update_song_event_button(button, item_data)
			elif item_type == "event_label":
				_update_event_label_button(button, item_data)
			else:
				_update_item_button_state(button, item_data, _check_item_availability(item_data))
				
	var map_tab: Node = get_tree().get_first_node_in_group("map_tab")
	if map_tab and map_tab.is_visible_in_tree():
		if map_tab.has_method("_sync_data_from_main"): map_tab._sync_data_from_main()
		if map_tab.has_method("request_counters_update"): map_tab.request_counters_update()
		if map_tab.has_method("refresh_quick_jump_visibility"): map_tab.refresh_quick_jump_visibility()
		if map_tab.has_method("refresh_entrance_markers_visibility"): map_tab.refresh_entrance_markers_visibility()
		if map_tab.has_method("refresh_location_markers_visibility"): map_tab.refresh_location_markers_visibility()
	
	var settings_tab: Node = get_tree().get_first_node_in_group("settings_tab")
	if settings_tab and settings_tab.has_method("refresh_price_visibilities"):
		settings_tab.refresh_price_visibilities()

func _clean_location_item_name(item_name: String) -> String:
	var s: String = item_name.strip_edges()
	var dash: int = s.find("-")
	if dash <= 0:
		return s
	var left: String = s.substr(0, dash).strip_edges()
	var right: String = s.substr(dash + 1).strip_edges()
	if right.is_empty():
		return s
	if left.begins_with("P") or left.begins_with("Player"):
		var num: String = left.substr(1 if left.begins_with("P") and not left.begins_with("Player") else 6).strip_edges()
		if num.is_valid_int():
			return right
	return s

func _step_progressive_group_from_location(seed_data: Dictionary, pressed: bool, world: int) -> void:
	var group_name: String = str(seed_data.get("progressive_group", ""))
	var shared_key: String = str(seed_data.get("shared_key", ""))
	var progressive_mode: String = _get_progressive_mode_for(seed_data)
	var settings_tab: Node = _settings_tab_cache
	var is_shared: bool = not shared_key.is_empty() and settings_tab and settings_tab.has_method("get_setting_value") and settings_tab.get_setting_value(shared_key) == true

	var group_items: Array = []
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if not data.has("progressive_index"):
			continue
		var item_modes: Array = data.get("progressive_modes", [])
		var actual_mode: String = progressive_mode
		if actual_mode in ["ascending", "descending"]:
			actual_mode = "progressive"
		if not item_modes.is_empty() and not item_modes.has(actual_mode):
			continue
		if (is_shared and str(data.get("shared_key", "")) == shared_key) or (not is_shared and str(data.get("progressive_group", "")) == group_name):
			group_items.append({"name": widget_name, "index": int(data.get("progressive_index", 0)), "data": data})
			
	group_items.sort_custom(func(a: Dictionary, b: Dictionary): return a["index"] < b["index"])
	var anchor_index: int = _anchor_for_mode(progressive_mode)
	
	if pressed:
		for it: Dictionary in group_items:
			if _check_item_availability(it["data"]) and _get_group_units(it["name"], it["data"], world) < _get_group_capacity(it["data"]):
				_add_group_unit(it["name"], it["data"], world)
				break
	else:
		for i: int in range(group_items.size() - 1, -1, -1):
			var it: Dictionary = group_items[i]
			if it["index"] == anchor_index:
				continue
			if _get_group_units(it["name"], it["data"], world) > 0:
				_remove_group_unit(it["name"], it["data"], world)
				break

func _get_progressive_mode_for(item_data: Dictionary) -> String:
	var setting_key: String = str(item_data.get("progressive_setting", ""))
	var mode: String = "separate"
	var settings_tab: Node = _settings_tab_cache
	if not setting_key.is_empty() and settings_tab and settings_tab.has_method("get_setting_value"):
		var mode_val: Variant = settings_tab.get_setting_value(setting_key)
		if mode_val != null:
			mode = str(mode_val)
	return "ascending" if mode == "progressive" else mode

func _get_progressive_mode_by_key(setting_key: String) -> String:
	if setting_key.is_empty() or not _settings_tab_cache:
		return "separate"
	if not _settings_tab_cache.has_method("get_setting_value"):
		return "separate"
	var v: Variant = _settings_tab_cache.get_setting_value(setting_key)
	return "separate" if v == null else str(v)

func _handle_equipment_progressive_click(item_data: Dictionary, is_right_click: bool) -> void:
	var group_name: String = str(item_data.get("progressive_group", ""))
	var chain_mode: String = _get_progressive_mode_by_key(_get_progressive_setting_for_item(item_data))
	
	if chain_mode == "separate" or chain_mode.is_empty():
		return
	
	var normalized: String = "progressive" if chain_mode in ["ascending", "descending"] else chain_mode
	var chain: Array = []
	
	for wname: String in item_widgets:
		var d: Dictionary = item_widgets[wname].get("data", {})
		if d.is_empty():
			continue
		if str(d.get("progressive_group", "")) != group_name:
			continue
		if not d.has("progressive_index"):
			continue
		
		var item_mode: String = _get_progressive_mode_by_key(_get_progressive_setting_for_item(d))
		if item_mode == "separate" or item_mode.is_empty():
			continue
		
		if normalized == "goron":
			var modes: Array = d.get("progressive_modes", [])
			if not modes.is_empty() and not modes.has("goron"):
				continue
		
		chain.append({"name": wname, "index": int(d.get("progressive_index", 0)), "data": d})
	
	var unique: Dictionary = {}
	for entry: Dictionary in chain:
		unique[entry["name"]] = entry
	chain = unique.values()
	chain.sort_custom(func(a: Dictionary, b: Dictionary): return a["index"] < b["index"])
	
	var indices: Array = []
	for entry: Dictionary in chain:
		var idx: int = entry["index"]
		if not indices.has(idx) and _check_item_availability(entry["data"]):
			indices.append(idx)
	indices.sort()
	if chain_mode == "descending":
		indices.reverse()
	if indices.is_empty():
		return
	
	var target_index: int = -1
	
	if not is_right_click:
		for idx: int in indices:
			var all_checked: bool = true
			for entry: Dictionary in chain:
				if entry["index"] == idx and _check_item_availability(entry["data"]):
					if not is_item_checked(entry["name"], current_world):
						all_checked = false
						break
			if not all_checked:
				target_index = idx
				break
	else:
		for i: int in range(indices.size() - 1, -1, -1):
			var idx: int = indices[i]
			for entry: Dictionary in chain:
				if entry["index"] == idx and _check_item_availability(entry["data"]):
					if is_item_checked(entry["name"], current_world):
						target_index = idx
						break
			if target_index != -1:
				break
	
	if target_index != -1:
		_apply_equipment_step(group_name, target_index, not is_right_click)
	
	request_save_checked_items()

func _get_progressive_setting_for_item(item_data: Dictionary) -> String:
	var setting_key: String = str(item_data.get("progressive_setting", "")).strip_edges()
	var group_name: String = str(item_data.get("progressive_group", "")).strip_edges()
	var shared_key: String = str(item_data.get("shared_key", "")).strip_edges()
	
	if not _settings_tab_cache or not _settings_tab_cache.has_method("get_setting_value"):
		return setting_key
	
	if group_name == "shields_oot" or group_name == "shields_mm":
		if (_settings_tab_cache.get_setting_value("sharedDekuShield") == true
				and _settings_tab_cache.get_setting_value("sharedHylianShield") == true
				and _settings_tab_cache.get_setting_value("sharedHeroShield") == true
				and _settings_tab_cache.get_setting_value("sharedMirrorShield") == true):
			return "progressiveShieldsShared"
	
	if not shared_key.is_empty() and _settings_tab_cache.get_setting_value(shared_key) == true:
		if setting_key in ["progressiveChildSwordsOot", "progressiveChildSwordsMm"]:
			return "progressiveChildSwordsMm"
		if setting_key in ["progressiveSwordsOot", "progressiveSwordsMm"]:
			return "progressiveSwordsOot"
		if setting_key in ["progressiveGFSOot", "progressiveGFSMm"]:
			return "progressiveGFSMm"
	
	return setting_key

func _get_item_shared_identity(item_data: Dictionary) -> String:
	var n: String = _get_internal_name(item_data)
	n = n.replace(" (OoT)", "").replace(" (MM)", "")
	return n.strip_edges()

func _get_shared_counterparts(item_data: Dictionary) -> Array:
	var result: Array = []
	var shared_key: String = str(item_data.get("shared_key", "")).strip_edges()
	if shared_key.is_empty():
		return result
	if not _settings_tab_cache or not _settings_tab_cache.has_method("get_setting_value"):
		return result
	if _settings_tab_cache.get_setting_value(shared_key) != true:
		return result
	
	var identity: String = _get_item_shared_identity(item_data)
	var own_name: String = _get_internal_name(item_data)
	
	for wname: String in item_widgets:
		var d: Dictionary = item_widgets[wname].get("data", {})
		if d.is_empty():
			continue
		if str(d.get("shared_key", "")).strip_edges() != shared_key:
			continue
		if _get_internal_name(d) == own_name:
			continue
		if _get_item_shared_identity(d) != identity:
			continue
		if not _check_item_availability(d):
			continue
		result.append(wname)
	
	return result

func _update_single_widget(item_name: String) -> void:
	var w: Dictionary = item_widgets.get(item_name, {})
	var btn: TextureButton = w.get("button")
	var d: Dictionary = w.get("data", {})
	if btn and not d.is_empty():
		_update_item_button_state(btn, d, _check_item_availability(d))

func _toggle_single_item_with_shared(item_name: String, checked: bool) -> void:
	var w: Dictionary = item_widgets.get(item_name, {})
	var d: Dictionary = w.get("data", {})
	if d.is_empty():
		return
	
	var touched: Array = [item_name]
	for other: String in _get_shared_counterparts(d):
		if not touched.has(other):
			touched.append(other)
	
	for wname: String in touched:
		set_item_checked(wname, current_world, checked)
		_update_single_widget(wname)

func _apply_equipment_step(group_name: String, target_index: int, checked: bool) -> void:
	var touched: Array = []
	
	for wname: String in item_widgets:
		var d: Dictionary = item_widgets[wname].get("data", {})
		if d.is_empty():
			continue
		if str(d.get("progressive_group", "")) != group_name:
			continue
		if int(d.get("progressive_index", -1)) != target_index:
			continue
		if not _check_item_availability(d):
			continue
		
		if not touched.has(wname):
			touched.append(wname)
		for other: String in _get_shared_counterparts(d):
			if not touched.has(other):
				touched.append(other)
	
	for wname: String in touched:
		set_item_checked(wname, current_world, checked)
		_update_single_widget(wname)

func _get_group_capacity(data: Dictionary) -> int:
	return max(1, _get_effective_max_level(data)) if str(data.get("type", "toggle")) == "progressive" else 1

func _get_group_units(item_name: String, data: Dictionary, world: int) -> int:
	return get_item_count(item_name, world) if str(data.get("type", "toggle")) == "progressive" else (1 if is_item_checked(item_name, world) else 0)

func _add_group_unit(item_name: String, data: Dictionary, world: int) -> void:
	if str(data.get("type", "toggle")) == "progressive":
		set_item_count(item_name, get_item_count(item_name, world) + 1, world)
	else:
		set_item_checked(item_name, world, true)

func _remove_group_unit(item_name: String, data: Dictionary, world: int) -> void:
	if str(data.get("type", "toggle")) == "progressive":
		var cur: int = get_item_count(item_name, world)
		if cur > 0: set_item_count(item_name, cur - 1, world)
	else:
		set_item_checked(item_name, world, false)

func sync_item_from_location(loc_item_name: String, pressed: bool, world: int, enforce_requirements: bool = true, base_filter: String = "all", save_after: bool = true) -> void:
	var clean_name: String = _clean_location_item_name(loc_item_name)
	if clean_name.is_empty() or clean_name.to_lower() == "(unknown)":
		return
	
	_cache_batch_begin()
	var initial_sn: bool = _is_initial_sticks_nuts()
	if _sync_bottle_from_location(clean_name, pressed, world):
		if enforce_requirements and _reset_items_failing_count_requirements():
			_request_widgets_update()
			request_save_checked_items()
		_cache_batch_end()
		return

	var seed_data: Dictionary = {}
	var group_matches: int = 0
	
	var clean_name_lower: String = clean_name.to_lower()
	var matched_items: Array = _location_to_tracker_cache.get(clean_name_lower, [])
	
	for match_info: Dictionary in matched_items:
		var gd: Dictionary = match_info["data"]
		if not gd.has("progressive_group"):
			continue
		group_matches += 1
		if seed_data.is_empty():
			seed_data = gd

	if group_matches > 1 and not seed_data.is_empty():
		if base_filter != "only_base":
			_step_progressive_group_from_location(seed_data, pressed, world)
			var group_name: String = str(seed_data.get("progressive_group", ""))
			for widget_name: String in item_widgets:
				var wd: Dictionary = item_widgets[widget_name].get("data", {})
				if str(wd.get("progressive_group", "")) == group_name:
					var btn: TextureButton = item_widgets[widget_name].get("button")
					if btn:
						_update_item_button_state(btn, wd, _check_item_availability(wd))
			if enforce_requirements and _reset_items_failing_count_requirements():
				_update_all_widgets()
			if save_after:
				request_save_checked_items()
		_cache_batch_end()
		return
	
	for match_info: Dictionary in matched_items:
		var item_data: Dictionary = match_info["data"]
		var match_entry: Variant = match_info["entry"]
		
		if match_entry is Dictionary and match_entry.has("if"):
			if not _evaluate_item_condition(match_entry["if"]):
				continue

		var tracker_name: String = _get_internal_name(item_data)
		var item_type: String = item_data.get("type", "toggle")
		var sync_mode: String = ""
		var is_progressive_entry: bool = false
		
		if match_entry is Dictionary:
			sync_mode = str(match_entry.get("mode", ""))
			is_progressive_entry = bool(match_entry.get("progressive", false))
		if sync_mode == "progressive":
			is_progressive_entry = true

		var is_base_progressive: bool = (item_type == "progressive" and sync_mode == "base")
		if base_filter == "no_base" and is_base_progressive:
			continue
		if base_filter == "only_base" and not is_base_progressive:
			continue
		if initial_sn and is_base_progressive:
			continue

		if item_type == "toggle":
			set_item_checked(tracker_name, world, pressed)
		elif item_type == "count":
			set_item_count(tracker_name, get_item_count(tracker_name, world) + (1 if pressed else -1), world)
		elif item_type == "progressive":
			var current: int = get_item_count(tracker_name, world)
			var max_val: int = _get_effective_max_level(item_data)
			if pressed:
				if is_base_progressive and current < 1:
					set_item_count(tracker_name, 1, world)
				elif sync_mode == "upgrade":
					if initial_sn and current < max_val:
						set_item_count(tracker_name, current + 1, world)
					elif not initial_sn and current < 1:
						set_item_count(tracker_name, min(2, max_val), world)
					elif current < max_val:
						set_item_count(tracker_name, current + 1, world)
				elif current < max_val:
					set_item_count(tracker_name, current + 1, world)
			else:
				if is_base_progressive and current == 1:
					set_item_count(tracker_name, 0, world)
				elif current > 0:
					set_item_count(tracker_name, current - 1, world)
		elif item_type == "song":
			var effective_max: int = _get_song_effective_max(item_data)
			var current: int = _get_song_count(tracker_name, world, effective_max)
			if pressed:
				if sync_mode == "note" or is_progressive_entry or (not _is_song_notes_mode() and sync_mode != "full"):
					if current < effective_max: set_item_count(tracker_name, current + 1, world)
				elif sync_mode == "full":
					set_item_count(tracker_name, effective_max, world)
				else:
					set_item_count(tracker_name, effective_max, world)
			else:
				if sync_mode == "note" or is_progressive_entry or (not _is_song_notes_mode() and sync_mode != "full"):
					if current > 0: set_item_count(tracker_name, current - 1, world)
				elif sync_mode == "full":
					set_item_count(tracker_name, 0, world)
				else:
					set_item_count(tracker_name, 0, world)

		var widget: Dictionary = item_widgets.get(tracker_name, {})
		var btn: TextureButton = widget.get("button")
		if btn:
			_update_item_button_state(btn, item_data, _check_item_availability(item_data))

	if enforce_requirements and _reset_items_failing_count_requirements():
		_request_widgets_update()
	if save_after:
		request_save_checked_items()
	_cache_batch_end()

func sync_all_items_from_locations(all_data: Array, world: int) -> void:
	_cache_batch_begin()
	if world == 1:
		_sync_world_filter_from_main()
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		
		if _is_triforce_shared(item_name):
			if world == 1:
				if item_data.get("type", "toggle") == "toggle":
					set_item_checked(item_name, 1, false)
				else:
					set_item_count(item_name, 0, 1)
			continue
			
		if item_data.get("type", "toggle") == "toggle":
			set_item_checked(item_name, world, false)
		else:
			set_item_count(item_name, 0, world)

	var checked_locations: Array = []
	for data: Dictionary in all_data:
		var owner_world: int = int(data.get("player", 0)) if int(data.get("player", 0)) > 0 else int(data.get("world", 1))
		if owner_world != world or not data.get("checked", false):
			continue
		var loc_item: String = str(data.get("item", "")).strip_edges()
		if not loc_item.is_empty() and loc_item.to_lower() != "(unknown)":
			checked_locations.append(loc_item)

	for loc_item: String in checked_locations:
		sync_item_from_location(loc_item, true, world, false, "no_base", false)
	for loc_item: String in checked_locations:
		sync_item_from_location(loc_item, true, world, false, "only_base", false)
	
	_set_clock_checked(_anchor_for_mode(_get_clocks_progressive_mode()), world, true)
	_reset_items_failing_count_requirements()
	_update_all_widgets()
	request_save_checked_items()
	_cache_batch_end()

func sync_starting_items(starting_items: Dictionary) -> void:
	_cache_batch_begin()
	for world: Variant in starting_items:
		var world_int: int = int(world)
		for item_name: String in starting_items[world]:
			var count: int = starting_items[world][item_name]
			var clean_name: String = item_name.strip_edges()
			for item_data: Dictionary in tracker_items:
				if _tracker_item_matches_name(item_data, clean_name):
					var tracker_name : String = _get_internal_name(item_data)
					if not _check_item_availability(item_data):
						break
					var item_type: String = item_data.get("type", "toggle")
					if item_type == "toggle":
						if count > 0: set_item_checked(tracker_name, world_int, true)
					elif item_type == "count" or item_type == "progressive":
						if _is_triforce_shared(tracker_name):
							var current = get_item_count(tracker_name, 1)
							set_item_count(tracker_name, current + count, 1)
						else:
							set_item_count(tracker_name, count, world_int)
					elif item_type == "song":
						set_item_count(tracker_name, 0 if count <= 0 else _get_song_max(item_data), world_int)
					break
	_update_all_widgets()
	request_save_checked_items()
	_cache_batch_end()

func _on_load_button_pressed() -> void:
	var main_node: Node = _main_scene_cache
	if main_node and main_node.has_method("_on_load_pressed"):
		main_node._on_load_pressed()

func _on_save_button_pressed() -> void:
	var main_node: Node = _main_scene_cache
	if main_node and main_node.has_method("_on_save_pressed"):
		main_node._on_save_pressed()
	_save_checked_items()

func _on_clear_button_pressed() -> void:
	var main_node: Node = _main_scene_cache
	if main_node and main_node.has_method("_show_reset_confirmation"):
		main_node._show_reset_confirmation()

func reset_tracker() -> void:
	_cache_batch_begin()
	LogicEvaluator.clear_cache(true)
	checked_items.clear()
	_sync_world_filter_from_main()
	_update_all_widgets()
	_save_checked_items()
	_cache_batch_end()

func _add_dependency_key(keys: Array, key: String) -> void:
	if not key.is_empty() and not keys.has(key):
		keys.append(key)

func _collect_dependency_keys_from_condition(cond: Variant, keys: Array) -> void:
	if cond is Dictionary:
		if cond.has("and"):
			_collect_dependency_keys_from_condition(cond["and"], keys)
		elif cond.has("or"):
			_collect_dependency_keys_from_condition(cond["or"], keys)
		elif cond.has("not"):
			_collect_dependency_keys_from_condition(cond["not"], keys)
		elif cond.has("eq"):
			_add_dependency_key(keys, str(cond["eq"]))
		else:
			for k: Variant in cond:
				_add_dependency_key(keys, str(k))
				var v: Variant = cond[k]
				if v is Dictionary and v.has("eq"):
					_add_dependency_key(keys, str(v["eq"]))
	elif cond is Array:
		for sub_cond: Variant in cond:
			_collect_dependency_keys_from_condition(sub_cond, keys)

func _get_item_dependency_keys(item_data: Dictionary) -> Array:
	var keys: Array = []
	if item_data.has("cond"):
		_collect_dependency_keys_from_condition(item_data["cond"], keys)
	var max_ref: Variant = item_data.get("max", "")
	if typeof(max_ref) == TYPE_STRING:
		_add_dependency_key(keys, max_ref)
	for req: Variant in item_data.get("requires_count", []):
		if req is Dictionary and req.has("if"):
			_collect_dependency_keys_from_condition(req["if"], keys)
	for entry: Variant in item_data.get("item", []):
		if entry is Dictionary and entry.has("if"):
			_collect_dependency_keys_from_condition(entry["if"], keys)
	for key: Variant in _get_bound_setting_keys(item_data):
		_add_dependency_key(keys, str(key))
	if str(item_data.get("type", "")) == "song":
		_add_dependency_key(keys, "songs")
	var progressive_setting: String = str(item_data.get("progressive_setting", "")).strip_edges()
	if not progressive_setting.is_empty():
		_add_dependency_key(keys, progressive_setting)
	return keys

func on_setting_changed(changed_key: String, _value: Variant) -> void:
	_cache_batch_begin()
	LogicEvaluator.invalidate_setting_cache([changed_key])
	LogicEvaluator.invalidate_reachability()

	var triforce_keys: Array = ["goal", "triforcePieces", "triforceGoal", "triforceSharedMulti"]
	if changed_key in triforce_keys:
		var should_reset_triforce: bool = false

		if changed_key == "goal":
			var new_goal: Variant = _get_setting_value_for_world("goal")
			if new_goal != "triforce" and new_goal != "triforce3":
				should_reset_triforce = true
		elif changed_key == "triforceSharedMulti":
			var is_shared: bool = _get_setting_value_for_world("triforceSharedMulti") == true
			if not is_shared:
				should_reset_triforce = true

		if should_reset_triforce:
			reset_triforce_progress()

	var changed_mq_dungeons: Array = []
	if changed_key == "mqDungeons":
		var old_mq: Array = _mq_state_cache.get(current_world, [])
		var new_mq: Array = _get_mq_dungeons()
		for tag: Variant in new_mq:
			if not old_mq.has(tag): changed_mq_dungeons.append(tag)
		for tag: Variant in old_mq:
			if not new_mq.has(tag) and not changed_mq_dungeons.has(tag):
				changed_mq_dungeons.append(tag)

	var needs_update: bool = false
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		var new_signature: String = _get_item_state_signature(item_data)
		var old_signature: String = item_state_cache.get(item_name, "")
		var state_changed: bool = old_signature.is_empty() or new_signature != old_signature
		var should_reset: bool = false

		if changed_key == "mqDungeons":
			if _item_has_mq_tag_in(item_data, changed_mq_dungeons):
				should_reset = true
		else:
			should_reset = _get_state_reset_keys(item_data).has(changed_key)

		if should_reset:
			var item_type: String = str(item_data.get("type", "toggle"))
			if item_type == "count" or item_type == "progressive" or item_type == "song":
				set_item_count(item_name, 0, current_world)
			elif item_type == "bottle":
				set_item_checked(item_name, current_world, false)
				set_bottle_content_index(item_name, 0, current_world)
			else:
				set_item_checked(item_name, current_world, false)
			needs_update = true

		if state_changed:
			item_state_cache[item_name] = new_signature

	if changed_key == "mqDungeons":
		_mq_state_cache[current_world] = _get_mq_dungeons()
	if changed_key == "songEventsShuffleOot" or changed_key == "songEventsShuffleMm":
		_request_song_events_sync()

	if needs_update:
		_update_all_widgets()
		request_save_checked_items()

	sync_auto_checked_items()
	clear_auto_checked_items(changed_key)
	reset_progressive_bounds(changed_key)
	reset_progressive_groups(changed_key)
	sync_progressive_mode(changed_key)
	sync_all_tracker_states()
	_cache_batch_end()

func _get_item_state_salt(item_data: Dictionary) -> String:
	var salt: String = ""
	var mq_tags: Variant = item_data.get("mq_reset", [])
	if mq_tags is String:
		mq_tags = [mq_tags]
	if mq_tags is Array and not (mq_tags as Array).is_empty():
		var mq_value: Variant = _get_setting_value_for_world("mqDungeons")
		var mq_list: Array = mq_value if mq_value is Array else []
		for tag: Variant in mq_tags:
			var tag_str: String = str(tag)
			salt += "|mq:" + tag_str + "=" + ("1" if mq_list.has(tag_str) else "0")
	return salt

func on_shared_setting_changed(changed_key: String) -> void:
	_cache_batch_begin()
	LogicEvaluator.invalidate_setting_cache([changed_key])
	LogicEvaluator.invalidate_reachability()
	var needs_update: bool = false
	for item_name: String in item_widgets:
		var item_data: Dictionary = item_widgets[item_name]["data"]
		if item_data.get("shared_key", "") == changed_key:
			var item_type: String = item_data.get("type", "toggle")
			if item_type == "count" or item_type == "progressive" or item_type == "song":
				set_item_count(item_name, 0, current_world)
			else:
				set_item_checked(item_name, current_world, false)
			needs_update = true

	if needs_update:
		_update_all_widgets()
		request_save_checked_items()
	sync_all_tracker_states()
	_cache_batch_end()

func refresh_world_filter_from_settings() -> void:
	if not world_filter:
		return

	var players := 1
	var settings_tab: Node = _settings_tab_cache

	if settings_tab:
		if settings_tab.has_method("get_players_count"):
			players = int(settings_tab.get_players_count())
		elif settings_tab.has_method("get_setting_value"):
			var mode: Variant = settings_tab.get_setting_value("mode")
			if str(mode).to_lower() == "multi":
				var p: Variant = settings_tab.get_setting_value("players")
				players = _get_players_count_from_variant(p)

	if players < 1:
		players = 1

	var prev_selected: int = world_filter.selected
	world_filter.clear()

	for i: int in range(1, players + 1):
		world_filter.add_item("World " + str(i), i - 1)

	if prev_selected >= 0 and prev_selected < world_filter.item_count:
		world_filter.select(prev_selected)
	else:
		world_filter.select(0)

	current_world = world_filter.selected + 1
	_update_all_widgets()

func _get_players_count_from_variant(value: Variant) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return int(value)

	if typeof(value) == TYPE_STRING and str(value).is_valid_int():
		return int(str(value))

	if typeof(value) == TYPE_ARRAY and not value.is_empty():
		return _get_players_count_from_variant(value[0])

	if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
		var best := 1

		for v: Variant in value.values():
			best = max(best, _get_players_count_from_variant(v))

		return best

	return 1

func _is_triforce_shared_multi_enabled() -> bool:
	var settings_tab: Node = _settings_tab_cache
	if not settings_tab or not settings_tab.has_method("get_setting_value"):
		return false
	var mode = settings_tab.get_setting_value("mode")
	if str(mode).to_lower() != "multi":
		return false
	return settings_tab.get_setting_value("triforceSharedMulti") == true

func _is_triforce_shared(item_name: String) -> bool:
	if not _is_triforce_shared_multi_enabled():
		return false
	var clean_name = item_name.strip_edges()
	return clean_name == "Triforce Piece" or \
		   clean_name == "Triforce of Courage" or \
		   clean_name == "Triforce of Wisdom" or \
		   clean_name == "Triforce of Power"

func _get_item_state_signature(item_data: Dictionary) -> String:
	var item_type: String = str(item_data.get("type", "toggle"))
	var signature: String = _get_internal_name(item_data) + "|" + _get_display_name(item_data) + "|" + item_type + "|" + str(_check_item_cond_only(item_data))
	if item_type == "count":
		signature += "|" + str(_get_max_value(item_data))
	elif item_type == "progressive":
		signature += "|" + str(_get_effective_min_level(item_data)) + "|" + str(_get_effective_max_level(item_data))
	elif item_type == "song":
		signature += "|" + str(_get_song_effective_max(item_data))
	signature += _get_item_state_salt(item_data)
	return signature

func _cache_item_states() -> void:
	item_state_cache.clear()
	for item_name: String in item_widgets:
		item_state_cache[item_name] = _get_item_state_signature(item_widgets[item_name]["data"])

func request_save_checked_items() -> void:
	if _items_save_timer:
		_items_save_timer.start()

func _exit_tree() -> void:
	_save_checked_items()

func _get_linked_items(item_data: Dictionary) -> Array:
	var linked_names: Array = []
	var base_name: String = _get_internal_name(item_data)
	linked_names.append(base_name)
	var shared_key: String = str(item_data.get("shared_key", ""))
	if shared_key.is_empty():
		return linked_names

	var settings_tab: Node = _settings_tab_cache
	if not settings_tab or not settings_tab.has_method("get_setting_value") or settings_tab.get_setting_value(shared_key) != true:
		return linked_names

	var group_id: String = _get_shared_group_id(item_data)
	for other_data: Dictionary in tracker_items:
		var other_name: String = _get_internal_name(other_data)
		if other_name == base_name or str(other_data.get("shared_key", "")) != shared_key or _get_shared_group_id(other_data) != group_id:
			continue
		if _check_item_availability(other_data):
			linked_names.append(other_name)
	return linked_names

func get_bottle_content_index(item_name: String, world: int = 1) -> int:
	return int(checked_items.get(str(world) + "_" + item_name + "_bottle_content", 0))

func set_bottle_content_index(item_name: String, content_index: int, world: int = 1) -> void:
	var key: String = str(world) + "_" + item_name + "_bottle_content"
	if checked_items.get(key, 0) != content_index:
		checked_items[key] = content_index
		_mark_logic_dirty(item_name, world)

func _get_bottle_contents(item_data: Dictionary) -> Array:
	var raw_contents: Array = item_data.get("contents", [])
	if raw_contents.is_empty() and item_data.has("contents_from"):
		var source_name: String = str(item_data["contents_from"])
		for data: Dictionary in tracker_items:
			if str(data.get("name", "")) == source_name and data.has("contents"):
				raw_contents = data["contents"]
				break

	var settings_tab: Node = _settings_tab_cache
	var filtered: Array = []
	for entry: Variant in raw_contents:
		if entry is Dictionary and entry.has("if"):
			if settings_tab and not _evaluate_item_condition(entry["if"]):
				continue
		filtered.append(entry)
	return filtered

func _get_bottle_content_index_by_id(item_data: Dictionary, content_id: String) -> int:
	var contents: Array = _get_bottle_contents(item_data)
	for i: int in range(contents.size()):
		if str(contents[i].get("id", "")) == content_id:
			return i
	return 0

func _get_bottle_content_id(item_data: Dictionary, content_index: int) -> String:
	var contents: Array = _get_bottle_contents(item_data)
	if content_index >= 0 and content_index < contents.size():
		return str(contents[content_index].get("id", ""))
	return ""

func _get_bottle_slots(group_name: String) -> Array:
	var slots: Array = []
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if data.get("type", "") != "bottle" or str(data.get("bottle_group", "")) != group_name or not _check_item_availability(data):
			continue
		slots.append({"name": widget_name, "index": int(data.get("bottle_index", 0)), "data": data})
	slots.sort_custom(func(a: Dictionary, b: Dictionary): return a["index"] < b["index"])
	return slots

func _is_initial_sticks_nuts() -> bool:
	var settings_tab: Node = _settings_tab_cache
	return settings_tab and settings_tab.has_method("get_setting_value") and settings_tab.get_setting_value("sticksNutsUpgradesInitial") == true

func _check_has_usable_bottle(group_name: String, exclude_content: Variant, world: int) -> bool:
	var is_shared: bool = _settings_tab_cache and _settings_tab_cache.has_method("get_setting_value") and _settings_tab_cache.get_setting_value("sharedBottles") == true
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if data.get("type", "") != "bottle" or not _check_item_availability(data) or (not is_shared and str(data.get("bottle_group", "")) != group_name) or not is_item_checked(widget_name, world):
			continue
		var content_index: int = get_bottle_content_index(widget_name, world)
		var contents: Array = _get_bottle_contents(data)
		var content_id: String = ""
		if content_index >= 0 and content_index < contents.size():
			content_id = str(contents[content_index].get("id", ""))
		if _is_content_excluded(content_id, exclude_content):
			continue
		return true
	return false

func _is_content_excluded(content_id: String, exclude_content: Variant) -> bool:
	if exclude_content == null:
		return false
	if exclude_content is Array:
		for ex: Variant in exclude_content:
			if str(ex).strip_edges() == content_id:
				return true
		return false
	return str(exclude_content).strip_edges() == content_id

func _check_bottle_content_exists(content_id: String, world: int) -> bool:
	for widget_name: String in item_widgets:
		var data: Dictionary = item_widgets[widget_name].get("data", {})
		if data.get("type", "") != "bottle" or not is_item_checked(widget_name, world):
			continue
		var content_index: int = get_bottle_content_index(widget_name, world)
		var contents: Array = _get_bottle_contents(data)
		if content_index >= 0 and content_index < contents.size() and str(contents[content_index].get("id", "")) == content_id:
			return true
	return false

func get_song_event_song_index(event_id: String, world: int) -> int:
	var clean_event_id: String = event_id.strip_edges()
	var world_key: String = str(world) + "_" + clean_event_id
	if song_event_indices.has(world_key):
		return song_event_indices[world_key]
	var old_key: String = clean_event_id + "_" + str(world)
	if song_event_indices.has(old_key):
		return song_event_indices[old_key]
	if song_event_indices.has(clean_event_id):
		return song_event_indices[clean_event_id]
	
	for item_data: Dictionary in tracker_items:
		if str(item_data.get("type", "")) == "event_song" and str(item_data.get("event_id", "")).strip_edges() == clean_event_id:
			return int(item_data.get("dafault_index", item_data.get("default_index", 0)))
	return -1

func get_collectibles_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/CollectiblesPanel") as TextureRect

func get_equipment_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/EquipmentPanel") as TextureRect

func get_items_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/ItemsPanelImage") as TextureRect

func get_masks_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/MasksPanel") as TextureRect

func get_songs_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/SongsPanel") as TextureRect

func get_rusty_keys_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/RustyKeysPanel") as TextureRect

func get_dungeons_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/DungeonsPanel") as TextureRect

func get_souls_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/SoulsPanel") as TextureRect

func get_song_events_panel() -> TextureRect:
	return get_node("MainContainer/ScrollContainer/ItemsPanel/SongEventsPanel") as TextureRect
