extends Control

@onready var load_button: Button = %LoadButton
@onready var save_button: Button = %SaveButton
@onready var clear_button: Button = %ClearButton
@onready var world_filter: OptionButton = %WorldFilter
@onready var game_filter: OptionButton = %GameFilter
@onready var status_filter: OptionButton = %StatusFilter
@onready var logic_filter: OptionButton = %LogicFilter
@onready var zoom_in_button: Button = %ZoomInButton
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var reset_zoom_button: Button = %ResetZoomButton
@onready var location_tree: VBoxContainer = %LocationTree
@onready var info_label: Label = %InfoLabel
@onready var total_label: Label = %TotalLabel
@onready var map_container: Control = %MapContainer
@onready var map_image: TextureRect = %MapImage
@onready var quick_jump_button: Button = $MainContainer/TopPanel/QuickJumpButton

const MIN_FIELD_WIDTH: float = 200.0
const MIN_FIELD_HEIGHT: float = 150.0

const CAT_NONE: int = -1
const CAT_UNKNOWN: int = 0
const CAT_REACHABLE: int = 1
const CAT_COLLECTED: int = 2
const CAT_UNREACHABLE: int = 3

const QUICK_JUMP_ROW_1 = [
	{"code": "OOT_SPAWN_CHILD", "name": "Child Spawn", "icon": "res://images/equipment/kokiri_sword_oot.png"},
	{"code": "OOT_SPAWN_ADULT", "name": "Adult Spawn", "icon": "res://images/equipment/master_sword.png"},
	{"code": "OOT_WARP_SONG_MEADOW", "name": "Minuet of Forest", "icon": "res://images/songs/minuet.png"},
	{"code": "OOT_WARP_SONG_CRATER", "name": "Bolero of Fire", "icon": "res://images/songs/bolero.png"},
	{"code": "OOT_WARP_SONG_LAKE", "name": "Serenade of Water", "icon": "res://images/songs/serenade.png"},
	{"code": "OOT_WARP_SONG_GRAVE", "name": "Nocturne of Shadow", "icon": "res://images/songs/nocturne.png"},
	{"code": "OOT_WARP_SONG_DESERT", "name": "Requiem of Spirit", "icon": "res://images/songs/requiem.png"},
	{"code": "OOT_WARP_SONG_TEMPLE", "name": "Prelude of Light", "icon": "res://images/songs/prelude.png"},
	{"code": "OOT_WALLMASTER_FOREST_CORRIDOR_WEST", "name": "Wallmaster (Forest Temple - West Corridor)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_FOREST_CORRIDOR_EAST", "name": "Wallmaster (Forest Temple - East Corridor)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_SHADOW", "name": "Wallmaster (Shadow Temple)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_SPIRIT_CHILD_RUPEES", "name": "Wallmaster (Spirit Temple - Child Lobby)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_SPIRIT_ADULT_CLIMB", "name": "Wallmaster (Spirit Temple - Adult Climb Room)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_SPIRIT_CHILD_SUN", "name": "Wallmaster (Spirit Temple - Sun Block Room)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_SPIRIT_STATUE", "name": "Wallmaster (Spirit Temple - Main Room)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_BOTW_MAIN", "name": "Wallmaster (Bottom of the Well - Main)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_BOTW_BASEMENT", "name": "Wallmaster (Bottom of the Well - Basement)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_BOTW_PIT", "name": "Wallmaster (Bottom of the Well - Pit)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_GTG", "name": "Wallmaster (Gerudo Training Grounds)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_GANON_SPIRIT", "name": "Wallmaster (Ganon's Castle - Spirit Trial)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "OOT_WALLMASTER_GANON_LIGHT", "name": "Wallmaster (Ganon's Castle - Light Trial)", "icon": "res://images/marks/entrances/wallmaster.png"},
]

const QUICK_JUMP_ROW_2 = [
	{"code": "MM_ASTRAL_OBSERVATORY_FROM_TELESCOPE", "name": "Astral Observatory Telescope", "icon": "res://images/marks/entrances/telescope.png"},
	{"code": "MM_KAFEI_HIDEOUT_FROM_TELESCOPE", "name": "Kafei's Hideout Telescope", "icon": "res://images/marks/entrances/telescope.png"},
	{"code": "MM_PIRATE_FORTRESS_SEWERS_FROM_TELESCOPE", "name": "Pirate's Fortress Telescope", "icon": "res://images/marks/entrances/telescope.png"},
	{"code": "MM_WARP_OWL_CLOCK_TOWN", "name": "Clock Town Owl Statue", "icon": "res://images/owls/clock_town.png"},
	{"code": "MM_WARP_OWL_MILK_ROAD", "name": "Milk Road Owl Statue", "icon": "res://images/owls/milk_road.png"},
	{"code": "MM_WARP_OWL_SOUTHERN_SWAMP", "name": "Southern Swamp Owl Statue", "icon": "res://images/owls/southern_swamp.png"},
	{"code": "MM_WARP_OWL_WOODFALL", "name": "Woodfall Owl Statue", "icon": "res://images/owls/woodfall.png"},
	{"code": "MM_WARP_OWL_MOUNTAIN_VILLAGE", "name": "Mountain Village Owl Statue", "icon": "res://images/owls/mountain_village.png"},
	{"code": "MM_WARP_OWL_SNOWHEAD", "name": "Snowhead Owl Statue", "icon": "res://images/owls/snowhead.png"},
	{"code": "MM_WARP_OWL_GREAT_BAY", "name": "Great Bay Coast Owl Statue", "icon": "res://images/owls/great_bay.png"},
	{"code": "MM_WARP_OWL_ZORA_CAPE", "name": "Zora Cape Owl Statue", "icon": "res://images/owls/zora_cape.png"},
	{"code": "MM_WARP_OWL_IKANA_CANYON", "name": "Ikana Canyon Owl Statue", "icon": "res://images/owls/ikana_canyon.png"},
	{"code": "MM_WARP_OWL_STONE_TOWER", "name": "Stone Tower Owl Statue", "icon": "res://images/owls/stone_tower.png"},
	{"code": "MM_WALLMASTER_DAMPE", "name": "Wallmaster (Dampe's House)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "MM_WALLMASTER_BTW_ENTRANCE", "name": "Wallmaster (Beneath the Well - Near Entrance)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "MM_WALLMASTER_BTW_FOUNTAIN", "name": "Wallmaster (Beneath the Well - Near Fairy Fountain)", "icon": "res://images/marks/entrances/wallmaster.png"},
	{"code": "MM_WALLMASTER_BTW_EXIT", "name": "Wallmaster (Beneath the Well - Near Exit)", "icon": "res://images/marks/entrances/wallmaster.png"},
]

const LOST_WOODS_ALTERED_EXITS = [
	"OOT_LOST_WOODS_FROM_LOST_WOODS_NORTH",
	"OOT_LOST_WOODS_FROM_LOST_WOODS_EAST",
	"OOT_LOST_WOODS_FROM_LOST_WOODS_SOUTH",
	"OOT_LOST_WOODS_FROM_LOST_WOODS_WEST"
]

const LOST_WOODS_MAIN_EXIT = "OOT_KOKIRI_FOREST_FROM_LOST_WOODS"

var _quick_jump_visible: bool = true
var _log_info: Dictionary = {}
var _log_mode: String = ""
var _worlds_count: int = 1
var _all_data: Array = []
var _current_map_texture: Texture2D = null

var _subregion_btns: Dictionary = {}
var _region_btns: Dictionary = {}
var _game_btns: Dictionary = {}

var _subregion_locs_map: Dictionary = {}
var _loc_to_subregions: Dictionary = {}
var _loc_original_names: Dictionary = {}

var _subs_by_region: Dictionary = {}
var _regions_by_game: Dictionary = {}

var _sub_counts: Dictionary = {}
var _reg_counts: Dictionary = {}
var _game_counts: Dictionary = {}

var _wk_region_counted: Dictionary = {}
var _wk_game_counted: Dictionary = {}
var _pending_text_loc_keys: Dictionary = {}

var _auto_scale: float = 1.0
var _user_zoom: float = 1.0
var _map_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO

var _region_maps: Array = []
var _region_map_by_key: Dictionary = {}

var _markers: Array = []
var _marker_buttons: Array = []
var _markers_container: Control
var _loc_to_marker_containers: Dictionary = {}

var _current_region: String = ""
var _current_subregion: String = ""
var _markers_need_rebuild: bool = true

var _entrance_markers: Array = []
var _entrance_marker_buttons: Array = []
var _entrance_markers_container: Control
var _entrance_exit_map: Dictionary = {}
var _entrance_dest_info: Dictionary = {}
var _entrance_to_region_map: Dictionary = {}
var _exit_to_region_map: Dictionary = {}
var _entrance_markers_need_rebuild: bool = true
var _has_entrance_data: bool = false

var _jp_layouts: Variant = []
var _mq_dungeons_cache: Array = []

var _current_game_filter: String = ""
var _current_games_setting: String = "ootmm"
var _current_game: String = ""
var _current_world_filter: int = 1
var _current_status_filter: int = 1
var _current_logic_filter: int = 1

var _active_custom_menu: PanelContainer = null
var _is_menu_dragging: bool = false
var _menu_drag_start_pos: Vector2 = Vector2.ZERO
var _menu_drag_offset: Vector2 = Vector2.ZERO

var _quick_jump_buttons: Array = []
var _quick_jump_container: VBoxContainer = null
var _quick_jump_rows: Array = []

var _location_cache: Dictionary = {}
var _jp_marker_names_cache: Dictionary = {}
var _jp_entrance_base_names: Dictionary = {}
var _cache_built: bool = false

var _cached_first_elem = null
var _location_cache_ref = null
var _data_ref = null
var _first_elem_ref = null

var _loc_reach_cache: Dictionary = {}
var _loc_reach_stale: bool = false
var _loc_reach_have_any: bool = false

var _entrance_marker_state_cache: Dictionary = {}
var _quick_jump_state_cache: Dictionary = {}

var _main_node_cache: Node = null

var _sub_meta: Dictionary = {}

func _ready() -> void:
	add_to_group("map_tab")
	_register_all_quick_jump_codes()

	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	game_filter.item_selected.connect(_on_game_filter_changed)
	world_filter.item_selected.connect(_on_world_filter_changed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	reset_zoom_button.pressed.connect(_on_reset_zoom_pressed)

	if map_container:
		map_container.resized.connect(_on_map_container_resized)

	map_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	map_image.expand = true

	_init_filters()
	_load_region_maps()
	_build_location_tree()

	if info_label:
		info_label.text = "No map selected"

	map_image.texture = null
	_current_map_texture = null

	if status_filter:
		status_filter.item_selected.connect(_on_status_filter_changed)

	if logic_filter:
		logic_filter.item_selected.connect(_on_logic_filter_changed)

	await get_tree().process_frame
	_sync_data_from_main()

	visibility_changed.connect(func():
		if is_visible_in_tree():
			_sync_data_from_main()
			LogicEvaluator.request_reach_compute(_current_world_filter, _on_reach_ready)
			_update_markers()
			request_counters_update()
		else:
			_location_cache.clear()
			_cache_built = false
			_location_cache_ref = null
			_data_ref = null
			_first_elem_ref = null
			_jp_marker_names_cache.clear()
			_loc_to_marker_containers.clear()
			_entrance_marker_state_cache.clear()
			_quick_jump_state_cache.clear()
			LogicEvaluator.drop_transient_caches()
	)

	if quick_jump_button:
		quick_jump_button.pressed.connect(_on_quick_jump_button_pressed)

	load_button.tooltip_text = "Load spoiler log or tracker save (F1)"
	save_button.tooltip_text = "Save tracker state (F2)"
	clear_button.tooltip_text = "Reset all progress (F3)"

func _get_main_node() -> Node:
	if _main_node_cache == null or not is_instance_valid(_main_node_cache):
		_main_node_cache = get_tree().get_first_node_in_group("main_scene")
	return _main_node_cache

func _is_logic_active() -> bool:
	return (_log_mode != "") or _has_entrance_data

func _loc_key(game: String, loc_name: String) -> String:
	return "%s|%s" % [game.strip_edges().to_upper(), loc_name.strip_edges().to_lower()]

func _world_key(loc_key: String, world: int) -> String:
	return "%s|%d" % [loc_key, world]

func _is_countable_world_key(wk: String) -> bool:
	if not _location_cache.has(wk):
		return false
	var data: Dictionary = _location_cache[wk]
	var item: String = str(data.get("item", "")).strip_edges()
	return item != "" and item.to_lower() != "(unknown)"

func _get_wk_category(wk: String) -> int:
	if not _is_countable_world_key(wk):
		return CAT_NONE

	var data: Dictionary = _location_cache[wk]

	if bool(data.get("checked", false)):
		return CAT_COLLECTED

	if not _is_logic_active():
		return CAT_UNKNOWN

	if _loc_reach_cache.has(wk):
		return CAT_REACHABLE if bool(_loc_reach_cache[wk]) else CAT_UNREACHABLE

	return CAT_UNKNOWN

func _adjust_count_dict(d: Dictionary, cat: int, delta: int) -> void:
	match cat:
		CAT_UNKNOWN:
			d.unknown += delta
		CAT_REACHABLE:
			d.reachable += delta
		CAT_COLLECTED:
			d.collected += delta
		CAT_UNREACHABLE:
			pass

func _empty_counts() -> Dictionary:
	return {"total": 0, "collected": 0, "reachable": 0, "unknown": 0}

func _ensure_count_dicts() -> void:
	for sub_key in _subregion_locs_map.keys():
		if not _sub_counts.has(sub_key):
			_sub_counts[sub_key] = _empty_counts()

	for region_key in _subs_by_region.keys():
		if not _reg_counts.has(region_key):
			_reg_counts[region_key] = _empty_counts()

	for game in _regions_by_game.keys():
		if not _game_counts.has(game):
			_game_counts[game] = _empty_counts()

func _rebuild_counts_from_cache() -> void:
	_sub_counts.clear()
	_reg_counts.clear()
	_game_counts.clear()
	_wk_region_counted.clear()
	_wk_game_counted.clear()
	_pending_text_loc_keys.clear()

	_ensure_count_dicts()

	for loc_key in _loc_to_subregions.keys():
		for world in range(1, _worlds_count + 1):
			var wk: String = _world_key(loc_key, world)
			var cat: int = _get_wk_category(wk)

			if cat == CAT_NONE:
				continue

			for sub_key in _loc_to_subregions[loc_key]:
				var sd: Dictionary = _sub_counts.get(sub_key, {})
				if sd.is_empty():
					continue

				sd.total += 1
				_adjust_count_dict(sd, cat, 1)

				var meta: Dictionary = _sub_meta.get(sub_key, {})
				if meta.is_empty():
					continue

				var region_key: String = meta.get("region_key", "")
				var game: String = meta.get("game", "")

				if region_key == "" or game == "":
					continue

				if not _wk_region_counted.has(wk):
					_wk_region_counted[wk] = {}

				if not _wk_region_counted[wk].has(region_key):
					_wk_region_counted[wk][region_key] = true

					var rd: Dictionary = _reg_counts.get(region_key, {})
					if not rd.is_empty():
						rd.total += 1
						_adjust_count_dict(rd, cat, 1)

				if not _wk_game_counted.has(wk):
					_wk_game_counted[wk] = {}

				if not _wk_game_counted[wk].has(game):
					_wk_game_counted[wk][game] = true

					var gd: Dictionary = _game_counts.get(game, {})
					if not gd.is_empty():
						gd.total += 1
						_adjust_count_dict(gd, cat, 1)

func _change_wk_category(wk: String, loc_key: String, old_cat: int, new_cat: int) -> void:
	if old_cat == new_cat:
		return

	var regions: Dictionary = {}
	var games: Dictionary = {}

	for sub_key in _loc_to_subregions.get(loc_key, []):
		var sd: Dictionary = _sub_counts.get(sub_key, {})
		if sd.is_empty():
			continue

		if old_cat == CAT_NONE and new_cat != CAT_NONE:
			sd.total += 1
		elif new_cat == CAT_NONE and old_cat != CAT_NONE:
			sd.total -= 1

		_adjust_count_dict(sd, old_cat, -1)
		_adjust_count_dict(sd, new_cat, 1)

		var meta: Dictionary = _sub_meta.get(sub_key, {})
		if meta.is_empty():
			continue

		var region_key: String = meta.get("region_key", "")
		var game: String = meta.get("game", "")

		if region_key == "" or game == "":
			continue

		regions[region_key] = true
		games[game] = true

	for region_key in regions.keys():
		var rd: Dictionary = _reg_counts.get(region_key, {})
		if rd.is_empty():
			continue

		if not _wk_region_counted.has(wk):
			_wk_region_counted[wk] = {}

		var was_counted: bool = _wk_region_counted[wk].has(region_key)

		if old_cat == CAT_NONE and new_cat != CAT_NONE:
			if not was_counted:
				_wk_region_counted[wk][region_key] = true
				rd.total += 1
		elif new_cat == CAT_NONE and old_cat != CAT_NONE:
			if was_counted:
				_wk_region_counted[wk].erase(region_key)
				rd.total -= 1

		if old_cat != CAT_NONE:
			_adjust_count_dict(rd, old_cat, -1)

		if new_cat != CAT_NONE:
			_adjust_count_dict(rd, new_cat, 1)

	for game in games.keys():
		var gd: Dictionary = _game_counts.get(game, {})
		if gd.is_empty():
			continue

		if not _wk_game_counted.has(wk):
			_wk_game_counted[wk] = {}

		var was_counted: bool = _wk_game_counted[wk].has(game)

		if old_cat == CAT_NONE and new_cat != CAT_NONE:
			if not was_counted:
				_wk_game_counted[wk][game] = true
				gd.total += 1
		elif new_cat == CAT_NONE and old_cat != CAT_NONE:
			if was_counted:
				_wk_game_counted[wk].erase(game)
				gd.total -= 1

		if old_cat != CAT_NONE:
			_adjust_count_dict(gd, old_cat, -1)

		if new_cat != CAT_NONE:
			_adjust_count_dict(gd, new_cat, 1)

	_pending_text_loc_keys[loc_key] = true

func _set_loc_reachable(wk: String, loc_key: String, reachable: bool) -> void:
	var old_cat: int = _get_wk_category(wk)
	_loc_reach_cache[wk] = reachable
	var new_cat: int = _get_wk_category(wk)
	_change_wk_category(wk, loc_key, old_cat, new_cat)

func _flush_pending_text_updates() -> void:
	if _pending_text_loc_keys.is_empty():
		return

	for loc_key in _pending_text_loc_keys.keys():
		_refresh_texts_for_loc_key(loc_key)

	_pending_text_loc_keys.clear()

func _refresh_texts_for_loc_key(loc_key: String) -> void:
	var regions: Dictionary = {}
	var games: Dictionary = {}

	for sub_key in _loc_to_subregions.get(loc_key, []):
		_set_sub_button(sub_key)

		var meta: Dictionary = _sub_meta.get(sub_key, {})
		if meta.is_empty():
			continue

		var region_key: String = meta.get("region_key", "")
		var game: String = meta.get("game", "")

		if region_key != "":
			regions[region_key] = true
		if game != "":
			games[game] = true

	for region_key in regions.keys():
		_set_region_button(region_key)

	for game in games.keys():
		_set_game_button(game)

	_update_global_label()

func _apply_all_progress_texts() -> void:
	for sub_key in _subregion_btns.keys():
		_set_sub_button(sub_key)

	for region_key in _region_btns.keys():
		_set_region_button(region_key)

	for game_key in _game_btns.keys():
		_set_game_button(game_key)

	_update_global_label()

func _set_progress_button(
	btn: Button,
	prefix: String,
	base_name: String,
	p: Dictionary,
	default_color: Color,
	is_log_loaded: bool
) -> void:
	var total: int = int(p.get("total", 0))
	var collected: int = int(p.get("collected", 0))
	var reachable: int = int(p.get("reachable", 0))
	var unknown: int = int(p.get("unknown", 0))

	if total == 0:
		btn.text = prefix + base_name
		btn.tooltip_text = "Collected: 0 | Available: 0 | Total: 0"
		btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		return

	if is_log_loaded:
		btn.tooltip_text = "Collected: %d | Available: %d | Total: %d" % [
			collected,
			reachable,
			total
		]

		btn.text = "%s%s [%d/%d/%d]" % [
			prefix,
			base_name,
			collected,
			reachable,
			total
		]

		if collected >= total:
			btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		elif unknown > 0:
			btn.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		elif reachable == 0:
			btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			btn.add_theme_color_override("font_color", default_color)
	else:
		btn.tooltip_text = "Collected: %d | Total: %d" % [collected, total]

		if collected >= total:
			btn.text = prefix + base_name
			btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			if collected > 0:
				btn.text = "%s%s [%d/%d]" % [prefix, base_name, collected, total]
			else:
				btn.text = prefix + base_name

			btn.add_theme_color_override("font_color", default_color)

func _set_sub_button(sub_key: String) -> void:
	var btn: Button = _subregion_btns.get(sub_key, null)
	if btn == null or not is_instance_valid(btn):
		return

	_set_progress_button(
		btn,
		"",
		str(btn.get_meta("base_name", "")),
		_sub_counts.get(sub_key, _empty_counts()),
		btn.get_meta("default_color", Color(1.0, 1.0, 1.0)),
		_is_logic_active()
	)

func _set_region_button(region_key: String) -> void:
	var btn: Button = _region_btns.get(region_key, null)
	if btn == null or not is_instance_valid(btn):
		return

	var container: Variant = btn.get_meta("container", null)
	var arrow: String = "  ▼ " if (
		container != null and
		container is VBoxContainer and
		container.visible
	) else "  ▶ "

	_set_progress_button(
		btn,
		arrow,
		str(btn.get_meta("base_name", "")),
		_reg_counts.get(region_key, _empty_counts()),
		btn.get_meta("default_color", Color(0.5, 0.7, 1.0)),
		_is_logic_active()
	)

func _set_game_button(game_key: String) -> void:
	var btn: Button = _game_btns.get(game_key, null)
	if btn == null or not is_instance_valid(btn):
		return

	var container: Variant = btn.get_meta("container", null)
	var arrow: String = "▼ " if (
		container != null and
		container is VBoxContainer and
		container.visible
	) else "▶ "

	_set_progress_button(
		btn,
		arrow,
		str(btn.get_meta("base_name", "")),
		_game_counts.get(game_key, _empty_counts()),
		btn.get_meta("default_color", Color(1.0, 0.85, 0.0)),
		_is_logic_active()
	)

func _update_global_label() -> void:
	if not total_label:
		return

	var global_total: int = 0
	var global_collected: int = 0
	var global_reachable: int = 0
	var global_unknown: int = 0

	for game_key in _game_counts.keys():
		var gp: Dictionary = _game_counts[game_key]
		global_total += int(gp.get("total", 0))
		global_collected += int(gp.get("collected", 0))
		global_reachable += int(gp.get("reachable", 0))
		global_unknown += int(gp.get("unknown", 0))

	if _is_logic_active():
		total_label.text = "%d (Collected) / %d (Available) / %d (Total)" % [
			global_collected,
			global_reachable,
			global_total
		]

		if global_unknown > 0:
			total_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		else:
			total_label.remove_theme_color_override("font_color")
	else:
		total_label.text = "%d (Collected) / %d (Total)" % [
			global_collected,
			global_total
		]
		total_label.remove_theme_color_override("font_color")

func _sync_data_from_main() -> void:
	var main_node = _get_main_node()
	if not main_node:
		return

	if main_node.has_method("get_all_data"):
		var data = main_node.get_all_data()
		var first_elem = data[0] if not data.is_empty() else null

		var array_changed: bool = not is_same(data, _data_ref)
		var first_changed: bool = not is_same(first_elem, _first_elem_ref)

		_all_data = data
		_data_ref = data
		_first_elem_ref = first_elem

		if array_changed:
			LogicEvaluator.clear_cache(true)
			_loc_reach_cache.clear()
			_loc_reach_stale = false
			_loc_reach_have_any = false
			_entrance_marker_state_cache.clear()
			_quick_jump_state_cache.clear()
			_cache_built = false
			_markers_need_rebuild = true
			_entrance_markers_need_rebuild = true
		elif first_changed:
			_loc_reach_stale = true
			_cache_built = false

		_build_location_cache()

	if main_node.has_method("get_log_info"):
		var log_info = main_node.get_log_info()
		if log_info is Dictionary:
			_log_mode = log_info.get("mode", "")
		else:
			_log_mode = ""
	else:
		_log_mode = ""

	if main_node.has_method("get_log_data"):
		var log_data = main_node.get_log_data()
		_has_entrance_data = not log_data.is_empty()
	else:
		_has_entrance_data = false

	var settings: Dictionary = {}
	if main_node.has_method("get_current_settings"):
		var s = main_node.get_current_settings()
		if s is Dictionary:
			settings = s

	var new_jp: Array = []
	if settings.has("jpLayouts"):
		var jp_data = settings["jpLayouts"]
		if jp_data is Array:
			new_jp = jp_data
		elif jp_data is Dictionary and jp_data.has(_current_world_filter):
			var world_jp = jp_data[_current_world_filter]
			if world_jp is Array:
				new_jp = world_jp

	if new_jp != _jp_layouts:
		_jp_layouts = new_jp
		LogicEvaluator.invalidate_setting_cache(["jpLayouts"])
		LogicEvaluator.invalidate_entrance_shuffle()
		_entrance_markers_need_rebuild = true
		_markers_need_rebuild = true
		_loc_reach_stale = true
		_entrance_marker_state_cache.clear()
		_quick_jump_state_cache.clear()
		_build_location_mapping()
		_update_markers()
		_update_location_tree_visibility()
		_apply_all_progress_texts()
		request_counters_update()

	var new_mq: Array = []
	if settings.has("mqDungeons"):
		var mq_data = settings["mqDungeons"]
		if mq_data is Array:
			new_mq = mq_data
		elif mq_data is Dictionary:
			for key in [_current_world_filter, str(_current_world_filter)]:
				if mq_data.has(key):
					var world_mq = mq_data[key]
					if world_mq is Array:
						new_mq = world_mq
						break

	if new_mq != _mq_dungeons_cache:
		_mq_dungeons_cache = new_mq
		_entrance_markers_need_rebuild = true
		_update_markers()

	var new_games := "ootmm"
	if settings.has("games"):
		new_games = str(settings["games"]).strip_edges()

	if new_games != _current_games_setting:
		_current_games_setting = new_games
		_loc_reach_stale = true
		_entrance_marker_state_cache.clear()
		_quick_jump_state_cache.clear()
		_markers_need_rebuild = true
		_entrance_markers_need_rebuild = true

		if _current_game_filter != "" and not _is_game_allowed(_current_game_filter):
			_current_game_filter = ""
			if game_filter:
				game_filter.select(0)

		_build_location_tree()
		_update_markers()

		if _current_game != "" and not _is_game_allowed(_current_game):
			_current_game = ""
			_current_region = ""
			_current_subregion = ""
			map_image.texture = null
			_current_map_texture = null
			_update_map_display()
			if info_label:
				info_label.text = "No map selected"

	if main_node.has_method("get_worlds_count"):
		var new_worlds = main_node.get_worlds_count()
		if new_worlds != _worlds_count:
			_worlds_count = new_worlds
			update_world_filter(_worlds_count)

	_update_active_location_menu()

func _build_location_cache() -> void:
	if _cache_built and is_same(_all_data, _location_cache_ref):
		return

	_location_cache.clear()

	for data in _all_data:
		var g = str(data.get("game", "")).strip_edges().to_upper()
		var loc = str(data.get("name", "")).strip_edges().to_lower()
		var world = int(data.get("world", 1))
		var key = "%s|%s|%d" % [g, loc, world]
		_location_cache[key] = data

	_location_cache_ref = _all_data
	_cache_built = true

	_rebuild_counts_from_cache()
	_apply_all_progress_texts()

func _update_location_cache_entry(game: String, loc_name: String, world: int, checked: bool) -> void:
	var key = "%s|%s|%d" % [
		game.strip_edges().to_upper(),
		loc_name.strip_edges().to_lower(),
		world
	]

	if _location_cache.has(key):
		_location_cache[key]["checked"] = checked
	else:
		_location_cache[key] = {"checked": checked, "item": ""}

func _build_jp_marker_cache() -> void:
	_jp_marker_names_cache.clear()
	_jp_entrance_base_names.clear()

	for marker in _markers:
		if _is_jp_marker(marker):
			var region = str(marker.get("region", "")).strip_edges()
			var marker_name = str(marker.get("marker_name", "")).strip_edges()
			_jp_marker_names_cache["%s|%s" % [region, marker_name]] = true

	for marker in _entrance_markers:
		var region = str(marker.get("region", "")).strip_edges()
		var marker_name = str(marker.get("marker_name", "")).strip_edges()
		var is_jp: bool = _is_jp_marker(marker) or _name_has_jp_suffix(marker_name)
		if is_jp:
			_jp_marker_names_cache["%s|%s" % [region, marker_name]] = true
			if marker.has("entrance") or marker.has("exit"):
				_jp_entrance_base_names["%s|%s" % [region, _strip_jp_suffix(marker_name)]] = true

func _is_jp_entrance_marker(marker: Dictionary) -> bool:
	var subregion = str(marker.get("subregion", "")).strip_edges()
	return subregion.begins_with("JP ")

func _has_jp_version_cached(region: String, marker_name: String) -> bool:
	return _jp_marker_names_cache.has("%s|%s" % [region, marker_name])

func _init_filters() -> void:
	if game_filter.item_count == 0:
		game_filter.add_item("All Games", 0)
		game_filter.add_item("OoT", 1)
		game_filter.add_item("MM", 2)

	_current_game_filter = ""

	if world_filter.item_count == 0:
		_current_world_filter = 1

	if status_filter and status_filter.item_count == 0:
		status_filter.add_item("All Status", 0)
		status_filter.add_item("Unchecked", 1)
		status_filter.add_item("Checked", 2)

	if logic_filter and logic_filter.item_count == 0:
		logic_filter.add_item("No Logic", 0)
		logic_filter.add_item("Reachable", 1)
		logic_filter.add_item("Unreachable", 2)

func _load_region_maps() -> void:
	const REGION_MAPS_PATH = "res://data/region_maps.json"

	_region_maps.clear()
	_region_map_by_key.clear()

	var data = _load_json_file(REGION_MAPS_PATH)
	if not (data is Array):
		return

	for row in data:
		if not (row is Array) or row.size() < 4:
			continue

		var game: String = str(row[0]).strip_edges()
		var region: String = str(row[1]).strip_edges()
		var subregion: String = str(row[2]).strip_edges()
		var map_path: String = str(row[3]).strip_edges()

		_region_maps.append({
			"game": game,
			"region": region,
			"subregion": subregion,
			"map_path": map_path
		})

		_region_map_by_key["%s|%s|%s" % [game, region, subregion]] = map_path

	_load_markers()
	_load_entrance_markers()
	_load_entrances_data()

func _load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	if text.is_empty():
		return null
	return JSON.parse_string(text)

func _load_markers() -> void:
	const MARKERS_PATH = "res://data/location_markers.json"

	_markers.clear()

	var data = _load_json_file(MARKERS_PATH)
	if not (data is Array):
		return

	for row in data:
		if not (row is Dictionary):
			continue

		var clean_row = {}
		for k in row:
			var clean_key = str(k).strip_edges()
			var v = row[k]
			if v is String:
				clean_row[clean_key] = str(v).strip_edges()
			else:
				clean_row[clean_key] = v

		var raw_locs = clean_row.get("locations", [])
		var locs_array: Array = []

		if raw_locs is Array and not raw_locs.is_empty():
			for loc in raw_locs:
				locs_array.append(str(loc).strip_edges())
		else:
			var marker_name = clean_row.get("marker_name", "").strip_edges()
			if marker_name != "":
				locs_array.append(marker_name)

		_markers.append({
			"game": clean_row.get("game", ""),
			"marker_name": clean_row.get("marker_name", ""),
			"locations": locs_array,
			"region": clean_row.get("region", ""),
			"subregion": clean_row.get("subregion", ""),
			"x": float(clean_row.get("x", 0)),
			"y": float(clean_row.get("y", 0)),
			"size": float(clean_row.get("size", 30)),
			"image": clean_row.get("image", ""),
			"overlay_image": clean_row.get("overlay_image", "")
		})

	_build_location_mapping()
	_build_location_cache()
	_build_jp_marker_cache()

func _build_location_mapping() -> void:
	_loc_to_subregions.clear()
	_subregion_locs_map.clear()
	_loc_original_names.clear()
	_subs_by_region.clear()
	_regions_by_game.clear()
	_sub_meta.clear()

	for marker in _markers:
		# Проверяем видимость маркера
		if not _should_show_marker(marker, _markers):
			continue

		var g = str(marker.get("game", "")).strip_edges().to_upper()
		var r = str(marker.get("region", "")).strip_edges()
		var s = str(marker.get("subregion", "")).strip_edges()
		var sub_key = "%s|%s|%s" % [g, r, s]

		_sub_meta[sub_key] = {
			"region_key": "%s|%s" % [g, r],
			"game": g
		}

		var sub_visible: bool = _should_show_subregion(g, r, s)

		if sub_visible and not _subregion_locs_map.has(sub_key):
			_subregion_locs_map[sub_key] = []

		var locs = marker.get("locations", [])

		for loc in locs:
			var orig_name = str(loc).strip_edges()
			var loc_clean = orig_name.to_lower()

			if loc_clean == "":
				continue

			var loc_key = "%s|%s" % [g, loc_clean]

			if not _loc_original_names.has(loc_key):
				_loc_original_names[loc_key] = orig_name

			if not sub_visible:
				continue

			if not _subregion_locs_map[sub_key].has(loc_key):
				_subregion_locs_map[sub_key].append(loc_key)

			if not _loc_to_subregions.has(loc_key):
				_loc_to_subregions[loc_key] = []

			if not _loc_to_subregions[loc_key].has(sub_key):
				_loc_to_subregions[loc_key].append(sub_key)

	for sub_key in _subregion_locs_map.keys():
		var meta: Dictionary = _sub_meta.get(sub_key, {})
		if meta.is_empty():
			continue

		var game: String = meta.get("game", "")
		var region_key: String = meta.get("region_key", "")

		if game == "" or region_key == "":
			continue

		if not _subs_by_region.has(region_key):
			_subs_by_region[region_key] = []

		if not _subs_by_region[region_key].has(sub_key):
			_subs_by_region[region_key].append(sub_key)

		if not _regions_by_game.has(game):
			_regions_by_game[game] = []

		if not _regions_by_game[game].has(region_key):
			_regions_by_game[game].append(region_key)

	_rebuild_counts_from_cache()

func _update_map_display() -> void:
	if not map_image.texture:
		map_image.custom_minimum_size = Vector2.ZERO
		map_image.size = Vector2.ZERO
		map_image.position = Vector2.ZERO
		_auto_scale = 1.0
		_user_zoom = 1.0
		_map_offset = Vector2.ZERO

		if info_label:
			info_label.text = "No map selected"

		if _markers_container:
			_markers_container.queue_free()
			_markers_container = null

		if _entrance_markers_container:
			_entrance_markers_container.queue_free()
			_entrance_markers_container = null

		return

	if not _markers_container:
		_markers_container = Control.new()
		_markers_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		_markers_container.name = "MarkersContainer"
		_markers_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_image.add_child(_markers_container)

	if not _entrance_markers_container:
		_entrance_markers_container = Control.new()
		_entrance_markers_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		_entrance_markers_container.name = "EntranceMarkersContainer"
		_entrance_markers_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_image.add_child(_entrance_markers_container)

	var min_size = Vector2(MIN_FIELD_WIDTH, MIN_FIELD_HEIGHT)
	map_container.custom_minimum_size = min_size

	var container_size = map_container.size
	container_size = Vector2(
		max(container_size.x, min_size.x),
		max(container_size.y, min_size.y)
	)

	var texture_size = map_image.texture.get_size()
	var scale_x = container_size.x / texture_size.x
	var scale_y = container_size.y / texture_size.y

	_auto_scale = min(scale_x, scale_y)

	var total_scale = _auto_scale * _user_zoom
	var scaled_size = texture_size * total_scale

	map_image.custom_minimum_size = scaled_size
	map_image.size = scaled_size
	map_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT

	var center_offset = Vector2.ZERO

	if scaled_size.x <= container_size.x:
		center_offset.x = (container_size.x - scaled_size.x) / 2

	if scaled_size.y <= container_size.y:
		center_offset.y = (container_size.y - scaled_size.y) / 2

	if scaled_size.x > container_size.x:
		map_image.position.x = center_offset.x + _map_offset.x
	else:
		map_image.position.x = center_offset.x
		_map_offset.x = 0

	if scaled_size.y > container_size.y:
		map_image.position.y = center_offset.y + _map_offset.y
	else:
		map_image.position.y = center_offset.y
		_map_offset.y = 0

	_update_markers()

func _build_location_tree() -> void:
	_subregion_btns.clear()
	_region_btns.clear()
	_game_btns.clear()

	for child in location_tree.get_children():
		child.queue_free()

	var games_data = {}
	var game_order = []
	var region_order_by_game = {}

	for map_data in _region_maps:
		var game = map_data.get("game", "Unknown")
		var region = map_data.get("region", "Unknown")
		var subregion = map_data.get("subregion", "Unknown")

		if _current_game_filter != "" and game != _current_game_filter:
			continue

		if not _is_game_allowed(game):
			continue

		if not games_data.has(game):
			games_data[game] = {}
			game_order.append(game)
			region_order_by_game[game] = []

		if not games_data[game].has(region):
			games_data[game][region] = []
			region_order_by_game[game].append(region)

		games_data[game][region].append({
			"name": subregion,
			"map_path": map_data.get("map_path", "")
		})

	for game in game_order:
		location_tree.add_child(
			_create_game_block(game, games_data[game], region_order_by_game[game])
		)

	_apply_all_progress_texts()

func _create_game_block(game: String, regions_data: Dictionary, region_order: Array) -> VBoxContainer:
	var game_vbox = VBoxContainer.new()
	game_vbox.add_theme_constant_override("separation", 4)

	var game_btn = Button.new()
	game_btn.text = "▼  " + game
	game_btn.set_meta("base_name", game)
	game_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	game_btn.flat = true

	var default_color = Color(1.0, 0.85, 0.0)
	game_btn.add_theme_color_override("font_color", default_color)
	game_btn.set_meta("default_color", default_color)

	game_vbox.add_child(game_btn)

	var game_clean = game.strip_edges().to_upper()
	_game_btns[game_clean] = game_btn

	var regions_container = VBoxContainer.new()
	regions_container.add_theme_constant_override("separation", 2)
	regions_container.visible = false
	game_btn.set_meta("container", regions_container)
	game_vbox.add_child(regions_container)

	for region in region_order:
		regions_container.add_child(
			_create_region_block(game, region, regions_data[region])
		)

	game_btn.pressed.connect(func():
		regions_container.visible = not regions_container.visible
		_set_game_button(game_clean)
	)

	regions_container.visible = true
	game_btn.text = "▼  " + game

	return game_vbox

func _create_region_block(game: String, region: String, subregions_data: Array) -> VBoxContainer:
	var region_vbox = VBoxContainer.new()
	region_vbox.add_theme_constant_override("separation", 2)

	var region_btn = Button.new()
	region_btn.text = "  ▼  " + region
	region_btn.set_meta("base_name", region)
	region_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	region_btn.flat = true

	var reg_default_color = Color(0.5, 0.7, 1.0)
	region_btn.add_theme_color_override("font_color", reg_default_color)
	region_btn.set_meta("default_color", reg_default_color)

	region_vbox.add_child(region_btn)

	var game_clean = game.strip_edges().to_upper()
	var region_clean = region.strip_edges()
	var region_key = "%s|%s" % [game_clean, region_clean]
	_region_btns[region_key] = region_btn

	var subregions_container = VBoxContainer.new()
	subregions_container.add_theme_constant_override("separation", 1)
	subregions_container.visible = false
	region_btn.set_meta("container", subregions_container)
	region_vbox.add_child(subregions_container)

	for subregion_data in subregions_data:
		var subregion_name = subregion_data.get("name", "Unknown")
		var map_path = subregion_data.get("map_path", "")

		var subregion_btn = Button.new()
		subregion_btn.text = "    • " + subregion_name
		subregion_btn.set_meta("base_name", "    • " + subregion_name)
		subregion_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		subregion_btn.flat = true

		var sub_default_color = Color(1.0, 1.0, 1.0)
		subregion_btn.add_theme_color_override("font_color", sub_default_color)
		subregion_btn.set_meta("default_color", sub_default_color)

		var sub_key = "%s|%s|%s" % [game_clean, region_clean, subregion_name]
		_subregion_btns[sub_key] = subregion_btn
		subregion_btn.visible = _should_show_subregion(game, region, subregion_name)

		subregion_btn.pressed.connect(func(sub_name = subregion_name, path = map_path):
			_on_subregion_selected(game, region, sub_name, path)
		)

		subregions_container.add_child(subregion_btn)

	region_btn.pressed.connect(func():
		subregions_container.visible = not subregions_container.visible
		_set_region_button(region_key)
	)

	subregions_container.visible = true
	region_btn.text = "  ▼ " + region

	return region_vbox

func _update_location_tree_visibility() -> void:
	for sub_key in _subregion_btns.keys():
		var btn = _subregion_btns[sub_key]
		if is_instance_valid(btn):
			btn.visible = _sub_key_visible(sub_key)

	_update_parent_containers_visibility()

func _update_parent_containers_visibility() -> void:
	for region_key in _region_btns.keys():
		var region_btn = _region_btns[region_key]
		if is_instance_valid(region_btn):
			var container = region_btn.get_meta("container", null)
			var has_visible_children = false

			if container and container is VBoxContainer:
				for child in container.get_children():
					if child is Button and child.visible:
						has_visible_children = true
						break

			region_btn.visible = has_visible_children

	for game_key in _game_btns.keys():
		var game_btn = _game_btns[game_key]
		if is_instance_valid(game_btn):
			var container = game_btn.get_meta("container", null)
			var has_visible_children = false

			if container and container is VBoxContainer:
				for child in container.get_children():
					if child is VBoxContainer and child.visible:
						has_visible_children = true
						break

			game_btn.visible = has_visible_children

func _on_map_container_resized() -> void:
	_update_map_display()

func _on_logic_filter_changed(index: int) -> void:
	_current_logic_filter = index
	_refresh_all_location_markers_from_cache()
	_refresh_entrance_markers_from_cache()
	_refresh_quick_jump_from_cache()

func _on_game_filter_changed(index: int) -> void:
	_markers_need_rebuild = true
	_entrance_markers_need_rebuild = true

	if index == 0:
		_current_game_filter = ""
	elif index == 1:
		_current_game_filter = "OoT"
	elif index == 2:
		_current_game_filter = "MM"

	_build_location_tree()
	_update_markers()

func _on_world_filter_changed(index: int) -> void:
	_markers_need_rebuild = true
	_entrance_markers_need_rebuild = true
	_current_world_filter = index + 1

	LogicEvaluator.ensure_reach(_current_world_filter)

	_rebuild_counts_from_cache()
	_apply_all_progress_texts()

	_update_markers()

	request_counters_update()

func _on_status_filter_changed(index: int) -> void:
	_current_status_filter = index
	_markers_need_rebuild = true
	_entrance_markers_need_rebuild = true
	_update_markers()

func _on_zoom_in_pressed() -> void:
	if not map_image.texture:
		return

	_user_zoom *= 1.2
	_user_zoom = clamp(_user_zoom, 0.1, 5.0)
	_update_map_display()

func _on_zoom_out_pressed() -> void:
	if not map_image.texture:
		return

	_user_zoom *= 0.8
	_user_zoom = clamp(_user_zoom, 0.1, 5.0)
	_update_map_display()

func _on_reset_zoom_pressed() -> void:
	_user_zoom = 1.0
	_map_offset = Vector2.ZERO
	_update_map_display()

func _zoom_map(scale_factor: float) -> void:
	if not map_image.texture:
		return

	_user_zoom *= scale_factor
	_user_zoom = clamp(_user_zoom, 0.1, 5.0)
	_update_map_display()

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
	
	if _is_menu_dragging and _active_custom_menu and is_instance_valid(_active_custom_menu):
		if event is InputEventMouseMotion:
			var map_global_rect = map_container.get_global_rect()
			var menu_size = _active_custom_menu.size
			var new_global_pos = _menu_drag_offset + (event.global_position - _menu_drag_start_pos)

			var min_x = map_global_rect.position.x
			var max_x = max(min_x, map_global_rect.end.x - menu_size.x)
			var min_y = map_global_rect.position.y
			var max_y = max(min_y, map_global_rect.end.y - menu_size.y)

			new_global_pos.x = clamp(new_global_pos.x, min_x, max_x)
			new_global_pos.y = clamp(new_global_pos.y, min_y, max_y)

			_active_custom_menu.global_position = new_global_pos
			get_viewport().set_input_as_handled()
			return

	if _active_custom_menu and is_instance_valid(_active_custom_menu):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos = get_global_mouse_position()
			var menu_rect = Rect2(_active_custom_menu.global_position, _active_custom_menu.size)

			if not menu_rect.has_point(click_pos):
				var click_on_marker = false

				for marker_btn in _marker_buttons:
					if is_instance_valid(marker_btn):
						var marker_rect = Rect2(marker_btn.global_position, marker_btn.size)
						if marker_rect.has_point(click_pos):
							click_on_marker = true
							break

				if not click_on_marker:
					_active_custom_menu.queue_free()
					_active_custom_menu = null
					return

	if not is_visible_in_tree() or not map_image.texture:
		return

	var mouse_pos = get_global_mouse_position()
	var map_rect = map_container.get_global_rect()

	if not map_rect.has_point(mouse_pos):
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_map(1.1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_map(0.9)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var container_size = map_container.size
			var image_size = map_image.size

			if image_size.x > container_size.x or image_size.y > container_size.y:
				_is_dragging = true
				_drag_start_pos = event.position
				_drag_start_offset = map_image.position
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var container_size = map_container.size
		var scaled_size = map_image.size
		var max_offset_x = max(0, scaled_size.x - container_size.x)
		var max_offset_y = max(0, scaled_size.y - container_size.y)
		var delta = event.position - _drag_start_pos
		var new_offset = _drag_start_offset + delta

		new_offset.x = clamp(new_offset.x, -max_offset_x, 0) if max_offset_x > 0 else 0
		new_offset.y = clamp(new_offset.y, -max_offset_y, 0) if max_offset_y > 0 else 0

		_map_offset = new_offset
		_update_map_display()

func _on_load_pressed() -> void:
	var main_node = _get_main_node()
	if main_node and main_node.has_method("_on_load_pressed"):
		main_node._on_load_pressed()

func _on_save_pressed() -> void:
	var main_node = _get_main_node()
	if main_node and main_node.has_method("_on_save_pressed"):
		main_node._on_save_pressed()

func _on_clear_pressed() -> void:
	var main_node = _get_main_node()
	if main_node and main_node.has_method("_on_clear_pressed"):
		main_node._on_clear_pressed()

func update_world_filter(worlds_count: int) -> void:
	var prev_world = _current_world_filter
	_worlds_count = worlds_count

	world_filter.clear()

	for i in range(1, worlds_count + 1):
		world_filter.add_item("World " + str(i), i)

	if prev_world > 0 and prev_world <= worlds_count:
		world_filter.select(prev_world - 1)
		_current_world_filter = prev_world
	elif worlds_count >= 1:
		world_filter.select(0)
		_current_world_filter = 1
	else:
		_current_world_filter = 1

func update_from_log_data(log_info: Dictionary, all_data: Array, worlds_count: int) -> void:
	_log_info = log_info
	_log_mode = log_info.get("mode", "")
	_all_data = all_data
	_cached_first_elem = all_data[0] if not all_data.is_empty() else null
	_worlds_count = worlds_count

	_build_location_cache()
	update_world_filter(worlds_count)

	var main_node = _get_main_node()
	if main_node and main_node.has_method("get_log_data"):
		_has_entrance_data = not main_node.get_log_data().is_empty()

	_register_all_quick_jump_codes()

	_sync_data_from_main()
	LogicEvaluator.invalidate_entrance_shuffle()
	LogicEvaluator.clear_cache(true)

	_loc_reach_cache.clear()
	_loc_reach_stale = true
	_loc_reach_have_any = false
	_entrance_marker_state_cache.clear()
	_quick_jump_state_cache.clear()

	_markers_need_rebuild = true
	_entrance_markers_need_rebuild = true

	_update_markers()

	LogicEvaluator.build_static_graph()

	for w in range(1, _worlds_count + 1):
		LogicEvaluator.ensure_reach(w)

	_rebuild_counts_from_cache()
	_apply_all_progress_texts()

	request_counters_update()
	_post_load_refresh()

func _register_all_quick_jump_codes() -> void:
	for row_data in [QUICK_JUMP_ROW_1, QUICK_JUMP_ROW_2]:
		for spawn_data in row_data:
			LogicEvaluator.register_quick_jump_code(
				str(spawn_data.get("name", "")),
				str(spawn_data.get("code", ""))
			)

func _post_load_refresh() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_register_all_quick_jump_codes()
	_sync_data_from_main()

	_loc_reach_stale = true
	_markers_need_rebuild = true
	_entrance_markers_need_rebuild = true

	_update_markers()

	LogicEvaluator.build_static_graph()

	for w in range(1, _worlds_count + 1):
		LogicEvaluator.ensure_reach(w)

	_rebuild_counts_from_cache()
	_apply_all_progress_texts()

	request_counters_update()

func _sub_key_visible(sub_key: String) -> bool:
	return _should_show_subregion(
		sub_key.get_slice("|", 0),
		sub_key.get_slice("|", 1),
		sub_key.get_slice("|", 2)
	)

func refresh_markers() -> void:
	if not is_visible_in_tree():
		return

	_loc_reach_stale = true
	_entrance_marker_state_cache.clear()
	_quick_jump_state_cache.clear()
	_sync_data_from_main()
	_update_markers()
	request_counters_update()

func refresh_games_visibility() -> void:
	_sync_data_from_main()
	_update_markers()
	request_counters_update()

func refresh_jp_layout_visibility() -> void:
	LogicEvaluator.invalidate_setting_cache(["jpLayouts"])
	LogicEvaluator.invalidate_entrance_shuffle()
	_sync_data_from_main()
	_update_location_tree_visibility()
	_update_markers()
	request_counters_update()

func request_counters_update() -> void:
	if not is_visible_in_tree():
		return

	_start_async_counters()

func _start_async_counters() -> void:
	if not is_visible_in_tree():
		return

	if not _cache_built:
		_build_location_cache()

	LogicEvaluator.build_static_graph()

	var all_prepared: bool = true
	for w in range(1, _worlds_count + 1):
		if not LogicEvaluator.is_reach_prepared(w):
			all_prepared = false
			break

	if not all_prepared:
		for w in range(1, _worlds_count + 1):
			LogicEvaluator.request_reach_compute(w, _on_reach_ready)

		_rebuild_counts_from_cache()
		_apply_all_progress_texts()
		_refresh_all_location_markers_from_cache()
		_refresh_entrance_markers_from_cache()
		_refresh_quick_jump_from_cache()
		return

	var completed: bool = await _fill_all_caches_async()

	if completed and is_visible_in_tree():
		_rebuild_counts_from_cache()
		_apply_all_progress_texts()
		_refresh_all_location_markers_from_cache()
		_refresh_entrance_markers_from_cache()
		_refresh_quick_jump_from_cache()

func _on_reach_ready() -> void:
	if not is_visible_in_tree():
		return

	_loc_reach_stale = true
	_entrance_marker_state_cache.clear()
	_quick_jump_state_cache.clear()

	request_counters_update()

func _fill_all_caches_async() -> bool:
	if not _is_logic_active():
		if not _loc_reach_cache.is_empty():
			_loc_reach_cache.clear()
			_rebuild_counts_from_cache()
			_apply_all_progress_texts()

		_loc_reach_stale = false
		_loc_reach_have_any = true
		return true

	var force: bool = _loc_reach_stale or (not _loc_reach_have_any)
	var last_yield: int = Time.get_ticks_msec()
	var processed: int = 0

	for loc_key in _loc_to_subregions.keys():
		var parts: Array = str(loc_key).split("|")
		if parts.size() < 2:
			continue

		var game: String = parts[0]
		var orig_name: String = _loc_original_names.get(loc_key, parts[1])
		if orig_name == "":
			continue

		for world in range(1, _worlds_count + 1):
			var wk: String = _world_key(loc_key, world)

			if not _is_countable_world_key(wk):
				continue

			var checked: bool = bool(_location_cache[wk].get("checked", false))

			if checked:
				if not _loc_reach_cache.has(wk) or bool(_loc_reach_cache[wk]):
					_set_loc_reachable(wk, loc_key, false)
				continue

			if not force and _loc_reach_cache.has(wk):
				continue

			var now: int = Time.get_ticks_msec()
			if now - last_yield > 6:
				_flush_pending_text_updates()
				_refresh_all_location_markers_from_cache()

				await get_tree().process_frame
				last_yield = Time.get_ticks_msec()

				if not is_visible_in_tree():
					return false

			var reachable: bool = LogicEvaluator.is_location_reachable(orig_name, world, game)
			_set_loc_reachable(wk, loc_key, reachable)

			processed += 1
			if processed % 250 == 0:
				_flush_pending_text_updates()
				_refresh_all_location_markers_from_cache()

	_loc_reach_stale = false
	_loc_reach_have_any = true

	_flush_pending_text_updates()
	_refresh_all_location_markers_from_cache()

	await _fill_marker_states_async()

	return true

func _fill_marker_states_async() -> bool:
	if not _has_entrance_data:
		return true

	var last_yield: int = Time.get_ticks_msec()
	var prepared: bool = LogicEvaluator.is_reach_prepared(_current_world_filter)

	for container in _entrance_marker_buttons:
		if not is_instance_valid(container):
			continue

		var marker: Dictionary = container.get_meta("marker_data", {})
		var marker_name: String = str(marker.get("marker_name", "")).strip_edges()
		if marker_name == "":
			continue

		var key: String = "%d|%s" % [_current_world_filter, marker_name]

		if _entrance_marker_state_cache.has(key):
			continue

		if not prepared:
			continue

		var now: int = Time.get_ticks_msec()
		if now - last_yield > 6:
			_refresh_entrance_markers_from_cache()
			await get_tree().process_frame
			last_yield = Time.get_ticks_msec()

			if not is_visible_in_tree():
				return false

		_entrance_marker_state_cache[key] = LogicEvaluator.is_marker_reachable(marker_name, _current_world_filter)

	for panel in _quick_jump_buttons:
		if not is_instance_valid(panel):
			continue

		var qj_name: String = str(panel.get_meta("qj_name", ""))
		if qj_name == "":
			continue

		var key: String = "%d|%s" % [_current_world_filter, qj_name]

		if _quick_jump_state_cache.has(key):
			continue

		if not prepared:
			continue

		var now: int = Time.get_ticks_msec()
		if now - last_yield > 6:
			_refresh_quick_jump_from_cache()
			await get_tree().process_frame
			last_yield = Time.get_ticks_msec()

			if not is_visible_in_tree():
				return false

		_quick_jump_state_cache[key] = LogicEvaluator.is_quick_jump_reachable(qj_name, _current_world_filter)

	_refresh_entrance_markers_from_cache()
	_refresh_quick_jump_from_cache()

	return true

func _update_markers() -> void:
	if not map_image.texture or not _markers_container:
		return

	if _markers_need_rebuild:
		_loc_to_marker_containers.clear()

		for btn in _marker_buttons:
			if is_instance_valid(btn):
				btn.queue_free()

		_marker_buttons.clear()
		_build_location_markers()
		_markers_need_rebuild = false
	else:
		_update_location_marker_transforms()

	if _entrance_markers_need_rebuild:
		for btn in _entrance_marker_buttons:
			if is_instance_valid(btn):
				btn.queue_free()

		_entrance_marker_buttons.clear()

		if _has_entrance_data:
			_build_entrance_markers()
			_build_quick_jump_buttons()
		else:
			if _entrance_markers_container:
				_entrance_markers_container.visible = false
			if _quick_jump_container:
				_quick_jump_container.visible = false

		_entrance_markers_need_rebuild = false
	else:
		_update_entrance_marker_transforms()

	_refresh_all_location_markers_from_cache()
	_refresh_entrance_markers_from_cache()
	_refresh_quick_jump_from_cache()

func _build_location_markers() -> void:
	var total_scale = _auto_scale * _user_zoom

	for marker in _markers:
		if not _should_show_marker(marker, _markers):
			continue

		if not _is_game_allowed(str(marker.get("game", ""))):
			continue

		if marker.region == _current_region and marker.subregion == _current_subregion:
			if _should_show_marker_for_world(marker.get("game", ""), marker.get("locations", []), _current_world_filter):
				_create_map_marker(marker, total_scale, false)

func _update_location_marker_transforms() -> void:
	var total_scale = _auto_scale * _user_zoom

	for container in _marker_buttons:
		if is_instance_valid(container):
			var marker = container.get_meta("marker_data")
			var marker_size = marker.get("size", 30) * total_scale

			container.custom_minimum_size = Vector2(marker_size, marker_size)
			container.size = Vector2(marker_size, marker_size)

			var marker_x = marker.get("x", 0) * total_scale
			var marker_y = marker.get("y", 0) * total_scale

			container.position = Vector2(marker_x - marker_size / 2.0, marker_y - marker_size / 2.0)

func _build_entrance_markers() -> void:
	if _entrance_markers_container:
		_entrance_markers_container.visible = true

	var total_scale = _auto_scale * _user_zoom

	for marker in _entrance_markers:
		if not _should_show_marker(marker, _entrance_markers):
			continue

		if not _is_game_allowed(str(marker.get("game", ""))):
			continue

		if marker.get("region", "") == _current_region and marker.get("subregion", "") == _current_subregion:
			var marker_game = marker.get("game", "")
			if _current_game_filter == "" or marker_game == _current_game_filter:
				_create_map_marker(marker, total_scale, true)

func _update_entrance_marker_transforms() -> void:
	var total_scale = _auto_scale * _user_zoom

	for container in _entrance_marker_buttons:
		if is_instance_valid(container):
			var marker = container.get_meta("marker_data")
			var marker_size = marker.get("size", 30) * total_scale

			container.custom_minimum_size = Vector2(marker_size, marker_size)
			container.size = Vector2(marker_size, marker_size)

			var marker_x = marker.get("x", 0) * total_scale
			var marker_y = marker.get("y", 0) * total_scale

			container.position = Vector2(marker_x - marker_size / 2.0, marker_y - marker_size / 2.0)

func _should_show_marker_for_world(marker_game: String, locations_array: Array, world: int) -> bool:
	if locations_array.is_empty():
		return false

	if not _cache_built:
		_build_location_cache()

	var game_upper = marker_game.strip_edges().to_upper()

	for loc_name in locations_array:
		var loc_lower = str(loc_name).strip_edges().to_lower()
		var key = "%s|%s|%d" % [game_upper, loc_lower, world]

		if _location_cache.has(key):
			var data = _location_cache[key]
			var item = str(data.get("item", "")).strip_edges()

			if item != "" and item.to_lower() != "(unknown)":
				if _current_status_filter == 0:
					return true
				elif _current_status_filter == 1:
					if not bool(data.get("checked", false)):
						return true
				elif _current_status_filter == 2:
					if bool(data.get("checked", false)):
						return true

	return false

func _create_map_marker(marker: Dictionary, scale_factor: float, is_entrance: bool) -> void:
	var container = Control.new()
	var marker_name = str(marker.get("marker_name", "group"))
	container.name = ("Entrance" if is_entrance else "Marker_") + marker_name.replace(" ", "")
	container.set_meta("marker_data", marker)

	var marker_size = float(marker.get("size", 30)) * scale_factor
	container.custom_minimum_size = Vector2(marker_size, marker_size)
	container.size = Vector2(marker_size, marker_size)
	container.modulate.a = 0.3

	var image_path = str(marker.get("image", ""))
	if image_path != "" and ResourceLoader.exists(image_path):
		var main_img = TextureRect.new()
		main_img.texture = load(image_path)
		main_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		main_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		main_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		main_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(main_img)
	else:
		var fallback = ColorRect.new()
		fallback.color = Color(0.3, 0.6, 1.0, 0.8) if is_entrance else Color.RED
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(fallback)

	var overlay_path = str(marker.get("overlay_image", ""))
	if overlay_path != "" and ResourceLoader.exists(overlay_path):
		var overlay = TextureRect.new()
		overlay.texture = load(overlay_path)
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(overlay)

	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.tooltip_text = marker_name
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if is_entrance:
		btn.pressed.connect(_on_entrance_marker_clicked.bind(marker))
	else:
		btn.pressed.connect(_on_marker_clicked.bind(marker, marker.get("locations", []), btn))
	
	container.add_child(btn)

	if not is_entrance:
		for i in range(2):
			var digit_rect := TextureRect.new()
			digit_rect.name = "counter_digit_" + str(i)
			digit_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			digit_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			digit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			digit_rect.visible = false
			container.add_child(digit_rect)

	var marker_x = float(marker.get("x", 0)) * scale_factor
	var marker_y = float(marker.get("y", 0)) * scale_factor
	container.position = Vector2(marker_x - marker_size / 2.0, marker_y - marker_size / 2.0)

	if is_entrance:
		if _entrance_markers_container:
			_entrance_markers_container.add_child(container)
			_entrance_marker_buttons.append(container)
	else:
		if _markers_container:
			_markers_container.add_child(container)
			_marker_buttons.append(container)

		var marker_game = str(marker.get("game", ""))
		for loc_name in marker.get("locations", []):
			var lk = _loc_key(marker_game, loc_name)
			if not _loc_to_marker_containers.has(lk):
				_loc_to_marker_containers[lk] = []
			_loc_to_marker_containers[lk].append(container)

func _update_marker_counter(container: Control, reachable_count: int) -> void:
	var digit0: TextureRect = container.get_node_or_null("counter_digit_0") as TextureRect
	var digit1: TextureRect = container.get_node_or_null("counter_digit_1") as TextureRect

	if reachable_count <= 1:
		if digit0:
			digit0.visible = false
		if digit1:
			digit1.visible = false
		return

	var marker_size: float = container.size.x
	var dw: float = clamp(marker_size * 0.25, 6.0, 16.0)
	var dh: float = clamp(marker_size * 0.35, 8.0, 22.0)

	var tens: int = int(reachable_count / 10.0)
	var units: int = reachable_count % 10

	if tens > 0:
		if digit0:
			var p0 := "res://images/numbers/" + str(tens) + ".png"
			if ResourceLoader.exists(p0):
				digit0.texture = load(p0)
			digit0.position = Vector2.ZERO
			digit0.size = Vector2(dw, dh)
			digit0.visible = true

		if digit1:
			var p1 := "res://images/numbers/" + str(units) + ".png"
			if ResourceLoader.exists(p1):
				digit1.texture = load(p1)
			digit1.position = Vector2(dw, 0)
			digit1.size = Vector2(dw, dh)
			digit1.visible = true
	else:
		if digit0:
			var p0 := "res://images/numbers/" + str(units) + ".png"
			if ResourceLoader.exists(p0):
				digit0.texture = load(p0)
			digit0.position = Vector2.ZERO
			digit0.size = Vector2(dw, dh)
			digit0.visible = true

		if digit1:
			digit1.visible = false

func _marker_passes_status_filter(marker: Dictionary) -> bool:
	if _current_status_filter == 0:
		return true

	var game: String = str(marker.get("game", ""))
	var locations: Array = marker.get("locations", [])

	for loc_name: String in locations:
		var wk: String = _world_key(_loc_key(game, loc_name), _current_world_filter)

		if not _is_countable_world_key(wk):
			continue

		var checked: bool = bool(_location_cache[wk].get("checked", false))

		if _current_status_filter == 1 and not checked:
			return true

		if _current_status_filter == 2 and checked:
			return true

	return false

func _update_marker_container_state(container: Control) -> void:
	var marker: Dictionary = container.get_meta("marker_data", {})

	if not _marker_passes_status_filter(marker):
		container.visible = false
		return

	var game: String = str(marker.get("game", "")).strip_edges()
	var locations_array: Array = marker.get("locations", [])

	var total_uncollected: int = 0
	var reachable_uncollected: int = 0
	var unknown_uncollected: int = 0

	for loc_name: String in locations_array:
		var clean_loc: String = str(loc_name).strip_edges()
		if clean_loc.is_empty():
			continue

		var loc_key: String = _loc_key(game, clean_loc)
		var wk: String = _world_key(loc_key, _current_world_filter)

		if not _location_cache.has(wk):
			continue

		var data: Dictionary = _location_cache[wk]
		if bool(data.get("checked", false)):
			continue

		if not _is_countable_world_key(wk):
			continue

		total_uncollected += 1

		var cat: int = _get_wk_category(wk)

		if cat == CAT_REACHABLE:
			reachable_uncollected += 1
		elif cat == CAT_UNKNOWN:
			unknown_uncollected += 1

	_update_marker_counter(container, reachable_uncollected)

	var is_unreachable: bool = total_uncollected > 0 and reachable_uncollected == 0 and unknown_uncollected == 0
	var is_reachable: bool = total_uncollected > 0 and reachable_uncollected > 0
	var is_all_collected: bool = total_uncollected == 0

	if _current_logic_filter == 0:
		container.visible = true

		if is_all_collected:
			container.modulate.a = 1.0
		elif unknown_uncollected > 0:
			container.modulate.a = 0.6
		elif is_unreachable:
			container.modulate.a = 0.3
		else:
			container.modulate.a = 1.0
	elif _current_logic_filter == 1:
		container.visible = is_all_collected or is_reachable
		container.modulate.a = 1.0
	elif _current_logic_filter == 2:
		container.visible = is_unreachable
		container.modulate.a = 1.0

func _refresh_markers_for_loc_key(loc_key: String) -> void:
	for container in _loc_to_marker_containers.get(loc_key, []):
		if is_instance_valid(container):
			_update_marker_container_state(container)

func _refresh_all_location_markers_from_cache() -> void:
	for container in _marker_buttons:
		if is_instance_valid(container):
			_update_marker_container_state(container)

func refresh_location_markers_visibility() -> void:
	_refresh_all_location_markers_from_cache()

func _refresh_entrance_markers_from_cache() -> void:
	if _entrance_marker_buttons.is_empty():
		return

	var prepared: bool = LogicEvaluator.is_reach_prepared(_current_world_filter)

	for container in _entrance_marker_buttons:
		if not is_instance_valid(container):
			continue

		var marker: Dictionary = container.get_meta("marker_data", {})
		var marker_name: String = str(marker.get("marker_name", "")).strip_edges()
		var key: String = "%d|%s" % [_current_world_filter, marker_name]

		var reachable: bool = false
		var known: bool = false

		if _entrance_marker_state_cache.has(key):
			reachable = bool(_entrance_marker_state_cache[key])
			known = true
		elif prepared:
			reachable = LogicEvaluator.is_marker_reachable(marker_name, _current_world_filter)
			_entrance_marker_state_cache[key] = reachable
			known = true

		if _current_logic_filter == 0:
			container.visible = true
			container.modulate.a = 1.0 if reachable else (0.6 if not known else 0.3)
		elif _current_logic_filter == 1:
			container.visible = reachable
			container.modulate.a = 1.0
		elif _current_logic_filter == 2:
			container.visible = known and not reachable
			container.modulate.a = 1.0

func refresh_entrance_markers_visibility() -> void:
	_refresh_entrance_markers_from_cache()

func _refresh_quick_jump_from_cache() -> void:
	if not _quick_jump_container or not _has_entrance_data:
		return

	if _quick_jump_buttons.is_empty():
		_build_quick_jump_buttons()

	var prepared: bool = LogicEvaluator.is_reach_prepared(_current_world_filter)

	for panel in _quick_jump_buttons:
		if not is_instance_valid(panel):
			continue

		var qj_name: String = str(panel.get_meta("qj_name", ""))
		var key: String = "%d|%s" % [_current_world_filter, qj_name]

		var reachable: bool = false
		var known: bool = false

		if _quick_jump_state_cache.has(key):
			reachable = bool(_quick_jump_state_cache[key])
			known = true
		elif prepared:
			reachable = LogicEvaluator.is_quick_jump_reachable(qj_name, _current_world_filter)
			_quick_jump_state_cache[key] = reachable
			known = true

		if _current_logic_filter == 0:
			panel.visible = true
			panel.modulate.a = 1.0 if reachable else (0.6 if not known else 0.3)
		elif _current_logic_filter == 1:
			panel.visible = reachable
			panel.modulate.a = 1.0
		elif _current_logic_filter == 2:
			panel.visible = known and not reachable
			panel.modulate.a = 1.0

func refresh_quick_jump_visibility() -> void:
	_refresh_quick_jump_from_cache()

func _on_marker_clicked(marker: Dictionary, locations_array: Array, _source_btn: Button) -> void:
	if _active_custom_menu and is_instance_valid(_active_custom_menu):
		_active_custom_menu.queue_free()
		_active_custom_menu = null

	var custom_menu = PanelContainer.new()
	custom_menu.name = "CustomLocationMenu"

	var base_height: int = 50
	var row_height: int = 32
	var spacing: int = 4
	var content_height = locations_array.size() * row_height + locations_array.size() * spacing

	var max_scroll_height: int = int(map_container.size.y - 80)
	if max_scroll_height < 100:
		max_scroll_height = 400

	var scroll_height = min(content_height, max_scroll_height)
	var final_menu_height = base_height + scroll_height

	var min_width: float = 250
	var max_width: float = min(800, map_container.size.x - 40)

	var font = ThemeDB.fallback_font
	var font_size = custom_menu.get_theme_font_size("font_size")
	var max_text_width: float = 0

	var title_text = " " + marker.get("marker_name", "Locations")
	var title_width = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 50
	max_text_width = max(max_text_width, title_width)

	for loc_name in locations_array:
		var loc_width = font.get_string_size(loc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 100
		max_text_width = max(max_text_width, loc_width)

	var final_width = clamp(max_text_width, min_width, max_width)
	custom_menu.custom_minimum_size = Vector2(final_width, final_menu_height)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 4)
	menu_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_menu.add_child(menu_vbox)

	var main_node = _get_main_node()
	var marker_game = marker.get("game", "")

	var title_hbox = HBoxContainer.new()
	title_hbox.mouse_filter = Control.MOUSE_FILTER_STOP

	var marker_img_path = marker.get("image", "")
	if marker_img_path != "" and ResourceLoader.exists(marker_img_path):
		var marker_icon = TextureRect.new()
		marker_icon.texture = load(marker_img_path)
		marker_icon.custom_minimum_size = Vector2(24, 24)
		marker_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		title_hbox.add_child(marker_icon)

	var title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)

	menu_vbox.add_child(title_hbox)

	title_hbox.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_is_menu_dragging = true
				_menu_drag_start_pos = event.global_position
				_menu_drag_offset = custom_menu.global_position
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_is_menu_dragging = false
	)

	menu_vbox.add_child(HSeparator.new())

	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, scroll_height)
	menu_vbox.add_child(scroll_container)

	var locations_vbox = VBoxContainer.new()
	locations_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locations_vbox.add_theme_constant_override("separation", spacing)
	scroll_container.add_child(locations_vbox)

	var icon_checked = "res://images/checkbox_checked.png"
	var icon_unchecked = "res://images/checkbox_unchecked.png"
	var tex_checked = load(icon_checked) if ResourceLoader.exists(icon_checked) else null
	var tex_unchecked = load(icon_unchecked) if ResourceLoader.exists(icon_unchecked) else null

	for loc_name in locations_array:
		var world = 1
		var item_name = ""
		var is_checked = false

		var ckey = "%s|%s|%d" % [
			marker_game.strip_edges().to_upper(),
			loc_name.strip_edges().to_lower(),
			_current_world_filter
		]

		if _location_cache.has(ckey):
			var cdata = _location_cache[ckey]
			world = int(cdata.get("world", _current_world_filter))
			item_name = str(cdata.get("item", "")).strip_edges()
			is_checked = bool(cdata.get("checked", false))

		var loc_key = _loc_key(marker_game, loc_name)
		var wk = _world_key(loc_key, world)
		var is_reachable = true

		if _is_logic_active():
			if _loc_reach_cache.has(wk):
				is_reachable = bool(_loc_reach_cache[wk])
			else:
				is_reachable = LogicEvaluator.is_location_reachable(str(loc_name), world, marker_game)
				_set_loc_reachable(wk, loc_key, is_reachable)

		var row_btn = Button.new()
		row_btn.set_meta("loc_name", loc_name)
		row_btn.set_meta("marker_game", marker_game)
		row_btn.set_meta("world", world)
		row_btn.flat = true
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.custom_minimum_size = Vector2(0, row_height)
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_btn.add_child(HBoxContainer.new())

		var row_hbox = row_btn.get_child(0)

		var status_icon = TextureRect.new()
		if is_checked and tex_checked:
			status_icon.texture = tex_checked
		elif not is_checked and tex_unchecked:
			status_icon.texture = tex_unchecked

		status_icon.custom_minimum_size = Vector2(16, 16)
		status_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		row_hbox.add_child(status_icon)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(4, 0)
		row_hbox.add_child(spacer)

		if item_name != "" and item_name.to_lower() != "(unknown)" and main_node and main_node.has_method("get_item_texture"):
			var item_tex = main_node.get_item_texture(item_name)
			if item_tex:
				var item_icon = TextureRect.new()
				item_icon.texture = item_tex
				item_icon.custom_minimum_size = Vector2(20, 20)
				item_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
				item_icon.tooltip_text = item_name
				row_hbox.add_child(item_icon)

				spacer = Control.new()
				spacer.custom_minimum_size = Vector2(4, 0)
				row_hbox.add_child(spacer)

		var loc_label = Label.new()
		loc_label.text = loc_name
		loc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(loc_label)

		if is_checked:
			loc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		elif not is_reachable:
			loc_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			loc_label.remove_theme_color_override("font_color")

		row_btn.pressed.connect(func():
			var current_checked: bool = _is_location_checked(marker_game, loc_name)
			var new_state: bool = not current_checked

			if main_node and main_node.has_method("set_location_checked_by_name"):
				main_node.set_location_checked_by_name(
					marker_game,
					loc_name,
					world,
					new_state,
					true
				)

			_apply_single_location_change(marker_game, loc_name, world, new_state)

			if new_state and tex_checked:
				status_icon.texture = tex_checked
			elif not new_state and tex_unchecked:
				status_icon.texture = tex_unchecked

			var new_wk: String = _world_key(_loc_key(marker_game, loc_name), world)
			var new_reachable: bool = true

			if _loc_reach_cache.has(new_wk):
				new_reachable = bool(_loc_reach_cache[new_wk])

			if new_state:
				loc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			elif not new_reachable:
				loc_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				loc_label.remove_theme_color_override("font_color")

			request_counters_update()
		)

		locations_vbox.add_child(row_btn)

	add_child(custom_menu)
	_active_custom_menu = custom_menu

	await get_tree().process_frame

	var map_global_rect = map_container.get_global_rect()
	var menu_size = custom_menu.size
	var start_pos = map_global_rect.position

	start_pos.x = min(start_pos.x, max(map_global_rect.position.x, map_global_rect.end.x - menu_size.x))
	start_pos.y = min(start_pos.y, max(map_global_rect.position.y, map_global_rect.end.y - menu_size.y))

	custom_menu.global_position = start_pos
	custom_menu.z_index = 100

func _apply_single_location_change(game: String, loc_name: String, world: int, checked: bool) -> void:
	var loc_key: String = _loc_key(game, loc_name)
	var wk: String = _world_key(loc_key, world)

	var old_cat: int = _get_wk_category(wk)

	_update_location_cache_entry(game, loc_name, world, checked)

	var item_name: String = ""
	if _location_cache.has(wk):
		item_name = str(_location_cache[wk].get("item", "")).strip_edges()

	var affected_names: Array = [loc_name]
	if item_name != "" and item_name.to_lower() != "(unknown)":
		affected_names.append(item_name)

	LogicEvaluator.invalidate_item_cache(affected_names)

	if _is_logic_active():
		_loc_reach_stale = true
		_loc_reach_have_any = false
		_entrance_marker_state_cache.clear()
		_quick_jump_state_cache.clear()
	else:
		_loc_reach_cache.erase(wk)

	var new_cat: int = _get_wk_category(wk)
	_change_wk_category(wk, loc_key, old_cat, new_cat)

	_flush_pending_text_updates()
	_refresh_markers_for_loc_key(loc_key)

func _is_location_checked_in_world(marker_game: String, location_name: String, world: int) -> bool:
	var key = "%s|%s|%d" % [
		marker_game.strip_edges().to_upper(),
		location_name.strip_edges().to_lower(),
		world
	]

	if _location_cache.has(key):
		return bool(_location_cache[key].get("checked", false))

	return false

func _is_location_checked(marker_game: String, location_name: String) -> bool:
	return _is_location_checked_in_world(marker_game, location_name, _current_world_filter)

func _load_map_from_path(map_path: String) -> void:
	if map_path == "":
		return

	var new_texture = load(map_path)
	if new_texture:
		map_image.texture = new_texture
		_current_map_texture = new_texture
		_update_map_display()

func _on_subregion_selected(game: String, region: String, subregion: String, map_path: String) -> void:
	_markers_need_rebuild = true
	_entrance_markers_need_rebuild = true

	if info_label:
		info_label.text = "%s - %s - %s" % [game, region, subregion]

	_current_game = game
	_current_region = region
	_current_subregion = subregion

	_user_zoom = 1.0
	_map_offset = Vector2.ZERO

	_load_map_from_path(map_path)
	_update_markers()
	_ensure_subregion_button_centered(game, region, subregion)

func _ensure_subregion_button_centered(game: String, region: String, subregion: String) -> void:
	var g := game.strip_edges().to_upper()
	var r := region.strip_edges()
	var s := subregion.strip_edges()

	var sub_key := "%s|%s|%s" % [g, r, s]
	var btn := _subregion_btns.get(sub_key, null) as Button

	if btn == null:
		for k in _subregion_btns.keys():
			var meta: Dictionary = _sub_meta.get(k, {})
			if not meta.is_empty():
				var meta_game: String = meta.get("game", "")
				var meta_region_key: String = meta.get("region_key", "")
				if meta_game == g and meta_region_key == "%s|%s" % [g, r]:
					btn = _subregion_btns[k] as Button
					sub_key = str(k)
					break

	if btn == null or not is_instance_valid(btn):
		return

	var state_changed := false

	var game_btn := _game_btns.get(g, null) as Button
	if game_btn != null and is_instance_valid(game_btn):
		var game_container = game_btn.get_meta("container", null)
		if game_container is VBoxContainer and not game_container.visible:
			game_container.visible = true
			state_changed = true

	var region_key := "%s|%s" % [g, r]
	var region_btn := _region_btns.get(region_key, null) as Button
	if region_btn != null and is_instance_valid(region_btn):
		var region_container = region_btn.get_meta("container", null)
		if region_container is VBoxContainer and not region_container.visible:
			region_container.visible = true
			state_changed = true

	btn.visible = true

	if state_changed:
		_set_game_button(g)
		_set_region_button(region_key)

	call_deferred("_center_tree_button", btn)

func _center_tree_button(btn: Button) -> void:
	if not is_instance_valid(btn):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(btn):
		return

	var scroll := _find_scroll_container(location_tree)
	if scroll == null:
		return

	var btn_rect := btn.get_global_rect()
	var scroll_rect := scroll.get_global_rect()

	var target_y := btn_rect.position.y - scroll_rect.position.y + float(scroll.scroll_vertical)
	target_y -= (scroll_rect.size.y - btn_rect.size.y) * 0.5

	var content_height = max(location_tree.size.y, location_tree.get_combined_minimum_size().y)
	var max_y = max(0.0, content_height - scroll_rect.size.y)

	target_y = clamp(target_y, 0.0, max_y)
	scroll.scroll_vertical = int(target_y)

func _find_scroll_container(from: Control) -> ScrollContainer:
	var cur: Node = from

	while cur != null:
		var sc := cur as ScrollContainer
		if sc != null:
			return sc
		cur = cur.get_parent()

	return null

func _load_entrance_markers() -> void:
	const ENTRANCE_MARKERS_PATH = "res://data/entrance_markers.json"

	_entrance_markers.clear()
	_entrance_exit_map.clear()
	_entrance_to_region_map.clear()
	_exit_to_region_map.clear()

	var data = _load_json_file(ENTRANCE_MARKERS_PATH)
	if not (data is Array):
		return

	for row in data:
		if not (row is Dictionary):
			continue

		var clean_row = {}
		for k in row:
			var clean_key = str(k).strip_edges()
			var v = row[k]

			if v is String:
				clean_row[clean_key] = str(v).strip_edges()
			elif v is Array:
				var arr = []
				for item in v:
					arr.append(str(item).strip_edges())
				clean_row[clean_key] = arr
			else:
				clean_row[clean_key] = v

		_entrance_markers.append(clean_row)

		var game = clean_row.get("game", "").strip_edges()
		var region = clean_row.get("region", "").strip_edges()
		var subregion = clean_row.get("subregion", "").strip_edges()
		var image = clean_row.get("image", "").strip_edges()

		var entrances = clean_row.get("entrance", [])
		if entrances is Array:
			for ent_code in entrances:
				var clean_ent = str(ent_code).strip_edges()
				if clean_ent != "":
					if not _entrance_to_region_map.has(clean_ent):
						_entrance_to_region_map[clean_ent] = []
					_entrance_to_region_map[clean_ent].append({
						"game": game,
						"region": region,
						"subregion": subregion,
						"image": image
					})

		var exits = clean_row.get("exit", [])
		if exits is Array:
			for ex_code in exits:
				var clean_ex = str(ex_code).strip_edges()
				if clean_ex != "":
					if not _exit_to_region_map.has(clean_ex):
						_exit_to_region_map[clean_ex] = []
					_exit_to_region_map[clean_ex].append({
						"game": game,
						"region": region,
						"subregion": subregion,
						"image": image
					})

					var display_name = subregion
					if region != "" and region != subregion:
						display_name = region + " - " + subregion

					if not _entrance_exit_map.has(clean_ex):
						_entrance_exit_map[clean_ex] = {
							"name": display_name,
							"image": image
						}

	_build_jp_marker_cache()

func _on_entrance_marker_clicked(marker: Dictionary) -> void:
	if _active_custom_menu and is_instance_valid(_active_custom_menu):
		_active_custom_menu.queue_free()
		_active_custom_menu = null

	var main_node = _get_main_node()
	var ent_shuffle = {}

	if main_node and main_node.has_method("get_entrance_shuffle"):
		ent_shuffle = main_node.get_entrance_shuffle()

	var world_ent = ent_shuffle.get(_current_world_filter, {})

	var raw_entrances = marker.get("entrance", [])
	var shuffled_entrances = []

	for code in raw_entrances:
		var c = _remap_lost_woods_exit(str(code).strip_edges())
		if c != "":
			shuffled_entrances.append(world_ent.get(c, c))

	var leads_to_results = []
	var seen_leads: Dictionary = {}

	for ent_code in shuffled_entrances:
		if _entrance_dest_info.has(ent_code):
			var dest_array = _entrance_dest_info[ent_code]
			var items = dest_array if dest_array is Array else [dest_array]

			for info in items:
				var dedup_key = "%s|%s|%s" % [
					info.get("game", ""),
					info.get("region", ""),
					info.get("name", "")
				]

				if seen_leads.has(dedup_key):
					continue

				seen_leads[dedup_key] = true

				leads_to_results.append({
					"game": info.get("game", ""),
					"region": info.get("region", ""),
					"subregion": info.get("name", ""),
					"image": info.get("image", ""),
					"code": ent_code
				})

	var raw_exits = marker.get("exit", [])
	var exit_codes = []

	for code in raw_exits:
		var c = str(code).strip_edges()
		if c != "":
			exit_codes.append(c)

	var comes_from_results = []
	var seen_comes_from: Dictionary = {}

	for other_marker in _entrance_markers:
		var other_entrances = other_marker.get("entrance", [])

		for code in other_entrances:
			var c = _remap_lost_woods_exit(str(code).strip_edges())
			if c == "":
				continue

			var shuffled_code = world_ent.get(c, c)

			if shuffled_code in exit_codes:
				var game = other_marker.get("game", "").strip_edges()
				var region = other_marker.get("region", "").strip_edges()
				var subregion = other_marker.get("subregion", "").strip_edges()

				var dedup_key = "%s|%s|%s" % [game, region, subregion]
				if seen_comes_from.has(dedup_key):
					continue

				seen_comes_from[dedup_key] = true

				var result = {
					"game": game,
					"region": region,
					"subregion": subregion,
					"code": shuffled_code
				}

				if _entrance_dest_info.has(shuffled_code):
					var dest_array = _entrance_dest_info[shuffled_code]
					if dest_array is Array and not dest_array.is_empty():
						result["image"] = dest_array[0].get("image", "")
					elif dest_array is Dictionary:
						result["image"] = dest_array.get("image", "")

				comes_from_results.append(result)

	if leads_to_results.is_empty() and comes_from_results.is_empty():
		return

	var custom_menu = PanelContainer.new()
	custom_menu.name = "CustomEntranceMenu"

	var row_height: int = 32
	var spacing: int = 4
	var total_rows = leads_to_results.size() + comes_from_results.size()
	var content_height = total_rows * row_height + total_rows * spacing + 60 if total_rows > 0 else 0

	var max_scroll_height: int = int(map_container.size.y - 80)
	if max_scroll_height < 100:
		max_scroll_height = 400

	var scroll_height = min(content_height, max_scroll_height)
	var final_menu_height = 50 + scroll_height

	var min_width: float = 250
	var max_width: float = min(800, map_container.size.x - 40)

	var font = ThemeDB.fallback_font
	var font_size = custom_menu.get_theme_font_size("font_size")
	var max_text_width: float = 0

	var title_text = "  " + marker.get("marker_name", "Entrances")
	max_text_width = max(
		max_text_width,
		font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 50
	)

	for info in leads_to_results + comes_from_results:
		var display_name = info.get("subregion", "")
		var region = info.get("region", "")

		if display_name == "":
			display_name = region
		elif region != "" and region != display_name:
			display_name = region + " - " + display_name

		max_text_width = max(
			max_text_width,
			font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 100
		)

	max_text_width = max(
		max_text_width,
		font.get_string_size("Leads to:", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 50
	)
	max_text_width = max(
		max_text_width,
		font.get_string_size("Comes from:", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 50
	)

	custom_menu.custom_minimum_size = Vector2(
		clamp(max_text_width, min_width, max_width),
		final_menu_height
	)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", spacing)
	menu_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_menu.add_child(menu_vbox)

	var title_hbox = HBoxContainer.new()
	title_hbox.mouse_filter = Control.MOUSE_FILTER_STOP

	var marker_img_path = marker.get("image", "")
	if marker_img_path != "" and ResourceLoader.exists(marker_img_path):
		var marker_icon = TextureRect.new()
		marker_icon.texture = load(marker_img_path)
		marker_icon.custom_minimum_size = Vector2(24, 24)
		marker_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		title_hbox.add_child(marker_icon)

	var title_label = Label.new()
	title_label.text = marker.get("marker_name", "Entrances")
	title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)

	menu_vbox.add_child(title_hbox)

	title_hbox.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_is_menu_dragging = true
				_menu_drag_start_pos = event.global_position
				_menu_drag_offset = custom_menu.global_position
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_is_menu_dragging = false
	)

	menu_vbox.add_child(HSeparator.new())

	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, scroll_height)
	menu_vbox.add_child(scroll_container)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", spacing)
	scroll_container.add_child(main_vbox)

	if not leads_to_results.is_empty():
		var ent_label = Label.new()
		ent_label.text = "Leads to:"
		ent_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		main_vbox.add_child(ent_label)

		var ent_vbox = VBoxContainer.new()
		ent_vbox.add_theme_constant_override("separation", spacing)
		main_vbox.add_child(ent_vbox)

		for info in leads_to_results:
			_navigate_row_button(ent_vbox, info)

	if not comes_from_results.is_empty():
		var ext_label = Label.new()
		ext_label.text = "Comes from:"
		ext_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		main_vbox.add_child(ext_label)

		var ext_vbox = VBoxContainer.new()
		ext_vbox.add_theme_constant_override("separation", spacing)
		main_vbox.add_child(ext_vbox)

		for info in comes_from_results:
			_navigate_row_button(ext_vbox, info)

	add_child(custom_menu)
	_active_custom_menu = custom_menu

	await get_tree().process_frame

	var map_global_rect = map_container.get_global_rect()
	var menu_size = custom_menu.size
	var start_pos = map_global_rect.position

	start_pos.x = min(start_pos.x, max(map_global_rect.position.x, map_global_rect.end.x - menu_size.x))
	start_pos.y = min(start_pos.y, max(map_global_rect.position.y, map_global_rect.end.y - menu_size.y))

	custom_menu.global_position = start_pos
	custom_menu.z_index = 101

