extends Control
@onready var load_button: Button = $VBox/TopPanel/LoadButton
@onready var save_button: Button = $VBox/TopPanel/SaveButton
@onready var clear_button: Button = $VBox/TopPanel/ClearButton
@onready var categories_hbox: HBoxContainer = $VBox/CategoryFilters/CategoriesHBox
@onready var settings_container: VBoxContainer = $VBox/Scroll/MarginContainer/SettingsContainer
var all_settings: Array = []
var setting_widgets: Dictionary = {}
var current_settings: Dictionary = {}
var all_categories: Array = []
var category_buttons: Dictionary = {}
var current_filter: String = ""
var is_rebuilding: bool = false
var current_grid: GridContainer = null
var _item_tracker_cache: Node = null
var _map_tab_cache: Node = null
var _sync_pending: bool = false
var _pending_keys: Dictionary = {}
var _cfg_save_timer: Timer = null
var _suspend_sync: bool = false
var _price_shown_once: Dictionary = {}
var _updating_settings: bool = false
var _normalizing_prices: bool = false

func _get_current_world() -> int:
	if _item_tracker_cache and "current_world" in _item_tracker_cache:
		return int(_item_tracker_cache.current_world)
	return 1

func _is_location_checked_in_world(loc_name: String, world: int, game: String = "") -> bool:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if not main_node or loc_name == "":
		return false
	
	if main_node.has_method("get_all_data"):
		var all_data = main_node.get_all_data()
		var target_loc = loc_name.strip_edges().to_lower()
		var target_game = game.strip_edges().to_upper()
		for data in all_data:
			var data_loc = str(data.get("name", "")).strip_edges().to_lower()
			var data_world = int(data.get("world", 1))
			var data_game = str(data.get("game", "")).strip_edges().to_upper()
			if data_loc == target_loc and data_world == world:
				if target_game != "" and data_game != target_game:
					continue
				return bool(data.get("checked", false))
	
	if main_node.has_method("is_location_checked"):
		return main_node.is_location_checked(loc_name, world)
		
	return false

func _ready() -> void:
	add_to_group("settings_tab")
	_item_tracker_cache = get_tree().get_first_node_in_group("item_tracker")
	_map_tab_cache = get_tree().get_first_node_in_group("map_tab")
	load_settings()
	_normalize_price_values_to_mode()
	setup_ui()
	display_settings()

func _get_players_count() -> int:
	var players_raw = current_settings.get("players", 1)
	if typeof(players_raw) in [TYPE_INT, TYPE_FLOAT]:
		return int(players_raw)
	elif typeof(players_raw) == TYPE_STRING and str(players_raw).is_valid_int():
		return int(str(players_raw))
	elif typeof(players_raw) == TYPE_ARRAY and players_raw.size() > 0:
		var first = players_raw[0]
		if typeof(first) in [TYPE_INT, TYPE_FLOAT]:
			return int(first)
		elif typeof(first) == TYPE_STRING and str(first).is_valid_int():
			return int(str(first))
	elif typeof(players_raw) == TYPE_DICTIONARY and players_raw.size() > 0:
		var first = players_raw.values()[0]
		if typeof(first) in [TYPE_INT, TYPE_FLOAT]:
			return int(first)
		elif typeof(first) == TYPE_STRING and str(first).is_valid_int():
			return int(str(first))
	return 1

func get_players_count() -> int:
	var mode := str(current_settings.get("mode", "single")).to_lower()
	var players := _get_players_count()

	if str(mode).to_lower() != "multi":
		return 1

	return max(players, 2)

func _safe_to_float(value: Variant, default: float = 1.0) -> float:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return float(value)
	elif typeof(value) == TYPE_STRING and str(value).is_valid_float():
		return float(str(value))
	elif typeof(value) == TYPE_DICTIONARY and value.size() > 0:
		return _safe_to_float(value.values()[0], default)
	elif typeof(value) == TYPE_ARRAY and value.size() > 0:
		return _safe_to_float(value[0], default)
	return default

func _request_external_sync(key: String, value: Variant) -> void:
	_pending_keys[key] = value
	if _suspend_sync: return
	if not _sync_pending:
		_sync_pending = true
		call_deferred("_process_external_sync")

func _process_external_sync() -> void:
	_sync_pending = false
	var keys_to_process = _pending_keys.duplicate()
	_pending_keys.clear()
	for key in keys_to_process:
		var value = keys_to_process[key]
		if _item_tracker_cache:
			if _item_tracker_cache.has_method("on_setting_changed"):
				_item_tracker_cache.on_setting_changed(key, value)
			if key.begins_with("shared") and _item_tracker_cache.has_method("on_shared_setting_changed"):
				_item_tracker_cache.on_shared_setting_changed(key)
		if key == "jpLayouts" and _map_tab_cache:
			if _map_tab_cache.has_method("refresh_jp_layout_visibility"):
				_map_tab_cache.refresh_jp_layout_visibility()
		if (key == "games" or key == "mqDungeons") and _map_tab_cache:
			if _map_tab_cache.has_method("refresh_games_visibility"):
				_map_tab_cache.refresh_games_visibility()
		if key == "mode" or key == "players":
			var main_node := get_tree().get_first_node_in_group("main_scene")
			if main_node and main_node.has_method("refresh_worlds_from_settings"):
				main_node.refresh_worlds_from_settings()
			elif _item_tracker_cache and _item_tracker_cache.has_method("refresh_world_filter_from_settings"):
				_item_tracker_cache.refresh_world_filter_from_settings()

var _applying_bulk: bool = false

func apply_saved_settings(saved_settings: Dictionary) -> void:
	_applying_bulk = true
	for key in saved_settings:
		current_settings[key] = _normalize_dict_keys(saved_settings[key])
	
	for setting in all_settings:
		if setting.get("category", "") != "locations_prices":
			continue
		var setting_key: String = setting["key"]
		if not saved_settings.has(setting_key):
			continue
		var saved_val: Variant = saved_settings[setting_key]
		var players: int = _get_players_count()
		if str(current_settings.get("mode", "single")).to_lower() != "multi":
			players = 1
		for world in range(1, players + 1):
			var val_for_world: Variant
			if typeof(saved_val) == TYPE_DICTIONARY:
				val_for_world = saved_val.get(world, setting.get("default", 0))
			else:
				val_for_world = saved_val
			if _is_price_user_modified(setting, val_for_world):
				_price_shown_once[setting_key + "|" + str(world)] = true
	
	_normalize_price_values_to_mode()
	display_settings()
	_applying_bulk = false

func _convert_log_value(val: Variant, setting_type: String, all_possible_set_values: Array = []) -> Variant:
	match setting_type:
		"boolean":
			if typeof(val) == TYPE_STRING:
				return str(val).to_lower() == "true"
			return bool(val)
		"number":
			if typeof(val) == TYPE_STRING:
				var s = str(val)
				if s.is_valid_int(): return int(s)
				if s.is_valid_float(): return float(s)
			elif typeof(val) == TYPE_BOOL:
				return 1 if val else 0
			return val
		"set":
			var arr = []
			if typeof(val) == TYPE_STRING:
				var s = str(val).to_lower()
				if s == "all": arr = all_possible_set_values.duplicate()
				elif s == "none" or s == "": arr = []
				else: arr = [str(val)]
			elif typeof(val) == TYPE_ARRAY:
				arr = val
			else:
				arr = [val]
			return arr
		"special_cond":
			if typeof(val) == TYPE_DICTIONARY:
				var res = {}
				for k in val:
					var v = val[k]
					if str(k).to_lower() == "count":
						res[k] = _convert_log_value(v, "number")
					else:
						res[k] = _convert_log_value(v, "boolean")
				return res
			return val
		_:
			return val

