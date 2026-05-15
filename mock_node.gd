extends GraphNode
class_name MockNode

var node_color: Color = Color(0.2, 0.2, 0.2, 0.8)
var graphmock_id: String = ""

# Array of dictionaries holding row data
var items: Array[Dictionary] = []

func _ready():
	# Let GraphEdit handle dragging and resizing
	resizable = true
	resize_request.connect(_on_resize_request)
	_update_visuals()
	
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
		"items": saved_items
	}

func from_save_dict(data: Dictionary) -> void:
	graphmock_id = str(data.get("id", ""))
	name = str(data.get("name", graphmock_id if graphmock_id != "" else "MockNode"))
	title = str(data.get("title", "ノード"))
	position_offset = _array_to_vector2(data.get("position_offset", [0.0, 0.0]))
	node_color = _array_to_color(data.get("node_color", [0.2, 0.2, 0.2, 0.8]))
	
	items.clear()
	var saved_items = data.get("items", [])
	if saved_items is Array:
		for saved_item in saved_items:
			if saved_item is Dictionary:
				var item: Dictionary = saved_item.duplicate(true)
				if item.has("color"):
					item["color"] = _array_to_color(item["color"])
				items.append(item)
	
	_update_visuals()
	_rebuild_ui()
	size = _array_to_vector2(data.get("size", size))

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
		"prop_type": prop_type
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
	
	for i in range(items.size()):
		var item = items[i]
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
			
			set_slot(i, 
				item["is_input"], 0, item["color"], 
				item["is_output"], 0, item["color"])
		elif item["type"] == "property":
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = item["name"]
			label.custom_minimum_size.x = 40
			hbox.add_child(label)
			if item["prop_type"] == "string":
				var le = LineEdit.new()
				le.expand_to_text_length = true
				le.custom_minimum_size.x = 60
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(le)
			elif item["prop_type"] == "number":
				var sb = SpinBox.new()
				sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(sb)
			add_child(hbox)
			set_slot(i, false, 0, Color.WHITE, false, 0, Color.WHITE)
			
	# Emit a signal or update size so GraphEdit layout updates
	reset_size()

func _update_visuals():
	set_node_color(node_color)

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