func _navigate_row_button(parent: VBoxContainer, info: Dictionary) -> void:
	var row_btn = Button.new()
	row_btn.flat = true
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.custom_minimum_size = Vector2(0, 32)
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_hbox = HBoxContainer.new()
	row_btn.add_child(row_hbox)

	var icon_path = info.get("image", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var dest_icon = TextureRect.new()
		dest_icon.texture = load(icon_path)
		dest_icon.custom_minimum_size = Vector2(20, 20)
		dest_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		row_hbox.add_child(dest_icon)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(4, 0)
		row_hbox.add_child(spacer)

	var display_name = info.get("subregion", "")
	var region = info.get("region", "")

	if display_name == "":
		display_name = region
	elif region != "" and region != display_name:
		display_name = region + " - " + display_name

	var dest_label = Label.new()
	dest_label.text = display_name
	dest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_hbox.add_child(dest_label)

	var captured_info = info
	row_btn.pressed.connect(func():
		_navigate_to_marker_region(captured_info)
	)

	parent.add_child(row_btn)

func _load_entrances_data() -> void:
	const ENTRANCES_PATH = "res://data/entrances.json"

	_entrance_dest_info.clear()

	var data = _load_json_file(ENTRANCES_PATH)
	if not (data is Array):
		return

	for row in data:
		if not (row is Array) or row.size() < 5:
			continue

		var game_name = str(row[0]).strip_edges()
		var region_name = str(row[1]).strip_edges()
		var subregion_name = str(row[2]).strip_edges()
		var codes = row[3]
		var image_path = str(row[4]).strip_edges()

		if codes is Array:
			for code in codes:
				var clean_code = str(code).strip_edges()
				if clean_code == "":
					continue

				var entry = {
					"game": game_name,
					"region": region_name,
					"name": subregion_name,
					"image": image_path
				}

				if not _entrance_dest_info.has(clean_code):
					_entrance_dest_info[clean_code] = []

				var already = false
				for existing in _entrance_dest_info[clean_code]:
					if existing["game"] == entry["game"] and \
					   existing["region"] == entry["region"] and \
					   existing["name"] == entry["name"]:
						already = true
						break

				if not already:
					_entrance_dest_info[clean_code].append(entry)

func _is_jp_marker(marker: Dictionary) -> bool:
	return str(marker.get("overlay_image", "")).strip_edges() == "res://images/marks_cond/jp_layout.png"

func _is_jp_enabled(jp_key: String) -> bool:
	if _jp_layouts is Array:
		return jp_key in _jp_layouts

	if _jp_layouts is Dictionary:
		for key in [_current_world_filter, str(_current_world_filter)]:
			if _jp_layouts.has(key):
				var world_jp = _jp_layouts[key]
				if world_jp is Array:
					return jp_key in world_jp

	return false

func _should_show_marker(marker: Dictionary, _all_markers: Array) -> bool:
	var game = str(marker.get("game", "")).strip_edges()
	var region = str(marker.get("region", "")).strip_edges()
	var subregion = str(marker.get("subregion", "")).strip_edges()
	var marker_name = str(marker.get("marker_name", "")).strip_edges()

	if not _should_show_subregion(game, region, subregion):
		return false

	var jp_key = _region_to_jp_key(region)
	if jp_key == "":
		return true

	var jp_enabled = _is_jp_enabled(jp_key)
	var is_entrance: bool = marker.has("entrance") or marker.has("exit")
	var is_jp: bool = _is_jp_marker(marker) or (is_entrance and _name_has_jp_suffix(marker_name))

	if is_jp:
		return jp_enabled

	if jp_enabled:
		if _has_jp_version_cached(region, marker_name):
			return false
		if is_entrance and _has_jp_entrance_pair(region, marker_name):
			return false

	return true

func _is_game_allowed(game: String) -> bool:
	var g = game.strip_edges().to_upper()

	if _current_games_setting == "oot":
		return g == "OOT"

	if _current_games_setting == "mm":
		return g == "MM"

	return true

func _should_show_subregion(_game: String, region: String, subregion: String) -> bool:
	var jp_key = _region_to_jp_key(region)
	if jp_key == "":
		return true
	if subregion.begins_with("JP "):
		return _is_jp_enabled(jp_key)
	return true

func _region_to_jp_key(region: String) -> String:
	var mapping = {
		"Deku Palace": "DekuPalace",
		"Stone Tower": "StoneTower",
		"Stone Tower Temple": "ST",
		"Great Bay Coast": "GreatBayCoast"
	}

	return mapping.get(region.strip_edges(), "")

func _should_show_quick_jump_button(code: String) -> bool:
	if not code.begins_with("OOT_WALLMASTER_"):
		return true

	var mq = _mq_dungeons_cache
	var is_mq_shadow = "Shadow" in mq
	var is_mq_spirit = "Spirit" in mq
	var is_mq_botw = "BotW" in mq
	var is_mq_ganon = "Ganon" in mq

	match code:
		"OOT_WALLMASTER_SHADOW":
			return not is_mq_shadow
		"OOT_WALLMASTER_SPIRIT_CHILD_RUPEES":
			return not is_mq_spirit
		"OOT_WALLMASTER_GANON_LIGHT":
			return not is_mq_ganon
		"OOT_WALLMASTER_SPIRIT_CHILD_SUN", "OOT_WALLMASTER_SPIRIT_STATUE":
			return is_mq_spirit
		"OOT_WALLMASTER_BOTW_BASEMENT", "OOT_WALLMASTER_BOTW_PIT":
			return is_mq_botw
		_:
			return true

func _build_quick_jump_buttons() -> void:
	for btn in _quick_jump_buttons:
		if is_instance_valid(btn):
			btn.queue_free()

	_quick_jump_buttons.clear()

	for row in _quick_jump_rows:
		if is_instance_valid(row):
			row.queue_free()

	_quick_jump_rows.clear()

	if not _has_entrance_data:
		if _quick_jump_container:
			_quick_jump_container.visible = false
		return

	if not _quick_jump_container:
		_quick_jump_container = VBoxContainer.new()
		_quick_jump_container.name = "QuickJumpContainer"
		_quick_jump_container.add_theme_constant_override("separation", 2)
		_quick_jump_container.z_index = 50
		_quick_jump_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_container.add_child(_quick_jump_container)

	_quick_jump_container.visible = _quick_jump_visible

	var rows_data = [QUICK_JUMP_ROW_1, QUICK_JUMP_ROW_2]
	var row_games = ["OoT", "MM"]

	for row_index in rows_data.size():
		var row_data = rows_data[row_index]

		if not _is_game_allowed(row_games[row_index]):
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		for spawn_data in row_data:
			var code = spawn_data.get("code", "")
			if not _should_show_quick_jump_button(code):
				continue

			LogicEvaluator.register_quick_jump_code(spawn_data["name"], code)

			var panel = PanelContainer.new()
			panel.custom_minimum_size = Vector2(40, 40)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0.6)
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			panel.add_theme_stylebox_override("panel", style)

			var icon = TextureRect.new()
			var icon_path = spawn_data.get("icon", "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)

			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
			panel.add_child(icon)

			var btn = Button.new()
			btn.flat = true
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.tooltip_text = spawn_data["name"]
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.pressed.connect(func():
				_on_quick_jump_clicked(spawn_data)
			)
			panel.add_child(btn)

			panel.set_meta("qj_name", spawn_data.get("name", ""))
			panel.visible = true

			row.add_child(panel)
			_quick_jump_buttons.append(panel)

		_quick_jump_container.add_child(row)
		_quick_jump_rows.append(row)

func _on_quick_jump_clicked(spawn_data: Dictionary, _btn_pos: Vector2 = Vector2.ZERO) -> void:
	if _active_custom_menu and is_instance_valid(_active_custom_menu):
		_active_custom_menu.queue_free()
		_active_custom_menu = null

	var main_node = _get_main_node()
	var ent_shuffle = {}

	if main_node and main_node.has_method("get_entrance_shuffle"):
		ent_shuffle = main_node.get_entrance_shuffle()

	var world_ent = ent_shuffle.get(_current_world_filter, {})
	var spawn_code = _remap_lost_woods_exit(spawn_data["code"])
	var dest_code = world_ent.get(spawn_code, spawn_code)

	var results = []
	var seen: Dictionary = {}

	if _entrance_dest_info.has(dest_code):
		var dest_array = _entrance_dest_info[dest_code]
		var items = dest_array if dest_array is Array else [dest_array]

		for info in items:
			var dedup_key = "%s|%s|%s" % [
				info.get("game", ""),
				info.get("region", ""),
				info.get("name", "")
			]

			if seen.has(dedup_key):
				continue

			seen[dedup_key] = true

			results.append({
				"game": info.get("game", ""),
				"region": info.get("region", ""),
				"subregion": info.get("name", ""),
				"image": info.get("image", ""),
				"code": dest_code
			})

	if results.is_empty():
		return

	var custom_menu = PanelContainer.new()
	custom_menu.name = "QuickJumpMenu"

	var row_height: int = 32
	var spacing: int = 4
	var content_height = results.size() * row_height + results.size() * spacing + 60

	var max_scroll_height: int = int(map_container.size.y - 80)
	if max_scroll_height < 100:
		max_scroll_height = 400

	var scroll_height = min(content_height, max_scroll_height)
	var final_menu_height = 50 + scroll_height

	var min_width: float = 250
	var max_width: float = min(800, map_container.size.x - 40)

	var font = ThemeDB.fallback_font
	var font_size = custom_menu.get_theme_font_size("font_size")

	var max_text_width = font.get_string_size(
		"  " + spawn_data["name"],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x + 50

	for info in results:
		var display_name = info.get("subregion", "")
		var region = info.get("region", "")

		if display_name == "":
			display_name = region
		elif region != "" and region != display_name:
			display_name = region + " - " + display_name

		max_text_width = max(
			max_text_width,
			font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 100
		)

	custom_menu.custom_minimum_size = Vector2(
		clamp(max_text_width, min_width, max_width),
		final_menu_height
	)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", spacing)
	menu_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_menu.add_child(menu_vbox)

	var title_hbox = HBoxContainer.new()
	title_hbox.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon_path = spawn_data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var title_icon = TextureRect.new()
		title_icon.texture = load(icon_path)
		title_icon.custom_minimum_size = Vector2(24, 24)
		title_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		title_hbox.add_child(title_icon)

	var title_label = Label.new()
	title_label.text = spawn_data["name"]
	title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)

	menu_vbox.add_child(title_hbox)

	title_hbox.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_is_menu_dragging = true
				_menu_drag_start_pos = event.global_position
				_menu_drag_offset = custom_menu.global_position
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_is_menu_dragging = false
	)

	menu_vbox.add_child(HSeparator.new())

	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, scroll_height)
	menu_vbox.add_child(scroll_container)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", spacing)
	scroll_container.add_child(main_vbox)

	var ent_label = Label.new()
	ent_label.text = "Leads to:"
	ent_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	main_vbox.add_child(ent_label)

	var ent_vbox = VBoxContainer.new()
	ent_vbox.add_theme_constant_override("separation", spacing)
	main_vbox.add_child(ent_vbox)

	for info in results:
		_navigate_row_button(ent_vbox, info)

	add_child(custom_menu)
	_active_custom_menu = custom_menu

	await get_tree().process_frame

	var menu_size = custom_menu.size
	var map_global_rect = map_container.get_global_rect()
	var start_pos = map_global_rect.position

	start_pos.x = min(start_pos.x, max(map_global_rect.position.x, map_global_rect.end.x - menu_size.x))
	start_pos.y = min(start_pos.y, max(map_global_rect.position.y, map_global_rect.end.y - menu_size.y))

	custom_menu.global_position = start_pos
	custom_menu.z_index = 101