func apply_log_settings(spoiler_settings: Dictionary, world_flags: Dictionary, _worlds_count: int, special_conditions: Dictionary = {}) -> void:
	if spoiler_settings.is_empty() and world_flags.is_empty() and special_conditions.is_empty():
		return
	_suspend_sync = true
	var norm_spoiler: Dictionary = {}
	var key_mapping: Dictionary = {}
	if all_settings.is_empty():
		load_settings()
	for s in all_settings:
		var original_key = s["key"]
		key_mapping[original_key.to_lower()] = original_key
	for key in spoiler_settings:
		var lower_key = str(key).to_lower()
		norm_spoiler[lower_key] = spoiler_settings[key]
	var norm_special: Dictionary = {}
	for key in special_conditions:
		norm_special[str(key).to_lower()] = special_conditions[key]
	var setting_types: Dictionary = {}
	var setting_all_values: Dictionary = {}
	for s in all_settings:
		var k = s["key"].to_lower()
		setting_types[k] = s.get("type", "")
		if s.get("type") == "set":
			var possible_values = []
			for opt in s.get("values", []):
				possible_values.append(opt["value"])
			setting_all_values[k] = possible_values
	var mode = current_settings.get("mode", "single")
	if norm_spoiler.has("mode"):
		mode = str(norm_spoiler["mode"]).to_lower()
		current_settings["mode"] = mode
	var players = _get_players_count()
	if norm_spoiler.has("players"):
		players = _convert_log_value(norm_spoiler["players"], "number")
		current_settings["players"] = players
	if str(mode).to_lower() != "multi":
		players = 1
	for lower_key in norm_spoiler.keys():
		if lower_key == "mode" or lower_key == "players":
			continue
		var setting_type = setting_types.get(lower_key, "")
		var val = _convert_log_value(norm_spoiler[lower_key], setting_type, setting_all_values.get(lower_key, []))
		var original_key = key_mapping.get(lower_key, lower_key)
		if mode == "multi" and (setting_type == "set" or setting_type == "number"):
			var per_world = {}
			for i in range(1, players + 1):
				per_world[i] = val.duplicate() if typeof(val) in [TYPE_ARRAY, TYPE_DICTIONARY] else val
			current_settings[original_key] = per_world
		else:
			current_settings[original_key] = val
	var normalized_world_flags = {}
	for wf_key in world_flags.keys():
		var wf_val = world_flags[wf_key]
		if wf_val is Dictionary:
			normalized_world_flags[wf_key] = wf_val
		else:
			for i in range(1, players + 1):
				if not normalized_world_flags.has(i):
					normalized_world_flags[i] = {}
				normalized_world_flags[i][wf_key] = wf_val
	for world_id in normalized_world_flags.keys():
		var world_data = normalized_world_flags[world_id]
		for key in world_data.keys():
			var lower_key = str(key).to_lower()
			var original_key = key_mapping.get(lower_key, key)
			if current_settings.has(original_key):
				var setting_type = setting_types.get(lower_key, "")
				var value = _convert_log_value(world_data[key], setting_type, setting_all_values.get(lower_key, []))
				if typeof(current_settings.get(original_key)) == TYPE_DICTIONARY:
					current_settings[original_key][world_id] = value
				else:
					var per_player_dict = {}
					for i in range(1, players + 1):
						if setting_type == "set":
							per_player_dict[i] = []
						else:
							per_player_dict[i] = 0
					per_player_dict[world_id] = value
					current_settings[original_key] = per_player_dict
	for lower_key in norm_special:
		var original_key = key_mapping.get(lower_key, lower_key)
		if current_settings.has(original_key):
			var setting_type = setting_types.get(lower_key, "")
			current_settings[original_key] = _convert_log_value(norm_special[lower_key], setting_type)
	_normalize_price_values_to_mode()
	display_settings()
	if _item_tracker_cache:
		if _item_tracker_cache.has_method("refresh_world_filter_from_settings"):
			_item_tracker_cache.refresh_world_filter_from_settings()
		if _item_tracker_cache.has_method("sync_song_events"):
			_item_tracker_cache.call_deferred("sync_song_events")
	if _map_tab_cache:
		if current_settings.has("jpLayouts") or current_settings.has("jpllayouts"):
			if _map_tab_cache.has_method("refresh_jp_layout_visibility"):
				_map_tab_cache.refresh_jp_layout_visibility()
		if _map_tab_cache.has_method("refresh_games_visibility"):
			_map_tab_cache.refresh_games_visibility()
	save_settings_to_file()
	_suspend_sync = false
	_process_external_sync()

func load_settings() -> void:
	var file = FileAccess.open("res://data/settings.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return
	all_settings = json.get_data()
	var mode = current_settings.get("mode", "single")
	var players = _get_players_count()
	if str(mode).to_lower() != "multi":
		players = 1
	elif players < 2:
		players = 2
	current_settings["players"] = players
	for setting in all_settings:
		var key = setting["key"]
		var setting_type = setting.get("type", "")
		var default_value = setting.get("default", get_default_for_type(setting_type))
		if setting_type == "set":
			default_value = _normalize_dict_keys(default_value)
			if typeof(default_value) == TYPE_ARRAY:
				var per_player_dict = {}
				for i in range(1, players + 1):
					per_player_dict[i] = default_value.duplicate()
				current_settings[key] = per_player_dict
			else:
				current_settings[key] = default_value
		elif setting_type == "number" and mode == "multi":
			var per_player_dict = {}
			for i in range(1, players + 1):
				per_player_dict[i] = default_value
			current_settings[key] = per_player_dict
		else:
			current_settings[key] = default_value

func get_default_for_type(type: String) -> Variant:
	match type:
		"boolean": return false
		"enum": return ""
		"set": return {}
		"number": return 1
		"special_cond": return {}
		_: return null

func setup_ui() -> void:
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	load_button.tooltip_text = "Load spoiler log or tracker save (F1)"
	save_button.tooltip_text = "Save tracker state (F2)"
	clear_button.tooltip_text = "Reset all progress (F3)"
	var categories_set = {}
	all_categories = []
	for setting in all_settings:
		var category = setting.get("category", "uncategorized")
		if not categories_set.has(category):
			categories_set[category] = true
			all_categories.append(category)
	for category in all_categories:
		var button = Button.new()
		button.text = _format_category_button(category)
		button.toggle_mode = true
		button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.4, 0.7, 1, 1))
		button.add_theme_color_override("font_hover_color", Color(0.6, 0.85, 1, 1))
		button.add_theme_color_override("font_hover_pressed_color", Color(0.4, 0.7, 1, 1))
		button.toggled.connect(_on_category_button_toggled.bind(category))
		categories_hbox.add_child(button)
		category_buttons[category] = button

func _format_category_button(category: String) -> String:
	var parts = category.split(".")
	if parts.size() > 1:
		return parts[-1].capitalize()
	else:
		return parts[0].capitalize()

func _format_category_header(category: String) -> String:
	var parts = category.split(".")
	var formatted_parts = []
	for part in parts:
		formatted_parts.append(part.capitalize())
	return " - ".join(formatted_parts)

