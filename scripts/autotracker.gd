extends Node

@onready var host_input: LineEdit = %HostInput
@onready var port_input: SpinBox = %PortInput
@onready var connect_button: Button = %ConnectButton
@onready var status_indicator: TextureRect = %StatusIndicator
@onready var status_label: Label = %StatusLabel
@onready var log_output: TextEdit = %LogOutput
@onready var clear_log_button: Button = %ClearLogButton
@onready var load_button: Button = %LoadButton
@onready var save_button: Button = %SaveButton
@onready var clear_button: Button = %ClearButton

var _tex_green: Texture2D = preload("res://images/indicator_green.png")
var _tex_yellow: Texture2D = preload("res://images/indicator_yellow.png")
var _tex_red: Texture2D = preload("res://images/indicator_red.png")

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }
var connection_state: ConnectionState = ConnectionState.DISCONNECTED
var mem_listening: bool = false
var mem_connected: bool = false

var ws_peer: WebSocketPeer = WebSocketPeer.new()
var current_client_id: String = ""
var daemon_host: String = "127.0.0.1"
var daemon_port: int = 39278
var debug_raw: bool = false

var tcp_server: TCPServer = TCPServer.new()
var peer: StreamPeerTCP = null
var request_queue: Array = []
var pending_request: Dictionary = {}
const MEM_PORT: int = 13249
const QUEUE_MAX: int = 300

var poll_timer: Timer = null
var poll_interval: float = 0.2
var last_read_values: Dictionary = {}
var last_poll_time: float = 0.0
var poll_timeout: float = 5.0

const EXT_SAVE_START: int = 0x8011B400
const EXT_SAVE_SIZE: int = 0x180
const XFLAG_OV: int = 0x10

var marked: Dictionary = {}
var pending_mem: Dictionary = {}
const MEM_DEDUP_WINDOW: float = 2.0

var current_player: String = ""
var current_session: String = ""
var current_world_id: int = 1

var _unknown_locs: Dictionary = {}

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

func _ready() -> void:
	host_input.text = "127.0.0.1"
	port_input.value = 39278
	
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	clear_log_button.pressed.connect(_on_clear_log_pressed)
	
	poll_timer = Timer.new()
	poll_timer.wait_time = poll_interval
	poll_timer.timeout.connect(_poll_memory)
	add_child(poll_timer)
	
	_refresh_status()
	load_button.tooltip_text = "Load spoiler log or tracker save (F1)"
	save_button.tooltip_text = "Save tracker state (F2)"
	clear_button.tooltip_text = "Reset all progress (F3)"

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _is_log_loaded() -> bool:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("get_log_data"):
		var log_data = main_node.get_log_data()
		return not log_data.is_empty() and log_data.has("version") and log_data["version"] != "?"
	return false

func _get_worlds_count() -> int:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("get_worlds_count"):
		return main_node.get_worlds_count()
	return 1

func _mark_location_in_tracker(raw_loc_name: String, _item_name: String, source: String) -> void:
	if not _is_log_loaded():
		_log(_line(["Tracker sync: skipped", "no spoiler log loaded"]))
		return
	
	var game: String = ""
	var loc_name: String = ""
	
	if raw_loc_name.begins_with("OOT_"):
		game = "OoT"
		loc_name = _snake_to_title(raw_loc_name.substr(4))
	elif raw_loc_name.begins_with("MM_"):
		game = "MM"
		loc_name = _snake_to_title(raw_loc_name.substr(3))
	elif raw_loc_name.begins_with("OOT "):
		game = "OoT"
		loc_name = raw_loc_name.substr(4).strip_edges()
	elif raw_loc_name.begins_with("MM "):
		game = "MM"
		loc_name = raw_loc_name.substr(3).strip_edges()
	else:
		_log(_line(["Tracker sync: skipped", "unknown location format: %s" % raw_loc_name]))
		return
	
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node == null or not main_node.has_method("set_location_checked_by_name"):
		_log(_line(["Tracker sync: failed", "main scene not found"]))
		return
	
	var world: int = current_world_id
	var worlds_count: int = _get_worlds_count()
	if world < 1 or world > worlds_count:
		world = 1
	
	if main_node.has_method("is_location_checked"):
		if main_node.is_location_checked(loc_name, world):
			return
	
	if not _location_exists_in_db(main_node, game, loc_name, world):
		if not _unknown_locs.has(raw_loc_name):
			_unknown_locs[raw_loc_name] = true
			_log(_line(["Tracker sync: skipped", "location not in DB", "%s" % game, loc_name, "world %d" % world]))
		return
	
	main_node.set_location_checked_by_name(game, loc_name, world, true, false)
	_log(_line(["Tracker sync: marked", loc_name, game, "world %d" % world, "via %s" % source]))

