extends GraphNode
class_name MockNode

var node_color: Color = Color(0.2, 0.2, 0.2, 0.8)
var graphmock_id: String = ""
# Array of dictionaries holding row data
var items: Array[Dictionary] = []

var has_top_port: bool = false
var has_bottom_port: bool = false
var top_port_color: Color = Color.WHITE
var bottom_port_color: Color = Color.WHITE

var _top_satellite: GraphNode = null
var _bottom_satellite: GraphNode = null
var image_path: String = ""
var base_dir: String = ""
var image_max_height: int = 80

func _ready():
	# Let GraphEdit handle dragging and resizing
	resizable = true
	resize_request.connect(_on_resize_request)
	_update_visuals()
	set_process(true)
	
func _process(_delta):
	_sync_satellites()

func _exit_tree():
	if _top_satellite and is_instance_valid(_top_satellite):
		_top_satellite.queue_free()
		_top_satellite = null
	if _bottom_satellite and is_instance_valid(_bottom_satellite):
		_bottom_satellite.queue_free()
		_bottom_satellite = null

func _sync_satellites():
	if _top_satellite and is_instance_valid(_top_satellite):
		_top_satellite.position_offset = position_offset + Vector2((size.x - _top_satellite.size.x) / 2, -_top_satellite.size.y + 12)
	if _bottom_satellite and is_instance_valid(_bottom_satellite):
		_bottom_satellite.position_offset = position_offset + Vector2((size.x - _bottom_satellite.size.x) / 2, size.y - 12)

func set_has_top_port(enabled: bool):
	has_top_port = enabled
	if enabled:
		if not _top_satellite or not is_instance_valid(_top_satellite):
			_top_satellite = SatelliteNode.new()
			_top_satellite.name = name + "_top"
			if get_parent():
				get_parent().add_child(_top_satellite)
			#top スロットは左ポートのみ
	
			_top_satellite.set_slot(0, true, 0, top_port_color, false, 0, top_port_color)
	else:
		if _top_satellite and is_instance_valid(_top_satellite):
			_top_satellite.queue_free()
			_top_satellite = null

func set_has_bottom_port(enabled: bool):
	has_bottom_port = enabled
	if enabled:
		if not _bottom_satellite or not is_instance_valid(_bottom_satellite):
			_bottom_satellite = SatelliteNode.new()
			_bottom_satellite.name = name + "_bottom"
			if get_parent():
				get_parent().add_child(_bottom_satellite)
			#bottom スロットは右ポートのみ
			_bottom_satellite.set_slot(0, false, 0, bottom_port_color, true, 0, bottom_port_color)
	else:
		if _bottom_satellite and is_instance_valid(_bottom_satellite):
			_bottom_satellite.queue_free()
			_bottom_satellite = null

func set_top_port_color(color: Color):
	top_port_color = color
	if _top_satellite and is_instance_valid(_top_satellite):
		#_top_satellite.set_slot(0, true, 0, color, true, 0, color)
		#top スロットは左ポートのみ

		_top_satellite.set_slot(0, true, 0, color, false, 0, color)

func set_bottom_port_color(color: Color):
	bottom_port_color = color
	if _bottom_satellite and is_instance_valid(_bottom_satellite):
		#_bottom_satellite.set_slot(0, true, 0, color, true, 0, color)
		#bottom スロットは右ポートのみ

		_bottom_satellite.set_slot(0, false, 0, color, true, 0, color)
	
func _on_resize_request(new_size: Vector2):
	size = new_size

func set_node_title(new_title: String):
	title = new_title

func set_node_color(color: Color):
	node_color = color
	var sb_panel = StyleBoxFlat.new()
	sb_panel.bg_color = color
	sb_panel.border_width_left = 2
	sb_panel.border_width_top = 2
	sb_panel.border_width_right = 2
	sb_panel.border_width_bottom = 2
	sb_panel.border_color = Color(0.1, 0.1, 0.1, 1.0)
	sb_panel.corner_radius_bottom_left = 4
	sb_panel.corner_radius_bottom_right = 4
	sb_panel.corner_radius_top_left = 4
	sb_panel.corner_radius_top_right = 4
	sb_panel.content_margin_left = 8
	sb_panel.content_margin_right = 8
	sb_panel.content_margin_top = 8
	sb_panel.content_margin_bottom = 8
	
	var sb_selected = sb_panel.duplicate()
	sb_selected.border_color = Color(0.8, 0.8, 0.8, 1.0)

	var sb_titlebar = sb_panel.duplicate()
	sb_titlebar.bg_color = color.darkened(0.2)
	sb_titlebar.corner_radius_bottom_left = 0
	sb_titlebar.corner_radius_bottom_right = 0
	sb_titlebar.content_margin_bottom = 4
	
	var sb_titlebar_sel = sb_titlebar.duplicate()
	sb_titlebar_sel.border_color = Color(0.8, 0.8, 0.8, 1.0)

	add_theme_stylebox_override("panel", sb_panel)
	add_theme_stylebox_override("panel_selected", sb_selected)
	add_theme_stylebox_override("titlebar", sb_titlebar)
	add_theme_stylebox_override("titlebar_selected", sb_titlebar_sel)

