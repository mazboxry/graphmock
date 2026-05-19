extends Control

const SAVE_VERSION := 1
const DRAFT_SAVE_PATH := "user://graphmock_save.json"
const DEFAULT_JSON_FILENAME := "graphmock.json"
const APP_FONT := preload("res://assets/fonts/noto_sans_jp-regular.woff2")

@onready var toolbar: HBoxContainer = $VBoxContainer/Toolbar
@onready var graph_edit: GraphEdit = $VBoxContainer/HSplitContainer/GraphEdit
@onready var inspector_panel: PanelContainer = $VBoxContainer/HSplitContainer/InspectorPanel
@onready var inspector_vbox: VBoxContainer = $VBoxContainer/HSplitContainer/InspectorPanel/ScrollContainer/VBoxContainer

var selected_node: MockNode = null
var next_node_id := 1
var status_label: Label
var export_dialog: FileDialog
var import_dialog: FileDialog
var image_dialog: FileDialog
var web_import_callback
var current_json_dir: String = ""

func _ready():
	_apply_app_theme()
	_setup_toolbar()
	_setup_file_dialogs()
	
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.node_deselected.connect(_on_node_deselected)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	
	$VBoxContainer/Toolbar/AddNodeBtn.pressed.connect(_on_add_node_pressed)
	
	_clear_inspector()
	
	# Load tutorial if no save exists
	if not FileAccess.file_exists(DRAFT_SAVE_PATH):
		_deserialize_graph(_get_tutorial_data())
		_set_status("チュートリアルを表示しました")
	else:
		_on_load_pressed()
		_set_status("準備完了")

func _apply_app_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = APP_FONT
	app_theme.default_font_size = 16
	theme = app_theme

func _setup_toolbar() -> void:
	var add_node_btn: Button = $VBoxContainer/Toolbar/AddNodeBtn
	add_node_btn.text = "ノード追加"
	
	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_btn)
	
	var load_btn := Button.new()
	load_btn.text = "読込"
	load_btn.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_btn)
	
	var export_btn := Button.new()
	export_btn.text = "JSON書出"
	export_btn.pressed.connect(_on_export_pressed)
	toolbar.add_child(export_btn)
	
	var import_btn := Button.new()
	import_btn.text = "JSON読込"
	import_btn.pressed.connect(_on_import_pressed)
	toolbar.add_child(import_btn)
	
	status_label = Label.new()
	status_label.text = ""
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(status_label)

func _setup_file_dialogs() -> void:
	export_dialog = FileDialog.new()
	export_dialog.title = "JSONを書き出し"
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.current_file = DEFAULT_JSON_FILENAME
	export_dialog.filters = PackedStringArray(["*.json ; JSON"])
	export_dialog.file_selected.connect(_on_export_file_selected)
	add_child(export_dialog)
	
	import_dialog = FileDialog.new()
	import_dialog.title = "JSONを読み込み"
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.filters = PackedStringArray(["*.json ; JSON"])
	import_dialog.file_selected.connect(_on_import_file_selected)
	add_child(import_dialog)
	
	image_dialog = FileDialog.new()
	image_dialog.title = "画像を選択"
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	image_dialog.file_selected.connect(_on_image_file_selected)
	add_child(image_dialog)

func _on_image_file_selected(path: String) -> void:
	if not selected_node:
		return
	var relative_path = path
	if current_json_dir != "":
		var base_dir = current_json_dir.replace("\\", "/")
		var target_path = path.replace("\\", "/")
		if target_path.begins_with(base_dir):
			relative_path = target_path.trim_prefix(base_dir)
			if relative_path.begins_with("/"):
				relative_path = relative_path.substr(1)
	selected_node.set_image_path(relative_path)
	_build_inspector()

func _on_add_node_pressed():
	var node = _create_mock_node()
	node.title = "新しいノード"
	
	# Initial offset in the center of the scroll offset
	node.position_offset = graph_edit.scroll_offset + Vector2(200, 200)
	
	graph_edit.add_child(node)
	
	# Add default port
	node.add_port("入力", true, false, Color.GREEN)
	node.add_port("出力", false, true, Color.BLUE)
	_set_status("ノードを追加しました")