func _navigate_to_marker_region(info: Dictionary) -> void:
	var dest_game = str(info.get("game", "")).strip_edges()
	var dest_region = str(info.get("region", "")).strip_edges()
	var dest_subregion = str(info.get("subregion", "")).strip_edges()

	var map_key = "%s|%s|%s" % [dest_game, dest_region, dest_subregion]
	var map_path = _region_map_by_key.get(map_key, "")

	if map_path == "":
		return

	if _active_custom_menu and is_instance_valid(_active_custom_menu):
		_active_custom_menu.queue_free()
		_active_custom_menu = null

	_on_subregion_selected(dest_game, dest_region, dest_subregion, map_path)

func _get_alter_lost_woods_exits() -> bool:
	var main_node = _get_main_node()
	if main_node and main_node.has_method("get_current_settings"):
		var settings = main_node.get_current_settings()
		if settings is Dictionary:
			return settings.get("alterLostWoodsExits", false)
	return false

func _remap_lost_woods_exit(code: String) -> String:
	if not _get_alter_lost_woods_exits():
		if code in LOST_WOODS_ALTERED_EXITS:
			return LOST_WOODS_MAIN_EXIT
	return code

func switch_map_by_entrance(entrance_code: String) -> void:
	if entrance_code.is_empty() or entrance_code == "UNKNOWN":
		return

	entrance_code = _remap_lost_woods_exit(entrance_code)

	var dest_info: Dictionary = {}

	if _entrance_dest_info.has(entrance_code):
		var dest_array = _entrance_dest_info[entrance_code]
		if dest_array is Array and not dest_array.is_empty():
			dest_info = dest_array[0]
		elif dest_array is Dictionary:
			dest_info = dest_array
	elif _entrance_to_region_map.has(entrance_code):
		var region_info = _entrance_to_region_map[entrance_code]
		if region_info is Array and not region_info.is_empty():
			dest_info = region_info[0]
			if dest_info.has("subregion") and not dest_info.has("name"):
				dest_info["name"] = dest_info["subregion"]
		elif region_info is Dictionary:
			dest_info = region_info
			if dest_info.has("subregion") and not dest_info.has("name"):
				dest_info["name"] = dest_info["subregion"]

	if dest_info.is_empty():
		return

	var dest_game = str(dest_info.get("game", "")).strip_edges()
	var dest_region = str(dest_info.get("region", "")).strip_edges()
	var dest_subregion = str(dest_info.get("name", "")).strip_edges()

	if dest_game.is_empty() or dest_region.is_empty() or dest_subregion.is_empty():
		return

	var map_key = "%s|%s|%s" % [dest_game, dest_region, dest_subregion]
	var map_path = _region_map_by_key.get(map_key, "")

	if map_path != "":
		_on_subregion_selected(dest_game, dest_region, dest_subregion, map_path)

