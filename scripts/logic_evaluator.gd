extends Node

const _SONG_NAMES: Array = [
	"zelda_lullaby", "epona_song", "saria_song", "sun_song",
	"song_of_time", "song_of_storms", "minuet_of_forest", "bolero_of_fire",
	"serenade_of_water", "requiem_of_spirit", "nocturne_of_shadow", "prelude_of_light",
	"song_of_healing", "song_of_soaring", "sonata_of_awakening", "goron_lullaby_intro",
	"goron_lullaby_full", "new_wave_bossa_nova", "elegy_of_emptiness", "oath_to_order"
]

static func _make_song_dict(suffix: String) -> Dictionary:
	var d: Dictionary = {}
	for n in _SONG_NAMES:
		d["can_play_%s_%s" % [n, suffix]] = true
	return d

static func _make_song_arr(suffix: String) -> Array:
	var a: Array = []
	for n in _SONG_NAMES:
		a.append("can_play_%s_%s" % [n, suffix])
	return a

const SONG_MACROS_OOT: Dictionary = {}
const SONG_MACROS_MM: Dictionary = {}
const SONG_MACROS_OOT_ARR: Array = []
const SONG_MACROS_MM_ARR: Array = []

static func _init_song_consts() -> void:
	pass

const OOT_SONG_EVENTS_SET: Dictionary = {
	"SONG_EVENT_TEMPLE_OF_TIME": true, "SONG_EVENT_WINDMILL": true, "SONG_EVENT_GRAVEYARD": true,
	"SONG_EVENT_GORON_CITY": true, "SONG_EVENT_ZORA_RIVER": true, "SONG_EVENT_GREAT_FAIRY_SPELL_FIRE": true,
	"SONG_EVENT_GREAT_FAIRY_SPELL_WIND": true, "SONG_EVENT_GREAT_FAIRY_SPELL_LOVE": true, "SONG_EVENT_GREAT_FAIRY_UPGRADE_MAGIC": true,
	"SONG_EVENT_GREAT_FAIRY_UPGRADE_MAGIC2": true, "SONG_EVENT_GREAT_FAIRY_UPGRADE_DEFENSE": true, "SONG_EVENT_TEMPLE_WATER": true,
	"SONG_EVENT_TEMPLE_SHADOW": true, "SONG_EVENT_TEMPLE_SPIRIT_STATUE": true, "SONG_EVENT_TEMPLE_SPIRIT_LOWER": true,
	"SONG_EVENT_TEMPLE_SPIRIT_HIGHER": true, "SONG_EVENT_TEMPLE_BOTW": true, "SONG_EVENT_TEMPLE_GANON": true
}
const MM_SONG_EVENTS_SET: Dictionary = {
	"SONG_EVENT_TEMPLE_WOODFALL": true, "SONG_EVENT_TEMPLE_SNOWHEAD": true, "SONG_EVENT_TEMPLE_GREATBAY": true,
	"SONG_EVENT_HEALING_KAMARO": true, "SONG_EVENT_AWAKENING_SCRUB": true, "SONG_EVENT_HEALING_DARMANI": true,
	"SONG_EVENT_LULLABY_KID": true, "SONG_EVENT_HEALING_MIKAU": true, "SONG_EVENT_AWAKENING_KEETA": true,
	"SONG_EVENT_HEALING_POEHUT": true, "SONG_EVENT_HEALING_PAMELA_FATHER": true, "SONG_EVENT_STORMS_COMPOSER": true,
	"SONG_EVENT_CLOCK_TOWER_ROOF": true
}
const BOSS_KILL_MACROS: Dictionary = {
	"OOT_BOSS_DEKU_TREE": "can_kill_queen_gohma_oot",
	"OOT_BOSS_DODONGO_CAVERN": "can_kill_king_dodongo_oot",
	"OOT_BOSS_JABU_JABU": "can_kill_barinade_oot",
	"OOT_BOSS_TEMPLE_FOREST": "can_kill_phantom_ganon_oot",
	"OOT_BOSS_TEMPLE_FIRE": "can_kill_volvagia_oot",
	"OOT_BOSS_TEMPLE_WATER": "can_kill_morpha_oot",
	"OOT_BOSS_TEMPLE_SHADOW": "can_kill_bongo_bongo_oot",
	"OOT_BOSS_TEMPLE_SPIRIT": "can_kill_twinrova_oot",
	"MM_BOSS_TEMPLE_WOODFALL": "can_kill_odolwa_mm",
	"MM_BOSS_TEMPLE_SNOWHEAD": "can_kill_goht_mm",
	"MM_BOSS_TEMPLE_GREAT_BAY": "can_kill_gyorg_mm",
	"MM_BOSS_TEMPLE_STONE_TOWER": "can_kill_twinmold_mm",
}
const OOT_TIME_FLOW_FULL_SUBREGIONS: Array = [
	["OoT", "Hyrule Field", "Hyrule Field"],
	["OoT", "Hyrule/Ganon Castle", "Hyrule Castle"],
	["OoT", "Death Mountain Trail", "Death Mountain Trail - Bottom"],
	["OoT", "Death Mountain Trail", "Death Mountain Trail - Middle"],
	["OoT", "Death Mountain Trail", "Death Mountain Trail - Top"],
	["OoT", "Zora's River", "Zora's River"],
	["OoT", "Lake Hylia", "Lake Hylia"],
	["OoT", "Lake Hylia", "Fishing Pond"],
	["OoT", "Gerudo Valley", "Gerudo Valley"],
	["OoT", "Desert Colossus", "Desert Colossus"]
]
const REACH_CONDITION_KEYS: Array = [
	"entrance", "entrance_prefix", "boss", "game",
	"time_flow_oot", "song_event", "bottle_group", "bottle_content",
	"mask_group", "special_condition"
]
const BLUR_AGE_CONTROL_NAMES: Array = ["can_time_travel_song_of_time"]
const BLUR_NONE: int = 0
const BLUR_DIRECT: int = 1
const BLUR_FULL: int = 2

const MAX_FIXED_POINT_PASSES: int = 200
const MAX_REACH_ITERATIONS: int = 200000
const MAX_TIME_FLOW_CACHE: int = 2000

var _song_macros_oot: Dictionary = {}
var _song_macros_mm: Dictionary = {}
var _song_macros_oot_arr: Array = []
var _song_macros_mm_arr: Array = []

var _loc_rules: Dictionary = {}
var _ent_rules: Dictionary = {}
var _qj_rules: Dictionary = {}
var _qj_code_by_name: Dictionary = {}
var _entrance_markers_cache: Array = []
var _marker_overlays: Dictionary = {}
var _location_to_marker: Dictionary = {}
var _tracker_cache: Node = null
var _main_scene_cache: Node = null
var _age_context_cache: Dictionary = {}
var _rc_codes_by_world: Dictionary = {}
var _rc_games_by_world: Dictionary = {}
var _rc_markers_by_world: Dictionary = {}
var _rc_regions_by_world: Dictionary = {}
var _why_code_by_world: Dictionary = {}
var _why_marker_by_world: Dictionary = {}
var _why_region_by_world: Dictionary = {}
var _rc_codes_by_world_stale: Dictionary = {}
var _rc_games_by_world_stale: Dictionary = {}
var _rc_markers_by_world_stale: Dictionary = {}
var _rc_regions_by_world_stale: Dictionary = {}
var _code_consumers: Dictionary = {}
var _marker_reqs: Dictionary = {}
var _marker_entr_codes: Dictionary = {}
var _region_dependents: Dictionary = {}
var _region_incoming: Dictionary = {}
var _code_producers: Dictionary = {}
var _region_producers: Dictionary = {}
var _marker_blocked: Dictionary = {}
var _root_codes: Dictionary = {}
var _graph_built_worlds: Dictionary = {}
var _graph_by_world: Dictionary = {}
var _active_graph_world: int = -1
var _generation: int = 1
var _cached_generation: Dictionary = {}
var _reach_changed: Dictionary = {}
var _macros_normalized: Dictionary = {}
var _macros_normalized_built: bool = false
var _macro_cache: Dictionary = {}
var _macro_keys_by_name: Dictionary = {}
var _macro_in_progress: Dictionary = {}
var _validating: Dictionary = {}
var _primitive_versions: Dictionary = {}
var _primitive_macro_keys: Dictionary = {}
var _version_counter: int = 1
var _location_cache: Dictionary = {}
var _marker_cache: Dictionary = {}
var _macro_reach_dep: Dictionary = {}
var _reach_dep_built: bool = false
var _item_to_macros: Dictionary = {}
var _setting_to_macros: Dictionary = {}
var _macro_to_parents: Dictionary = {}
var _deps_built: bool = false
var _macro_to_locations: Dictionary = {}
var _macro_to_markers: Dictionary = {}
var _reach_settings: Dictionary = {}
var _reach_items: Dictionary = {}
var _settings_cache: Dictionary = {}
var _resolve_code_cache: Dictionary = {}
var _entrances_meta: Array = []
var _code_to_oot_full_subregion: Dictionary = {}
var _oot_time_flow_full_set: Dictionary = {}
var _time_flow_oot_cache: Dictionary = {}
var _building_reach: bool = false
var _internal_reach_eval: bool = false
var _suppress_compute_depth: int = 0
var _batch_depth: int = 0
var _pending_clear: bool = false
var _pending_invalidate: bool = false
var _pending_drop: bool = false
var _dirty_location_names: Dictionary = {}
var _dirty_marker_names: Dictionary = {}
var _pending_reach_callbacks: Dictionary = {}
var _reach_compute_in_progress: Dictionary = {}