func to_save_dict() -> Dictionary:
	var saved_items: Array = []
	for item in items:
		var saved_item: Dictionary = item.duplicate(true)
		if saved_item.has("color"):
			saved_item["color"] = _color_to_array(saved_item["color"])
		saved_items.append(saved_item)
	
	return {
		"id": graphmock_id,
		"name": name,
		"title": title,
		"position_offset": _vector2_to_array(position_offset),
		"size": _vector2_to_array(size),
		"node_color": _color_to_array(node_color),
		"items": saved_items,
		"has_top_port": has_top_port,
		"has_bottom_port": has_bottom_port,
		"top_port_color": _color_to_array(top_port_color),
		"bottom_port_color": _color_to_array(bottom_port_color),
		"image_path": image_path,
		"image_max_height": image_max_height
	}

func from_save_dict(data: Dictionary) -> void:
	graphmock_id = str(data.get("id", ""))
	name = str(data.get("name", graphmock_id if graphmock_id != "" else "MockNode"))
	title = str(data.get("title", "ノード"))
	position_offset = _array_to_vector2(data.get("position_offset", [0.0, 0.0]))
	node_color = _array_to_color(data.get("node_color", [0.2, 0.2, 0.2, 0.8]))
	image_path = str(data.get("image_path", ""))
	image_max_height = int(data.get("image_max_height", 80))
	
	items.clear()
	var saved_items = data.get("items", [])
	if saved_items is Array:
		for saved_item in saved_items:
			if saved_item is Dictionary:
				var item: Dictionary = saved_item.duplicate(true)
				if item.has("color"):
					item["color"] = _array_to_color(item["color"])
				else:
					item["color"] = Color.WHITE
				if not item.has("is_input"):
					item["is_input"] = false
				if not item.has("is_output"):
					item["is_output"] = false
				if not item.has("type_annotation"):
					item["type_annotation"] = ""
				if not item.has("prop_type"):
					item["prop_type"] = "string"
				if not item.has("value"):
					item["value"] = "" if item["prop_type"] == "string" else 0.0
				items.append(item)
	
	_update_visuals()
	_rebuild_ui()
	size = _array_to_vector2(data.get("size", size))
	
	has_top_port = data.get("has_top_port", false)
	has_bottom_port = data.get("has_bottom_port", false)
	top_port_color = _array_to_color(data.get("top_port_color", [1.0, 1.0, 1.0, 1.0]))
	bottom_port_color = _array_to_color(data.get("bottom_port_color", [1.0, 1.0, 1.0, 1.0]))
	
	# Delay satellite creation until we are in the tree
	if is_inside_tree():
		set_has_top_port(has_top_port)
		set_has_bottom_port(has_bottom_port)
	else:
		tree_entered.connect(func():
			set_has_top_port(has_top_port)
			set_has_bottom_port(has_bottom_port)
		, CONNECT_ONE_SHOT)

func add_port(port_name: String, is_input: bool, is_output: bool, color: Color = Color.WHITE):
	items.append({
		"type": "port",
		"name": port_name,
		"is_input": is_input,
		"is_output": is_output,
		"color": color
	})
	_rebuild_ui()

func add_property(prop_name: String, prop_type: String = "string"):
	items.append({
		"type": "property",
		"name": prop_name,
		"prop_type": prop_type,
		"is_input": false,
		"is_output": false,
		"color": Color.WHITE,
		"type_annotation": "",
		"value": "" if prop_type == "string" else 0.0
	})
	_rebuild_ui()

func remove_item(index: int):
	if index >= 0 and index < items.size():
		items.remove_at(index)
		_rebuild_ui()

func update_item_port(index: int, port_name: String, is_input: bool, is_output: bool, color: Color):
	if index >= 0 and index < items.size() and items[index]["type"] == "port":
		items[index]["name"] = port_name
		items[index]["is_input"] = is_input
		items[index]["is_output"] = is_output
		items[index]["color"] = color
		_rebuild_ui()