func display_settings() -> void:
	if is_rebuilding:
		return
	is_rebuilding = true
	if current_filter == "":
		if all_categories.size() > 0:
			current_filter = all_categories[0]
			if category_buttons.has(current_filter):
				category_buttons[current_filter].button_pressed = true
	for child in settings_container.get_children():
		child.queue_free()
	setting_widgets.clear()
	current_grid = null
	var last_category = ""
	for setting in all_settings:
		var category = setting.get("category", "uncategorized")
		if current_filter != category:
			continue
		if category != last_category:
			_create_category_header(category)
			last_category = category
		_create_setting_widget(setting)
	is_rebuilding = false

func _create_category_header(category_name: String) -> void:
	var header_container = HBoxContainer.new()
	var header = Label.new()
	header.text = _format_category_header(category_name)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(header)
	settings_container.add_child(header_container)
	var separator = HSeparator.new()
	separator.add_theme_color_override("color", Color(0.3, 0.3, 0.35, 1))
	settings_container.add_child(separator)
	current_grid = GridContainer.new()
	current_grid.columns = 3
	current_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_container.add_child(current_grid)

func _create_setting_widget(setting_data: Dictionary) -> void:
	var target_container: Control
	if current_grid:
		target_container = current_grid
	else:
		target_container = settings_container
	var current_value = current_settings.get(setting_data["key"], setting_data.get("default", get_default_for_type(setting_data["type"])))
	var widget = null
	match setting_data["type"]:
		"boolean":
			widget = _create_boolean_widget(setting_data, current_value)
		"enum":
			widget = _create_enum_widget(setting_data, current_value)
		"set":
			widget = _create_set_widget(setting_data, current_value)
		"number":
			widget = _create_number_widget(setting_data, current_value)
		"special_cond":
			widget = _create_special_cond_widget(setting_data, current_value)
		_:
			return
	if widget:
		if target_container is GridContainer:
			widget.custom_minimum_size = Vector2(300, 60)
		target_container.add_child(widget)
		setting_widgets[setting_data["key"]] = widget
		var should_be_visible = _check_visibility_condition(setting_data)
		widget.visible = should_be_visible
		if should_be_visible and setting_data.get("category", "") == "locations_prices":
			widget.visible = _update_price_widget_rows(widget)
		if setting_data.has("disabled_if") and setting_data.get("category", "") != "locations_prices":
			var should_be_disabled = _evaluate_condition(setting_data["disabled_if"])
			_apply_disabled_state(widget, setting_data, should_be_disabled)

func _apply_disabled_state(widget: Control, setting_data: Dictionary, should_be_disabled: bool) -> void:
	if not (widget is Control):
		return
	var input_node: Control = null
	if widget is SpinBox or widget is CheckBox or widget is OptionButton:
		input_node = widget
	else:
		for child in widget.get_children():
			if child is SpinBox or child is CheckBox or child is OptionButton:
				input_node = child
				break
	if input_node == null:
		return
	if should_be_disabled and setting_data.has("disabled_value"):
		var disabled_values = setting_data["disabled_value"]
		var disabled_if = setting_data["disabled_if"]
		var dependent_key = ""
		if disabled_if is Dictionary:
			for key in disabled_if.keys():
				dependent_key = key
				break
		if dependent_key != "" and current_settings.has(dependent_key):
			var dependent_value = str(current_settings[dependent_key]).to_lower()
			var matched_key = ""
			for dv_key in disabled_values.keys():
				if str(dv_key).to_lower() == dependent_value:
					matched_key = dv_key
					break
			if matched_key != "":
				var new_value = disabled_values[matched_key]
				if input_node is SpinBox:
					input_node.set_block_signals(true)
					input_node.value = float(new_value)
					input_node.set_block_signals(false)
					if typeof(current_settings[setting_data["key"]]) == TYPE_DICTIONARY:
						for w in current_settings[setting_data["key"]]:
							current_settings[setting_data["key"]][w] = int(new_value)
					else:
						current_settings[setting_data["key"]] = int(new_value)
				elif input_node is CheckBox:
					input_node.set_block_signals(true)
					input_node.button_pressed = bool(new_value)
					input_node.set_block_signals(false)
					current_settings[setting_data["key"]] = bool(new_value)
				elif input_node is OptionButton:
					input_node.set_block_signals(true)
					var found = false
					for i in range(input_node.item_count):
						var item_val = input_node.get_item_metadata(i)
						if item_val != null and str(item_val).to_lower() == str(new_value).to_lower():
							input_node.select(i)
							current_settings[setting_data["key"]] = new_value
							found = true
							break
					if not found:
						for i in range(input_node.item_count):
							if str(input_node.get_item_text(i)).to_lower() == str(new_value).to_lower():
								input_node.select(i)
								current_settings[setting_data["key"]] = new_value
								break
					input_node.set_block_signals(false)
	if input_node is SpinBox:
		input_node.editable = !should_be_disabled
	elif input_node is CheckBox:
		input_node.disabled = should_be_disabled
	elif input_node is OptionButton:
		input_node.disabled = should_be_disabled