var _blur_cache: Dictionary = {}

func _ready() -> void:
	_song_macros_oot = _make_song_dict("oot")
	_song_macros_mm = _make_song_dict("mm")
	_song_macros_oot_arr = _make_song_arr("oot")
	_song_macros_mm_arr = _make_song_arr("mm")

	_loc_rules = _read_json("res://data/access_rules_locations.json")
	_ent_rules = _read_json("res://data/access_rules_entrances.json")
	_qj_rules = _read_json("res://data/access_rules_quickjump.json")
	_entrance_markers_cache = _read_json_array("res://data/entrance_markers.json")
	_load_marker_overlays("res://data/location_markers.json")
	_load_marker_overlays("res://data/entrance_markers.json")
	_entrances_meta = _read_json_array("res://data/entrances.json")
	_build_oot_time_flow_full_set()
	_build_oot_code_to_full_subregion_map()
	_build_macro_dependencies()
	_build_rule_dependencies()
	_build_macro_to_targets(_loc_rules, _macro_to_locations)
	_build_macro_to_targets(_ent_rules, _macro_to_markers)
	_build_macro_to_targets(_qj_rules, _macro_to_markers)
	_build_macro_reach_deps()
	call_deferred("_cache_tracker")

func _cache_tracker() -> void:
	_tracker_cache = get_tree().get_first_node_in_group("item_tracker")

func _read_json(path: String) -> Dictionary:
	var res: Variant = _load_json(path)
	return res if res is Dictionary else {}

func _read_json_array(path: String) -> Array:
	var res: Variant = _load_json(path)
	return res if res is Array else []

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	if text.is_empty() or text.strip_edges().is_empty():
		return {}
	return JSON.parse_string(text)

func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	if v == null:
		return []
	return [v]

func _set_world_reach_stale(world: int) -> void:
	_generation += 1
	_blur_cache.clear()
	_cached_generation[world] = -1

func invalidate_entrance_shuffle() -> void:
	_resolve_code_cache.clear()
	_graph_by_world.clear()
	_graph_built_worlds.clear()
	_active_graph_world = -1
	_set_all_reach_stale()

func _load_marker_overlays(path: String) -> void:
	_age_context_cache.clear()
	var data: Variant = _load_json(path)
	if not (data is Array):
		return
	for marker_variant in data:
		if not (marker_variant is Dictionary):
			continue
		var marker: Dictionary = marker_variant
		var mname: String = str(marker.get("marker_name", "")).strip_edges()
		var overlay: String = str(marker.get("overlay_image", "")).strip_edges()
		if mname.is_empty():
			continue
		var unique_key: String = "%s|%s|%s|%s" % [
			str(marker.get("game", "")).strip_edges(),
			str(marker.get("region", "")).strip_edges(),
			str(marker.get("subregion", "")).strip_edges(),
			mname
		]
		_marker_overlays[unique_key] = overlay
		if not _marker_overlays.has(mname):
			_marker_overlays[mname] = overlay
		var locs: Variant = marker.get("locations", [])
		if locs is Array:
			for loc in locs:
				_location_to_marker[str(loc).strip_edges()] = unique_key

func _get_age_context(marker_name: String) -> String:
	if _age_context_cache.has(marker_name):
		return _age_context_cache[marker_name]
	var overlay: String = _marker_overlays.get(marker_name, "")
	var result: String
	if overlay.find("child.png") != -1:
		result = "child"
	elif overlay.find("adult.png") != -1:
		result = "adult"
	else:
		result = "any"
	_age_context_cache[marker_name] = result
	return result

func _get_normalized_macros() -> Dictionary:
	if not _macros_normalized_built:
		_macros_normalized = _normalize_variant(LogicMacros.MACROS)
		_macros_normalized_built = true
	return _macros_normalized