func _create_mock_node() -> MockNode:
	var node := MockNode.new()
	node.graphmock_id = _allocate_node_id()
	node.name = node.graphmock_id
	node.base_dir = current_json_dir
	return node

func _allocate_node_id() -> String:
	var node_id := "node_%04d" % next_node_id
	next_node_id += 1
	return node_id

func _sync_next_node_id_from(node_id: String) -> void:
	if not node_id.begins_with("node_"):
		return
	var number := node_id.trim_prefix("node_").to_int()
	next_node_id = max(next_node_id, number + 1)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	graph_edit.connect_node(from_node, from_port, to_node, to_port)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)

func _on_node_selected(node: Node):
	if node is MockNode:
		selected_node = node
		_build_inspector()

func _on_node_deselected(node: Node):
	if node == selected_node:
		selected_node = null
		_clear_inspector()

func _on_delete_nodes_request(nodes: Array[StringName]):
	for node_name in nodes:
		var node = graph_edit.get_node_or_null(NodePath(node_name))
		if node:
			_delete_node(node)

func _delete_node(node: Node):
	# Disconnect all connections related to this node and its satellites
	var names_to_disconnect = [node.name]
	if node is MockNode:
		names_to_disconnect.append(node.name + "_top")
		names_to_disconnect.append(node.name + "_bottom")
	
	for node_name in names_to_disconnect:
		for c in graph_edit.get_connection_list():
			if c["from_node"] == node_name or c["to_node"] == node_name:
				graph_edit.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
	
	if node == selected_node:
		selected_node = null
		_clear_inspector()
	
	node.queue_free()

func _on_duplicate_node_pressed(node: MockNode):
	if not node:
		return
	var data = node.to_save_dict()
	var new_id = _allocate_node_id()
	data["id"] = new_id
	data["name"] = new_id
	
	# Shift position slightly
	var pos = MockNode._array_to_vector2(data.get("position_offset", [0.0, 0.0]))
	pos += Vector2(40, 40)
	data["position_offset"] = MockNode._vector2_to_array(pos)
	
	var dup := MockNode.new()
	dup.base_dir = current_json_dir
	dup.from_save_dict(data)
	
	graph_edit.add_child(dup)
	
	# Deselect old and select new
	node.selected = false
	dup.selected = true
	selected_node = dup
	_build_inspector()
	_set_status("ノードを複製しました")

func _clear_inspector():
	for child in inspector_vbox.get_children():
		inspector_vbox.remove_child(child)
		child.queue_free()
	
	var label = Label.new()
	label.text = "ノードを選択してください"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_vbox.add_child(label)