func _update_active_location_menu() -> void:
	if not is_instance_valid(_active_custom_menu):
		return

	if _active_custom_menu.name != "CustomLocationMenu":
		return

	var menu_vbox = _active_custom_menu.get_child(0)
	if not menu_vbox:
		return

	var scroll_container = null
	for child in menu_vbox.get_children():
		if child is ScrollContainer:
			scroll_container = child
			break

	if not scroll_container or scroll_container.get_child_count() == 0:
		return

	var locations_vbox = scroll_container.get_child(0)
	if not locations_vbox:
		return

	var icon_checked = "res://images/checkbox_checked.png"
	var icon_unchecked = "res://images/checkbox_unchecked.png"
	var tex_checked = load(icon_checked) if ResourceLoader.exists(icon_checked) else null
	var tex_unchecked = load(icon_unchecked) if ResourceLoader.exists(icon_unchecked) else null

	for row_btn in locations_vbox.get_children():
		if not is_instance_valid(row_btn) or not row_btn is Button:
			continue

		var loc_name = row_btn.get_meta("loc_name", "")
		var marker_game = row_btn.get_meta("marker_game", "")
		var world = row_btn.get_meta("world", 1)

		if loc_name == "":
			continue

		var is_checked = _is_location_checked_in_world(marker_game, loc_name, world)
		var loc_key = _loc_key(marker_game, loc_name)
		var wk = _world_key(loc_key, world)

		var is_reachable = true

		if _is_logic_active():
			if _loc_reach_cache.has(wk):
				is_reachable = bool(_loc_reach_cache[wk])
			else:
				is_reachable = LogicEvaluator.is_location_reachable(str(loc_name), world, marker_game)
				_set_loc_reachable(wk, loc_key, is_reachable)

		var row_hbox = row_btn.get_child(0)
		if not row_hbox:
			continue

		var status_icon = row_hbox.get_child(0)
		if status_icon is TextureRect:
			if is_checked and tex_checked:
				status_icon.texture = tex_checked
			elif not is_checked and tex_unchecked:
				status_icon.texture = tex_unchecked

		var loc_label = null
		for c in row_hbox.get_children():
			if c is Label:
				loc_label = c
				break

		if loc_label:
			if is_checked:
				loc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			elif not is_reachable:
				loc_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				loc_label.remove_theme_color_override("font_color")

