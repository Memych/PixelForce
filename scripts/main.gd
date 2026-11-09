extends Control

@onready var location_list: VBoxContainer = %LocationList
@onready var status_label: Label = %StatusLabel
@onready var search_box: LineEdit = %SearchBox
@onready var game_filter: OptionButton = %GameFilter
@onready var status_filter: OptionButton = %StatusFilter
@onready var world_filter: OptionButton = %WorldFilter
@onready var load_button: Button = %LoadLogButton
@onready var save_button: Button = %SaveButton
@onready var clear_button: Button = %ClearButton
@onready var file_dialog: FileDialog = %FileDialog
@onready var log_info_button: Button = %LogInfoButton

const LOCATIONS_PATH: String = "res://data/locations.json"
const ITEMS_PATH: String = "res://data/items.json"
const BATCH_SIZE: int = 50

enum DialogMode { NONE, LOAD, SAVE }

var _reset_dialog: ConfirmationDialog
var _dialog_mode: int = DialogMode.NONE
var _log_info: Dictionary = {}
var _log_mode: String = ""
var _worlds_count: int = 1
var _all_data: Array = []
var _world_assignments: Dictionary = {}
var _items: Array = []
var _items_by_name: Dictionary = {}
var _items_name_lower: Dictionary = {}
var _item_texture_cache: Dictionary = {}
var _world_blocks: Array = []
var _filter_timer: Timer
var _data_by_key: Dictionary = {}
var _checked_count: int = 0
var _valid_total_cache: int = 0
var _visible_cache: Dictionary = {}
var _build_token: int = 0
var _filter_token: int = 0
var _shown_count: int = 0
var _checked_shown_count: int = 0
var _re_entry: RegEx
var _re_world: RegEx
var _re_region: RegEx
var _re_player: RegEx
var _re_seed_line: RegEx
var _re_version_line: RegEx
var _re_mode_line: RegEx
var _re_cloak: RegEx
var _re_item_cleanup: RegEx
var _entrance_shuffle: Dictionary = {}
var _exit_shuffle: Dictionary = {}
var _spoiler_settings: Dictionary = {}
var _world_flags: Dictionary = {}
var _starting_items: Dictionary = {}
var _settings_name_to_value: Dictionary = {}
var _tricks_name_to_key: Dictionary = {}
var _special_conditions: Dictionary = {}
var _song_events_log: Dictionary = {}
var _fast_location_lookup: Dictionary = {}
var _deferred_refresh_timer: Timer = null
var _location_idx: Dictionary = {}

func _ready() -> void:
	add_to_group("main_scene")
	_compile_regexes()
	search_box.text_changed.connect(_on_filter_input_changed)
	game_filter.item_selected.connect(_on_filter_input_changed)
	status_filter.item_selected.connect(_on_filter_input_changed)
	world_filter.item_selected.connect(_on_filter_input_changed)
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	log_info_button.pressed.connect(_on_log_info_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(_on_file_dialog_canceled)
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray([
		"*.json, *.txt ; All supported files",
		"*.json ; JSON files",
		"*.txt ; Text files",
	])
	if game_filter.item_count == 0:
		game_filter.add_item("All Games", 0)
		game_filter.add_item("OoT", 1)
		game_filter.add_item("MM", 2)
	if log_info_button != null:
		log_info_button.visible = false
		log_info_button.text = "Log not loaded"
	_filter_timer = Timer.new()
	_filter_timer.one_shot = true
	_filter_timer.wait_time = 0.12
	_filter_timer.timeout.connect(_on_filter_timer_timeout)
	add_child(_filter_timer)
	_load_items()
	reset_to_default()
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Reset Progress"
	_reset_dialog.dialog_text = "Are you sure you want to reset all progress?\nAll checked locations, tracked items and settings will be cleared."
	_reset_dialog.ok_button_text = "Reset"
	_reset_dialog.cancel_button_text = "Cancel"
	_reset_dialog.confirmed.connect(reset_all)
	add_child(_reset_dialog)

	load_button.tooltip_text = "Load spoiler log or tracker save (F1)"
	save_button.tooltip_text = "Save tracker state (F2)"
	clear_button.tooltip_text = "Reset all progress (F3)"
	visibility_changed.connect(func():
		if is_visible_in_tree():
			_filter_token += 1
			_apply_optimized_filters(_filter_token)
	)

func _request_deferred_refresh() -> void:
	if _deferred_refresh_timer == null:
		_deferred_refresh_timer = Timer.new()
		_deferred_refresh_timer.one_shot = true
		_deferred_refresh_timer.wait_time = 0.05
		_deferred_refresh_timer.timeout.connect(_do_deferred_refresh)
		add_child(_deferred_refresh_timer)
	_deferred_refresh_timer.start()

func _do_deferred_refresh() -> void:
	var map_tab := get_tree().get_first_node_in_group("map_tab")
	if map_tab and map_tab.is_visible_in_tree():
		_update_map_counters()
	var settings_node := get_tree().get_first_node_in_group("settings_tab")
	if settings_node and settings_node.has_method("refresh_setting_visibilities"):
		settings_node.refresh_setting_visibilities()

func _compile_regexes() -> void:
	_re_entry = RegEx.new()
	_re_entry.compile("^\\s*(?:Location\\s+-\\s+)?(OOT|MM)\\s+([^:]+?):\\s*(.+?)\\s*$")
	_re_world = RegEx.new()
	_re_world.compile("^\\s+World\\s+(\\d+)\\s*\\(")
	_re_region = RegEx.new()
	_re_region.compile("^\\s{2}([^()]+?)\\s*\\((\\d+)\\)\\s*:\\s*$")
	_re_player = RegEx.new()
	_re_player.compile("^(?:Player\\s+([0-9]+)|P([0-9]+)\\s*[-:]?\\s*)(.*)$")
	_re_seed_line = RegEx.new()
	_re_seed_line.compile("^Seed:\\s*([A-Fa-f0-9]+)")
	_re_version_line = RegEx.new()
	_re_version_line.compile("^Version:\\s*(.+)$")
	_re_mode_line = RegEx.new()
	_re_mode_line.compile("^\\s*mode:\\s*(single|coop|multi)\\s*$")
	_re_cloak = RegEx.new()
	_re_cloak.compile("^(.+?)\\s*\\(cloaked as .+?\\)$")
	_re_item_cleanup = RegEx.new()
	_re_item_cleanup.compile("^(?:Player\\s+\\d+|P\\d+\\s*-\\s*)(.*)$")

func _load_items() -> void:
	_items.clear()
	_items_by_name.clear()
	_items_name_lower.clear()
	_item_texture_cache.clear()
	if not FileAccess.file_exists(ITEMS_PATH): return
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null: return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array): return
	for row in parsed:
		if not (row is Array) or row.size() < 1: continue
		var name_str: String = row[0].strip_edges()
		var image_path: String = row[1].strip_edges() if row.size() >= 2 else ""
		_items.append([name_str, image_path])
		_items_by_name[name_str] = image_path
		_items_name_lower[name_str.to_lower()] = image_path

func has_item(item_name: String) -> bool:
	var clean_name: String = item_name.strip_edges()
	return clean_name != "" and clean_name != "(unknown)" and _items_by_name.has(clean_name)