func _snake_to_title(s: String) -> String:
	var out: String = ""
	for word in s.to_lower().split(" "):
		if word.length() > 0:
			out += word[0].to_upper() + word.substr(1) + " "
	return out.strip_edges()

func _location_exists_in_db(main_node: Node, game: String, loc_name: String, world: int) -> bool:
	var g: String = game.to_upper()
	var n: String = loc_name.to_lower()
	for d in main_node.get_all_data():
		if int(d.get("world", 1)) == world \
			and str(d.get("game", "")).to_upper() == g \
			and str(d.get("name", "")).to_lower() == n:
			return true
	return false

func _process(delta: float) -> void:
	if connection_state == ConnectionState.CONNECTED:
		ws_peer.poll()
		var st = ws_peer.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws_peer.get_available_packet_count() > 0:
				var text = ws_peer.get_packet().get_string_from_utf8()
				_handle_ws_message(text)
		elif st == WebSocketPeer.STATE_CLOSED:
			_log("WebSocket connection closed")
			connection_state = ConnectionState.DISCONNECTED
			current_client_id = ""
			_refresh_status()
	
	if mem_connected and peer != null:
		last_poll_time += delta
		if last_poll_time > poll_timeout:
			_log("Memory adapter timeout")
			_stop_memory()
		else:
			_mem_process()
	
	if not pending_mem.is_empty():
		var now = _now()
		for loc in pending_mem.keys():
			if now - pending_mem[loc]["t"] > MEM_DEDUP_WINDOW:
				pending_mem.erase(loc)
				if not marked.has(loc):
					marked[loc] = {"item": "(vanilla)", "source": "mem"}
					_log("Check cleared (memory, vanilla): %s" % loc)
					_mark_location_in_tracker(loc, "(vanilla)", "memory")

func _on_connect_pressed() -> void:
	if connection_state != ConnectionState.DISCONNECTED or mem_listening or mem_connected:
		_stop_all()
	else:
		daemon_host = host_input.text.strip_edges()
		daemon_port = int(port_input.value)
		_start_memory_server()
		_fetch_clients_list()

func _stop_all() -> void:
	_stop_memory()
	if ws_peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws_peer.close()
	connection_state = ConnectionState.DISCONNECTED
	current_client_id = ""
	marked.clear()
	pending_mem.clear()
	_refresh_status()
	_log("Disconnected from all sources")

func _stop_memory() -> void:
	if peer != null:
		peer.disconnect_from_host()
		peer = null
	tcp_server.stop()
	mem_listening = false
	mem_connected = false
	request_queue.clear()
	pending_request.clear()
	last_read_values.clear()
	last_poll_time = 0.0
	poll_timer.stop()
	_refresh_status()

func _start_memory_server() -> void:
	var err = tcp_server.listen(MEM_PORT, "127.0.0.1")
	if err != OK:
		_log("Memory adapter failed to listen on %d: %s" % [MEM_PORT, error_string(err)])
	else:
		mem_listening = true
		_log("Memory adapter listening on 127.0.0.1:%d" % MEM_PORT)
		_refresh_status()