func _build_inspector():
	for child in inspector_vbox.get_children():
		inspector_vbox.remove_child(child)
		child.queue_free()
		
	if not selected_node:
		return
		
	var title_hbox = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "タイトル:"
	var title_le = LineEdit.new()
	title_le.text = selected_node.title
	title_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_le.text_changed.connect(func(text): selected_node.set_node_title(text))
	title_hbox.add_child(title_lbl)
	title_hbox.add_child(title_le)
	inspector_vbox.add_child(title_hbox)
	
	var color_hbox = HBoxContainer.new()
	var color_lbl = Label.new()
	color_lbl.text = "色:"
	var color_picker = ColorPickerButton.new()
	color_picker.color = selected_node.node_color
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.color_changed.connect(func(color): selected_node.set_node_color(color))
	color_hbox.add_child(color_lbl)
	color_hbox.add_child(color_picker)
	inspector_vbox.add_child(color_hbox)
	
	# Vertical Ports UI
	inspector_vbox.add_child(HSeparator.new())
	var vp_lbl = Label.new()
	vp_lbl.text = "垂直ポート (ナビ風)"
	inspector_vbox.add_child(vp_lbl)
	
	# Top Port
	var top_hbox = HBoxContainer.new()
	var top_cb = CheckBox.new()
	top_cb.text = "上ポート"
	top_cb.button_pressed = selected_node.has_top_port
	top_cb.toggled.connect(func(pressed): selected_node.set_has_top_port(pressed))
	var top_cp = ColorPickerButton.new()
	top_cp.color = selected_node.top_port_color
	top_cp.custom_minimum_size.x = 40
	top_cp.color_changed.connect(func(color): selected_node.set_top_port_color(color))
	top_hbox.add_child(top_cb)
	top_hbox.add_child(top_cp)
	inspector_vbox.add_child(top_hbox)
	
	# Bottom Port
	var bot_hbox = HBoxContainer.new()
	var bot_cb = CheckBox.new()
	bot_cb.text = "下ポート"
	bot_cb.button_pressed = selected_node.has_bottom_port
	bot_cb.toggled.connect(func(pressed): selected_node.set_has_bottom_port(pressed))
	var bot_cp = ColorPickerButton.new()
	bot_cp.color = selected_node.bottom_port_color
	bot_cp.custom_minimum_size.x = 40
	bot_cp.color_changed.connect(func(color): selected_node.set_bottom_port_color(color))
	bot_hbox.add_child(bot_cb)
	bot_hbox.add_child(bot_cp)
	inspector_vbox.add_child(bot_hbox)
	
	inspector_vbox.add_child(HSeparator.new())
	
	var action_node_hbox = HBoxContainer.new()
	
	var dup_node_btn = Button.new()
	dup_node_btn.text = "このノードを複製"
	dup_node_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_node_btn.pressed.connect(func(): _on_duplicate_node_pressed(selected_node))
	action_node_hbox.add_child(dup_node_btn)
	
	var del_node_btn = Button.new()
	del_node_btn.text = "削除"
	del_node_btn.modulate = Color.INDIAN_RED
	del_node_btn.pressed.connect(func(): _delete_node(selected_node))
	action_node_hbox.add_child(del_node_btn)
	
	inspector_vbox.add_child(action_node_hbox)
	
	# Node Image UI
	inspector_vbox.add_child(HSeparator.new())
	var img_lbl = Label.new()
	img_lbl.text = "ノード画像"
	inspector_vbox.add_child(img_lbl)
	
	var img_hbox = HBoxContainer.new()
	var img_le = LineEdit.new()
	img_le.text = selected_node.image_path
	img_le.placeholder_text = "例: images/001.jpg"
	img_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_le.text_changed.connect(func(text):
		selected_node.set_image_path(text)
	)
	img_hbox.add_child(img_le)
	
	var img_btn = Button.new()
	img_btn.text = "選択"
	img_btn.pressed.connect(func():
		image_dialog.popup_centered_ratio(0.6)
	)
	img_hbox.add_child(img_btn)
	inspector_vbox.add_child(img_hbox)
	
	# Image Height UI
	var height_hbox = HBoxContainer.new()
	var height_lbl = Label.new()
	height_lbl.text = "画像高さ(px):"
	height_hbox.add_child(height_lbl)
	
	var height_sb = SpinBox.new()
	height_sb.min_value = 20
	height_sb.max_value = 300
	height_sb.step = 5
	height_sb.value = selected_node.image_max_height
	height_sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	height_sb.value_changed.connect(func(value):
		selected_node.set_image_max_height(int(value))
	)
	height_hbox.add_child(height_sb)
	inspector_vbox.add_child(height_hbox)
	
	inspector_vbox.add_child(HSeparator.new())
	
	var port_title = Label.new()
	port_title.text = "ソケット / プロパティ"
	inspector_vbox.add_child(port_title)
	
	# Actions
	var action_hbox = HBoxContainer.new()
	var add_in_btn = Button.new()
	add_in_btn.text = "+ 入力"
	add_in_btn.pressed.connect(func():
		selected_node.add_port("入力", true, false, Color.WHITE)
		_build_inspector()
	)
	var add_out_btn = Button.new()
	add_out_btn.text = "+ 出力"
	add_out_btn.pressed.connect(func():
		selected_node.add_port("出力", false, true, Color.WHITE)
		_build_inspector()
	)
	var add_prop_btn = Button.new()
	add_prop_btn.text = "+ プロパティ"
	add_prop_btn.pressed.connect(func():
		selected_node.add_property("プロパティ", "string")
		_build_inspector()
	)
	action_hbox.add_child(add_in_btn)
	action_hbox.add_child(add_out_btn)
	action_hbox.add_child(add_prop_btn)
	inspector_vbox.add_child(action_hbox)
	
	inspector_vbox.add_child(HSeparator.new())
	
	# List items
	for i in range(selected_node.items.size()):
		var item = selected_node.items[i]
		var item_vbox = VBoxContainer.new()
		
		var row1 = HBoxContainer.new()
		var del_btn = Button.new()
		del_btn.text = "削除"
		del_btn.pressed.connect(func():
			# When a slot changes, clear this node's existing connections to avoid stale port indices.
			var node_name = selected_node.name
			for c in graph_edit.get_connection_list():
				if c["from_node"] == node_name or c["to_node"] == node_name:
					graph_edit.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
			selected_node.remove_item(i)
			_build_inspector()
		)
		row1.add_child(del_btn)
		
		var up_btn = Button.new()
		up_btn.text = "▲"
		up_btn.disabled = (i == 0)
		up_btn.pressed.connect(func():
			var node_name = selected_node.name
			for c in graph_edit.get_connection_list():
				if c["from_node"] == node_name or c["to_node"] == node_name:
					graph_edit.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
			var temp = selected_node.items[i]
			selected_node.items[i] = selected_node.items[i - 1]
			selected_node.items[i - 1] = temp
			selected_node._rebuild_ui()
			_build_inspector()
		)
		row1.add_child(up_btn)
		
		var down_btn = Button.new()
		down_btn.text = "▼"
		down_btn.disabled = (i == selected_node.items.size() - 1)
		down_btn.pressed.connect(func():
			var node_name = selected_node.name
			for c in graph_edit.get_connection_list():
				if c["from_node"] == node_name or c["to_node"] == node_name:
					graph_edit.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
			var temp = selected_node.items[i]
			selected_node.items[i] = selected_node.items[i + 1]
			selected_node.items[i + 1] = temp
			selected_node._rebuild_ui()
			_build_inspector()
		)
		row1.add_child(down_btn)
		
		var type_lbl = Label.new()
		type_lbl.text = "ソケット" if item["type"] == "port" else "プロパティ"
		row1.add_child(type_lbl)
		
		var name_le = LineEdit.new()
		name_le.text = item["name"]
		name_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_le.text_changed.connect(func(text):
			selected_node.items[i]["name"] = text
			selected_node._rebuild_ui()
		)
		row1.add_child(name_le)
		
		item_vbox.add_child(row1)
		
		if item["type"] == "port":
			var row2 = HBoxContainer.new()
			var in_cb = CheckBox.new()
			in_cb.text = "入力"
			in_cb.button_pressed = item["is_input"]
			in_cb.toggled.connect(func(pressed):
				selected_node.items[i]["is_input"] = pressed
				selected_node._rebuild_ui()
			)
			row2.add_child(in_cb)
			
			var out_cb = CheckBox.new()
			out_cb.text = "出力"
			out_cb.button_pressed = item["is_output"]
			out_cb.toggled.connect(func(pressed):
				selected_node.items[i]["is_output"] = pressed
				selected_node._rebuild_ui()
			)
			row2.add_child(out_cb)
			
			var cp = ColorPickerButton.new()
			cp.color = item["color"]
			cp.custom_minimum_size.x = 40
			cp.color_changed.connect(func(color):
				selected_node.items[i]["color"] = color
				selected_node._rebuild_ui()
			)
			row2.add_child(cp)
			item_vbox.add_child(row2)
			
		elif item["type"] == "property":
			var row2 = HBoxContainer.new()
			
			var in_cb = CheckBox.new()
			in_cb.text = "入力"
			in_cb.button_pressed = item.get("is_input", false)
			in_cb.toggled.connect(func(pressed):
				selected_node.items[i]["is_input"] = pressed
				selected_node._rebuild_ui()
			)
			row2.add_child(in_cb)
			
			var out_cb = CheckBox.new()
			out_cb.text = "出力"
			out_cb.button_pressed = item.get("is_output", false)
			out_cb.toggled.connect(func(pressed):
				selected_node.items[i]["is_output"] = pressed
				selected_node._rebuild_ui()
			)
			row2.add_child(out_cb)
			
			var cp = ColorPickerButton.new()
			cp.color = item.get("color", Color.WHITE)
			cp.custom_minimum_size.x = 40
			cp.color_changed.connect(func(color):
				selected_node.items[i]["color"] = color
				selected_node._rebuild_ui()
			)
			row2.add_child(cp)
			
			var annot_lbl = Label.new()
			annot_lbl.text = "型:"
			row2.add_child(annot_lbl)
			
			var annot_le = LineEdit.new()
			annot_le.text = item.get("type_annotation", "")
			annot_le.placeholder_text = "例: int"
			annot_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			annot_le.text_changed.connect(func(text):
				selected_node.items[i]["type_annotation"] = text
				selected_node._rebuild_ui()
			)
			row2.add_child(annot_le)
			item_vbox.add_child(row2)
			
			var row3 = HBoxContainer.new()
			var type_lbl_opt = Label.new()
			type_lbl_opt.text = "種別:"
			row3.add_child(type_lbl_opt)
			
			var type_opt = OptionButton.new()
			type_opt.add_item("文字列")
			type_opt.add_item("数値")
			type_opt.selected = 0 if item.get("prop_type", "string") == "string" else 1
			type_opt.item_selected.connect(func(idx):
				var new_type = "string" if idx == 0 else "number"
				selected_node.items[i]["prop_type"] = new_type
				selected_node.items[i]["value"] = "" if new_type == "string" else 0.0
				selected_node._rebuild_ui()
				_build_inspector()
			)
			row3.add_child(type_opt)
			
			var val_lbl = Label.new()
			val_lbl.text = " 値:"
			row3.add_child(val_lbl)
			
			if item.get("prop_type", "string") == "string":
				var val_le = LineEdit.new()
				val_le.text = str(item.get("value", ""))
				val_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				val_le.text_changed.connect(func(text):
					selected_node.items[i]["value"] = text
					selected_node._rebuild_ui()
				)
				row3.add_child(val_le)
			else:
				var val_sb = SpinBox.new()
				val_sb.min_value = -999999
				val_sb.max_value = 999999
				val_sb.step = 0.01
				val_sb.allow_greater = true
				val_sb.allow_lesser = true
				val_sb.value = float(item.get("value", 0.0))
				val_sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				val_sb.value_changed.connect(func(val):
					selected_node.items[i]["value"] = val
					selected_node._rebuild_ui()
				)
				row3.add_child(val_sb)
			
			item_vbox.add_child(row3)
			
		inspector_vbox.add_child(item_vbox)
		inspector_vbox.add_child(HSeparator.new())

