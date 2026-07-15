class_name NetworkPanel extends Control

signal connect_requested(address: String, port: int, use_simulation: bool)

const CONNECTION_SETTINGS_PATH := "user://robot_connection.cfg"
const CONNECTION_SECTION := "robot_connection"
const ADDRESS_KEY := "address"
const PORT_KEY := "port"

var _ip_input: LineEdit
var _port_input: LineEdit
var _simulation_toggle: CheckBox
var _connect_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.282)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var fields := VBoxContainer.new()
	fields.custom_minimum_size.x = 360.0
	center.add_child(fields)

	_ip_input = _add_field(fields, "IP address", "192.168.0.10")
	_port_input = _add_field(fields, "UDP port", "1240")
	_port_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_ip_input.text_changed.connect(_on_field_changed)
	_port_input.text_changed.connect(_on_field_changed)

	_simulation_toggle = CheckBox.new()
	_simulation_toggle.text = "Simulation mode"
	_simulation_toggle.toggled.connect(_on_simulation_toggled)
	fields.add_child(_simulation_toggle)

	_connect_button = Button.new()
	_connect_button.text = "Connect"
	_connect_button.tooltip_text = "Apply the destination and restart robot communication."
	_connect_button.pressed.connect(_request_connection)
	fields.add_child(_connect_button)
	visible = false


func configure(address: String, port: int) -> void:
	var saved_connection := _load_connection()
	_ip_input.text = saved_connection.address if not saved_connection.address.is_empty() else address
	_port_input.text = str(saved_connection.port if saved_connection.port > 0 else port)
	_update_connect_button()


func connection_address() -> String:
	return _ip_input.text.strip_edges()


func connection_port() -> int:
	return _port_input.text.to_int()


func _add_field(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 75.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.select_all_on_focus = true
	row.add_child(input)
	return input


func _request_connection() -> void:
	if not _validate_inputs():
		return
	if not _simulation_toggle.button_pressed:
		_save_connection(connection_address(), connection_port())
	connect_requested.emit(connection_address(), connection_port(), _simulation_toggle.button_pressed)


func _load_connection() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(CONNECTION_SETTINGS_PATH) != OK:
		return {"address": "", "port": 0}
	return {
		"address": str(config.get_value(CONNECTION_SECTION, ADDRESS_KEY, "")),
		"port": int(config.get_value(CONNECTION_SECTION, PORT_KEY, 0)),
	}


func _save_connection(address: String, port: int) -> void:
	var config := ConfigFile.new()
	config.set_value(CONNECTION_SECTION, ADDRESS_KEY, address)
	config.set_value(CONNECTION_SECTION, PORT_KEY, port)
	var error := config.save(CONNECTION_SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save robot connection: %s" % error_string(error))


func _validate_inputs() -> bool:
	if _simulation_toggle.button_pressed:
		return true
	if connection_address().is_empty():
		_ip_input.grab_focus()
		return false
	if connection_port() < 1 or connection_port() > 65535:
		_port_input.grab_focus()
		return false
	return true


func _on_field_changed(_text: String) -> void:
	_update_connect_button()


func _on_simulation_toggled(enabled: bool) -> void:
	_ip_input.editable = not enabled
	_port_input.editable = not enabled
	_update_connect_button()


func _update_connect_button() -> void:
	if _connect_button == null:
		return
	var use_simulation := _simulation_toggle != null and _simulation_toggle.button_pressed
	_connect_button.text = "Start simulation" if use_simulation else "Connect"
	_connect_button.disabled = not use_simulation and (connection_address().is_empty() or connection_port() < 1 or connection_port() > 65535)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		visible = not visible
		if visible:
			_ip_input.grab_focus()
		else:
			_ip_input.release_focus()
		get_viewport().set_input_as_handled()