func get_item_image(item_name: String) -> String:
	var clean_name: String = item_name.strip_edges()
	var m := _re_item_cleanup.search(clean_name)
	if m != null and m.get_string(1) != "":
		clean_name = m.get_string(1).strip_edges()
	return _items_name_lower.get(clean_name.to_lower(), "")

func get_item_texture(item_name: String) -> Texture2D:
	var clean_name: String = item_name.strip_edges()
	var path: String = get_item_image(clean_name)
	if path.is_empty() or not ResourceLoader.exists(path): return null
	if _item_texture_cache.has(path): return _item_texture_cache[path]
	var tex: Texture2D = load(path)
	_item_texture_cache[path] = tex
	return tex

func _base_color(n: int) -> Color:
	var fixed: Array[Color] = [
		Color(1.0, 0.6, 0.6), Color(0.55, 1.0, 0.55), Color(0.55, 0.55, 1.0),
		Color(1.0, 1.0, 0.55), Color(1.0, 0.55, 1.0), Color(0.55, 1.0, 1.0),
		Color(1.0, 0.8, 0.55), Color(0.8, 0.55, 1.0),
	]
	if n >= 1 and n <= fixed.size(): return fixed[n - 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 2654435761 + 0xC0FFEE
	rng.randomize()
	return Color.from_hsv(rng.randf(), 0.55, 0.95)

func color_to_hex(c: Color) -> String:
	return "#%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]

func _player_color_hex_for(player: int) -> String:
	return color_to_hex(_base_color(player))

func reset_to_default() -> void:
	_log_info.clear()
	_log_mode = ""
	_worlds_count = 1
	_all_data.clear()
	_world_assignments.clear()
	_entrance_shuffle.clear()
	_exit_shuffle.clear()
	_special_conditions.clear()
	var locations: Array = _load_locations_json()
	for row in locations:
		_all_data.append({
			"game": row[0], "region": row[1], "name": row[2],
			"item": "(unknown)", "world": 1, "player": 0, "checked": false,
			"key": row[0] + "|" + row[2] + "|w1",
		})
	_rebuild_location_idx()
	_recompute_valid_total()
	_refresh_world_filter()
	_build_tree_lazy()
	_starting_items.clear()
	_song_events_log.clear()
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("sync_song_events"):
		item_tracker.sync_song_events()
	_update_map_tab()

func _load_locations_json() -> Array:
	if not FileAccess.file_exists(LOCATIONS_PATH): return []
	var file := FileAccess.open(LOCATIONS_PATH, FileAccess.READ)
	if file == null: return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Array else []

func _build_tree_lazy() -> void:
	_build_token += 1
	var current_token = _build_token
	for child in location_list.get_children():
		child.queue_free()
	_world_blocks.clear()
	_data_by_key.clear()
	_checked_count = 0
	_visible_cache.clear()
	for d in _all_data:
		var key = str(d.get("key", ""))
		_data_by_key[key] = d
		if d.get("checked", false): _checked_count += 1
	var worlds_sorted: Array = []
	var grouped: Dictionary = {}
	for d in _all_data:
		var world: int = int(d.get("world", 1))
		var game: String = str(d.get("game", "OoT"))
		var region: String = str(d.get("region", "Extras"))
		if not grouped.has(world):
			grouped[world] = {}
			worlds_sorted.append(world)
		if not grouped[world].has(game): grouped[world][game] = {}
		if not grouped[world][game].has(region): grouped[world][game][region] = []
		grouped[world][game][region].append(d)
	worlds_sorted.sort()
	for world in worlds_sorted:
		var world_int: int = int(world)
		var world_block: Dictionary = {"world": world_int, "game_blocks": [], "cached_rows": {}}
		var world_valid_count: int = 0
		for g in grouped[world_int].keys():
			for r in grouped[world_int][g].keys():
				for loc in grouped[world_int][g][r]:
					var item_name: String = str(loc.get("item", "(unknown)")).strip_edges()
					if item_name != "" and item_name.to_lower() != "(unknown)":
						world_valid_count += 1
		
		var world_color: Color = _base_color(world_int).lightened(0.25)
		var world_header: Button = _create_header("▼ World " + str(world_int) + " (" + str(world_valid_count) + ")", 10, world_color)
		location_list.add_child(world_header)
		var world_vbox: VBoxContainer = VBoxContainer.new()
		world_vbox.add_theme_constant_override("separation", 4)
		location_list.add_child(world_vbox)
		world_header.pressed.connect(_make_toggle_handler(world_header, world_vbox))
		world_block["header"] = world_header
		world_block["container"] = world_vbox
		_world_blocks.append(world_block)
		for game in ["OoT", "MM"]:
			if not grouped[world].has(game): continue
			var game_block: Dictionary = {"game": game, "region_blocks": []}
			var game_color: Color = Color(0.95, 0.85, 0.4)
			
			var game_valid_count: int = 0
			for r in grouped[world][game].keys():
				for loc in grouped[world][game][r]:
					var item_name: String = str(loc.get("item", "(unknown)")).strip_edges()
					if item_name != "" and item_name.to_lower() != "(unknown)":
						game_valid_count += 1
			
			var game_header: Button = _create_header(" ▼ " + game + " (" + str(game_valid_count) + ")", 10, game_color)
			world_vbox.add_child(game_header)
			var game_vbox: VBoxContainer = VBoxContainer.new()
			game_vbox.add_theme_constant_override("separation", 4)
			world_vbox.add_child(game_vbox)
			game_header.pressed.connect(_make_toggle_handler(game_header, game_vbox))
			game_block["header"] = game_header
			game_block["container"] = game_vbox
			for region in grouped[world][game].keys():
				var locs: Array = grouped[world][game][region]
				locs.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
				var region_block: Dictionary = {"region": region, "rows": [], "locs": locs}
				var region_color: Color = Color(0.7, 0.9, 1.0)
				
				var valid_count: int = 0
				for loc in locs:
					var item_name: String = str(loc.get("item", "(unknown)")).strip_edges()
					if item_name != "" and item_name.to_lower() != "(unknown)":
						valid_count += 1
				
				var region_header: Button = _create_header("  ▼ " + region + " (" + str(valid_count) + ")", 10, region_color)
				game_vbox.add_child(region_header)
				var region_vbox: VBoxContainer = VBoxContainer.new()
				region_vbox.add_theme_constant_override("separation", 1)
				game_vbox.add_child(region_vbox)
				region_header.pressed.connect(_make_toggle_handler(region_header, region_vbox))
				region_block["header"] = region_header
				region_block["container"] = region_vbox
				game_block["region_blocks"].append(region_block)
			world_block["game_blocks"].append(game_block)
	_update_counters()
	_populate_rows_async(current_token)

func _create_header(text: String, _size: int, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_font_size_override("font_size", _size)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color.lightened(0.2))
	btn.add_theme_color_override("font_pressed_color", color)
	return btn

func _make_toggle_handler(label_btn: Button, content: Control) -> Callable:
	var updater := func() -> void:
		var txt: String = label_btn.text
		var cleaned: String = txt.lstrip("▼▶ ")
		label_btn.text = ("▼  " if content.visible else "▶  ") + cleaned
	content.visibility_changed.connect(updater)
	updater.call()
	return func() -> void:
		content.visible = not content.visible

func _populate_rows_async(token: int) -> void:
	var row_scene: PackedScene = preload("res://scenes/location_row.tscn")
	var count: int = 0
	for world_block in _world_blocks:
		if token != _build_token: return
		for game_block in world_block.get("game_blocks", []):
			for region_block in game_block.get("region_blocks", []):
				var region_vbox: VBoxContainer = region_block.get("container")
				var locs: Array = region_block.get("locs", [])
				for loc in locs:
					if token != _build_token: return
					if not is_instance_valid(region_vbox): return
					var item_name: String = str(loc.get("item", "(unknown)")).strip_edges()
					if item_name == "" or item_name.to_lower() == "(unknown)":
						continue
					var row_btn: PanelContainer = row_scene.instantiate()
					region_vbox.add_child(row_btn)
					var p: int = int(loc.get("player", 0))
					var loc_name_str: String = str(loc.get("name", ""))
					var key: String = str(loc.get("key", ""))
					row_btn.set_meta("world", int(loc.get("world", 1)))
					row_btn.set_meta("game", str(loc.get("game", "OoT")))
					row_btn.set_meta("loc_name", loc_name_str)
					row_btn.set_meta("loc_name_lower", loc_name_str.to_lower())
					row_btn.set_meta("loc_item", item_name)
					row_btn.set_meta("loc_item_lower", item_name.to_lower())
					row_btn.set_meta("player", p)
					row_btn.set_meta("player_color_hex", _player_color_hex_for(p))
					row_btn.set_meta("mode", _log_mode)
					row_btn.set_meta("checked", bool(loc.get("checked", false)))
					row_btn.set_meta("key", key)
					row_btn.set_meta("region", region_block.get("region", ""))
					row_btn.set_meta("source_dict", loc)
					var icon_node = row_btn.find_child("IconRect", true, false)
					if icon_node and icon_node is TextureRect:
						icon_node.texture = get_item_texture(item_name)
					row_btn.update_via_meta()
					row_btn.check_changed.connect(_on_row_check_changed)
					region_block["rows"].append(row_btn)
					world_block["cached_rows"][key] = row_btn
					count += 1
					if count >= BATCH_SIZE:
						count = 0
						await get_tree().process_frame
	if token != _build_token: return
	if token == _build_token:
		_apply_optimized_filters()

func _on_filter_input_changed(_arg = null) -> void:
	_filter_timer.start()

func _on_filter_timer_timeout() -> void:
	_filter_token += 1
	_apply_optimized_filters(_filter_token)

func _apply_optimized_filters(token: int = 0) -> void:
	var query: String = search_box.text.strip_edges().to_lower()
	var game_idx: int = game_filter.selected
	var status_idx: int = status_filter.selected
	var world_idx: int = world_filter.selected if world_filter else 0
	var batch_count: int = 0
	for world_block in _world_blocks:
		if token != 0 and token != _filter_token: return
		var world: int = int(world_block.get("world", 1))
		var world_container: VBoxContainer = world_block.get("container")
		var world_header: Button = world_block.get("header")
		var world_visible: bool = (world_idx == 0) or (world == world_idx)
		var any_game_visible: bool = false
		for game_block in world_block.get("game_blocks", []):
			if token != 0 and token != _filter_token: return
			var game: String = game_block.get("game", "")
			var game_container: VBoxContainer = game_block.get("container")
			var game_header: Button = game_block.get("header")
			var game_visible: bool = world_visible and (
				game_idx == 0 or (game_idx == 1 and game == "OoT") or (game_idx == 2 and game == "MM")
			)
			var any_region_visible: bool = false
			for region_block in game_block.get("region_blocks", []):
				if token != 0 and token != _filter_token: return
				var region_container: VBoxContainer = region_block.get("container")
				var region_header: Button = region_block.get("header")
				var any_row_visible: bool = false
				for row_btn in region_block.get("rows", []):
					if not is_instance_valid(row_btn): continue
					var checked_flag: bool = row_btn.get_meta("checked", false)
					var row_visible: bool = game_visible
					if row_visible:
						if status_idx == 1 and checked_flag: row_visible = false
						elif status_idx == 2 and not checked_flag: row_visible = false
					if row_visible and query != "":
						var nm: String = row_btn.get_meta("loc_name_lower", "")
						var item_lower: String = row_btn.get_meta("loc_item_lower", "")
						if nm.find(query) == -1 and item_lower.find(query) == -1:
							row_visible = false
					if row_btn.visible != row_visible:
						row_btn.visible = row_visible
					if row_visible:
						any_row_visible = true
					batch_count += 1
					if batch_count >= 300:
						batch_count = 0
						await get_tree().process_frame
						if token != 0 and token != _filter_token: return
				if is_instance_valid(region_container):
					region_container.visible = any_row_visible
				if is_instance_valid(region_header):
					region_header.visible = any_row_visible
				if any_row_visible: any_region_visible = true
			if is_instance_valid(game_container):
				game_container.visible = any_region_visible
			if is_instance_valid(game_header):
				game_header.visible = any_region_visible
			if any_region_visible: any_game_visible = true
		if is_instance_valid(world_container):
			world_container.visible = any_game_visible
		if is_instance_valid(world_header):
			world_header.visible = any_game_visible
	_recalculate_shown_count()
	_update_status_label_fast()

func _update_status_label_fast() -> void:
	var is_filter_active: bool = (
		search_box.text.strip_edges() != "" or game_filter.selected != 0 or
		status_filter.selected != 0 or (world_filter != null and world_filter.selected != 0)
	)
	var total_count: int = _get_valid_total_count()
	var world_suffix: String = "   |   Worlds: %d" % _worlds_count if _worlds_count > 1 else ""
	if is_filter_active:
		status_label.text = "Total: %d | Shown: %d | Checked: %d%s | Mode: %s" % [total_count, _shown_count, _checked_shown_count, world_suffix, _log_mode]
	else:
		status_label.text = "Total: %d | Checked: %d%s | Mode: %s" % [total_count, _checked_count, world_suffix, _log_mode]

func _recalculate_shown_count() -> void:
	_shown_count = 0
	_checked_shown_count = 0
	for world_block in _world_blocks:
		for game_block in world_block.get("game_blocks", []):
			for region_block in game_block.get("region_blocks", []):
				for row_btn in region_block.get("rows", []):
					if is_instance_valid(row_btn) and row_btn.visible:
						_shown_count += 1
						if row_btn.get_meta("checked", false):
							_checked_shown_count += 1

func _on_row_check_changed(row_btn: PanelContainer, pressed: bool) -> void:
	var key: String = row_btn.get_meta("key", "")
	if key and _data_by_key.has(key): _data_by_key[key]["checked"] = pressed
	row_btn.set_meta("checked", pressed)
	var src: Dictionary = row_btn.get_meta("source_dict", {})
	if not src.is_empty(): src["checked"] = pressed
	if pressed: _checked_count += 1
	else: _checked_count -= 1
	if row_btn.has_method("update_via_meta"):
		row_btn.update_via_meta()
	
	var loc_item: String = row_btn.get_meta("loc_item", "")
	var loc_world: int = int(row_btn.get_meta("world", 1))
	var loc_player: int = int(row_btn.get_meta("player", 0))
	var tracker_world: int = loc_player if loc_player > 0 else loc_world

	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("sync_item_from_location"):
		item_tracker.sync_item_from_location(loc_item, pressed, tracker_world)
	
	var status_idx: int = status_filter.selected
	var new_visible := row_btn.visible
	if status_idx == 1:
		new_visible = not pressed
	elif status_idx == 2:
		new_visible = pressed
	if new_visible != row_btn.visible:
		row_btn.visible = new_visible
		if new_visible:
			_shown_count += 1
		else:
			_shown_count -= 1
	if new_visible:
		if pressed:
			_checked_shown_count += 1
		else:
			_checked_shown_count -= 1
	_update_status_label_fast()
	_request_deferred_refresh()

func _get_valid_total_count() -> int:
	return _valid_total_cache

func _recompute_valid_total() -> void:
	var count: int = 0
	for d in _all_data:
		var item: String = str(d.get("item", "")).strip_edges()
		if item != "" and item.to_lower() != "(unknown)":
			count += 1
	_valid_total_cache = count

func _update_counters() -> void:
	var total_count: int = _get_valid_total_count()
	var world_suffix: String = " | Worlds: %d" % _worlds_count if _worlds_count > 1 else ""
	status_label.text = "Total: %d | Checked: %d%s | Mode: %s" % [total_count, _checked_count, world_suffix, _log_mode]

func _on_load_pressed() -> void:
	_dialog_mode = DialogMode.LOAD
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Load Log or Tracker Save"
	file_dialog.ok_button_text = "Load"
	file_dialog.popup_centered(Vector2i(900, 600))

func _on_save_pressed() -> void:
	_dialog_mode = DialogMode.SAVE
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Save Tracker State"
	file_dialog.ok_button_text = "Save"
	file_dialog.current_file = "tracker_save.json"
	file_dialog.current_dir = "res://"
	file_dialog.popup_centered(Vector2i(900, 600))

func _on_file_selected(path: String) -> void:
	match _dialog_mode:
		DialogMode.LOAD:
			_detect_and_load_file(path)
		DialogMode.SAVE:
			_save_to_path(path)
	_dialog_mode = DialogMode.NONE

func _detect_and_load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_error_dialog("Failed to open file. Please check if the file is accessible.")
		return
	var content := file.get_as_text()
	file.close()
	var extension: String = path.get_extension().to_lower()
	if extension == "json":
		var parsed: Variant = JSON.parse_string(content)
		if parsed is Dictionary and (parsed.has("locations") or parsed.has("log_info")):
			status_label.text = "Loading tracker save..."
			call_deferred("_process_save_async", path)
			return
		else:
			_show_error_dialog("Invalid save file format.\n\nThe JSON file does not contain valid tracker data.")
			return
	elif extension == "txt":
		if content.contains("Location List") or content.contains("Seed:") or content.contains("Version:"):
			status_label.text = "Loading spoiler log..."
			call_deferred("_process_log_async", path)
			return
		else:
			_show_error_dialog("Invalid file format.\n\nPlease select a valid OoTMM Spoiler Log (.txt) or Tracker Save (.json).")
			return
	else:
		var parsed: Variant = JSON.parse_string(content)
		if parsed is Dictionary and (parsed.has("locations") or parsed.has("log_info")):
			status_label.text = "Loading tracker save..."
			call_deferred("_process_save_async", path)
		elif content.contains("Location List") or content.contains("Seed:"):
			status_label.text = "Loading spoiler log..."
			call_deferred("_process_log_async", path)
		else:
			_show_error_dialog("Invalid file format.\n\nPlease select a valid OoTMM Spoiler Log (.txt) or Tracker Save (.json).")

func _show_error_dialog(message: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Error"
	dlg.dialog_text = message
	add_child(dlg)
	dlg.popup_centered(Vector2i(400, 150))
	dlg.connect("confirmed", dlg.queue_free)

func _on_file_dialog_canceled() -> void:
	_dialog_mode = DialogMode.NONE

func _load_log_from_path(path: String) -> void:
	status_label.text = "Loading log..."
	call_deferred("_process_log_async", path)

func _process_log_async(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status_label.text = "Failed to open file"
		return
	var content := file.get_as_text()
	file.close()
	_log_info = parse_log_metadata(content, path)
	_log_mode = _log_info.get("mode", "")
	var entries: Array = _parse_locations_section(content)
	_parse_entrance_shuffle(content)
	_parse_settings_section(content)
	_parse_world_flags_section(content)
	_parse_special_conditions_section(content)
	_parse_tricks_section(content)
	_parse_starting_items(content)
	_parse_song_events_section(content)
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("on_song_events_loaded"):
		item_tracker.on_song_events_loaded(_song_events_log)
	_apply_parsed_entries(entries)
	_refresh_world_filter()
	_build_tree_lazy()
	_update_log_info_button()
	_update_settings_from_log()
	_sync_item_tracker_from_locations()
	_sync_starting_items_to_tracker()
	LogicEvaluator.clear_cache(true)
	_warmup_logic_graph()
	_update_map_tab()

func _load_save_from_path(path: String) -> void:
	status_label.text = "Loading save..."
	call_deferred("_process_save_async", path)

func _process_save_async(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status_label.text = "Failed to open save file"
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		status_label.text = "Invalid save file format"
		return
	var save_data: Dictionary = parsed
	if save_data.has("log_info"):
		_log_info = save_data["log_info"]
	if save_data.has("log_mode"):
		_log_mode = save_data["log_mode"]
	if save_data.has("worlds_count"):
		_worlds_count = save_data["worlds_count"]
	if save_data.has("world_assignments"):
		_world_assignments = save_data["world_assignments"]
	if save_data.has("locations"):
		_all_data = save_data["locations"]
		_checked_count = 0
		for d in _all_data:
			if d.get("checked", false):
				_checked_count += 1
		_rebuild_location_idx()
		_recompute_valid_total()

	if save_data.has("settings"):
		var settings_node = get_tree().get_first_node_in_group("settings_tab")
		if settings_node and settings_node.has_method("apply_saved_settings"):
			settings_node.apply_saved_settings(save_data["settings"])

	if save_data.has("checked_items"):
		var item_tracker = get_tree().get_first_node_in_group("item_tracker")
		if item_tracker and item_tracker.has_method("load_checked_items"):
			item_tracker.load_checked_items(save_data["checked_items"])

	if save_data.has("song_events_log"):
		_song_events_log = save_data["song_events_log"]
		var item_tracker = get_tree().get_first_node_in_group("item_tracker")
		if item_tracker and item_tracker.has_method("on_song_events_loaded"):
			item_tracker.on_song_events_loaded(_song_events_log)

	_refresh_world_filter()
	var item_tracker_worlds = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker_worlds and item_tracker_worlds.has_method("set_worlds_count"):
		item_tracker_worlds.set_worlds_count(_worlds_count)
	_build_tree_lazy()
	_update_log_info_button()
	_update_settings_from_log()

	if save_data.has("settings"):
		var settings_node = get_tree().get_first_node_in_group("settings_tab")
		if settings_node and settings_node.has_method("apply_saved_settings"):
			settings_node.apply_saved_settings(save_data["settings"])

	if save_data.has("checked_items"):
		var item_tracker = get_tree().get_first_node_in_group("item_tracker")
		if item_tracker and item_tracker.has_method("load_checked_items"):
			item_tracker.load_checked_items(save_data["checked_items"])

	if save_data.has("entrance_shuffle"):
		_entrance_shuffle = _restore_shuffle_dict(save_data["entrance_shuffle"])
	else:
		_entrance_shuffle = {}
	if save_data.has("exit_shuffle"):
		_exit_shuffle = _restore_shuffle_dict(save_data["exit_shuffle"])
	else:
		_exit_shuffle = {}

	status_label.text = "Save loaded: %d locations" % _all_data.size()
	LogicEvaluator.clear_cache(true)
	_warmup_logic_graph()
	_update_map_tab()
	
func _warmup_logic_graph() -> void:
	call_deferred("_do_warmup_logic_graph")

func _do_warmup_logic_graph() -> void:
	LogicEvaluator.build_static_graph()
	await get_tree().process_frame
	for w in range(1, _worlds_count + 1):
		LogicEvaluator.ensure_reach(w)
		await get_tree().process_frame

func _restore_shuffle_dict(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (raw is Dictionary):
		return result
	for k in raw:
		var world: int = int(k)
		var inner: Dictionary = {}
		var inner_raw = raw[k]
		if inner_raw is Dictionary:
			for code in inner_raw:
				inner[str(code)] = str(inner_raw[code])
		result[world] = inner
	return result

func _save_to_path(path: String) -> void:
	var final_path: String = path if path.ends_with(".json") else path + ".json"
	var f: FileAccess = FileAccess.open(final_path, FileAccess.WRITE)
	if f == null:
		status_label.text = "Failed to save file"
		return
	
	var settings_node = get_tree().get_first_node_in_group("settings_tab")
	var settings_data: Dictionary = {}
	if settings_node != null and "current_settings" in settings_node:
		settings_data = settings_node.current_settings
	
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	var checked_items: Dictionary = {}
	if item_tracker != null and "checked_items" in item_tracker:
		checked_items = item_tracker.checked_items
	
	var save_data: Dictionary = {
		"version": "1.0",
		"save_date": Time.get_datetime_string_from_system(true),
		"log_info": _log_info,
		"log_mode": _log_mode,
		"worlds_count": _worlds_count,
		"world_assignments": _world_assignments,
		"locations": _all_data,
		"settings": settings_data,
		"checked_items": checked_items,
		"song_events_log": _song_events_log,
		"entrance_shuffle": _entrance_shuffle,
		"exit_shuffle": _exit_shuffle, 
	}
	f.store_string(JSON.stringify(save_data, "\t", false))
	f.close()
	status_label.text = "Saved %d locations to: %s" % [_all_data.size(), ProjectSettings.globalize_path(final_path)]

func parse_log_metadata(content: String, path: String) -> Dictionary:
	var info: Dictionary = { "version": "?", "seed_hash": "", "mode": "single", "file_path": path, "file_name": _file_name_from_path(path), "loaded_at": Time.get_datetime_string_from_system(true)}
	var pos: int = 0
	var length: int = content.length()
	var found_seed: bool = false
	var found_version: bool = false
	var found_mode: bool = false
	var lines_checked: int = 0
	while pos < length and lines_checked < 100:
		var nl: int = content.find("\n", pos)
		if nl == -1: nl = length
		var line: String = content.substr(pos, nl - pos).strip_edges()
		pos = nl + 1
		lines_checked += 1
		if line.is_empty(): continue
		if not found_seed:
			var m_seed := _re_seed_line.search(line)
			if m_seed != null: info["seed_hash"] = m_seed.get_string(1); found_seed = true
		if not found_version:
			var m_ver := _re_version_line.search(line)
			if m_ver != null: info["version"] = m_ver.get_string(1).strip_edges(); found_version = true
		if not found_mode:
			var m_mode := _re_mode_line.search(line)
			if m_mode != null: info["mode"] = m_mode.get_string(1).strip_edges(); found_mode = true
		if found_seed and found_version and found_mode: break
	return info

func _file_name_from_path(path: String) -> String:
	for sep in ["/", "\\"]:
		var parts := path.split(sep)
		if parts.size() > 1: return parts[parts.size() - 1]
	return path

func _update_log_info_button() -> void:
	if log_info_button == null: return
	if _log_info.is_empty():
		log_info_button.visible = false
		return
	log_info_button.visible = true
	log_info_button.text = "  %s  |  v%s  |  %s  |  %d w " % [_log_info.get("file_name", "?"), _log_info.get("version", "?"), _log_info.get("mode", "?"), _worlds_count]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var focus_owner := get_viewport().gui_get_focus_owner()
	var is_typing := focus_owner != null and (focus_owner is LineEdit or focus_owner is TextEdit)
	
	if is_typing:
		return
	
	if _reset_dialog.visible:
		return

	if key.keycode == KEY_F1:
		_on_load_pressed()
	elif key.keycode == KEY_F2:
		_on_save_pressed()
	elif key.keycode == KEY_F3:
		_show_reset_confirmation()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_5:
		_switch_tab(int(key.keycode - KEY_1))
	else:
		get_viewport().set_input_as_handled()
		return
	
	get_viewport().set_input_as_handled()


func _switch_tab(index: int) -> void:
	var tabs := get_parent() as TabContainer
	if tabs == null:
		return
	if index >= 0 and index < tabs.get_tab_count():
		tabs.current_tab = index


func _show_reset_confirmation() -> void:
	_reset_dialog.popup_centered(Vector2i(420, 180))

func _on_clear_pressed() -> void:
	_show_reset_confirmation()

func reset_all() -> void:
	reset_to_default()

	var settings_node = get_tree().get_first_node_in_group("settings_tab")
	if settings_node and settings_node.has_method("reset_to_defaults"):
		settings_node.reset_to_defaults()

	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("reset_tracker"):
		item_tracker.reset_tracker()

func _sync_item_tracker_from_locations() -> void:
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("sync_all_items_from_locations"):
		for w in range(1, _worlds_count + 1):
			item_tracker.sync_all_items_from_locations(_all_data, w)

func _refresh_world_filter() -> void:
	if world_filter == null: return
	var prev_selected: int = world_filter.selected
	world_filter.clear()
	world_filter.add_item("All Worlds", 0)
	var max_w: int = 1
	for d in _all_data:
		var w: int = int(d.get("world", 1))
		if w > max_w: max_w = w
	for i in range(1, max_w + 1): world_filter.add_item("World " + str(i), i)
	world_filter.select(prev_selected if prev_selected <= max_w else 0)

func _update_map_tab() -> void:
	var parent = get_parent()
	if parent and parent.get_class() == "TabContainer":
		for child in parent.get_children():
			if child.has_method("refresh_markers"): child.refresh_markers(); break

func _update_settings_from_log() -> void:
	var settings_node = get_tree().get_first_node_in_group("settings_tab")
	if settings_node and settings_node.has_method("apply_log_settings"):
		settings_node.apply_log_settings(_spoiler_settings, _world_flags, _worlds_count, _special_conditions)

func _rebuild_location_idx() -> void:
	_location_idx.clear()
	for d in _all_data:
		var ig = str(d.get("game", "")).strip_edges().to_upper()
		var n = str(d.get("name", "")).strip_edges().to_lower()
		var w = int(d.get("world", 1))
		var ikey = "%s|%s|%d" % [ig, n, w]
		if not _location_idx.has(ikey):
			_location_idx[ikey] = d

func set_location_checked_by_name(game: String, loc_name: String, world: int, checked: bool, from_map: bool = false) -> void:
	var game_upper = game.strip_edges().to_upper()
	var loc_lower = loc_name.strip_edges().to_lower()
	var ikey = "%s|%s|%d" % [game_upper, loc_lower, world]
	var d: Dictionary = _location_idx.get(ikey, {})
	if d.is_empty():
		return
	if str(d.get("game", "")).strip_edges().to_upper() != game_upper or str(d.get("name", "")).strip_edges().to_lower() != loc_lower or int(d.get("world", 1)) != world:
		return
	var key = str(d.get("key", ""))
	d["checked"] = checked
	if _data_by_key.has(key):
		_data_by_key[key]["checked"] = checked
	
	var row_btn = null
	for wb in _world_blocks:
		if int(wb.get("world", 0)) == world and wb.get("cached_rows", {}).has(key):
			row_btn = wb["cached_rows"][key]
			if is_instance_valid(row_btn):
				row_btn.set_meta("checked", checked)
				row_btn.update_via_meta()
	
	if from_map:
		if checked: _checked_count += 1
		else: _checked_count -= 1
		var loc_item: String = str(d.get("item", "")).strip_edges()
		var loc_player: int = int(d.get("player", 0))
		var tracker_world: int = loc_player if loc_player > 0 else world
		var item_tracker = get_tree().get_first_node_in_group("item_tracker")
		if item_tracker and item_tracker.has_method("sync_item_from_location"):
			item_tracker.sync_item_from_location(loc_item, checked, tracker_world)
	
	if not from_map and row_btn != null:
		_on_row_check_changed(row_btn, checked)
	else:
		call_deferred("_apply_optimized_filters")
	_request_deferred_refresh()

func _update_map_counters() -> void:
	var parent := get_parent()
	if parent and parent.get_class() == "TabContainer":
		for child in parent.get_children():
			if child.has_method("refresh_markers") and child.is_visible_in_tree():
				child.refresh_markers()
				break

func get_log_data() -> Dictionary: return _log_info.duplicate()
func get_all_data() -> Array: return _all_data
func get_worlds_count() -> int: return _worlds_count
func get_entrance_shuffle() -> Dictionary: return _entrance_shuffle
func get_exit_shuffle() -> Dictionary: return _exit_shuffle
func get_spoiler_settings() -> Dictionary: return _spoiler_settings
func get_world_flags() -> Dictionary: return _world_flags

func refresh_worlds_from_settings() -> void:
	var settings_node := get_tree().get_first_node_in_group("settings_tab")
	var settings_players := 1

	if settings_node:
		if settings_node.has_method("get_players_count"):
			settings_players = int(settings_node.get_players_count())
		elif "current_settings" in settings_node:
			settings_players = _players_from_variant(settings_node.current_settings.get("players", 1))

	if settings_players < 1:
		settings_players = 1

	var target_worlds := _worlds_count
	var data_changed := false

	if _log_info.is_empty():
		target_worlds = settings_players
		data_changed = _ensure_world_count(target_worlds)
	else:
		target_worlds = _worlds_count

	if target_worlds < 1:
		target_worlds = 1

	if data_changed:
		_build_tree_lazy()
	else:
		_refresh_world_filter()
		_update_counters()

	var item_tracker := get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("set_worlds_count"):
		item_tracker.set_worlds_count(target_worlds)

	var map_tab := get_tree().get_first_node_in_group("map_tab")
	if map_tab and map_tab.has_method("update_world_filter"):
		map_tab.update_world_filter(target_worlds)

	_update_map_tab()

func _players_from_variant(value: Variant) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return int(value)

	if typeof(value) == TYPE_STRING and str(value).is_valid_int():
		return int(str(value))

	if typeof(value) == TYPE_ARRAY and not value.is_empty():
		return _players_from_variant(value[0])

	if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
		var best := 1

		for v: Variant in value.values():
			best = max(best, _players_from_variant(v))

		return best

	return 1

func _ensure_world_count(count: int) -> bool:
	if count < 1:
		count = 1

	if count == _worlds_count and not _all_data.is_empty():
		return false

	var old_data: Dictionary = {}

	for d: Dictionary in _all_data:
		var key := str(d.get("key", ""))
		if key != "":
			old_data[key] = d

	var locations: Array = _load_locations_json()

	_all_data.clear()
	_fast_location_lookup.clear()
	_checked_count = 0

	for row: Variant in locations:
		if not row is Array or row.size() < 3:
			continue

		var game := str(row[0])
		var region := str(row[1])
		var loc_name := str(row[2])

		for w: int in range(1, count + 1):
			var key := game + "|" + loc_name + "|w" + str(w)
			var prev: Dictionary = old_data.get(key, {})

			var entry := {
				"game": game,
				"region": region,
				"name": loc_name,
				"item": prev.get("item", "(unknown)"),
				"world": w,
				"player": int(prev.get("player", 0)),
				"checked": bool(prev.get("checked", false)),
				"key": key,
			}

			_all_data.append(entry)
			_fast_location_lookup["%s|%d" % [loc_name.strip_edges().to_lower(), w]] = entry

			if entry["checked"]:
				_checked_count += 1

	_worlds_count = count

	_rebuild_location_idx()
	_recompute_valid_total()

	return true

func is_location_checked(loc_name: String, world: int) -> bool:
	var target = loc_name.strip_edges().to_lower()
	var key = "%s|%d" % [target, world]
	if _fast_location_lookup.has(key):
		return bool(_fast_location_lookup[key].get("checked", false))
	return false

func get_current_settings() -> Dictionary:
	var settings_node = get_tree().get_first_node_in_group("settings_tab")
	if settings_node != null and "current_settings" in settings_node:
		return settings_node.current_settings.duplicate()
	
	return _spoiler_settings.duplicate()

func _parse_song_events_section(content: String) -> void:
	_song_events_log.clear()
	var in_section := false
	var current_world := 1
	for line in content.split("\n"):
		var stripped := line.strip_edges()
		if stripped == "":
			continue
		if stripped == "Song Events":
			in_section = true
			continue
		if not in_section:
			continue
		if stripped.begins_with("World "):
			current_world = int(stripped.substr(6).strip_edges())
			continue
		if stripped == "Ocarina of Time" or stripped == "Majora's Mask":
			continue
		var colon_pos := stripped.find(":")
		if colon_pos > 0:
			var event_id := stripped.substr(0, colon_pos).strip_edges()
			var song_name := stripped.substr(colon_pos + 1).strip_edges()
			if event_id.begins_with("SONG_EVENT_") and song_name != "":
				if not _song_events_log.has(current_world):
					_song_events_log[current_world] = {}
				_song_events_log[current_world][event_id] = song_name
				continue
		break

func _push_song_events_to_tracker() -> void:
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("on_song_events_loaded"):
		item_tracker.on_song_events_loaded(_song_events_log)

func _handle_song_events_after_log_load(content: String) -> void:
	_parse_song_events_section(content)
	await get_tree().process_frame
	_push_song_events_to_tracker()

func _apply_song_events_from_save(data: Dictionary) -> void:
	_song_events_log = data.duplicate(true)
	call_deferred("_push_song_events_to_tracker")

func _split_player_prefix(s: String) -> Array:
	var txt := s.strip_edges()

	var dash := txt.find("-")
	if dash <= 0:
		return [0, txt]

	var left := txt.substr(0, dash).strip_edges()
	var right := txt.substr(dash + 1).strip_edges()

	if right == "":
		return [0, txt]

	if left.begins_with("P"):
		var num := left.substr(1).strip_edges()
		if num.is_valid_int():
			return [int(num), right]

	if left.begins_with("Player"):
		var num := left.substr(6).strip_edges()
		if num.is_valid_int():
			return [int(num), right]

	return [0, txt]

func _parse_locations_section(content: String) -> Array:
	var entries: Array = []
	var lines := content.split("\n")

	var in_section: bool = false
	var current_world: int = 1
	var current_region: String = ""
	var has_world_header: bool = false

	for i in range(lines.size()):
		var line: String = lines[i]

		if line.begins_with("Location List"):
			in_section = true
			continue

		if line.begins_with("---") and in_section:
			break

		if not in_section:
			continue

		var wm := _re_world.search(line)
		if wm != null:
			current_world = int(wm.get_string(1))
			has_world_header = true
			continue

		var rm := _re_region.search(line)
		if rm != null:
			current_region = rm.get_string(1).strip_edges()
			continue

		var em := _re_entry.search(line)
		if em != null:
			var prefix: String = em.get_string(1).strip_edges()
			var game: String = "OoT" if prefix == "OOT" else "MM"
			var loc_name_raw: String = em.get_string(2).strip_edges()
			var rest: String = em.get_string(3).strip_edges()

			if loc_name_raw == "" or rest == "":
				continue

			var player: int = 0

			var pm := _re_player.search(rest)
			if pm != null:
				var p1: String = pm.get_string(1)
				var p2: String = pm.get_string(2)

				player = int(p1) if p1 != "" else int(p2)
				rest = pm.get_string(3).strip_edges()
			else:
				var manual: Array = _split_player_prefix(rest)
				player = int(manual[0])

				if player > 0:
					rest = str(manual[1])

			var entry_world: int = current_world

			if player > 0 and not has_world_header:
				entry_world = player

			entries.append({
				"world": entry_world,
				"game": game,
				"region": current_region,
				"name": loc_name_raw,
				"player": player,
				"item": rest
			})

	return entries

func _parse_entrance_shuffle(content: String) -> void:
	_entrance_shuffle.clear()
	_exit_shuffle.clear()
	var lines := content.split("\n")
	var in_section = false
	var re_entrance := RegEx.new()
	re_entrance.compile("^(?:World\\s+(\\d+)\\s+)?.*\\(([^)]+)\\)\\s*->\\s*.*\\(([^)]+)\\)\\s*$")
	for line in lines:
		if line.begins_with("Entrances") or line.begins_with("Entrance Shuffle"):
			in_section = true
			continue
		if in_section and line.begins_with("---"):
			break
		if not in_section:
			continue
		var m = re_entrance.search(line)
		if m:
			var world_str = m.get_string(1)
			var world = int(world_str) if world_str != "" else 1
			var code_a = m.get_string(2).strip_edges()
			var code_b = m.get_string(3).strip_edges()
			if not _entrance_shuffle.has(world):
				_entrance_shuffle[world] = {}
			if not _exit_shuffle.has(world):
				_exit_shuffle[world] = {}
			_entrance_shuffle[world][code_a] = code_b
			_exit_shuffle[world][code_b] = code_a

func _parse_settings_section(content: String) -> void:
	_spoiler_settings.clear()
	var lines := content.split("\n")
	var in_section := false
	
	_load_settings_mapping()
	
	for line in lines:
		var stripped := line.strip_edges()
		if stripped == "Settings":
			in_section = true
			continue
		if in_section and (stripped == "World Flags" or stripped == "Entrances" or stripped == "Special Conditions" or stripped.begins_with("---")):
			break
		if not in_section:
			continue
		
		var colon_pos := stripped.find(":")
		if colon_pos > 0:
			var key := stripped.substr(0, colon_pos).strip_edges()
			var value := stripped.substr(colon_pos + 1).strip_edges()
			if key != "" and value != "":
				if value.find(",") != -1:
					var values_array := value.split(",")
					var cleaned_values: Array = []
					for v in values_array:
						var vv := v.strip_edges()
						if vv != "":
							cleaned_values.append(vv)
					_spoiler_settings[key] = cleaned_values
				elif value == "true":
					_spoiler_settings[key] = true
				elif value == "false":
					_spoiler_settings[key] = false
				elif value.is_valid_int():
					_spoiler_settings[key] = int(value)
				elif value.is_valid_float():
					_spoiler_settings[key] = float(value)
				else:
					_spoiler_settings[key] = value

func _load_settings_mapping() -> void:
	if not _settings_name_to_value.is_empty(): return
	var file = FileAccess.open("res://data/settings.json", FileAccess.READ)
	if file == null: return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_text) != OK: return
	var settings_array: Variant = json.get_data()
	for s in settings_array:
		if s.get("type") == "set":
			var key: String = s["key"]
			var mapping: Dictionary = {}
			for opt in s.get("values", []):
				mapping[opt["name"]] = opt["value"]
			_settings_name_to_value[key] = mapping
		elif s.get("category", "") == "tricks" and s.get("type") == "boolean":
			_tricks_name_to_key[s["name"]] = s["key"]

func _parse_world_flags_section(content: String) -> void:
	_world_flags.clear()
	_load_settings_mapping()
	
	var lines := content.split("\n")
	var in_section := false
	var current_world: int = 1
	var current_flag_key: String = ""
	
	var flag_key_map: Dictionary = {
		"Ganon Trials": "ganonTrials",
		"Small Key Ring (OoT)": "smallKeyRingOot",
		"Small Key Ring (MM)": "smallKeyRingMm",
		"Silver Rupee Pouches": "silverRupeePouches",
		"Open Dungeons (OoT)": "openDungeonsOot",
		"Open Dungeons (MM)": "openDungeonsMm",
		"Clear State Dungeons (MM)": "clearStateDungeonsMm",
		"Pre-Activated Owl Statues": "mmPreActivatedOwls",
		"Master Quest Dungeons": "mqDungeons", 
		"Majora's Mask JP Layouts": "jpLayouts",
	}
	
	for line in lines:
		var stripped := line.strip_edges()
		
		if stripped == "World Flags":
			in_section = true
			continue
		if in_section and (stripped == "Entrances" or stripped.begins_with("---")):
			break
		if not in_section:
			continue
			
		if stripped.begins_with("World "):
			var parts := stripped.split(" ")
			if parts.size() >= 2:
				current_world = int(parts[1])
			current_flag_key = ""
			continue
			
		if stripped.begins_with("- "):
			if current_flag_key != "":
				var item_name := stripped.substr(2).strip_edges()
				var setting_key: String = flag_key_map.get(current_flag_key, current_flag_key)
				
				if not _world_flags.has(current_world):
					_world_flags[current_world] = {}
				if not _world_flags[current_world].has(setting_key):
					_world_flags[current_world][setting_key] = []
				
				var mapped_value := item_name
				if _settings_name_to_value.has(setting_key) and _settings_name_to_value[setting_key].has(item_name):
					mapped_value = _settings_name_to_value[setting_key][item_name]
				
				_world_flags[current_world][setting_key].append(mapped_value)
			continue
			
		var colon_pos := stripped.find(":")
		if colon_pos > 0:
			var flag_name := stripped.substr(0, colon_pos).strip_edges()
			var value := stripped.substr(colon_pos + 1).strip_edges()
			
			current_flag_key = flag_name
			
			if flag_name == "" or value == "":
				continue
				
			var setting_key: String = flag_key_map.get(flag_name, flag_name)
			var parsed_value: Variant
			
			if value == "none" or value == "all":
				parsed_value = value
			elif value.find(",") != -1:
				var values_array := value.split(",")
				var cleaned_values: Array = []
				for v in values_array:
					var vv := v.strip_edges()
					if vv != "":
						if _settings_name_to_value.has(setting_key) and _settings_name_to_value[setting_key].has(vv):
							cleaned_values.append(_settings_name_to_value[setting_key][vv])
						else:
							cleaned_values.append(vv)
				parsed_value = cleaned_values
			else:
				parsed_value = value
				
			if not _world_flags.has(current_world):
				_world_flags[current_world] = {}
			_world_flags[current_world][setting_key] = parsed_value

func _apply_parsed_entries(entries: Array) -> void:
	var world_by_loc: Dictionary = {}
	var max_w: int = 1

	for e in entries:
		var w: int = int(e.get("world", 1))
		var g: String = str(e.get("game", "OoT"))

		if w > max_w:
			max_w = w

		var p: int = int(e.get("player", 0))

		if _log_mode != "single" and p > max_w:
			max_w = p
		if not world_by_loc.has(w): world_by_loc[w] = {}
		if not world_by_loc[w].has(g): world_by_loc[w][g] = {}
		var loc_name_str: String = str(e.get("name", ""))
		world_by_loc[w][g][loc_name_str] = {"item": e.get("item", "(unknown)"), "player": int(e.get("player", 0))}
	_worlds_count = max_w
	_all_data.clear()
	_world_assignments.clear()
	var locations: Array = _load_locations_json()
	for row in locations:
		var game: String = row[0]
		var region: String = row[1]
		var loc_name_str: String = row[2]
		for w in range(1, _worlds_count + 1):
			var data: Dictionary = {}
			if world_by_loc.has(w) and world_by_loc[w].has(game) and world_by_loc[w][game].has(loc_name_str):
				data = world_by_loc[w][game][loc_name_str]
			var item: String = data.get("item", "(unknown)")
			var player: int = int(data.get("player", 0))
			if w == 1 and player == 0 and _log_mode == "multi": player = 1
			_all_data.append({"game": game, "region": region, "name": loc_name_str, "item": item, "world": w, "player": player, "checked": false, "key": game + "|" + loc_name_str + "|w" + str(w)})
			if player > 0 or item != "(unknown)": _world_assignments[game + "|" + loc_name_str + "|w" + str(w)] = {"item": item, "player": player}
	
	_fast_location_lookup.clear()
	_rebuild_location_idx()
	_recompute_valid_total()
	for d in _all_data:
		var n = str(d.get("name", "")).strip_edges().to_lower()
		var w = int(d.get("world", 1))
		_fast_location_lookup["%s|%d" % [n, w]] = d

func _on_log_info_pressed() -> void:
	if _log_info.is_empty(): return
	var msg: String = "File: %s\nSeed: %s\nVersion: %s" % [_log_info.get("file_name", "?"), _log_info.get("seed_hash", "?"), _log_info.get("version", "?")]
	var dlg := AcceptDialog.new()
	dlg.title = "Log Info"
	dlg.dialog_text = msg
	add_child(dlg)
	dlg.popup_centered()
	
func _parse_tricks_section(content: String) -> void:
	_load_settings_mapping()
	var lines := content.split("\n")
	var in_section := false
	for line in lines:
		var stripped := line.strip_edges()
		if stripped == "Tricks":
			in_section = true
			continue
		if in_section and (stripped == "Starting Items" or stripped.begins_with("---")):
			break
		if not in_section or stripped == "":
			continue
		if _tricks_name_to_key.has(stripped):
			var trick_key: String = _tricks_name_to_key[stripped]
			_spoiler_settings[trick_key] = true

func _parse_starting_items(content: String) -> void:
	_starting_items.clear()
	var lines := content.split("\n")
	var in_section := false
	var current_player: int = 1
	for line in lines:
		var stripped := line.strip_edges()
		if stripped == "Starting Items":
			in_section = true
			continue
		if in_section and (stripped.begins_with("---") or stripped == "World Flags" or stripped == "Entrances" or stripped == "Song Events" or stripped == "Tricks" or stripped == "Special Conditions"):
			break
		if not in_section or stripped == "":
			continue
		if stripped.begins_with("Player "):
			var player_str = stripped.substr(7).strip_edges()
			if player_str.is_valid_int():
				current_player = int(player_str)
			continue
		var colon_pos := stripped.find(":")
		if colon_pos > 0:
			var item_name := stripped.substr(0, colon_pos).strip_edges()
			var count_str := stripped.substr(colon_pos + 1).strip_edges()
			var count: int = 1
			if count_str.is_valid_int():
				count = int(count_str)
			if not _starting_items.has(current_player):
				_starting_items[current_player] = {}
			_starting_items[current_player][item_name] = count

func _sync_starting_items_to_tracker() -> void:
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("sync_starting_items"):
		item_tracker.sync_starting_items(_starting_items)

func _parse_special_conditions_section(content: String) -> void:
	_special_conditions.clear()
	var lines := content.split("\n")
	var in_section := false
	var current_key := ""
	var current_data := {}

	for line in lines:
		var stripped := line.strip_edges()
		if stripped == "Special Conditions":
			in_section = true
			continue
		if in_section and (stripped == "Tricks" or stripped.begins_with("---")):
			if current_key != "":
				_special_conditions[current_key] = current_data
			break
		if not in_section:
			continue

		if stripped.ends_with(":") and not stripped.begins_with(" "):
			if current_key != "":
				_special_conditions[current_key] = current_data
			current_key = stripped.trim_suffix(":")
			current_data = {}
		elif current_key != "" and stripped != "":
			var colon_pos := stripped.find(":")
			if colon_pos > 0:
				var field_key := stripped.substr(0, colon_pos).strip_edges()
				var field_value_str := stripped.substr(colon_pos + 1).strip_edges()
				if field_value_str == "true":
					current_data[field_key] = true
				elif field_value_str == "false":
					current_data[field_key] = false
				elif field_value_str.is_valid_int():
					current_data[field_key] = int(field_value_str)
				else:
					current_data[field_key] = field_value_str

	if in_section and current_key != "":
		_special_conditions[current_key] = current_data

func evaluate_logic_condition(condition: Variant, world: int) -> bool:
	var item_tracker = get_tree().get_first_node_in_group("item_tracker")
	if item_tracker and item_tracker.has_method("_evaluate_item_condition"):
		var old_world = item_tracker.current_world
		item_tracker.current_world = world
		var result = item_tracker._evaluate_item_condition(condition)
		item_tracker.current_world = old_world
		return result
	return true