func _on_save_pressed() -> void:
	var result := _write_text_file(DRAFT_SAVE_PATH, _serialize_graph_text())
	_set_status("保存しました" if result == OK else "保存に失敗しました")

func _on_load_pressed() -> void:
	if not FileAccess.file_exists(DRAFT_SAVE_PATH):
		_set_status("保存ファイルがありません")
		return
	var file := FileAccess.open(DRAFT_SAVE_PATH, FileAccess.READ)
	if file == null:
		_set_status("読込に失敗しました")
		return
	_load_graph_text(file.get_as_text())

func _on_export_pressed() -> void:
	var json_text := _serialize_graph_text()
	if OS.get_name() == "Web":
		_export_json_web(json_text)
	else:
		export_dialog.current_file = DEFAULT_JSON_FILENAME
		export_dialog.popup_centered_ratio(0.6)

func _on_import_pressed() -> void:
	if OS.get_name() == "Web":
		_import_json_web()
	else:
		import_dialog.popup_centered_ratio(0.6)

func _on_export_file_selected(path: String) -> void:
	current_json_dir = path.get_base_dir()
	var result := _write_text_file(path, _serialize_graph_text())
	_set_status("JSONを書き出しました" if result == OK else "JSON書き出しに失敗しました")

func _on_import_file_selected(path: String) -> void:
	current_json_dir = path.get_base_dir()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("JSON読込に失敗しました")
		return
	_load_graph_text(file.get_as_text())