func _create_boolean_widget(setting_data: Dictionary, current_value: Variant) -> Control:
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = setting_data.get("name", setting_data["key"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var checkbox = CheckBox.new()
	checkbox.button_pressed = bool(current_value)
	checkbox.text = ""
	checkbox.add_theme_constant_override("icon_h_separation", 0)
	
	var checked_tex = load("res://images/checkbox_checked.png") as Texture2D
	var unchecked_tex = load("res://images/checkbox_unchecked.png") as Texture2D
	
	if checked_tex:
		checkbox.add_theme_icon_override("checked", checked_tex)
		checkbox.add_theme_icon_override("checked_disabled", checked_tex)
	if unchecked_tex:
		checkbox.add_theme_icon_override("unchecked", unchecked_tex)
		checkbox.add_theme_icon_override("unchecked_disabled", unchecked_tex)
	
	var empty_style = StyleBoxEmpty.new()
	checkbox.add_theme_stylebox_override("normal", empty_style)
	checkbox.add_theme_stylebox_override("pressed", empty_style)
	checkbox.add_theme_stylebox_override("hover", empty_style)
	checkbox.add_theme_stylebox_override("hover_pressed", empty_style)
	checkbox.add_theme_stylebox_override("focus", empty_style)
	checkbox.add_theme_stylebox_override("disabled", empty_style)
	
	if checked_tex:
		checkbox.custom_minimum_size = checked_tex.get_size()
	elif unchecked_tex:
		checkbox.custom_minimum_size = unchecked_tex.get_size()
	
	checkbox.toggled.connect(func(toggled: bool):
		current_settings[setting_data["key"]] = toggled
		_on_setting_changed(setting_data["key"], toggled)
	)
	
	container.add_child(checkbox)
	container.add_child(label)
	return container

func _create_enum_widget(setting_data: Dictionary, current_value: Variant) -> Control:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = setting_data.get("name", setting_data["key"])
	var option_button = OptionButton.new()
	var values_map = {}
	for option in setting_data["values"]:
		var display_text = option.get("name", option["value"])
		option_button.add_item(display_text)
		option_button.set_item_metadata(option_button.item_count - 1, option["value"])
		values_map[display_text] = option["value"]
	if typeof(current_value) != TYPE_DICTIONARY:
		for display_text in values_map:
			if values_map[display_text] == current_value:
				for i in range(option_button.item_count):
					if option_button.get_item_text(i) == display_text:
						option_button.select(i)
						break
	option_button.item_selected.connect(func(index: int):
		var selected_text = option_button.get_item_text(index)
		var selected_value = values_map[selected_text]
		current_settings[setting_data["key"]] = selected_value
		_on_setting_changed(setting_data["key"], selected_value)
	)
	container.add_child(label)
	container.add_child(option_button)
	return container

func _create_set_widget(setting_data: Dictionary, current_value: Variant) -> Control:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = setting_data.get("name", setting_data["key"])
	var mode = current_settings.get("mode", "single")
	var players = _get_players_count()
	if str(mode).to_lower() != "multi":
		players = 1
	elif players < 2:
		players = 2
	var per_player_values: Dictionary = {}
	if typeof(current_value) == TYPE_ARRAY:
		for i in range(1, players + 1):
			per_player_values[i] = current_value.duplicate()
	elif typeof(current_value) == TYPE_DICTIONARY:
		per_player_values = current_value
	var world_selector = OptionButton.new()
	for i in range(1, players + 1):
		world_selector.add_item("World " + str(i))
	world_selector.select(0)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var checkboxes = {}
	var update_checkboxes = func():
		var idx: int = world_selector.selected
		if idx < 0:
			idx = 0
			world_selector.select(0)

		var world: int = idx + 1
		var current_array = per_player_values.get(world, [])

		if typeof(current_array) == TYPE_STRING:
			if current_array == "all":
				for cb_value in checkboxes:
					checkboxes[cb_value].button_pressed = true
			else:
				for cb_value in checkboxes:
					checkboxes[cb_value].button_pressed = false
		else:
			for cb_value in checkboxes:
				checkboxes[cb_value].button_pressed = cb_value in current_array
	for option in setting_data["values"]:
		var display_text = option.get("name", option["value"])
		var value = option["value"]
		var checkbox = CheckBox.new()
		checkbox.text = display_text
		checkboxes[value] = checkbox
		checkbox.toggled.connect(func(_toggled: bool):
			var idx: int = world_selector.selected
			if idx < 0:
				idx = 0
				world_selector.select(0)

			var world: int = idx + 1
			var selected_items: Array = []

			for cb_value in checkboxes:
				if checkboxes[cb_value].button_pressed:
					selected_items.append(cb_value)

			per_player_values[world] = selected_items
			current_settings[setting_data["key"]] = per_player_values
			_on_setting_changed(setting_data["key"], per_player_values)
		)
		grid.add_child(checkbox)
	world_selector.item_selected.connect(func(_index: int):
		update_checkboxes.call()
	)
	for cb_value in checkboxes:
		checkboxes[cb_value].set_block_signals(true)
	update_checkboxes.call()
	for cb_value in checkboxes:
		checkboxes[cb_value].set_block_signals(false)
	container.add_child(label)
	container.add_child(world_selector)
	container.add_child(grid)
	return container

func _create_number_widget(setting_data: Dictionary, current_value: Variant) -> Control:
	var mode = current_settings.get("mode", "single")
	var players = _get_players_count()
	if str(mode).to_lower() != "multi":
		players = 1
	elif players < 2:
		players = 2
	var min_val_raw = setting_data.get("min", 1)
	if typeof(min_val_raw) == TYPE_DICTIONARY:
		min_val_raw = min_val_raw.get(mode, 1)
	elif typeof(min_val_raw) == TYPE_STRING:
		min_val_raw = current_settings.get(min_val_raw, 1)
	var min_val: float = _safe_to_float(min_val_raw, 1.0)
	var max_val_raw = setting_data.get("max", 100)
	if typeof(max_val_raw) == TYPE_DICTIONARY:
		max_val_raw = max_val_raw.get(mode, 100)
	elif typeof(max_val_raw) == TYPE_STRING:
		max_val_raw = current_settings.get(max_val_raw, 100)
	var max_val: float = _safe_to_float(max_val_raw, 100.0)
	var step_val_raw = setting_data.get("step", 1)
	var step_val: float = _safe_to_float(step_val_raw, 1.0)
	var category = setting_data.get("category", "")
	if category == "locations_prices":
		var container = VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label = Label.new()
		label.text = setting_data.get("name", setting_data["key"])
		container.add_child(label)
		var is_multi = mode == "multi"
		var price_mode_key = str(setting_data.get("price_setting", ""))
		var disabled_if = setting_data.get("disabled_if", {})
		if price_mode_key == "" and typeof(disabled_if) == TYPE_DICTIONARY:
			for k in disabled_if:
				price_mode_key = str(k)
				break
		var _lock_values := []
		if typeof(disabled_if) == TYPE_DICTIONARY and disabled_if.has(price_mode_key):
			var lock_source = disabled_if[price_mode_key]
			if typeof(lock_source) == TYPE_ARRAY:
				_lock_values = lock_source
			else:
				_lock_values = [lock_source]
		var _disabled_values = setting_data.get("disabled_value", {})
		var loc_name = str(setting_data.get("location_name", ""))
		container.set_meta("price_loc_name", loc_name)
		var per_world_values := {}
		if typeof(current_value) == TYPE_DICTIONARY:
			per_world_values = current_value.duplicate(true)
		else:
			var scalar_value = _safe_to_float(
				current_value,
				_safe_to_float(setting_data.get("default", min_val), min_val)
			)
			for i in range(1, players + 1):
				per_world_values[i] = scalar_value
		for i in range(1, players + 1):
			if not per_world_values.has(i):
				per_world_values[i] = _safe_to_float(setting_data.get("default", min_val), min_val)
		for world in range(1, players + 1):
			var hbox = HBoxContainer.new()
			hbox.set_meta("price_world", world)
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if is_multi:
				var world_label = Label.new()
				world_label.text = "World " + str(world) + ": "
				hbox.add_child(world_label)
			var spin_box = SpinBox.new()
			spin_box.min_value = min_val
			spin_box.max_value = max_val
			spin_box.step = step_val
			spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var stored_for_world: Variant = per_world_values.get(world, setting_data.get("default", min_val))
			var spin_value: float = _resolve_price_value(setting_data, world, stored_for_world)
			var locked: bool = _is_price_locked_for_mode(setting_data, world)
			per_world_values[world] = int(spin_value)

			var game: String = _get_game_from_setting(setting_data)
			var is_checked = _is_location_checked_in_world(loc_name, world, game)
			var condition_visible = _check_visibility_condition(setting_data, world)
			var is_reachable = _is_location_reachable_in_world(loc_name, world, game)

			var is_modified: bool = _is_price_user_modified(setting_data, int(spin_value))

			var sticky_key: String = setting_data["key"] + "|" + str(world)
			if is_reachable or is_modified:
				_price_shown_once[sticky_key] = true

			var was_shown: bool = _price_shown_once.get(sticky_key, false)

			var row_vis: bool = (not is_checked) and condition_visible and (is_reachable or was_shown)
			hbox.visible = row_vis
			spin_box.value = spin_value
			spin_box.editable = (not is_checked) and not locked and (is_reachable or was_shown)
			
			var on_value_changed := func(value: float, world_index: int):
				per_world_values[world_index] = int(value)
				if is_multi:
					current_settings[setting_data["key"]] = per_world_values.duplicate(true)
					_on_setting_changed(setting_data["key"], current_settings[setting_data["key"]])
				else:
					current_settings[setting_data["key"]] = int(value)
					_on_setting_changed(setting_data["key"], int(value))
			spin_box.value_changed.connect(on_value_changed.bind(world))
			hbox.add_child(spin_box)
			container.add_child(hbox)
		return container
	else:
		var container = HBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label = Label.new()
		label.text = setting_data.get("name", setting_data["key"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin_box = SpinBox.new()
		spin_box.min_value = min_val
		spin_box.max_value = max_val
		spin_box.step = step_val
		var display_value = current_value
		if typeof(display_value) == TYPE_DICTIONARY:
			display_value = display_value.get(1, setting_data.get("default", min_val))
		if typeof(display_value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			display_value = setting_data.get("default", min_val)
		if typeof(display_value) == TYPE_STRING:
			var str_val := str(display_value)
			if str_val.is_valid_int():
				display_value = int(str_val)
			elif str_val.is_valid_float():
				display_value = float(str_val)
			else:
				display_value = min_val
		spin_box.value = _safe_to_float(display_value, min_val)
		spin_box.value_changed.connect(func(value: float):
			current_settings[setting_data["key"]] = int(value)
			_on_setting_changed(setting_data["key"], int(value))
		)
		container.add_child(label)
		container.add_child(spin_box)
		return container

func _get_game_from_setting(setting_data: Dictionary) -> String:
	var visible_if = setting_data.get("visible_if", {})
	if visible_if is Dictionary and visible_if.has("games"):
		var games = visible_if["games"]
		if games is Array:
			if games.has("oot"):
				return "OOT"
			elif games.has("mm"):
				return "MM"
	return ""

func _check_visibility_condition(setting: Dictionary, world: int = 0) -> bool:
	if not setting.has("visible_if"):
		return true
	var condition = setting["visible_if"]
	return _evaluate_condition(condition, world)

func _value_matches_condition(current_value: Variant, expected_value: Variant, world: int = 0) -> bool:
	var check_world = world if world > 0 else _get_current_world()
	var actual_current_value = current_value
	
	if typeof(current_value) == TYPE_DICTIONARY:
		if current_value.has(check_world):
			actual_current_value = current_value[check_world]
		else:
			if typeof(expected_value) == TYPE_ARRAY:
				actual_current_value = []
			else:
				actual_current_value = null

	if _is_equal_safe(actual_current_value, expected_value):
		return true
		
	if typeof(expected_value) == TYPE_DICTIONARY:
		if expected_value.has("not"):
			var not_val = expected_value["not"]
			var is_in := false
			
			if typeof(not_val) == TYPE_ARRAY:
				if typeof(actual_current_value) == TYPE_ARRAY:
					for c_item in actual_current_value:
						for not_item in not_val:
							if _is_equal_safe(c_item, not_item):
								is_in = true
								break
						if is_in: break
				else:
					for not_item in not_val:
						if _is_equal_safe(actual_current_value, not_item):
							is_in = true
							break
			else:
				if typeof(actual_current_value) == TYPE_ARRAY:
					for c_item in actual_current_value:
						if _is_equal_safe(c_item, not_val):
							is_in = true
							break
				else:
					is_in = _is_equal_safe(actual_current_value, not_val)
					
			return not is_in
			
		elif expected_value.has("eq"):
			var eq_key = expected_value["eq"]
			var other_value = current_settings.get(eq_key, null)
			if typeof(other_value) == TYPE_DICTIONARY and other_value.has(check_world):
				other_value = other_value[check_world]
			return _is_equal_safe(actual_current_value, other_value)
			
	if typeof(expected_value) == TYPE_ARRAY:
		if expected_value.size() == 0:
			if typeof(actual_current_value) == TYPE_ARRAY and actual_current_value.size() == 0:
				return true
			if typeof(actual_current_value) == TYPE_DICTIONARY:
				var all_empty = true
				for k in actual_current_value:
					if typeof(actual_current_value[k]) == TYPE_ARRAY and actual_current_value[k].size() > 0:
						all_empty = false
						break
				return all_empty
			return false
		else:
			if typeof(actual_current_value) == TYPE_ARRAY:
				for c_item in actual_current_value:
					for e_item in expected_value:
						if _is_equal_safe(c_item, e_item):
							return true
			else:
				for e_item in expected_value:
					if _is_equal_safe(actual_current_value, e_item):
						return true
			return false
			
	if typeof(actual_current_value) == TYPE_ARRAY:
		for item in actual_current_value:
			if _is_equal_safe(item, expected_value):
				return true
		return false
		
	return false

func _evaluate_condition(condition: Variant, world: int = 0) -> bool:
	if typeof(condition) == TYPE_DICTIONARY:
		if condition.has("and"):
			var sub_conditions = condition["and"]
			if typeof(sub_conditions) == TYPE_ARRAY:
				for sub_cond in sub_conditions:
					if not _evaluate_condition(sub_cond, world):
						return false
			return true
		elif condition.has("or"):
			var sub_conditions = condition["or"]
			if typeof(sub_conditions) == TYPE_ARRAY:
				for sub_cond in sub_conditions:
					if _evaluate_condition(sub_cond, world):
						return true
			return false
		elif condition.has("not"):
			var sub_condition = condition["not"]
			return not _evaluate_condition(sub_condition, world)
		else:
			for key in condition:
				var value = condition[key]
				var current_value = current_settings.get(key, null)
				var match_found = false
				
				if key == "location_checked":
					var loc_name = str(value).strip_edges()
					var worlds_to_check = [world] if world > 0 else range(1, _get_players_count() + 1)
					
					var is_checked_anywhere = false
					for w in worlds_to_check:
						if _is_location_checked_in_world(loc_name, w):
							is_checked_anywhere = true
							break
					
					match_found = not is_checked_anywhere
					if not match_found:
						return false
					continue
				
				match_found = _value_matches_condition(current_value, value, world)
				
				if not match_found:
					return false
			return true
	elif typeof(condition) == TYPE_ARRAY:
		for sub_cond in condition:
			if _evaluate_condition(sub_cond, world):
				return true
		return false
	return true

func _is_equal_safe(a: Variant, b: Variant) -> bool:
	if typeof(a) == typeof(b):
		return a == b
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if (typeof(a) == TYPE_BOOL and typeof(b) in [TYPE_INT, TYPE_FLOAT]) or \
	   (typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) == TYPE_BOOL):
		return bool(a) == bool(b)
	return str(a) == str(b)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return
		
		if key_event.keycode == KEY_F1 or key_event.keycode == KEY_F2 or key_event.keycode == KEY_F3:
			return
		
		var focus_owner := get_viewport().gui_get_focus_owner()
		var is_typing := focus_owner != null and (
			focus_owner is LineEdit or 
			focus_owner is TextEdit or 
			focus_owner is SpinBox
		)
		
		if not is_typing and key_event.keycode >= KEY_1 and key_event.keycode <= KEY_5:
			return
		
		if is_typing:
			return
		
		get_viewport().set_input_as_handled()
		return

func _on_setting_changed(key: String, value: Variant) -> void:
	if _updating_settings:
		return
	_updating_settings = true
	
	LogicEvaluator.clear_cache()
	current_settings[key] = value
	_update_visibilities(key)
	_update_dependent_number_widgets(key)
	_update_dependent_special_cond_widgets(key)
	_update_dependent_price_settings(key)
	_request_external_sync(key, value)
	if key == "mode" or key == "players":
		if _item_tracker_cache and _item_tracker_cache.has_method("refresh_world_filter_from_settings"):
			_item_tracker_cache.refresh_world_filter_from_settings()
		var mode = current_settings.get("mode", "single")
		var players = _get_players_count()
		if str(mode).to_lower() != "multi":
			players = 1
		elif players < 2:
			players = 2
		current_settings["players"] = players
		for setting in all_settings:
			var stype = setting.get("type", "")
			if stype == "set" or stype == "number":
				var key_name = setting["key"]
				var current_val = current_settings.get(key_name, {})
				var def_val: Variant
				if stype == "number":
					def_val = 0
				else:
					def_val = []
				if mode == "multi":
					if typeof(current_val) == TYPE_INT or typeof(current_val) == TYPE_FLOAT:
						var per_player_dict = {}
						for i in range(1, players + 1):
							per_player_dict[i] = current_val
						current_settings[key_name] = per_player_dict
					elif typeof(current_val) == TYPE_DICTIONARY:
						for i in range(1, players + 1):
							if not current_val.has(i):
								current_val[i] = def_val
					elif stype == "set" and typeof(current_val) == TYPE_ARRAY:
						var per_player_dict = {}
						for i in range(1, players + 1):
							per_player_dict[i] = current_val.duplicate()
						current_settings[key_name] = per_player_dict
				else:
					if typeof(current_val) == TYPE_DICTIONARY:
						current_settings[key_name] = current_val.get(1, def_val)
		display_settings()
	save_settings_to_file()
	
	_updating_settings = false

func _update_dependent_number_widgets(changed_key: String) -> void:
	for setting in all_settings:
		if setting.get("type") == "number":
			var max_ref = setting.get("max", "")
			if typeof(max_ref) == TYPE_STRING and max_ref == changed_key:
				var container = setting_widgets.get(setting["key"])
				if container:
					for child in container.get_children():
						if child is SpinBox:
							var spin_box = child as SpinBox
							var new_max = _safe_to_float(current_settings.get(changed_key, 100), 100.0)
							spin_box.max_value = new_max
							if spin_box.value > new_max:
								spin_box.value = new_max

func _is_location_reachable_in_world(loc_name: String, world: int, game: String = "") -> bool:
	var clean_name: String = loc_name.strip_edges()
	var detected_game: String = game
	
	if detected_game == "":
		if clean_name.begins_with("OoT ") or clean_name.begins_with("OOT "):
			detected_game = "OOT"
			clean_name = clean_name.substr(4).strip_edges()
		elif clean_name.begins_with("MM ") or clean_name.begins_with("mm "):
			detected_game = "MM"
			clean_name = clean_name.substr(3).strip_edges()
	
	if not LogicEvaluator.has_method("is_location_reachable"):
		return false
	
	if LogicEvaluator.has_method("ensure_reach"):
		LogicEvaluator.ensure_reach(world)
	
	var normalized_game: String = detected_game.strip_edges().to_upper()
	if normalized_game == "OOT":
		normalized_game = "OOT"
	elif normalized_game == "MM":
		normalized_game = "MM"
	else:
		normalized_game = ""
	
	if normalized_game != "":
		return LogicEvaluator.is_location_reachable(clean_name, world, normalized_game)
	
	if LogicEvaluator.is_location_reachable(clean_name, world, "OOT"):
		return true
	if LogicEvaluator.is_location_reachable(clean_name, world, "MM"):
		return true
	return LogicEvaluator.is_location_reachable(clean_name, world, "")

func _update_visibilities(changed_key: String = "") -> void:
	var changed_keys = []
	var mode = current_settings.get("mode", "single")
	var players = _get_players_count()
	if str(mode).to_lower() != "multi":
		players = 1

	for setting in all_settings:
		var setting_key = setting["key"]

		if changed_key != "":
			var vis = setting.get("visible_if")
			if vis == null:
				continue
			if not _condition_depends_on_key(vis, changed_key):
				continue

		var should_be_visible = _check_visibility_condition(setting)
		if not should_be_visible:
			if setting.get("category", "") == "locations_prices":
				continue
			if _applying_bulk:
				continue
			var setting_type = setting.get("type", "")
			var default_value = setting.get("default", get_default_for_type(setting_type))
			var target_default = default_value
			if setting_type == "set" and typeof(default_value) == TYPE_ARRAY:
				var per_player_dict = {}
				for i in range(1, players + 1):
					per_player_dict[i] = default_value.duplicate(true)
				target_default = per_player_dict
			elif setting_type == "number" and mode == "multi" and typeof(default_value) in [TYPE_INT, TYPE_FLOAT]:
				var per_player_dict = {}
				for i in range(1, players + 1):
					per_player_dict[i] = int(default_value)
				target_default = per_player_dict
			elif typeof(target_default) in [TYPE_ARRAY, TYPE_DICTIONARY]:
				target_default = target_default.duplicate(true)

			var current_val = current_settings.get(setting_key)
			var is_different = false
			if typeof(current_val) != typeof(target_default):
				is_different = true
			elif typeof(current_val) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL]:
				is_different = (current_val != target_default)
			elif typeof(current_val) == TYPE_DICTIONARY and typeof(target_default) == TYPE_DICTIONARY:
				is_different = not _deep_equal_fast(current_val, target_default)
			elif typeof(current_val) == TYPE_ARRAY and typeof(target_default) == TYPE_ARRAY:
				is_different = not _deep_equal_fast(current_val, target_default)
			if is_different:
				current_settings[setting_key] = target_default
				changed_keys.append(setting_key)

	if changed_keys.size() > 0:
		display_settings()

	_apply_visibilities()

	if changed_keys.size() > 0:
		for key in changed_keys:
			_update_dependent_number_widgets(key)
			_update_dependent_special_cond_widgets(key)
			_request_external_sync(key, current_settings[key])
		save_settings_to_file()

func _deep_equal_fast(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _deep_equal_fast(a[i], b[i]): return false
		return true
	elif a is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k): return false
			if not _deep_equal_fast(a[k], b[k]): return false
		return true
	return a == b

func _apply_visibilities() -> void:
	var needs_redraw := false
	for setting in all_settings:
		var setting_key = setting["key"]
		if setting_widgets.has(setting_key):
			var should_be_visible = _check_visibility_condition(setting)
			var widget = setting_widgets[setting_key]
			if widget is Control and widget.visible != should_be_visible:
				widget.visible = should_be_visible
				needs_redraw = true
			if should_be_visible and setting.get("category", "") == "locations_prices":
				var old_visible: bool = widget.visible
				widget.visible = _update_price_widget_rows(widget)
				if widget.visible != old_visible:
					needs_redraw = true
	
	if needs_redraw:
		pass

func _is_price_user_modified(setting_data: Dictionary, current_value: Variant) -> bool:
	var default_value: Variant = setting_data.get("default", 0)
	var default_float: float = _safe_to_float(default_value, 0.0)
	var current_float: float = _safe_to_float(current_value, 0.0)
	
	if current_float == default_float:
		return false
	
	var disabled_values = setting_data.get("disabled_value", {})
	if typeof(disabled_values) == TYPE_DICTIONARY:
		for dv_key in disabled_values:
			var dv_float: float = _safe_to_float(disabled_values[dv_key], -1.0)
			if dv_float >= 0 and current_float == dv_float:
				return false
	
	return true

func _get_price_mode_key(setting_data: Dictionary) -> String:
	var price_mode_key: String = str(setting_data.get("price_setting", "")).strip_edges()
	if not price_mode_key.is_empty():
		return price_mode_key

	var disabled_if: Variant = setting_data.get("disabled_if", {})
	if typeof(disabled_if) == TYPE_DICTIONARY:
		for k in disabled_if:
			return str(k)

	return ""


func _get_price_mode_value_for_world(setting_data: Dictionary, world: int) -> String:
	var price_mode_key: String = _get_price_mode_key(setting_data)
	if price_mode_key.is_empty():
		return ""

	var raw: Variant = current_settings.get(price_mode_key, "")
	if typeof(raw) == TYPE_DICTIONARY:
		if raw.has(world):
			raw = raw[world]
		elif raw.has(str(world)):
			raw = raw[str(world)]
		else:
			raw = ""

	return str(raw).strip_edges().to_lower()


func _get_price_default_value(setting_data: Dictionary) -> float:
	var min_val: float = _safe_to_float(setting_data.get("min", 1), 1.0)
	return _safe_to_float(setting_data.get("default", min_val), min_val)


func _get_affordable_price_value(setting_data: Dictionary) -> float:
	var disabled_values: Variant = setting_data.get("disabled_value", {})
	if typeof(disabled_values) == TYPE_DICTIONARY and disabled_values.has("affordable"):
		return _safe_to_float(disabled_values["affordable"], 10.0)
	return 10.0


func _resolve_price_value(setting_data: Dictionary, world: int, stored_value: Variant) -> float:
	var mode: String = _get_price_mode_value_for_world(setting_data, world)
	var default_value: float = _get_price_default_value(setting_data)
	var affordable_value: float = _get_affordable_price_value(setting_data)
	var stored: float = _safe_to_float(stored_value, affordable_value)

	if mode == "vanilla":
		return default_value

	if mode == "affordable":
		return affordable_value

	if stored <= 0.0 or _is_equal_safe(stored, default_value):
		return affordable_value

	return stored

func _normalize_price_values_to_mode() -> void:
	if _normalizing_prices:
		return

	_normalizing_prices = true

	var global_mode: String = str(current_settings.get("mode", "single")).to_lower()
	var players: int = _get_players_count()

	if global_mode != "multi":
		players = 1

	var changed: bool = false

	for setting in all_settings:
		if setting.get("category", "") != "locations_prices":
			continue

		var key: String = str(setting["key"])
		var current_value: Variant = current_settings.get(key, setting.get("default", 0))

		if global_mode == "multi":
			var per_world: Dictionary = {}

			if typeof(current_value) == TYPE_DICTIONARY:
				per_world = current_value.duplicate(true)
			else:
				var scalar: float = _safe_to_float(current_value, 0.0)
				for i in range(1, players + 1):
					per_world[i] = int(scalar)

			for w in range(1, players + 1):
				var stored: Variant = per_world.get(w, setting.get("default", 0))
				var resolved: int = int(_resolve_price_value(setting, w, stored))
				var current_int: int = int(_safe_to_float(stored, resolved))

				if current_int != resolved:
					per_world[w] = resolved
					changed = true

			if not _deep_equal_fast(current_value, per_world):
				current_settings[key] = per_world
				changed = true
		else:
			var stored_single: Variant = current_value
			var resolved_single: int = int(_resolve_price_value(setting, 1, stored_single))
			var current_single_int: int = int(_safe_to_float(stored_single, resolved_single))

			if current_single_int != resolved_single:
				current_settings[key] = resolved_single
				changed = true

	if changed:
		save_settings_to_file()
		if current_filter == "locations_prices":
			display_settings()

	_normalizing_prices = false

func _is_price_locked_for_mode(setting_data: Dictionary, world: int) -> bool:
	var mode: String = _get_price_mode_value_for_world(setting_data, world)
	return mode == "vanilla" or mode == "affordable"

func _update_price_widget_rows(widget: Control) -> bool:
	var price_loc_name: String = str(widget.get_meta("price_loc_name", ""))
	if price_loc_name == "":
		return true
	
	var setting_key: String = ""
	var setting_data: Dictionary = {}
	for key in setting_widgets:
		if setting_widgets[key] == widget:
			setting_key = key
			for s in all_settings:
				if s["key"] == key:
					setting_data = s
					break
			break
	
	var game: String = _get_game_from_setting(setting_data)
	
	var any_visible: bool = false
	for row in widget.get_children():
		if not row.has_meta("price_world"):
			continue
		var row_world: int = int(row.get_meta("price_world"))
		var is_checked: bool = _is_location_checked_in_world(price_loc_name, row_world, game)
		var is_reachable: bool = _is_location_reachable_in_world(price_loc_name, row_world, game)
		
		var current_val_for_world: Variant
		var cs_val = current_settings.get(setting_key, 0)
		if typeof(cs_val) == TYPE_DICTIONARY:
			current_val_for_world = cs_val.get(row_world, 0)
		else:
			current_val_for_world = cs_val
		var is_modified: bool = _is_price_user_modified(setting_data, current_val_for_world)
		
		var sticky_key: String = setting_key + "|" + str(row_world)
		if is_reachable or is_modified:
			_price_shown_once[sticky_key] = true
		
		var was_shown: bool = _price_shown_once.get(sticky_key, false)
		
		var row_vis: bool = (not is_checked) and (is_reachable or was_shown)
		row.visible = row_vis
		if row_vis:
			any_visible = true
	return any_visible

func refresh_price_visibilities() -> void:
	for setting in all_settings:
		if setting.get("category", "") != "locations_prices":
			continue
		var widget = setting_widgets.get(setting["key"])
		if widget is Control and widget.visible:
			widget.visible = _update_price_widget_rows(widget)

func _on_load_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("_on_load_pressed"):
		main_node._on_load_pressed()

func _on_save_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("_on_save_pressed"):
		main_node._on_save_pressed()
	save_settings_to_file()

func _on_clear_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("reset_all"):
		main_node._show_reset_confirmation()

func _on_category_button_toggled(toggled_on: bool, category: String) -> void:
	if toggled_on:
		for cat in category_buttons:
			if cat != category:
				category_buttons[cat].button_pressed = false
		current_filter = category
		display_settings()

func save_settings_to_file() -> void:
	if _cfg_save_timer == null:
		_cfg_save_timer = Timer.new()
		_cfg_save_timer.one_shot = true
		_cfg_save_timer.wait_time = 0.4
		_cfg_save_timer.timeout.connect(_write_settings_cfg)
		add_child(_cfg_save_timer)
	_cfg_save_timer.start()

func _write_settings_cfg() -> void:
	var save_data = {}
	save_data["version"] = 1
	save_data["settings"] = current_settings
	save_data["price_shown_once"] = _price_shown_once
	var file = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(save_data, "\t", false))
	file.close()

func save_settings_now() -> void:
	if _cfg_save_timer and not _cfg_save_timer.is_stopped():
		_cfg_save_timer.stop()
	_write_settings_cfg()

func load_saved_settings() -> void:
	var file = FileAccess.open("user://settings.cfg", FileAccess.READ)
	if file == null: return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK: return
	var save_data = json.get_data()
	if save_data.has("settings"):
		var saved_settings = save_data["settings"]
		for key in saved_settings:
			current_settings[key] = _normalize_dict_keys(saved_settings[key])
	if save_data.has("price_shown_once"):
		_price_shown_once = save_data["price_shown_once"]
	if not all_settings.is_empty():
		_normalize_price_values_to_mode()

func reset_to_defaults() -> void:
	_price_shown_once.clear()
	var mode = current_settings.get("mode", "single")
	var players = _get_players_count()
	if str(mode).to_lower() != "multi":
		players = 1
	for setting in all_settings:
		var key = setting["key"]
		var setting_type = setting.get("type", "")
		var default_value = setting.get("default", get_default_for_type(setting_type))
		if setting_type == "set" and typeof(default_value) == TYPE_ARRAY:
			var per_player_dict = {}
			for i in range(1, players + 1):
				per_player_dict[i] = default_value.duplicate()
			current_settings[key] = per_player_dict
		else:
			current_settings[key] = default_value
	var map_tab = get_tree().get_first_node_in_group("map_tab")
	if map_tab and map_tab.has_method("refresh_jp_layout_visibility"):
		map_tab.refresh_jp_layout_visibility()
	_normalize_price_values_to_mode()
	display_settings()
	save_settings_to_file()

func get_setting_value(key: String) -> Variant:
	return current_settings.get(key, null)

func set_setting_value(key: String, value: Variant) -> bool:
	if current_settings.has(key):
		current_settings[key] = value
		return true
	return false

func get_all_settings() -> Dictionary:
	return current_settings.duplicate()

func _normalize_dict_keys(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var new_dict = {}
		for k in value.keys():
			var int_key = int(k) if str(k).is_valid_int() else k
			new_dict[int_key] = _normalize_dict_keys(value[k])
		return new_dict
	elif typeof(value) == TYPE_ARRAY:
		var new_array = []
		for item in value:
			new_array.append(_normalize_dict_keys(item))
		return new_array
	return value

func _create_special_cond_widget(setting_data: Dictionary, current_value: Variant) -> Control:
	var container = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = setting_data.get("name", setting_data["key"])
	container.add_child(label)
	if typeof(current_value) != TYPE_DICTIONARY:
		current_value = setting_data.get("default", {}).duplicate()
	var count_container = HBoxContainer.new()
	var count_label = Label.new()
	count_label.text = "Required Count: "
	count_container.add_child(count_label)
	var count_spin = SpinBox.new()
	count_spin.min_value = 0
	count_spin.max_value = 9999
	count_spin.value = current_value.get("count", 0)
	count_spin.value_changed.connect(func(val: float):
		current_value["count"] = int(val)
		current_settings[setting_data["key"]] = current_value
		_on_setting_changed(setting_data["key"], current_value)
	)
	count_container.add_child(count_spin)
	container.add_child(count_container)
	var fields = setting_data.get("fields", {})
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field_checkboxes = {}
	var field_containers = {}
	for field_key in fields:
		var field_data = fields[field_key]
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb = CheckBox.new()
		cb.text = field_data.get("name", field_key)
		cb.button_pressed = current_value.get(field_key, false)
		field_checkboxes[field_key] = cb
		field_containers[field_key] = hbox
		cb.toggled.connect(func(toggled: bool):
			current_value[field_key] = toggled
			current_settings[setting_data["key"]] = current_value
			_update_special_cond_max(container)
			_on_setting_changed(setting_data["key"], current_value)
		)
		hbox.add_child(cb)
		grid.add_child(hbox)
	container.add_child(grid)
	container.set_meta("field_checkboxes", field_checkboxes)
	container.set_meta("field_containers", field_containers)
	container.set_meta("count_spin", count_spin)
	container.set_meta("fields_data", fields)
	container.set_meta("current_value", current_value)
	_update_special_cond_visibility(container)
	_update_special_cond_max(container)
	return container

func _update_special_cond_visibility(widget: Control) -> void:
	var fields_data = widget.get_meta("fields_data")
	var field_containers = widget.get_meta("field_containers")
	for field_key in fields_data:
		var field_data = fields_data[field_key]
		var hbox = field_containers[field_key]
		if field_data.has("visible_if"):
			hbox.visible = _evaluate_condition(field_data["visible_if"])
		else:
			hbox.visible = true

func _update_special_cond_max(widget: Control) -> void:
	var fields_data = widget.get_meta("fields_data")
	var field_checkboxes = widget.get_meta("field_checkboxes")
	var field_containers = widget.get_meta("field_containers")
	var count_spin = widget.get_meta("count_spin")
	var max_total = 0
	for field_key in fields_data:
		var hbox = field_containers[field_key]
		if not hbox.visible:
			continue
		var cb = field_checkboxes[field_key]
		if cb.button_pressed:
			var field_data = fields_data[field_key]
			var field_max = field_data.get("max", 0)
			if typeof(field_max) == TYPE_STRING:
				if field_max == "masksOotCalc":
					var blast = 1 if current_settings.get("blastMaskOot", false) else 0
					var stone = 1 if current_settings.get("stoneMaskOot", false) else 0
					var kamaro = 1 if current_settings.get("kamaroMaskOot", false) else 0
					field_max = 8 + blast + stone + kamaro
				else:
					field_max = current_settings.get(field_max, 0)
			max_total += int(field_max)
	count_spin.max_value = max_total
	if count_spin.value > max_total:
		count_spin.value = max_total

func _condition_depends_on_key(condition: Variant, key: String) -> bool:
	if typeof(condition) == TYPE_DICTIONARY:
		if condition.has(key):
			return true
		for sub_key in condition:
			if _condition_depends_on_key(condition[sub_key], key):
				return true
	elif typeof(condition) == TYPE_ARRAY:
		for sub_cond in condition:
			if _condition_depends_on_key(sub_cond, key):
				return true
	return false

func _update_dependent_price_settings(changed_key: String) -> void:
	for setting in all_settings:
		if setting.get("category", "") != "locations_prices":
			continue

		var price_mode_key: String = _get_price_mode_key(setting)

		if price_mode_key == changed_key:
			_normalize_price_values_to_mode()
			return

		var disabled_if: Variant = setting.get("disabled_if", {})
		if typeof(disabled_if) == TYPE_DICTIONARY and disabled_if.has(changed_key):
			_normalize_price_values_to_mode()
			return

func _update_dependent_special_cond_widgets(changed_key: String) -> void:
	for setting in all_settings:
		if setting.get("type") == "special_cond":
			var widget = setting_widgets.get(setting["key"])
			if widget and widget.visible:
				var fields_data = widget.get_meta("fields_data")
				var need_update = false
				for field_key in fields_data:
					var field_max = fields_data[field_key].get("max", 0)
					if typeof(field_max) == TYPE_STRING and field_max == changed_key:
						need_update = true
						break
					if fields_data[field_key].has("visible_if"):
						if _condition_depends_on_key(fields_data[field_key]["visible_if"], changed_key):
							need_update = true
							break
				if need_update:
					_update_special_cond_visibility(widget)
					_update_special_cond_max(widget)

func refresh_setting_visibilities() -> void:
	var changed_keys: Array = []
	var mode = current_settings.get("mode", "single")
	var players = _get_players_count()
	if str(mode).to_lower() != "multi":
		players = 1
	for setting in all_settings:
		if not setting.has("visible_if"):
			continue
		if not _condition_depends_on_key(setting["visible_if"], "location_checked"):
			continue
		var setting_key = setting["key"]
		var should_be_visible = _check_visibility_condition(setting)
		if not should_be_visible:
			if setting.get("category", "") == "locations_prices":
				continue
			if _applying_bulk:
				continue
			var setting_type = setting.get("type", "")
			var default_value = setting.get("default", get_default_for_type(setting_type))
			var target_default = default_value
			if setting_type == "set" and typeof(default_value) == TYPE_ARRAY:
				var per_player_dict = {}
				for i in range(1, players + 1):
					per_player_dict[i] = default_value.duplicate(true)
				target_default = per_player_dict
			elif setting_type == "number" and mode == "multi" and typeof(default_value) in [TYPE_INT, TYPE_FLOAT]:
				var per_player_dict = {}
				for i in range(1, players + 1):
					per_player_dict[i] = int(default_value)
				target_default = per_player_dict
			elif typeof(target_default) in [TYPE_ARRAY, TYPE_DICTIONARY]:
				target_default = target_default.duplicate(true)
			if not _deep_equal_fast(current_settings.get(setting_key), target_default):
				current_settings[setting_key] = target_default
				changed_keys.append(setting_key)
		var widget = setting_widgets.get(setting_key)
		if widget is Control:
			widget.visible = should_be_visible
			if should_be_visible and setting.get("category", "") == "locations_prices":
				widget.visible = _update_price_widget_rows(widget)
	if changed_keys.size() > 0:
		save_settings_to_file()