func _normalize_variant(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			var ck: Variant = k.strip_edges() if k is String else k
			out[ck] = _normalize_variant(v[k])
		return out
	if v is Array:
		var out: Array = []
		for item in v:
			out.append(_normalize_variant(item))
		return out
	if v is String:
		return v.strip_edges()
	return v

func _substitute_in_variant(v: Variant, target: String, replacement: String) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			var new_k: Variant = k if k is not String else String(k).replace(target, replacement)
			out[new_k] = _substitute_in_variant(v[k], target, replacement)
		return out
	if v is Array:
		var out: Array = []
		for item in v:
			out.append(_substitute_in_variant(item, target, replacement))
		return out
	if v is String:
		return v.replace(target, replacement)
	return v

func _scan_rule_for_reach_deps(v: Variant) -> void:
	if v is Dictionary:
		if v.has("setting"):
			_reach_settings[str(v["setting"]).strip_edges()] = true
		if v.has("name"):
			_reach_items[str(v["name"]).strip_edges()] = true
		if v.has("location_item"):
			_reach_items[str(v["location_item"]).strip_edges()] = true
		if v.has("location"):
			_reach_items[str(v["location"]).strip_edges()] = true
		for k in v:
			_scan_rule_for_reach_deps(v[k])
	elif v is Array:
		for item in v:
			_scan_rule_for_reach_deps(item)

func _build_rule_dependencies() -> void:
	_reach_settings.clear()
	_reach_items.clear()
	for key in _loc_rules.keys():
		_scan_rule_for_reach_deps(_loc_rules[key])
	for key in _ent_rules.keys():
		_scan_rule_for_reach_deps(_ent_rules[key])
	for key in _qj_rules.keys():
		_scan_rule_for_reach_deps(_qj_rules[key])

func _build_macro_dependencies() -> void:
	if _deps_built:
		return
	_item_to_macros.clear()
	_setting_to_macros.clear()
	_macro_to_parents.clear()
	for mkey in LogicMacros.MACROS.keys():
		var mname: String = str(mkey).strip_edges()
		_scan_macro_for_deps(LogicMacros.MACROS[mkey], mname)
	_deps_built = true

func _scan_macro_for_deps(v: Variant, mname: String) -> void:
	if v is Dictionary:
		if v.has("name"):
			var display_name: String = str(v["name"]).strip_edges()
			if not _item_to_macros.has(display_name):
				_item_to_macros[display_name] = []
			if not _item_to_macros[display_name].has(mname):
				_item_to_macros[display_name].append(mname)
		if v.has("setting"):
			var setting_name: String = str(v["setting"]).strip_edges()
			if not _setting_to_macros.has(setting_name):
				_setting_to_macros[setting_name] = []
			if not _setting_to_macros[setting_name].has(mname):
				_setting_to_macros[setting_name].append(mname)
		if v.has("macro"):
			var dep_macro: String = str(v["macro"]).strip_edges()
			if not _macro_to_parents.has(dep_macro):
				_macro_to_parents[dep_macro] = []
			if not _macro_to_parents[dep_macro].has(mname):
				_macro_to_parents[dep_macro].append(mname)
		if v.has("location_item"):
			var loc_item: String = str(v["location_item"]).strip_edges()
			if not _item_to_macros.has(loc_item):
				_item_to_macros[loc_item] = []
			if not _item_to_macros[loc_item].has(mname):
				_item_to_macros[loc_item].append(mname)
		if v.has("location"):
			var loc_name2: String = str(v["location"]).strip_edges()
			if not _item_to_macros.has(loc_name2):
				_item_to_macros[loc_name2] = []
			if not _item_to_macros[loc_name2].has(mname):
				_item_to_macros[loc_name2].append(mname)
		for k in v:
			_scan_macro_for_deps(v[k], mname)
	elif v is Array:
		for item in v:
			_scan_macro_for_deps(item, mname)

func _build_macro_reach_deps() -> void:
	if _reach_dep_built:
		return
	_macro_reach_dep.clear()
	var queue: Array = []
	for mkey in LogicMacros.MACROS.keys():
		var mname: String = str(mkey).strip_edges()
		var def: Variant = LogicMacros.MACROS[mkey]
		if _scan_has_reach_key(def, REACH_CONDITION_KEYS):
			queue.append(mname)
			
	for mname in _macro_to_locations.keys():
		if not queue.has(mname):
			queue.append(mname)
	for mname in _macro_to_markers.keys():
		if not queue.has(mname):
			queue.append(mname)
			
	var head: int = 0
	while head < queue.size():
		var m: String = queue[head]
		head += 1
		if _macro_reach_dep.has(m):
			continue
		_macro_reach_dep[m] = true
		for p in _macro_to_parents.get(m, []):
			var ps: String = str(p).strip_edges()
			if not _macro_reach_dep.has(ps):
				queue.append(ps)
	_reach_dep_built = true

func _scan_has_reach_key(v: Variant, keys: Array) -> bool:
	if v is Dictionary:
		for k in v:
			if keys.has(k):
				return true
			if _scan_has_reach_key(v[k], keys):
				return true
	elif v is Array:
		for item in v:
			if _scan_has_reach_key(item, keys):
				return true
	return false

func _build_macro_to_targets(rules: Dictionary, target_map: Dictionary) -> void:
	target_map.clear()
	for key in rules.keys():
		var entry_name: String = str(key).strip_edges()
		var rule: Dictionary = rules[key]
		if rule.has("logic"):
			_scan_logic_for_macros(rule["logic"], entry_name, target_map)
		if rule.has("entrance"):
			for ent in _as_array(rule["entrance"]):
				if ent is Dictionary and ent.has("logic"):
					_scan_logic_for_macros(ent["logic"], entry_name, target_map)

func _scan_logic_for_macros(v: Variant, target_name: String, target_map: Dictionary) -> void:
	if v is Dictionary:
		if v.has("macro"):
			var mname: String = str(v["macro"]).strip_edges()
			if not target_map.has(mname):
				target_map[mname] = {}
			target_map[mname][target_name] = true
		for k in v:
			_scan_logic_for_macros(v[k], target_name, target_map)
	elif v is Array:
		for item in v:
			_scan_logic_for_macros(item, target_name, target_map)

func _next_version() -> int:
	_version_counter += 1
	return _version_counter

func _touch_primitive(dep_key: String) -> void:
	_primitive_versions[dep_key] = _next_version()
	var keys: Dictionary = _primitive_macro_keys.get(dep_key, {})
	for mk in keys.keys():
		var entry: Variant = _macro_cache.get(mk, null)
		if entry != null:
			entry["valid"] = false

func _get_primitive_version(dep_key: String) -> int:
	return int(_primitive_versions.get(dep_key, 0))

func _get_dep_version(dep_key: String) -> int:
	if dep_key.begins_with("macro:"):
		var mk: String = dep_key.substr(6)
		var entry: Variant = _macro_cache.get(mk, null)
		if entry == null:
			return -1
		if not _validate_macro_entry(mk, entry):
			return -1
		return int(entry.get("out_ver", 0))
	return _get_primitive_version(dep_key)

func _record_dep(ctx: Dictionary, dep_key: String) -> void:
	if not ctx.has("deps"):
		return
	ctx.deps[dep_key] = _get_dep_version(dep_key)

func _deps_valid(deps: Dictionary) -> bool:
	for dep_key in deps.keys():
		if _get_dep_version(dep_key) != int(deps[dep_key]):
			return false
	return true

func _validate_macro_entry(key: String, entry: Dictionary) -> bool:
	var id := "macro:" + key
	if _validating.has(id):
		return bool(entry.get("valid", false))
	_validating[id] = true
	var ok := bool(entry.get("valid", false)) and _deps_valid(entry.get("deps", {}))
	_validating.erase(id)
	if not ok:
		entry["valid"] = false
	return ok

func _store_macro_result(key: String, mname: String, value: bool, deps: Dictionary) -> void:
	var old: Variant = _macro_cache.get(key, null)
	var out_ver: int
	if old != null and bool(old.get("value", false)) == value:
		out_ver = int(old.get("out_ver", 0))
	else:
		out_ver = _next_version()
	var entry := {
		"value": value,
		"valid": true,
		"deps": deps.duplicate(),
		"out_ver": out_ver
	}
	_macro_cache[key] = entry
	if not _macro_keys_by_name.has(mname):
		_macro_keys_by_name[mname] = {}
	_macro_keys_by_name[mname][key] = true
	for dep_key in deps.keys():
		if not dep_key.begins_with("macro:"):
			if not _primitive_macro_keys.has(dep_key):
				_primitive_macro_keys[dep_key] = {}
			_primitive_macro_keys[dep_key][key] = true

func _invalidate_macro_name(mname: String) -> void:
	var keys: Dictionary = _macro_keys_by_name.get(mname, {})
	for key in keys.keys():
		var entry: Variant = _macro_cache.get(key, null)
		if entry != null:
			entry["valid"] = false

func _store_leaf_cache(cache: Dictionary, key: String, value: bool, deps: Dictionary) -> void:
	cache[key] = {"value": value, "valid": true, "deps": deps.duplicate()}

func _get_cached_leaf(cache: Dictionary, key: String) -> Array:
	var entry: Variant = cache.get(key, null)
	if entry == null:
		return [false, false]
	if bool(entry.get("valid", false)) and _deps_valid(entry.get("deps", {})):
		return [true, bool(entry.get("value", false))]
	entry["valid"] = false
	return [false, false]

func evaluate_macro(mname: String, world: int, param_value: String = "") -> bool:
	var ctx: Dictionary = _make_eval_ctx(is_reach_prepared(world) and not _building_reach)
	return _eval_macro_node(mname, world, "any", param_value, ctx)

func _make_eval_ctx(commit: bool) -> Dictionary:
	return {"commit": commit and not _building_reach, "deps": {}, "local": {}}

func _eval_blur_age(world: int, ctx: Dictionary) -> bool:
	for ctrl_name in BLUR_AGE_CONTROL_NAMES:
		_record_dep(ctx, "setting:" + ctrl_name)
		var check: bool = _evaluate_logic({"macro": ctrl_name}, world, "any", ctx, BLUR_NONE)
		if check:
			return true
		check = _evaluate_logic({"setting": ctrl_name, "value": true}, world, "any", ctx, BLUR_NONE)
		if check:
			return true
	return false

func _blur_modes(world: int, ctx: Dictionary) -> Array:
	var cache_key := "blur|" + str(world) + "|" + str(_generation)
	if _blur_cache.has(cache_key):
		return _blur_cache[cache_key]
	var result: Array
	if _eval_blur_age(world, ctx):
		result = [BLUR_FULL, BLUR_DIRECT]
	else:
		result = [BLUR_NONE, BLUR_NONE]
	_blur_cache[cache_key] = result
	return result

func _eval_macro_node(
	mname: String, world: int, age_context: String,
	param_value: String, ctx: Variant, blur_mode: int = BLUR_NONE
) -> bool:
	if mname.is_empty():
		return true
	if ctx == null:
		ctx = _make_eval_ctx(true)
	if not ctx.has("cycle"):
		ctx["cycle"] = false
	if not ctx.has("local"):
		ctx["local"] = {}
	if not ctx.has("commit"):
		ctx["commit"] = true
	if not ctx.has("deps"):
		ctx["deps"] = {}
	var cache_key: String = "%d|%s|%s|%s|%d" % [world, mname, age_context, param_value, blur_mode]
	if ctx.local.has(cache_key):
		_record_dep(ctx, "macro:" + cache_key)
		return bool(ctx.local[cache_key])
	if _macro_in_progress.has(cache_key):
		_record_dep(ctx, "macro:" + cache_key)
		return false
	var entry: Variant = null
	if not _building_reach:
		entry = _macro_cache.get(cache_key, null)
	if entry != null and _validate_macro_entry(cache_key, entry):
		ctx.local[cache_key] = bool(entry.get("value", false))
		_record_dep(ctx, "macro:" + cache_key)
		return bool(entry.get("value", false))
	if entry != null:
		entry["valid"] = false
	_macro_in_progress[cache_key] = true
	var child_ctx := {"commit": bool(ctx.commit), "deps": {}, "local": ctx.local}
	var res: bool = false
	var macros: Dictionary = _get_normalized_macros()
	if macros.has(mname):
		var macro_def: Variant = macros[mname]
		if not param_value.is_empty():
			macro_def = _substitute_in_variant(macro_def, "__PRICE_SETTING__", param_value)
		res = _evaluate_logic(macro_def, world, age_context, child_ctx, blur_mode)
	else:
		if _tracker_cache:
			var old_world: int = _tracker_cache.current_world
			_tracker_cache.current_world = world
			res = bool(_tracker_cache._evaluate_item_condition({"macro": mname, "param": param_value}, {}))
			_tracker_cache.current_world = old_world
		else:
			res = false
	_macro_in_progress.erase(cache_key)
	ctx.local[cache_key] = res
	if bool(ctx.commit):
		_store_macro_result(cache_key, mname, res, child_ctx.deps)
	_record_dep(ctx, "macro:" + cache_key)
	return res

func _invalidate_macro_closure(seeds: Array) -> void:
	if seeds.is_empty():
		return
	var queue: Array = []
	var seen: Dictionary = {}
	for s in seeds:
		var m: String = str(s).strip_edges()
		if m.is_empty():
			continue
		if not seen.has(m):
			seen[m] = true
			queue.append(m)
	var head: int = 0
	while head < queue.size():
		var m: String = queue[head]
		head += 1
		_invalidate_macro_name(m)
		for p in _macro_to_parents.get(m, []):
			var ps: String = str(p).strip_edges()
			if not seen.has(ps):
				seen[ps] = true
				queue.append(ps)

func _collect_and_invalidate(seed_list: Array, is_setting: bool, world: int = -1) -> void:
	_build_macro_dependencies()
	_build_rule_dependencies()
	if is_setting:
		for raw_name in seed_list:
			var seed_name: String = str(raw_name).strip_edges()
			if seed_name.is_empty():
				continue
			var suffix: String = "|" + seed_name
			var keys_to_remove: Array = []
			for k in _settings_cache.keys():
				if str(k).ends_with(suffix):
					keys_to_remove.append(k)
			for k in keys_to_remove:
				_settings_cache.erase(k)
	var source: Dictionary = _setting_to_macros if is_setting else _item_to_macros
	var seeds: Array = []
	var seen: Dictionary = {}
	var affects_reach: bool = false
	for raw_name in seed_list:
		var seed_name: String = str(raw_name).strip_edges()
		if seed_name.is_empty():
			continue
		var dep_key: String = ("setting:" if is_setting else "item:") + seed_name
		_touch_primitive(dep_key)
		
		if is_setting and _reach_settings.has(seed_name):
			affects_reach = true
		elif not is_setting and _reach_items.has(seed_name):
			affects_reach = true
			
		for m in source.get(seed_name, []):
			var ms: String = str(m).strip_edges()
			if not seen.has(ms):
				seen[ms] = true
				seeds.append(ms)
				if _macro_reach_dep.get(ms, false):
					affects_reach = true
	for raw_name in seed_list:
		if str(raw_name).strip_edges() in BLUR_AGE_CONTROL_NAMES:
			affects_reach = true
			break
	if not affects_reach:
		for ms in seeds:
			if ms in BLUR_AGE_CONTROL_NAMES:
				affects_reach = true
				break
	if not seeds.is_empty():
		_invalidate_macro_closure(seeds)
	if affects_reach:
		if world > 0:
			_set_world_reach_stale(world)
		else:
			_set_all_reach_stale()

func invalidate_item_cache(display_names: Array, world: int = -1) -> void:
	_collect_and_invalidate(display_names, false, world)

func invalidate_setting_cache(setting_names: Array, world: int = -1) -> void:
	_collect_and_invalidate(setting_names, true, world)

func invalidate_item_smart(display_names: Array, world: int = -1) -> void:
	_collect_and_invalidate(display_names, false, world)

func invalidate_reachability(_clear_macro_cache: bool = true) -> void:
	_set_all_reach_stale()

func item_affects_reach(display_name: String) -> bool:
	_build_macro_dependencies()
	var macros: Array = _item_to_macros.get(display_name, [])
	for m in macros:
		if _macro_reach_dep.get(str(m), false):
			return true
	return false

func clear_cache(full_reset: bool = false) -> void:
	if _batch_depth > 0:
		_pending_clear = full_reset
		return
	_clear_cache_internal(full_reset)

func _clear_cache_internal(full_reset: bool = false) -> void:
	_generation += 1
	_macro_in_progress.clear()
	_validating.clear()
	_location_cache.clear()
	_marker_cache.clear()
	_reach_changed.clear()
	_time_flow_oot_cache.clear()
	_blur_cache.clear()
	if full_reset:
		_macro_cache.clear()
		_macro_keys_by_name.clear()
		_primitive_versions.clear()
		_primitive_macro_keys.clear()
		_version_counter = 1
		_dirty_location_names.clear()
		_dirty_marker_names.clear()
		_item_to_macros.clear()
		_setting_to_macros.clear()
		_macro_to_parents.clear()
		_macro_to_locations.clear()
		_macro_to_markers.clear()
		_macro_reach_dep.clear()
		_deps_built = false
		_reach_dep_built = false
		_resolve_code_cache.clear()
		_graph_built_worlds.clear()
		_graph_by_world.clear()
		_active_graph_world = -1
		_settings_cache.clear()
		_build_macro_dependencies()
		_build_rule_dependencies()
		_build_macro_to_targets(_loc_rules, _macro_to_locations)
		_build_macro_to_targets(_ent_rules, _macro_to_markers)
		_build_macro_to_targets(_qj_rules, _macro_to_markers)
		_build_macro_reach_deps()
	else:
		for entry in _macro_cache.values():
			entry["valid"] = false

func begin_batch() -> void:
	_batch_depth += 1

func end_batch() -> void:
	_batch_depth -= 1
	if _batch_depth < 0:
		_batch_depth = 0
	if _batch_depth != 0:
		return
	if _pending_clear:
		var fr: bool = _pending_clear
		_pending_clear = false
		_clear_cache_internal(fr)
		return
	if _pending_invalidate:
		_pending_invalidate = false
		_set_all_reach_stale()
		return
	if _pending_drop:
		_pending_drop = false
		_drop_transient_internal()

func drop_transient_caches() -> void:
	if _batch_depth > 0:
		_pending_drop = true
		return
	_drop_transient_internal()

func _drop_transient_internal() -> void:
	_location_cache.clear()
	_marker_cache.clear()
	_macro_in_progress.clear()
	_validating.clear()
	_blur_cache.clear()

func consume_dirty_location_names() -> Array:
	var result: Array = _dirty_location_names.keys()
	_dirty_location_names.clear()
	return result

func consume_dirty_marker_names() -> Array:
	var result: Array = _dirty_marker_names.keys()
	_dirty_marker_names.clear()
	return result

func has_dirty_locations() -> bool:
	return not _dirty_location_names.is_empty()

func has_dirty_markers() -> bool:
	return not _dirty_marker_names.is_empty()

func mark_all_locations_dirty() -> void:
	for loc_key in _loc_rules.keys():
		_dirty_location_names[str(loc_key).strip_edges()] = true

func mark_all_markers_dirty() -> void:
	for marker_key in _ent_rules.keys():
		_dirty_marker_names[str(marker_key).strip_edges()] = true
	for marker_key in _qj_rules.keys():
		_dirty_marker_names[str(marker_key).strip_edges()] = true

func _ensure_graph(world: int) -> void:
	if _active_graph_world == world and _graph_built_worlds.get(world, false):
		return
	if _graph_by_world.has(world):
		_load_graph(world)
	else:
		_build_static_graph(world)

func _load_graph(world: int) -> void:
	var g: Dictionary = _graph_by_world.get(world, {})
	if g.is_empty():
		return
	_code_consumers = g.get("code_consumers", {})
	_marker_reqs = g.get("marker_reqs", {})
	_marker_entr_codes = g.get("marker_entr_codes", {})
	_region_dependents = g.get("region_dependents", {})
	_region_incoming = g.get("region_incoming", {})
	_code_producers = g.get("code_producers", {})
	_region_producers = g.get("region_producers", {})
	_marker_blocked = g.get("marker_blocked", {})
	_graph_built_worlds[world] = true
	_active_graph_world = world

func _build_static_graph(world: int) -> void:
	if _graph_by_world.has(world):
		_load_graph(world)
		return

	_code_consumers = {}
	_marker_reqs = {}
	_marker_entr_codes = {}
	_region_dependents = {}
	_region_incoming = {}
	_marker_blocked = {}

	for marker_variant in _entrance_markers_cache:
		if not (marker_variant is Dictionary):
			continue
		var marker: Dictionary = marker_variant
		var mname: String = str(marker.get("marker_name", "")).strip_edges()
		if mname.is_empty():
			continue
		var ents: Variant = marker.get("entrance", [])
		if ents is String:
			ents = [ents]
		if not (ents is Array):
			continue
		var codes: Array = []
		for e in ents:
			var c: String = str(e).strip_edges()
			if not c.is_empty():
				codes.append(_resolve_code(c, world))
		_marker_entr_codes[mname] = codes
		var src: String = _get_marker_source(mname)
		if not src.is_empty():
			if not _region_dependents.has(src):
				_region_dependents[src] = []
			if not _region_dependents[src].has(mname):
				_region_dependents[src].append(mname)
		var dest: String = _get_marker_dest(mname)
		if not dest.is_empty():
			if not _region_incoming.has(dest):
				_region_incoming[dest] = []
			if not _region_incoming[dest].has(mname):
				_region_incoming[dest].append(mname)

	var all_names: Dictionary = {}
	for mname in _marker_entr_codes.keys():
		all_names[mname] = true
	for k in _ent_rules.keys():
		all_names[str(k).strip_edges()] = true
	for k in _qj_rules.keys():
		all_names[str(k).strip_edges()] = true

	for mname in all_names.keys():
		var rule: Dictionary = _get_marker_rule(mname)
		var reqs: Array = []
		if rule.has("entrance"):
			for ent in _as_array(rule["entrance"]):
				var c: String = _ent_code_of(ent)
				if c.is_empty():
					continue
				reqs.append([c, _ent_logic_of(ent)])
				if not _code_consumers.has(c):
					_code_consumers[c] = []
				if not _code_consumers[c].has(mname):
					_code_consumers[c].append(mname)
		_marker_reqs[mname] = reqs
		if reqs.is_empty() and _marker_entr_codes.has(mname) and _get_marker_source(mname).is_empty():
			_marker_blocked[mname] = true

	_graph_built_worlds[world] = true
	_code_producers = {}
	_region_producers = {}
	for marker_name in _marker_entr_codes.keys():
		var mn: String = str(marker_name).strip_edges()
		var codes: Array = _marker_entr_codes[mn]
		for c_variant in codes:
			var c: String = str(c_variant).strip_edges()
			if not _code_producers.has(c):
				_code_producers[c] = []
			if not _code_producers[c].has(mn):
				_code_producers[c].append(mn)
		var d: String = _get_marker_dest(mn)
		if not d.is_empty():
			if not _region_producers.has(d):
				_region_producers[d] = []
			if not _region_producers[d].has(mn):
				_region_producers[d].append(mn)
	for qj_key in _qj_rules.keys():
		var qj_name: String = str(qj_key).strip_edges()
		var qj_code: String = str(_qj_code_by_name.get(qj_name, "")).strip_edges()
		if qj_code.is_empty():
			continue
		qj_code = _resolve_code(qj_code, world)
		if not _code_producers.has(qj_code):
			_code_producers[qj_code] = []
		if not _code_producers[qj_code].has(qj_name):
			_code_producers[qj_code].append(qj_name)

	_graph_by_world[world] = {
		"code_consumers": _code_consumers,
		"marker_reqs": _marker_reqs,
		"marker_entr_codes": _marker_entr_codes,
		"region_dependents": _region_dependents,
		"region_incoming": _region_incoming,
		"code_producers": _code_producers,
		"region_producers": _region_producers,
		"marker_blocked": _marker_blocked,
	}
	_active_graph_world = world

func _resolve_code(code: String, world: int) -> String:
	var key: String = str(world) + "|" + code
	if _resolve_code_cache.has(key):
		return _resolve_code_cache[key]
	var main_node: Node = _main_scene_cache
	if main_node == null:
		main_node = get_tree().get_first_node_in_group("main_scene")
		_main_scene_cache = main_node
	var resolved: String = code
	if main_node and main_node.has_method("get_entrance_shuffle"):
		var ent_shuffle: Variant = main_node.get_entrance_shuffle()
		if ent_shuffle is Dictionary:
			var world_ent: Variant = ent_shuffle.get(world, {})
			if world_ent is Dictionary and world_ent.has(code):
				resolved = str(world_ent[code])
	_resolve_code_cache[key] = resolved
	return resolved

func _ent_code_of(ent: Variant) -> String:
	if ent is String:
		return ent.strip_edges()
	if ent is Dictionary:
		var code: Variant = ent.get("code", "")
		return str(code).strip_edges() if code else ""
	return ""

func _ent_logic_of(ent: Variant) -> Dictionary:
	if ent is Dictionary:
		var l: Variant = ent.get("logic", {})
		return l if l is Dictionary else {}
	return {}

func _get_marker_source(marker_name: String) -> String:
	for arrow in ["→", "↔"]:
		var idx := marker_name.find(arrow)
		if idx != -1:
			return marker_name.substr(0, idx).strip_edges()
	return ""

func _get_marker_dest(marker_name: String) -> String:
	for arrow in ["→", "↔"]:
		var idx := marker_name.find(arrow)
		if idx != -1:
			return marker_name.substr(idx + 1).strip_edges()
	return ""

func _get_marker_rule(m: String) -> Dictionary:
	if _ent_rules.has(m):
		return _ent_rules[m]
	if _qj_rules.has(m):
		return _qj_rules[m]
	var alt := m.replace("↔", "→")
	if alt != m and _ent_rules.has(alt):
		return _ent_rules[alt]
	alt = m.replace("→", "↔")
	if alt != m and _ent_rules.has(alt):
		return _ent_rules[alt]
	return {}

func _make_full_subregion_name(game: Variant, region: Variant, subregion: Variant) -> String:
	return str(game).strip_edges() + "|" + str(region).strip_edges() + "|" + str(subregion).strip_edges()

func _build_oot_time_flow_full_set() -> void:
	_oot_time_flow_full_set.clear()
	for entry in OOT_TIME_FLOW_FULL_SUBREGIONS:
		if not entry is Array or entry.size() < 3:
			continue
		var full_name: String = _make_full_subregion_name(entry[0], entry[1], entry[2])
		_oot_time_flow_full_set[full_name] = true

func _build_oot_code_to_full_subregion_map() -> void:
	_code_to_oot_full_subregion.clear()
	for entry in _entrances_meta:
		if not entry is Array or entry.size() < 4:
			continue
		var game: String = str(entry[0]).strip_edges()
		if game.to_upper() != "OOT":
			continue
		var region: String = str(entry[1]).strip_edges()
		var subregion: String = str(entry[2]).strip_edges()
		var full_name: String = _make_full_subregion_name(game, region, subregion)
		for c in _as_array(entry[3]):
			var code: String = str(c).strip_edges()
			if not code.is_empty():
				_code_to_oot_full_subregion[code] = full_name

func _get_oot_full_subregion_for_code(code: String, world: int) -> String:
	var resolved: String = _resolve_code(code, world)
	if _code_to_oot_full_subregion.has(resolved):
		return _code_to_oot_full_subregion[resolved]
	return _code_to_oot_full_subregion.get(code, "")

func _should_use_stale_reach(world: int) -> bool:
	if _internal_reach_eval:
		return false
	if not is_reach_prepared(world):
		return true
	if _building_reach and _cached_generation.get(world, -1) != _generation:
		return true
	return false

func _codes_for_world(world: int) -> Dictionary:
	if _internal_reach_eval:
		return _rc_codes_by_world.get(world, {})
	if _should_use_stale_reach(world):
		return _rc_codes_by_world_stale.get(world, {})
	return _rc_codes_by_world.get(world, {})

func _regions_for_world(world: int) -> Dictionary:
	if _internal_reach_eval:
		return _rc_regions_by_world.get(world, {})
	if _should_use_stale_reach(world):
		return _rc_regions_by_world_stale.get(world, {})
	return _rc_regions_by_world.get(world, {})

func _markers_for_world(world: int) -> Dictionary:
	if _internal_reach_eval:
		return _rc_markers_by_world.get(world, {})
	if _should_use_stale_reach(world):
		return _rc_markers_by_world_stale.get(world, {})
	return _rc_markers_by_world.get(world, {})

func _games_for_world(world: int) -> Dictionary:
	if _internal_reach_eval:
		return _rc_games_by_world.get(world, {})
	if _should_use_stale_reach(world):
		return _rc_games_by_world_stale.get(world, {})
	return _rc_games_by_world.get(world, {})

func _is_code_available(c: String, world: int) -> bool:
	if c.is_empty():
		return false
	return _codes_for_world(world).has(c)

func _has_oot_time_flow(world: int) -> bool:
	var codes_dict: Dictionary = _codes_for_world(world)
	var use_stale: bool = _should_use_stale_reach(world)
	var key: String = "%d|%d|%d|%d" % [world, _generation, 1 if use_stale else 0, codes_dict.size()]
	if _time_flow_oot_cache.has(key):
		return bool(_time_flow_oot_cache[key])
	var result: bool = false
	for c in codes_dict:
		var full_name: String = _get_oot_full_subregion_for_code(str(c), world)
		if _oot_time_flow_full_set.has(full_name):
			result = true
			break
	if _time_flow_oot_cache.size() > MAX_TIME_FLOW_CACHE:
		_time_flow_oot_cache.clear()
	_time_flow_oot_cache[key] = result
	return result

func ensure_reach(world: int) -> void:
	_ensure_reach(world)

func build_static_graph() -> void:
	_build_static_graph(1)

func is_reach_prepared(world: int) -> bool:
	return _generation > 0 and _cached_generation.get(world, -1) == _generation

func _ensure_reach(world: int) -> void:
	if _cached_generation.get(world, -1) == _generation:
		_ensure_graph(world)
		return
	_ensure_graph(world)
	if _is_compute_suppressed():
		return
	if not _reach_compute_in_progress.get(world, false):
		_reach_compute_in_progress[world] = true
		_run_reach_async(world)

func _set_all_reach_stale() -> void:
	_generation += 1
	_blur_cache.clear()
	for world in _cached_generation.keys():
		_cached_generation[world] = -1

func request_reach_compute(world: int, callback: Callable = Callable(), start_compute: bool = true) -> void:
	if _cached_generation.get(world, -1) == _generation:
		_ensure_graph(world)
		if callback.is_valid():
			callback.call_deferred()
		return
	if callback.is_valid():
		if not _pending_reach_callbacks.has(world):
			_pending_reach_callbacks[world] = []
		var pending: Array = _pending_reach_callbacks[world]
		var exists: bool = false
		for cb in pending:
			if cb == callback:
				exists = true
				break
		if not exists:
			pending.append(callback)
	if not start_compute:
		return
	if _reach_compute_in_progress.get(world, false):
		return
	_reach_compute_in_progress[world] = true
	_run_reach_async(world)

func _run_reach_async(world: int) -> void:
	await get_tree().process_frame
	var gen: int = _generation
	if _cached_generation.get(world, -1) == gen:
		_reach_compute_in_progress.erase(world)
		_fire_reach_callbacks(world)
		return
	if _tracker_cache == null:
		_tracker_cache = get_tree().get_first_node_in_group("item_tracker")
	if _tracker_cache == null:
		_reach_compute_in_progress.erase(world)
		return
	_ensure_graph(world)
	_rc_codes_by_world_stale[world] = _rc_codes_by_world.get(world, {})
	_rc_regions_by_world_stale[world] = _rc_regions_by_world.get(world, {})
	_rc_markers_by_world_stale[world] = _rc_markers_by_world.get(world, {})
	_rc_games_by_world_stale[world] = _rc_games_by_world.get(world, {})
	_cached_generation[world] = -1
	_reach_changed[world] = false
	_rc_codes_by_world[world] = {}
	_rc_games_by_world[world] = {}
	_rc_markers_by_world[world] = {}
	_rc_regions_by_world[world] = {}
	_why_code_by_world[world] = {}
	_why_marker_by_world[world] = {}
	_why_region_by_world[world] = {}
	_building_reach = true
	_blur_cache.clear()
	_touch_primitive("reach:" + str(world))
	await _run_fixed_point_async(world, gen)
	_building_reach = false
	_time_flow_oot_cache.clear()
	if _generation != gen:
		_rc_codes_by_world[world] = _rc_codes_by_world_stale.get(world, {})
		_rc_regions_by_world[world] = _rc_regions_by_world_stale.get(world, {})
		_rc_markers_by_world[world] = _rc_markers_by_world_stale.get(world, {})
		_rc_games_by_world[world] = _rc_games_by_world_stale.get(world, {})
		_rc_codes_by_world_stale.erase(world)
		_rc_regions_by_world_stale.erase(world)
		_rc_markers_by_world_stale.erase(world)
		_rc_games_by_world_stale.erase(world)
		_reach_changed[world] = false
		_reach_compute_in_progress.erase(world)
		return
	_cached_generation[world] = gen
	_rc_codes_by_world_stale.erase(world)
	_rc_regions_by_world_stale.erase(world)
	_rc_markers_by_world_stale.erase(world)
	_rc_games_by_world_stale.erase(world)
	if bool(_reach_changed.get(world, false)):
		_touch_primitive("reach:" + str(world))
		_reach_changed[world] = false
	_reach_compute_in_progress.erase(world)
	_fire_reach_callbacks(world)

func _fire_reach_callbacks(world: int) -> void:
	if not _pending_reach_callbacks.has(world):
		return
	var callbacks: Array = _pending_reach_callbacks[world]
	_pending_reach_callbacks.erase(world)
	for cb in callbacks:
		if cb.is_valid():
			cb.call_deferred()

func _run_fixed_point_async(world: int, gen: int) -> void:
	var pending_codes: Array = []
	var pending_regions: Array = []
	var pass_count: int = 0
	while pass_count < MAX_FIXED_POINT_PASSES:
		pass_count += 1
		if _generation != gen:
			return
		var new_codes: Array = []
		var new_regions: Array = []
		var added: bool = _run_reach_pass_async(world, pending_codes, pending_regions, new_codes, new_regions, gen)
		if _generation != gen:
			return
		if not added:
			break
		for c_variant in new_codes:
			var c: String = str(c_variant)
			if not _rc_codes_by_world[world].has(c):
				_rc_codes_by_world[world][c] = true
				if c.begins_with("OOT_"):
					_rc_games_by_world[world]["OOT"] = true
				elif c.begins_with("MM_"):
					_rc_games_by_world[world]["MM"] = true
				pending_codes.append(["code", c])
		for r_variant in new_regions:
			var r: String = str(r_variant)
			if not _rc_regions_by_world[world].has(r):
				_rc_regions_by_world[world][r] = true
				_why_region_by_world[world][r] = "marker_effect"
				pending_regions.append(["region", r])
		await get_tree().process_frame

func _run_reach_pass_async(
	world: int, pending_codes: Array, pending_regions: Array,
	new_codes: Array, new_regions: Array, gen: int
) -> bool:
	if _generation != gen:
		return false
	_internal_reach_eval = true
	var queue: Array = []
	var processed: Dictionary = {}
	var added_something: bool = false
	for r_key in _region_dependents.keys():
		var r: String = str(r_key).strip_edges()
		if not _region_incoming.has(r) or (_region_incoming[r] as Array).is_empty():
			if not _rc_regions_by_world[world].has(r):
				_rc_regions_by_world[world][r] = true
				_why_region_by_world[world][r] = "root"
				new_regions.append(r)
				added_something = true
			queue.append(["region", r])
	for pc in pending_codes:
		queue.append(["code", str(pc[1])])
	for pr in pending_regions:
		queue.append(["region", str(pr[1])])
	pending_codes.clear()
	pending_regions.clear()
	for c_key in _rc_codes_by_world[world].keys():
		queue.append(["code", str(c_key)])
	for r_key in _rc_regions_by_world[world].keys():
		queue.append(["region", str(r_key)])
	for node_key in _marker_reqs.keys():
		var node_name: String = str(node_key).strip_edges()
		if (_marker_reqs[node_name] as Array).is_empty():
			if _try_activate_marker(node_name, world, queue, processed):
				added_something = true
	var games_setting: String = ""
	if _tracker_cache and _tracker_cache.has_method("_get_setting_value_for_world"):
		games_setting = str(_tracker_cache._get_setting_value_for_world("games")).strip_edges().to_lower()
	if games_setting == "mm":
		var mm_code := "MM_CLOCK_TOWN_FROM_CLOCK_TOWER"
		if not _rc_codes_by_world[world].has(mm_code) and not new_codes.has(mm_code):
			new_codes.append(mm_code)
			added_something = true
	for root_key in _root_codes.keys():
		var root_c: String = str(root_key).strip_edges()
		if not _rc_codes_by_world[world].has(root_c) and not new_codes.has(root_c):
			new_codes.append(root_c)
			added_something = true
	var head: int = 0
	var iteration: int = 0
	while head < queue.size() and iteration < MAX_REACH_ITERATIONS:
		iteration += 1
		var item: Array = queue[head]
		head += 1
		var kind: String = str(item[0])
		var val: String = str(item[1])
		if kind == "code":
			for m_variant in _code_consumers.get(val, []):
				var m: String = str(m_variant)
				if _try_activate_marker(m, world, queue, processed):
					added_something = true
		elif kind == "region":
			for m_variant in _region_dependents.get(val, []):
				var m: String = str(m_variant)
				if _try_activate_marker(m, world, queue, processed):
					added_something = true
		elif kind == "marker":
			for e_variant in _marker_entr_codes.get(val, []):
				var e: String = str(e_variant)
				if not _rc_codes_by_world[world].has(e) and not new_codes.has(e):
					new_codes.append(e)
					added_something = true
			var d: String = _get_marker_dest(val)
			if not d.is_empty() and not _rc_regions_by_world[world].has(d):
				new_regions.append(d)
				added_something = true
			if _qj_rules.has(val):
				var qjc := _resolve_code(str(_qj_code_by_name.get(val, "")), world)
				if not qjc.is_empty() and not _rc_codes_by_world[world].has(qjc) and not new_codes.has(qjc):
					new_codes.append(qjc)
					added_something = true
	if added_something:
		_reach_changed[world] = true
	_internal_reach_eval = false
	return added_something

func _try_activate_marker(m: String, world: int, queue: Array, processed: Dictionary) -> bool:
	if processed.has(m):
		return false
	if _rc_markers_by_world[world].has(m):
		return false
	if _marker_blocked.has(m):
		return false
	
	var rule: Dictionary = _get_marker_rule(m)
	var reqs: Array = _marker_reqs.get(m, [])
	var ctx: Dictionary = _make_eval_ctx(false)
	var modes: Array = _blur_modes(world, ctx)
	var entrance_blur: int = int(modes[0])
	var logic_blur: int = int(modes[1])
	
	var entrance_valid: bool = false
	
	if rule.is_empty():
		var codes: Array = _marker_entr_codes.get(m, [])
		for c_variant in codes:
			var c: String = str(c_variant).strip_edges()
			if _rc_codes_by_world[world].has(c):
				entrance_valid = true
				break
		if not entrance_valid:
			return false
	else:
		if reqs.is_empty():
			entrance_valid = true
		else:
			_record_dep(ctx, "reach:" + str(world))
			for req in reqs:
				var c: String = str(req[0])
				if not _is_code_available(c, world):
					continue
				var l: Dictionary = req[1]
				if not l.is_empty() and not _evaluate_logic(l, world, "any", ctx, entrance_blur):
					continue
				entrance_valid = true
				break
		if not entrance_valid:
			return false
	
	if rule.has("logic"):
		if not _evaluate_logic(rule["logic"], world, "any", ctx, logic_blur):
			return false
			
	processed[m] = true
	_rc_markers_by_world[world][m] = true
	_why_marker_by_world[world][m] = "reqs_met"
	queue.append(["marker", m])
	return true

func is_entrance_unshuffled(code: String, world: int) -> bool:
	code = code.strip_edges()
	if code.is_empty():
		return true
	return _resolve_code(code, world) == code

func evaluate_entrance_unshuffled(value: Variant, world: int) -> bool:
	if value is Dictionary:
		if value.has("any"):
			for c in _as_array(value["any"]):
				if is_entrance_unshuffled(str(c), world):
					return true
			return false
		if value.has("all"):
			value = value["all"]
		else:
			return false
	for c in _as_array(value):
		if not is_entrance_unshuffled(str(c), world):
			return false
	return true

func is_marker_reachable(marker_name: String, world: int) -> bool:
	marker_name = marker_name.strip_edges()
	if marker_name.is_empty():
		return true
	_ensure_reach(world)
	if _rc_markers_by_world.get(world, {}).has(marker_name):
		return true
	var prepared: bool = is_reach_prepared(world)
	var key: String = str(world) + "|" + marker_name
	var cached: Array = _get_cached_leaf(_marker_cache, key)
	if cached[0]:
		return bool(cached[1])
	var ctx: Dictionary = _make_eval_ctx(prepared)
	var res: bool = _compute_marker_lazy(marker_name, world, ctx)
	if prepared:
		_store_leaf_cache(_marker_cache, key, res, ctx.deps)
		if res and not _rc_markers_by_world.get(world, {}).has(marker_name):
			_set_all_reach_stale()
	return res

func _compute_marker_lazy(m: String, world: int, ctx: Dictionary) -> bool:
	var key: String = str(world) + "|" + m
	if _macro_in_progress.has("marker:" + key):
		return false
	_macro_in_progress["marker:" + key] = true
	
	var rule: Dictionary = _get_marker_rule(m)
	if rule.is_empty():
		var codes: Array = _marker_entr_codes.get(m, [])
		var code_available: bool = false
		for c_variant in codes:
			var c: String = str(c_variant).strip_edges()
			if _rc_codes_by_world[world].has(c):
				code_available = true
				break
		_macro_in_progress.erase("marker:" + key)
		return code_available
	
	var reqs: Array = _marker_reqs.get(m, [])
	var age_ctx: String = _get_age_context(m)
	var modes: Array = _blur_modes(world, ctx)
	var entrance_blur: int = int(modes[0])
	var logic_blur: int = int(modes[1])
	
	var entrance_valid: bool = false
	if reqs.is_empty():
		entrance_valid = true
	else:
		for req in reqs:
			var c: String = str(req[0])
			if not _is_code_available(c, world):
				continue
			var l: Dictionary = req[1]
			if not l.is_empty() and not _evaluate_logic(l, world, age_ctx, ctx, entrance_blur):
				continue
			entrance_valid = true
			break
			
	if entrance_valid:
		if not rule.has("logic") or _evaluate_logic(rule["logic"], world, age_ctx, ctx, logic_blur):
			_macro_in_progress.erase("marker:" + key)
			return true
			
	_macro_in_progress.erase("marker:" + key)
	return false

func is_code_reachable_in_current_marker(target_code: String, world: int) -> bool:
	target_code = target_code.strip_edges()
	if target_code.is_empty():
		return true
	_ensure_reach(world)
	return _codes_for_world(world).has(target_code)

func is_game_reachable(game: String, world: int) -> bool:
	var target: String = game.strip_edges().to_upper()
	if target.is_empty():
		return true
	_ensure_reach(world)
	if _games_for_world(world).has(target):
		return true
	if _tracker_cache == null:
		_tracker_cache = get_tree().get_first_node_in_group("item_tracker")
	if _tracker_cache and _tracker_cache.has_method("_get_setting_value_for_world"):
		var games_setting: String = str(_tracker_cache._get_setting_value_for_world("games")).strip_edges().to_upper()
		if games_setting == "OOTMM" or games_setting == target:
			return true
	return false

func is_region_reachable(region: String, world: int) -> bool:
	region = region.strip_edges()
	if region.is_empty():
		return true
	_ensure_reach(world)
	if _rc_regions_by_world.get(world, {}).has(region):
		return true
	var producers: Array = _region_producers.get(region, [])
	for producer_variant in producers:
		var producer_m: String = str(producer_variant)
		if is_marker_reachable(producer_m, world):
			return true
	return not _region_incoming.has(region) or (_region_incoming[region] as Array).is_empty()

func is_location_reachable(loc_name: String, world: int, game: String = "") -> bool:
	loc_name = str(loc_name).strip_edges()
	if loc_name.is_empty():
		return true
	var prepared: bool = is_reach_prepared(world)
	var key: String = str(world) + "|" + game.strip_edges().to_upper() + "|" + loc_name
	var cached: Array = _get_cached_leaf(_location_cache, key)
	if cached[0]:
		return bool(cached[1])
	var ctx: Dictionary = _make_eval_ctx(prepared)
	var result: bool = _compute_location_reachable(loc_name, world, game, ctx)
	if prepared:
		_store_leaf_cache(_location_cache, key, result, ctx.deps)
	return result

func _compute_location_reachable(loc_name: String, world: int, game: String, ctx: Dictionary) -> bool:
	_ensure_reach(world)
	var games_setting: String = ""
	if _tracker_cache and _tracker_cache.has_method("_get_setting_value_for_world"):
		games_setting = str(_tracker_cache._get_setting_value_for_world("games")).strip_edges().to_lower()
	var is_oot_active: bool = (games_setting == "oot" or games_setting == "ootmm")
	var is_mm_active: bool = (games_setting == "mm" or games_setting == "ootmm")
	var is_rule_valid = func(r: Dictionary) -> bool:
		if r.has("game"):
			var rule_game: String = str(r["game"]).strip_edges().to_lower()
			if rule_game == "oot" and not is_oot_active:
				return false
			if rule_game == "mm" and not is_mm_active:
				return false
		return true
	var rule: Dictionary = {}
	var game_upper: String = game.strip_edges().to_upper()
	if game_upper == "OOT":
		var search_name: String = loc_name
		if not search_name.begins_with("OoT ") and not search_name.begins_with("OOT "):
			search_name = "OoT " + loc_name
		var r: Dictionary = _loc_rules.get(search_name, {})
		if not r.is_empty() and is_rule_valid.call(r):
			rule = r
	elif game_upper == "MM":
		var search_name: String = loc_name
		if not search_name.begins_with("MM ") and not search_name.begins_with("mm "):
			search_name = "MM " + loc_name
		var r: Dictionary = _loc_rules.get(search_name, {})
		if not r.is_empty() and is_rule_valid.call(r):
			rule = r
	if rule.is_empty():
		var r: Dictionary = _loc_rules.get(loc_name, {})
		if not r.is_empty() and is_rule_valid.call(r):
			rule = r
	if rule.is_empty():
		var has_explicit_prefix: bool = (
			loc_name.begins_with("OoT ") or loc_name.begins_with("OOT ") or
			loc_name.begins_with("MM ") or loc_name.begins_with("mm ")
		)
		if not has_explicit_prefix:
			if is_oot_active and not is_mm_active:
				var r: Dictionary = _loc_rules.get("OoT " + loc_name, {})
				if not r.is_empty() and is_rule_valid.call(r):
					rule = r
			elif is_mm_active and not is_oot_active:
				var r: Dictionary = _loc_rules.get("MM " + loc_name, {})
				if not r.is_empty() and is_rule_valid.call(r):
					rule = r
			elif is_oot_active and is_mm_active:
				var r_oot: Dictionary = _loc_rules.get("OoT " + loc_name, {})
				if not r_oot.is_empty() and is_rule_valid.call(r_oot):
					rule = r_oot
				else:
					var r_mm: Dictionary = _loc_rules.get("MM " + loc_name, {})
					if not r_mm.is_empty() and is_rule_valid.call(r_mm):
						rule = r_mm
	if rule.is_empty():
		return false
	var parent_marker: String = _location_to_marker.get(loc_name, "")
	var age_ctx: String = _get_age_context(parent_marker)
	var modes: Array = _blur_modes(world, ctx)
	var entrance_blur: int = int(modes[0])
	var logic_blur: int = int(modes[1])
	var entrance_valid: bool = false
	if not rule.has("entrance"):
		entrance_valid = true
	else:
		_record_dep(ctx, "reach:" + str(world))
		for ent in _as_array(rule["entrance"]):
			var c: String = _ent_code_of(ent)
			if c.is_empty():
				continue
			if not _is_code_available(c, world):
				continue
			var l: Dictionary = _ent_logic_of(ent)
			if not l.is_empty() and not _evaluate_logic(l, world, age_ctx, ctx, entrance_blur):
				continue
			entrance_valid = true
			break
	if not entrance_valid:
		return false
	if rule.has("logic"):
		if not _evaluate_logic(rule["logic"], world, age_ctx, ctx, logic_blur):
			return false
	return true

func is_quick_jump_reachable(qj_name: String, world: int) -> bool:
	qj_name = qj_name.strip_edges()
	if qj_name.is_empty():
		return true
	_ensure_reach(world)
	if not _qj_rules.has(qj_name):
		return true
	return is_marker_reachable(qj_name, world)

func _record_condition_primitives(v: Variant, ctx: Dictionary, world: int) -> void:
	if v is Dictionary:
		if v.has("name"):
			_record_dep(ctx, "item:" + str(v["name"]).strip_edges())
		if v.has("location_item"):
			_record_dep(ctx, "item:" + str(v["location_item"]).strip_edges())
		if v.has("location"):
			_record_dep(ctx, "location:" + str(v["location"]).strip_edges() + "|" + str(world))
		if v.has("setting"):
			_record_dep(ctx, "setting:" + str(v["setting"]).strip_edges())
		if _scan_has_reach_key(v, REACH_CONDITION_KEYS):
			_record_dep(ctx, "reach:" + str(world))
		for k in v:
			_record_condition_primitives(v[k], ctx, world)
	elif v is Array:
		for item in v:
			_record_condition_primitives(item, ctx, world)

func _evaluate_logic(
	condition: Variant, world: int, age_context: String = "any",
	ctx: Variant = null, blur_mode: int = BLUR_NONE
) -> bool:
	if ctx == null:
		ctx = _make_eval_ctx(true)
	if not ctx.has("local"):
		ctx["local"] = {}
	if not ctx.has("commit"):
		ctx["commit"] = true
	if not ctx.has("deps"):
		ctx["deps"] = {}
	if not _tracker_cache:
		_tracker_cache = get_tree().get_first_node_in_group("item_tracker")
	if not _tracker_cache:
		return false
	if condition is Dictionary:
		if condition.has("macro"):
			var mname: String = str(condition["macro"]).strip_edges()
			var param_val: String = str(condition.get("param", "")).strip_edges()
			var is_age_macro: bool = (mname == "is_adult_oot" or mname == "is_child_oot")
			if is_age_macro and blur_mode >= BLUR_DIRECT:
				return true
			if blur_mode == BLUR_NONE:
				if age_context == "child" and mname == "is_adult_oot":
					return false
				if age_context == "adult" and mname == "is_child_oot":
					return false
			var child_blur: int = BLUR_NONE if blur_mode == BLUR_DIRECT else blur_mode
			return _eval_macro_node(mname, world, age_context, param_val, ctx, child_blur)
		if condition.has("and"):
			for sub in _as_array(condition["and"]):
				if not _evaluate_logic(sub, world, age_context, ctx, blur_mode):
					return false
			return true
		if condition.has("or"):
			for sub in _as_array(condition["or"]):
				if _evaluate_logic(sub, world, age_context, ctx, blur_mode):
					return true
			return false
		if condition.has("not"):
			var nv: Variant = condition["not"]
			if nv is Array:
				for sub in nv:
					if not _evaluate_logic(sub, world, age_context, ctx, blur_mode):
						return true
				return false
			return not _evaluate_logic(nv, world, age_context, ctx, blur_mode)
		if condition.has("entrance_prefix"):
			_record_dep(ctx, "reach:" + str(world))
			var prefix: String = str(condition["entrance_prefix"]).strip_edges()
			if prefix == "OOT_":
				return _games_for_world(world).has("OOT")
			if prefix == "MM_":
				return _games_for_world(world).has("MM")
			for c in _codes_for_world(world).keys():
				if str(c).begins_with(prefix):
					return true
			return false
		if condition.has("entrance_unshuffled"):
			_record_dep(ctx, "reach:" + str(world))
			return evaluate_entrance_unshuffled(condition["entrance_unshuffled"], world)
		if condition.has("entrance"):
			_record_dep(ctx, "reach:" + str(world))
			var ent_list: Array = _as_array(condition["entrance"])
			if ent_list.is_empty():
				return true
			for ent in ent_list:
				var c: String = _ent_code_of(ent)
				if c.is_empty():
					continue
				if not _is_code_available(c, world):
					continue
				var l: Dictionary = _ent_logic_of(ent)
				if not l.is_empty() and not _evaluate_logic(l, world, age_context, ctx, blur_mode):
					continue
				return true
			return false
		if condition.has("boss"):
			_record_dep(ctx, "reach:" + str(world))
			var boss_code: String = str(condition["boss"]).strip_edges()
			if boss_code.is_empty():
				return false
			if not _is_code_available(boss_code, world):
				return false
			var target_code: String = _resolve_code(boss_code, world)
			var kill_macro: String = BOSS_KILL_MACROS.get(target_code, "")
			if kill_macro.is_empty():
				kill_macro = BOSS_KILL_MACROS.get(boss_code, "")
			if kill_macro.is_empty():
				return false
			return _eval_macro_node(kill_macro, world, age_context, "", ctx, blur_mode)
		if condition.has("game"):
			_record_dep(ctx, "reach:" + str(world))
			return is_game_reachable(str(condition["game"]), world)
		if condition.has("time_flow_oot"):
			_record_dep(ctx, "reach:" + str(world))
			return _has_oot_time_flow(world)
		if condition.has("song_event"):
			_record_dep(ctx, "reach:" + str(world))
			var event_id: String = str(condition["song_event"])
			var is_mm: bool = MM_SONG_EVENTS_SET.has(event_id)
			var macros_array: Array = _song_macros_mm_arr if is_mm else _song_macros_oot_arr
			var song_idx: int = -1
			if _tracker_cache.has_method("get_song_event_song_index"):
				song_idx = int(_tracker_cache.get_song_event_song_index(event_id, world))
			if song_idx >= 0 and song_idx < macros_array.size():
				return _evaluate_logic({"macro": macros_array[song_idx]}, world, age_context, ctx, blur_mode)
			return true
		if condition.has("setting") and not condition.has("operator") and not condition.has("param"):
			var setting_name: String = str(condition["setting"]).strip_edges()
			_record_dep(ctx, "setting:" + setting_name)
			var expected_value: Variant = condition.get("value", null)
			if expected_value is String:
				expected_value = str(expected_value).strip_edges()
			var setting_key: String = str(world) + "|" + setting_name
			var actual_value: Variant
			if _settings_cache.has(setting_key):
				actual_value = _settings_cache[setting_key]
			else:
				if _tracker_cache.has_method("_get_setting_value_for_world"):
					actual_value = _tracker_cache._get_setting_value_for_world(setting_name, world)
				else:
					actual_value = null
				_settings_cache[setting_key] = actual_value
			return _setting_matches(actual_value, expected_value)
		if condition.has("setting") and condition.has("operator") and condition.has("value"):
			var setting_name2: String = str(condition["setting"]).strip_edges()
			_record_dep(ctx, "setting:" + setting_name2)
			var op: String = str(condition["operator"]).strip_edges()
			var expected_val: Variant = condition["value"]
			var setting_key2: String = str(world) + "|" + setting_name2
			var actual_val: Variant
			if _settings_cache.has(setting_key2):
				actual_val = _settings_cache[setting_key2]
			else:
				if _tracker_cache.has_method("_get_setting_value_for_world"):
					actual_val = _tracker_cache._get_setting_value_for_world(setting_name2, world)
				else:
					actual_val = null
				_settings_cache[setting_key2] = actual_val
			if actual_val == null:
				return false
			var num_actual: float = 0.0
			if str(actual_val).is_valid_float():
				num_actual = float(actual_val)
			var num_expected: float = 0.0
			if str(expected_val).is_valid_float():
				num_expected = float(expected_val)
			match op:
				"<=": return num_actual <= num_expected
				">=": return num_actual >= num_expected
				"<": return num_actual < num_expected
				">": return num_actual > num_expected
				"==", "=": return num_actual == num_expected
				"!=": return num_actual != num_expected
				_: return false
	_record_condition_primitives(condition, ctx, world)
	var old_world: int = _tracker_cache.current_world
	_tracker_cache.current_world = world
	var result: bool = bool(_tracker_cache._evaluate_item_condition(condition, {}))
	_tracker_cache.current_world = old_world
	return result

func _setting_matches(actual_value: Variant, expected_value: Variant) -> bool:
	if expected_value == null:
		if actual_value == null or actual_value == false:
			return false
		if actual_value is Array:
			return not (actual_value as Array).is_empty()
		return true

	if expected_value is Array:
		for ev in expected_value:
			if _setting_matches(actual_value, ev):
				return true
		return false

	if expected_value is Dictionary and expected_value.has("not"):
		for ev in _as_array(expected_value["not"]):
			if _setting_matches(actual_value, ev):
				return false
		return true

	if actual_value is Array:
		for av in actual_value:
			if str(av).strip_edges().to_lower() == str(expected_value).strip_edges().to_lower():
				return true
		return false

	return str(actual_value).strip_edges().to_lower() == str(expected_value).strip_edges().to_lower()

func register_quick_jump_code(qj_name: String, code: String) -> void:
	_qj_code_by_name[qj_name.strip_edges()] = code.strip_edges()

func register_root_code(code: String) -> void:
	var c := code.strip_edges()
	if not c.is_empty():
		_root_codes[c] = true

func begin_suppress_compute() -> void:
	_suppress_compute_depth += 1

func end_suppress_compute() -> void:
	_suppress_compute_depth -= 1
	if _suppress_compute_depth < 0:
		_suppress_compute_depth = 0

func _is_compute_suppressed() -> bool:
	return _suppress_compute_depth > 0
