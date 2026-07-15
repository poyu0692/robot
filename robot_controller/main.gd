class_name Main extends Node

const DEFAULT_ROBOT_IP := "10.119.23.109"
const DEFAULT_ROBOT_PORT := 1240
const MAX_LOG_LINES := 200

@onready var view: RobotView = $RobotView
@onready var activity_log: RichTextLabel = $ActivityLog
@onready var network_panel: NetworkPanel = $NetworkPanel

var session: RobotSession
var _log_lines: Array[String] = []


# setup
func _ready() -> void:
	network_panel.configure(DEFAULT_ROBOT_IP, DEFAULT_ROBOT_PORT)
	network_panel.connect_requested.connect(_connect_robot)
	_log("Application started")
	_connect_robot(network_panel.connection_address(), network_panel.connection_port(), false)


func _connect_robot(address: String, port: int, use_simulation: bool) -> void:
	if session != null:
		session.stop()

	if use_simulation:
		session = RobotSession.create_simulation()
		_log("Simulation mode started")
	else:
		session = RobotSession.create_udp(address, port)
		session.link_event.connect(_on_robot_link_event)
		_log("UDP target: %s:%d" % [address, port])
	session.start()


func _process(delta: float) -> void:
	if session == null:
		return
	var direction := Vector2.ZERO
	if not network_panel.visible:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var frame := session.process(direction, delta)
	view.present(frame)


func _log(message: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), message]
	_log_lines.push_back(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
		activity_log.text = "\n".join(_log_lines)
		activity_log.scroll_to_line(_log_lines.size() - 1)
	else:
		activity_log.append_text(line + "\n")


func _on_robot_link_event(message: String) -> void:
	_log(message)


func _exit_tree() -> void:
	if session != null:
		session.stop()
