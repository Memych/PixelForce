extends PanelContainer
signal check_changed(row_btn: PanelContainer, pressed: bool)

@onready var name_label: Label = %NameLabel
@onready var player_label: Label = %PlayerLabel
@onready var item_label: Label = %ItemLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var check_box: Button = %CheckBox

var _tex_checked: Texture2D = preload("res://images/checkbox_checked.png")
var _tex_unchecked: Texture2D = preload("res://images/checkbox_unchecked.png")

var _main_node: Control = null
var _cached_item_tex: Texture2D = null
var _is_known_item: bool = false
var _empty_stylebox: StyleBoxEmpty = StyleBoxEmpty.new()

var _loc_name: String = ""
var _item: String = ""
var _checked: bool = false
var _world: int = 1
var _player: int = 0
var _mode: String = ""
var _player_color_hex: String = "#ffffff"

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main_scene")
	
	check_box.flat = true
	check_box.text = ""
	check_box.add_theme_stylebox_override("normal", _empty_stylebox)
	check_box.add_theme_stylebox_override("pressed", _empty_stylebox)
	check_box.add_theme_stylebox_override("hover", _empty_stylebox)
	check_box.add_theme_stylebox_override("focus", _empty_stylebox)
	check_box.add_theme_stylebox_override("disabled", _empty_stylebox)
	check_box.toggled.connect(_on_check_toggled)

func update_via_meta() -> void:
	_loc_name = get_meta("loc_name", "  ")
	_item = str(get_meta("loc_item", "  ")).strip_edges()
	var new_checked: bool = bool(get_meta("checked", false))
	_world = int(get_meta("world", 1))
	_player = int(get_meta("player", 0))
	_mode = str(get_meta("mode", "  "))
	_player_color_hex = str(get_meta("player_color_hex", "#ffffff"))
	
	_check_and_cache_item()
	
	if _checked != new_checked:
		_checked = new_checked
		check_box.button_pressed = _checked
		
	refresh()

func _check_and_cache_item() -> void:
	_is_known_item = false
	_cached_item_tex = null
	
	if _item == "" or _item == "(unknown)":
		return
		
	if _main_node == null:
		_main_node = get_tree().get_first_node_in_group("main_scene")
		
	if _main_node and _main_node.has_method("has_item"):
		if _main_node.has_item(_item):
			_is_known_item = true
			if _main_node.has_method("get_item_texture"):
				_cached_item_tex = _main_node.get_item_texture(_item)

func refresh() -> void:
	name_label.text = _loc_name
	
	var show_prefix: bool = (_mode == "multi" and _player > 0)
	
	if _item == "" or _item == "(unknown)":
		player_label.text = ""
		player_label.visible = false
		item_label.text = "(unknown)"
		item_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		icon_rect.visible = false
		icon_rect.texture = null
	elif show_prefix:
		player_label.text = "P%d —" % _player
		player_label.visible = true
		player_label.add_theme_color_override("font_color", Color(_player_color_hex))
		item_label.text = _item
		var item_col: Color = Color(0.55, 1.0, 0.55) if (_is_known_item and _checked) else Color(1, 1, 1)
		if not _is_known_item:
			item_col = Color(0.6, 0.6, 0.6)
		item_label.add_theme_color_override("font_color", item_col)
	else:
		player_label.text = ""
		player_label.visible = false
		item_label.text = _item
		var item_col: Color = Color(0.55, 1.0, 0.55) if (_is_known_item and _checked) else Color(1, 1, 1)
		if not _is_known_item:
			item_col = Color(0.6, 0.6, 0.6)
		item_label.add_theme_color_override("font_color", item_col)
		
	if _is_known_item and _cached_item_tex:
		icon_rect.visible = true
		icon_rect.texture = _cached_item_tex
	else:
		icon_rect.visible = false
		icon_rect.texture = null
		
	var name_col: Color = Color(0.55, 0.95, 0.55) if _checked else Color(1, 1, 1)
	name_label.add_theme_color_override("font_color", name_col)
	
	check_box.icon = _tex_checked if _checked else _tex_unchecked
	check_box.button_pressed = _checked

func _on_check_toggled(pressed: bool) -> void:
	if _checked == pressed: return
	_checked = pressed
	set_meta("checked", _checked)
	var src: Dictionary = get_meta("source_dict", {})
	if not src.is_empty():
		src["checked"] = _checked
	refresh()
	check_changed.emit(self, pressed)
