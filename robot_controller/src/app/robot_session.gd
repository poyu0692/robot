class_name RobotSession extends RefCounted

signal link_event(message: String)

enum Mode {
	UDP,
	SIMULATION,
}

var _mode: int
var _robot_client: RobotUdpClient
var _simulated_robot: SimulatedRobot
var _pose := PoseEstimator.new()
var _map := OccupancyMap.new()
var _last_distance := -1.0


static func create_udp(address: String, port: int) -> RobotSession:
	return RobotSession.new(Mode.UDP, address, port)


static func create_simulation() -> RobotSession:
	return RobotSession.new(Mode.SIMULATION)


func _init(mode: int, address := "", port := 0) -> void:
	_mode = mode
	match _mode:
		Mode.UDP:
			_robot_client = RobotUdpClient.new(address, port)
			_robot_client.link_event.connect(_on_udp_link_event)
		Mode.SIMULATION:
			_simulated_robot = SimulatedRobot.new(SimulationWorld.new())
		_:
			push_error("Unsupported robot session mode: %d" % _mode)


func start() -> void:
	match _mode:
		Mode.UDP:
			_robot_client.start()
		Mode.SIMULATION:
			pass


func process(direction: Vector2, delta: float) -> RobotFrame:
	_pose.update(direction, delta)
	var distance: Variant = _update_backend(direction, delta)
	var changed_cells: Array[Vector2i] = []
	var replaces_previous_view := distance != null
	if distance != null:
		_last_distance = float(distance)
		# A received measurement replaces the prior sensor view.  Between
		# measurements, keep the last view while the pose continues to move.
		_map.clear()
		changed_cells = _map.integrate(_last_distance, _pose.robot_position, _pose.heading)
	return RobotFrame.new(
		_map,
		changed_cells,
		_pose.robot_position,
		_pose.heading,
		_last_distance,
		replaces_previous_view,
	)


func stop() -> void:
	match _mode:
		Mode.UDP:
			_robot_client.stop()
		Mode.SIMULATION:
			pass


func _update_backend(direction: Vector2, delta: float) -> Variant:
	match _mode:
		Mode.UDP:
			_robot_client.update(direction, delta)
			return _robot_client.poll_distance()
		Mode.SIMULATION:
			_simulated_robot.update(_pose.robot_position, _pose.heading, delta)
			return _simulated_robot.poll_distance()
	return null


func _on_udp_link_event(message: String) -> void:
	link_event.emit(message)