func _mem_process() -> void:
	if mem_listening and tcp_server.is_connection_available():
		var new_peer = tcp_server.take_connection()
		if new_peer != null:
			peer = new_peer
			mem_connected = true
			last_poll_time = 0.0
			request_queue.clear()
			last_read_values.clear()
			poll_timer.start()
			_log("Memory adapter: emulator connected")
			_refresh_status()
	
	peer.poll()
	var status = peer.get_status()
	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		_log("Memory adapter: emulator disconnected")
		_stop_memory()
		return
	
	if not pending_request.is_empty():
		var available = peer.get_available_bytes()
		if available >= pending_request["expected_bytes"]:
			var response = _read_response(pending_request["expected_bytes"])
			last_poll_time = 0.0
			if pending_request.has("callback") and not pending_request["callback"].is_null():
				pending_request["callback"].call(response)
			pending_request.clear()
		elif available > 0:
			_log("Memory protocol error: expected %d, got %d" % [pending_request["expected_bytes"], available])
			_stop_memory()
			return
	
	if request_queue.size() > 0 and pending_request.is_empty():
		var req = request_queue.pop_front()
		peer.put_u8(req["op"])
		peer.put_32(req["addr"])
		pending_request = {
			"op": req["op"],
			"addr": req["addr"],
			"expected_bytes": req["expected_bytes"],
			"callback": req.get("callback", Callable())
		}

func _poll_memory() -> void:
	if not mem_connected or request_queue.size() >= QUEUE_MAX:
		return
	var offset = 0
	while offset < EXT_SAVE_SIZE:
		if request_queue.size() >= QUEUE_MAX:
			return
		var addr = EXT_SAVE_START + offset
		request_queue.append({"op": 4, "addr": addr, "expected_bytes": 4, "callback": _on_extended_save_read.bind(addr)})
		offset += 4

func _read_response(bytes: int) -> int:
	if peer == null: return -1
	if bytes == 1: return peer.get_u8()
	elif bytes == 2: return peer.get_u16()
	elif bytes == 4: return peer.get_u32()
	return -1

func _on_extended_save_read(current_val: int, addr: int) -> void:
	var prev_val = last_read_values.get(addr, -1)
	if prev_val == -1:
		last_read_values[addr] = current_val
		return
	if current_val == prev_val:
		return
	var changed_bits = current_val & ~prev_val
	last_read_values[addr] = current_val
	if changed_bits == 0:
		return
	var word_index = (addr - EXT_SAVE_START) / 4.0
	for bit_pos in range(32):
		if changed_bits & (1 << bit_pos):
			var flag_index = (word_index * 32) + bit_pos
			var key = ((XFLAG_OV << 24) | (flag_index & 0xFFFF)) & 0xFFFFFFFF
			_trigger_memory_check(key)

func _trigger_memory_check(key: int) -> void:
	_log(_line(["Memory check: key 0x%08X" % key, "mark manually if vanilla"]))

func _fetch_clients_list() -> void:
	connection_state = ConnectionState.CONNECTING
	_refresh_status()
	_log("Requesting connected games list...")
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_clients_list_received.bind(http))
	var url = "http://%s:%d/clients" % [daemon_host, daemon_port]
	if http.request(url) != OK:
		_log("HTTP request failed")
		connection_state = ConnectionState.DISCONNECTED
		_refresh_status()