func _write_text_file(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	return OK

func _serialize_graph_text() -> String:
	return JSON.stringify(_serialize_graph(), "\t")

func _serialize_graph() -> Dictionary:
	var node_name_to_id := {}
	var nodes: Array = []
	for child in graph_edit.get_children():
		if child is MockNode:
			if child.graphmock_id == "":
				child.graphmock_id = _allocate_node_id()
			node_name_to_id[child.name] = child.graphmock_id
			# Map satellite nodes as well
			node_name_to_id[child.name + "_top"] = child.graphmock_id + ":top"
			node_name_to_id[child.name + "_bottom"] = child.graphmock_id + ":bottom"
			nodes.append(child.to_save_dict())
	
	var connections: Array = []
	for connection in graph_edit.get_connection_list():
		var from_node_id = node_name_to_id.get(connection["from_node"], "")
		var to_node_id = node_name_to_id.get(connection["to_node"], "")
		if from_node_id == "" or to_node_id == "":
			continue
		connections.append({
			"from_node_id": from_node_id,
			"from_port": connection["from_port"],
			"to_node_id": to_node_id,
			"to_port": connection["to_port"]
		})
	
	return {
		"version": SAVE_VERSION,
		"graph": {
			"scroll_offset": MockNode._vector2_to_array(graph_edit.scroll_offset),
			"zoom": graph_edit.zoom
		},
		"nodes": nodes,
		"connections": connections
	}

func _load_graph_text(json_text: String) -> void:
	var json := JSON.new()
	var parse_error := json.parse(json_text)
	if parse_error != OK:
		_set_status("JSONが不正です")
		return
	
	var data = json.data
	if not (data is Dictionary):
		_set_status("JSON形式が違います")
		return
	if int(data.get("version", 0)) > SAVE_VERSION:
		_set_status("この保存データは新しすぎます")
		return
	
	_deserialize_graph(data)
	_set_status("読み込みました")

func _deserialize_graph(data: Dictionary) -> void:
	_clear_graph()
	next_node_id = 1
	
	var id_to_node := {}
	var saved_nodes = data.get("nodes", [])
	if saved_nodes is Array:
		for node_data in saved_nodes:
			if not (node_data is Dictionary):
				continue
			var node := MockNode.new()
			node.base_dir = current_json_dir
			node.from_save_dict(node_data)
			if node.graphmock_id == "":
				node.graphmock_id = _allocate_node_id()
				node.name = node.graphmock_id
			_sync_next_node_id_from(node.graphmock_id)
			graph_edit.add_child(node)
			id_to_node[node.graphmock_id] = node
	
	var saved_connections = data.get("connections", [])
	if saved_connections is Array:
		for connection in saved_connections:
			if not (connection is Dictionary):
				continue
			var from_id_raw: String = connection.get("from_node_id", "")
			var to_id_raw: String = connection.get("to_node_id", "")
			
			var from_id_base = from_id_raw.split(":")[0]
			var to_id_base = to_id_raw.split(":")[0]
			
			var from_node: MockNode = id_to_node.get(from_id_base)
			var to_node: MockNode = id_to_node.get(to_id_base)
			
			if from_node == null or to_node == null:
				continue
				
			var from_port := int(connection.get("from_port", -1))
			var to_port := int(connection.get("to_port", -1))
			if from_port < 0 or to_port < 0:
				continue
				
			# Determine actual node names to connect in GraphEdit
			var from_target_name = from_node.name
			if from_id_raw.ends_with(":top"): from_target_name += "_top"
			elif from_id_raw.ends_with(":bottom"): from_target_name += "_bottom"
			
			var to_target_name = to_node.name
			if to_id_raw.ends_with(":top"): to_target_name += "_top"
			elif to_id_raw.ends_with(":bottom"): to_target_name += "_bottom"
			
			graph_edit.connect_node(from_target_name, from_port, to_target_name, to_port)
	
	var graph_data = data.get("graph", {})
	if graph_data is Dictionary:
		graph_edit.scroll_offset = MockNode._array_to_vector2(graph_data.get("scroll_offset", [0.0, 0.0]))
		graph_edit.zoom = float(graph_data.get("zoom", 1.0))
	
	selected_node = null
	_clear_inspector()

func _clear_graph() -> void:
	for connection in graph_edit.get_connection_list():
		graph_edit.disconnect_node(connection["from_node"], connection["from_port"], connection["to_node"], connection["to_port"])
	for child in graph_edit.get_children():
		if child is MockNode:
			graph_edit.remove_child(child)
			child.queue_free()

func _export_json_web(json_text: String) -> void:
	var escaped_text := JSON.stringify(json_text)
	var escaped_name := JSON.stringify(DEFAULT_JSON_FILENAME)
	var js_code := """
		const data = %s;
		const filename = %s;
		const blob = new Blob([data], { type: "application/json;charset=utf-8" });
		const url = URL.createObjectURL(blob);
		const a = document.createElement("a");
		a.href = url;
		a.download = filename;
		document.body.appendChild(a);
		a.click();
		a.remove();
		URL.revokeObjectURL(url);
	""" % [escaped_text, escaped_name]
	JavaScriptBridge.eval(js_code, true)
	_set_status("JSONを書き出しました")

func _import_json_web() -> void:
	web_import_callback = JavaScriptBridge.create_callback(_on_web_import_loaded)
	JavaScriptBridge.eval("""
		window.graphmockReadJson = function(callback) {
			const input = document.createElement("input");
			input.type = "file";
			input.accept = "application/json,.json";
			input.onchange = function() {
				const file = input.files && input.files[0];
				if (!file) {
					callback("");
					return;
				}
				const reader = new FileReader();
				reader.onload = function() { callback(String(reader.result || "")); };
				reader.onerror = function() { callback(""); };
				reader.readAsText(file, "utf-8");
			};
			input.click();
		};
	""", true)
	var window = JavaScriptBridge.get_interface("window")
	window.graphmockReadJson(web_import_callback)

func _on_web_import_loaded(args: Array) -> void:
	if args.is_empty() or str(args[0]) == "":
		_set_status("JSON読込をキャンセルしました")
		return
	_load_graph_text(str(args[0]))

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _get_tutorial_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"graph": {
			"scroll_offset": [0.0, 0.0],
			"zoom": 1.0
		},
		"nodes": [
			{
				"id": "node_0000",
				"name": "node_0000",
				"title": "Welcome!",
				"position_offset": [100.0, 20.0],
				"size": [500.0, 100.0],
				"node_color": [0.1, 0.6, 0.8, 0.8],
				"items": [
					{
						"type": "property",
						"name": "ノーコード風の図を描くためのツールです",
						"prop_type": "string"
					},
					{
						"type": "property",
						"name": "ゆっくりしていってね",
						"prop_type": "string"
					}
				]
			},
			{
				"id": "node_0001",
				"name": "node_0001",
				"title": "入力ソース",
				"position_offset": [100.0, 150.0],
				"size": [200.0, 100.0],
				"node_color": [0.2, 0.4, 0.2, 0.8],
				"items": [
					{
						"type": "port",
						"name": "データ出力",
						"is_input": false,
						"is_output": true,
						"color": [0.5, 1.0, 0.5, 1.0]
					}
				]
			},
			{
				"id": "node_0002",
				"name": "node_0002",
				"title": "ロジック変換",
				"position_offset": [400.0, 150.0],
				"size": [200.0, 150.0],
				"node_color": [0.4, 0.2, 0.2, 0.8],
				"items": [
					{
						"type": "port",
						"name": "入力",
						"is_input": true,
						"is_output": false,
						"color": [0.5, 1.0, 0.5, 1.0]
					},
					{
						"type": "property",
						"name": "変換倍率",
						"prop_type": "number"
					},
					{
						"type": "port",
						"name": "出力",
						"is_input": false,
						"is_output": true,
						"color": [0.5, 0.5, 1.0, 1.0]
					}
				]
			},
			{
				"id": "node_0003",
				"name": "node_0003",
				"title": "最終出力",
				"position_offset": [700.0, 150.0],
				"size": [200.0, 100.0],
				"node_color": [0.2, 0.2, 0.4, 0.8],
				"items": [
					{
						"type": "port",
						"name": "最終結果",
						"is_input": true,
						"is_output": false,
						"color": [0.5, 0.5, 1.0, 1.0]
					}
				]
			}
		],
		"connections": [
			{
				"from_node_id": "node_0001",
				"from_port": 0,
				"to_node_id": "node_0002",
				"to_port": 0
			},
			{
				"from_node_id": "node_0002",
				"from_port": 0,
				"to_node_id": "node_0003",
				"to_port": 0
			}
		]
	}
