extends Control

@onready var graph_edit: GraphEdit = $VBoxContainer/HSplitContainer/GraphEdit
@onready var inspector_panel: PanelContainer = $VBoxContainer/HSplitContainer/InspectorPanel
@onready var inspector_vbox: VBoxContainer = $VBoxContainer/HSplitContainer/InspectorPanel/ScrollContainer/VBoxContainer

var selected_node: MockNode = null

func _ready():
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.node_deselected.connect(_on_node_deselected)
	
	$VBoxContainer/Toolbar/AddNodeBtn.pressed.connect(_on_add_node_pressed)
	
	_clear_inspector()

func _on_add_node_pressed():
	var node = MockNode.new()
	node.title = "New Node"
	
	# Initial offset in the center of the scroll offset
	node.position_offset = graph_edit.scroll_offset + Vector2(200, 200)
	
	graph_edit.add_child(node)
	
	# Add default port
	node.add_port("In", true, false, Color.GREEN)
	node.add_port("Out", false, true, Color.BLUE)

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

func _clear_inspector():
	for child in inspector_vbox.get_children():
		inspector_vbox.remove_child(child)
		child.queue_free()
	
	var label = Label.new()
	label.text = "Select a node to edit."
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
	title_lbl.text = "Title:"
	var title_le = LineEdit.new()
	title_le.text = selected_node.title
	title_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_le.text_changed.connect(func(text): selected_node.set_node_title(text))
	title_hbox.add_child(title_lbl)
	title_hbox.add_child(title_le)
	inspector_vbox.add_child(title_hbox)
	
	var color_hbox = HBoxContainer.new()
	var color_lbl = Label.new()
	color_lbl.text = "Color:"
	var color_picker = ColorPickerButton.new()
	color_picker.color = selected_node.node_color
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.color_changed.connect(func(color): selected_node.set_node_color(color))
	color_hbox.add_child(color_lbl)
	color_hbox.add_child(color_picker)
	inspector_vbox.add_child(color_hbox)
	
	inspector_vbox.add_child(HSeparator.new())
	
	var port_title = Label.new()
	port_title.text = "Ports / Properties"
	inspector_vbox.add_child(port_title)
	
	# Actions
	var action_hbox = HBoxContainer.new()
	var add_in_btn = Button.new()
	add_in_btn.text = "+ Input"
	add_in_btn.pressed.connect(func():
		selected_node.add_port("In", true, false, Color.WHITE)
		_build_inspector()
	)
	var add_out_btn = Button.new()
	add_out_btn.text = "+ Output"
	add_out_btn.pressed.connect(func():
		selected_node.add_port("Out", false, true, Color.WHITE)
		_build_inspector()
	)
	var add_prop_btn = Button.new()
	add_prop_btn.text = "+ Prop"
	add_prop_btn.pressed.connect(func():
		selected_node.add_property("Prop", "string")
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
		del_btn.text = "X"
		del_btn.pressed.connect(func():
			# When port removed, disconnect existing connections to/from it.
			# For MVP, we can just let GraphEdit handle dangling lines or clear them.
			# Clearing all connections to this node for simplicity.
			var name = selected_node.name
			for c in graph_edit.get_connection_list():
				if c["from_node"] == name or c["to_node"] == name:
					graph_edit.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
			selected_node.remove_item(i)
			_build_inspector()
		)
		row1.add_child(del_btn)
		
		var type_lbl = Label.new()
		type_lbl.text = item["type"].to_upper()
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
			in_cb.text = "In"
			in_cb.button_pressed = item["is_input"]
			in_cb.toggled.connect(func(pressed):
				selected_node.items[i]["is_input"] = pressed
				selected_node._rebuild_ui()
			)
			row2.add_child(in_cb)
			
			var out_cb = CheckBox.new()
			out_cb.text = "Out"
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
			
		inspector_vbox.add_child(item_vbox)
		inspector_vbox.add_child(HSeparator.new())
