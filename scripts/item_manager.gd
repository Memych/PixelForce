extends Node

var items: Array = []
var items_by_name: Dictionary = {}
var item_texture_cache: Dictionary = {}

func _ready() -> void:
	_load_items()

func _load_items() -> void:
	const ITEMS_PATH = "res://data/items.json"
	
	items.clear()
	items_by_name.clear()
	item_texture_cache.clear()
	
	if not FileAccess.file_exists(ITEMS_PATH):
		print("Items file not found: ", ITEMS_PATH)
		return
	
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		print("Failed to open items file: ", ITEMS_PATH)
		return
	
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		print("Invalid items JSON format")
		return
	
	for row in parsed:
		if not (row is Array) or row.size() < 1:
			continue
		var name_str: String = row[0]
		var image_path: String = row[1] if row.size() >= 2 else ""
		items.append([name_str, image_path])
		items_by_name[name_str] = image_path

func has_item(item_name: String) -> bool:
	if item_name == "" or item_name == "(unknown)":
		return false
	return items_by_name.has(item_name)

func get_item_image(item_name: String) -> String:
	return items_by_name.get(item_name, "")

func get_item_texture(item_name: String) -> Texture2D:
	var path: String = get_item_image(item_name)
	if path.is_empty():
		return null
	
	if item_texture_cache.has(path):
		return item_texture_cache[path]
	
	if not ResourceLoader.exists(path):
		return null
	
	var tex: Texture2D = load(path)
	item_texture_cache[path] = tex
	return tex