func _on_quick_jump_button_pressed() -> void:
	if not _quick_jump_container:
		return

	_quick_jump_visible = not _quick_jump_visible
	_quick_jump_container.visible = _quick_jump_visible

	if _quick_jump_visible:
		quick_jump_button.text = "Hide Quick Jump"
	else:
		quick_jump_button.text = "Show Quick Jump"

func _check_current_subregion_valid() -> void:
	if _current_region == "" or _current_subregion == "":
		return

	if not _should_show_subregion("OoT", _current_region, _current_subregion) and \
	   not _should_show_subregion("MM", _current_region, _current_subregion):
		for marker in _markers:
			if str(marker.get("region", "")).strip_edges() == _current_region:
				var subregion = str(marker.get("subregion", "")).strip_edges()
				if _should_show_subregion(str(marker.get("game", "")), _current_region, subregion):
					var map_key = "%s|%s|%s" % [marker.get("game", ""), _current_region, subregion]
					var map_path = _region_map_by_key.get(map_key, "")
					if map_path != "":
						_on_subregion_selected(str(marker.get("game", "")), _current_region, subregion, map_path)
						return

func _name_has_jp_suffix(marker_name: String) -> bool:
	var n := marker_name.strip_edges()
	return n.contains("(JP-Layout)") or n.contains("(JP Layout)") or n.ends_with("(JP)")

func _strip_jp_suffix(marker_name: String) -> String:
	var n := marker_name.strip_edges()
	for suffix in [" (JP-Layout)", " (JP Layout)", " (JP)"]:
		if n.ends_with(suffix):
			return n.substr(0, n.length() - suffix.length())
	return n

func _has_jp_entrance_pair(region: String, marker_name: String) -> bool:
	return _jp_entrance_base_names.has("%s|%s" % [region.strip_edges(), marker_name.strip_edges()])