func _on_clients_list_received(_result: int, response_code: int, _headers: Array, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free()
	if response_code != 200:
		_log("Daemon not responding (HTTP %d). WS disabled, memory-only mode." % response_code)
		connection_state = ConnectionState.DISCONNECTED
		_refresh_status()
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		connection_state = ConnectionState.DISCONNECTED
		_refresh_status()
		return
	var data = json.data
	if not data.has("clients") or data["clients"].size() == 0:
		_log("No connected games yet. WS will not attach until a game starts.")
		connection_state = ConnectionState.DISCONNECTED
		_refresh_status()
		return
	current_client_id = data["clients"][0]["id"]
	_log("Game found! Client ID: %s" % current_client_id)
	_connect_to_websocket()

func _connect_to_websocket() -> void:
	ws_peer = WebSocketPeer.new()
	var ws_url = "ws://%s:%d/clients/%s/events" % [daemon_host, daemon_port, current_client_id]
	if ws_peer.connect_to_url(ws_url) != OK:
		_log("WebSocket connection failed")
		connection_state = ConnectionState.DISCONNECTED
		_refresh_status()
		return
	connection_state = ConnectionState.CONNECTED
	_refresh_status()
	_log("WebSocket connected! Waiting for game events...")

func _handle_ws_message(text: String) -> void:
	if debug_raw:
		_log("RAW: %s" % text)
	var json = JSON.new()
	if json.parse(text) != OK:
		return
	var msg = json.data
	if not msg.has("type"):
		return
	match msg["type"]:
		"GAME_START": _handle_game_start(msg)
		"GAME_END": _handle_game_end(msg)
		"INFO_ITEM": _handle_info_item(msg)
		"INFO_ENTRANCE": _handle_info_entrance(msg)

func _line(parts: Array) -> String:
	var out: String = ""
	for i in range(parts.size()):
		if i > 0:
			out += " | "
		out += str(parts[i])
	return out

func _handle_game_start(msg: Dictionary) -> void:
	marked.clear()
	pending_mem.clear()
	_unknown_locs.clear()
	current_player = msg.get("playerName", "")
	current_session = msg.get("sessionId", "")
	current_world_id = int(msg.get("worldId", 1))
	_log(_line([
		"Game started: %s" % current_player,
		"Session: %s" % current_session.substr(0, 8),
		"World: %d" % current_world_id
	]))

func _handle_game_end(_msg: Dictionary) -> void:
	_log("Game ended")
	current_player = ""
	current_session = ""

func _handle_info_item(msg: Dictionary) -> void:
	var item: String = msg.get("item", "")
	var loc: String = msg.get("location", "")
	var is_self: bool = msg.get("self", false)
	var source: String = "self" if is_self else "other player"
	if loc.is_empty():
		_log(_line(["Item collected: %s" % item, "Location: unknown", source]))
		return
	if pending_mem.has(loc):
		pending_mem.erase(loc)
	if marked.has(loc):
		if marked[loc]["source"] == "mem":
			marked[loc]["item"] = item
		return
	marked[loc] = {"item": item, "source": "ws"}
	_log(_line(["Item collected: %s" % item, "Location: %s" % loc, source]))
	_mark_location_in_tracker(loc, item, "WebSocket")

func _handle_info_entrance(msg: Dictionary) -> void:
	var entrance: String = msg.get("entrance", "")
	var original: String = msg.get("original", "")
	var age: String = msg.get("age", "")
	if entrance.is_empty() or entrance == "UNKNOWN":
		return
		
	if original.is_empty():
		_log(_line(["Entrance: %s" % entrance, age.to_lower()]))
	else:
		_log(_line(["Entrance: %s to %s" % [original, entrance], age.to_lower()]))
		
	var map_node = get_tree().get_first_node_in_group("map_tab")
	if map_node and map_node.has_method("switch_map_by_entrance"):
		map_node.switch_map_by_entrance(entrance)

func _refresh_status() -> void:
	match connection_state:
		ConnectionState.DISCONNECTED:
			if mem_connected:
				status_indicator.texture = _tex_yellow
				status_label.text = "Memory only"
				connect_button.text = "Disconnect"
			elif mem_listening:
				status_indicator.texture = _tex_yellow
				status_label.text = "Waiting (memory listening)"
				connect_button.text = "Disconnect"
			else:
				status_indicator.texture = _tex_red
				status_label.text = "Disconnected"
				connect_button.text = "Connect"
		ConnectionState.CONNECTING:
			status_indicator.texture = _tex_yellow
			status_label.text = "Connecting..."
			connect_button.text = "Cancel"
		ConnectionState.CONNECTED:
			status_indicator.texture = _tex_green
			status_label.text = "Connected (WS + Memory)" if mem_connected else "Connected (WebSocket)"
			connect_button.text = "Disconnect"

func _log(msg: String) -> void:
	if log_output:
		var time_str = Time.get_time_string_from_system()
		log_output.text += "[%s] %s\n" % [time_str, msg]
		log_output.scroll_vertical = log_output.get_line_count()

func _on_load_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("_on_load_pressed"):
		main_node._on_load_pressed()

func _on_save_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("_on_save_pressed"):
		main_node._on_save_pressed()

func _on_clear_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("main_scene")
	if main_node and main_node.has_method("_show_reset_confirmation"):
		main_node._show_reset_confirmation()

func _on_clear_log_pressed() -> void:
	if log_output:
		log_output.clear()
		_log("Log cleared.")