func _rebuild_ui():
	# Clear slots properly before removing children
	for i in range(get_child_count()):
		set_slot(i, false, 0, Color.WHITE, false, 0, Color.WHITE)

	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	var slot_offset = 0
	if image_path != "":
		var tex = load_external_texture(image_path, base_dir)
		if tex:
			var tr = TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size.y = image_max_height
			tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_child(tr)
			set_slot(0, false, 0, Color.WHITE, false, 0, Color.WHITE)
			slot_offset = 1
	
	for i in range(items.size()):
		var item = items[i]
		var child_idx = i + slot_offset
		if item["type"] == "port":
			var label = Label.new()
			label.text = item["name"]
			if item["is_input"] and not item["is_output"]:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			elif item["is_output"] and not item["is_input"]:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			else:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(label)
			
			set_slot(child_idx, 
				item["is_input"], 0, item["color"], 
				item["is_output"], 0, item["color"])
		elif item["type"] == "property":
			var hbox = HBoxContainer.new()
			var label = Label.new()
			
			var display_name = item["name"]
			var type_annot = item.get("type_annotation", "")
			if type_annot != "":
				display_name += ": " + type_annot
			label.text = display_name
			
			label.custom_minimum_size.x = 40
			hbox.add_child(label)
			
			var prop_val = item.get("value", "" if item.get("prop_type", "string") == "string" else 0.0)
			
			if item.get("prop_type", "string") == "string":
				var le = LineEdit.new()
				le.text = str(prop_val)
				le.expand_to_text_length = true
				le.custom_minimum_size.x = 60
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le.text_changed.connect(func(text):
					item["value"] = text
				)
				hbox.add_child(le)
			elif item.get("prop_type", "string") == "number":
				var sb = SpinBox.new()
				sb.min_value = -999999
				sb.max_value = 999999
				sb.step = 0.01
				sb.allow_greater = true
				sb.allow_lesser = true
				sb.value = float(prop_val)
				sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				sb.value_changed.connect(func(val):
					item["value"] = val
				)
				hbox.add_child(sb)
			add_child(hbox)
			
			var is_in = item.get("is_input", false)
			var is_out = item.get("is_output", false)
			var slot_color = item.get("color", Color.WHITE)
			set_slot(child_idx, is_in, 0, slot_color, is_out, 0, slot_color)
			
	# Emit a signal or update size so GraphEdit layout updates
	reset_size()

func _update_visuals():
	set_node_color(node_color)

func set_image_path(new_path: String):
	image_path = new_path
	_rebuild_ui()

func set_image_max_height(new_height: int):
	image_max_height = new_height
	_rebuild_ui()

static func load_external_texture(path_str: String, base_dir_str: String = "") -> Texture2D:
	if path_str == "":
		return null
	
	# 1. Try local filesystem if possible
	var paths_to_try: Array[String] = []
	if base_dir_str != "":
		paths_to_try.append(base_dir_str.path_join(path_str))
		paths_to_try.append(base_dir_str.path_join("images").path_join(path_str))
	paths_to_try.append(path_str)
	paths_to_try.append("images".path_join(path_str))
	paths_to_try.append("res://".path_join(path_str))
	paths_to_try.append("res://images/".path_join(path_str))
	
	for path in paths_to_try:
		if not path.begins_with("res://") and FileAccess.file_exists(path):
			var img = Image.load_from_file(path)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
	
	# 2. Try ResourceLoader for packed assets / Web export
	var res_paths = [
		path_str,
		"res://".path_join(path_str),
		"res://images/".path_join(path_str)
	]
	for rp in res_paths:
		if rp.begins_with("res://") and ResourceLoader.exists(rp):
			var res = load(rp)
			if res is Texture2D:
				return res
	
	return null

static func _color_to_array(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]

static func _array_to_color(value, fallback: Color = Color.WHITE) -> Color:
	if value is Array and value.size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return fallback

static func _vector2_to_array(value: Vector2) -> Array:
	return [value.x, value.y]

static func _array_to_vector2(value, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

# --- Internal Satellite Node Class ---
class SatelliteNode extends GraphNode:
	func _init():
		title = ""
		resizable = false
		draggable = false
		custom_minimum_size = Vector2(24, 24)
		size = Vector2(24, 24)
		
		# Transparent background for the satellite itself
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.draw_center = false
		add_theme_stylebox_override("panel", sb)
		add_theme_stylebox_override("panel_selected", sb)
		add_theme_stylebox_override("titlebar", sb)
		add_theme_stylebox_override("titlebar_selected", sb)
		
		# Dummy child to hold the slot
		var control = Control.new()
		control.custom_minimum_size = Vector2(16, 16)
		add_child(control)
