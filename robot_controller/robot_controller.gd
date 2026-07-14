class_name RobotController
extends RefCounted

var _robot: Robot
var _view: RobotView
var _simulation_world: SimulationWorld
var _show_simulation_walls: bool
var _pose := PoseEstimator.new()
var _map := OccupancyMap.new()
var _last_distance := -1.0


func _init(robot: Robot, view: RobotView, simulation_world: SimulationWorld = null, show_simulation_walls := false) -> void:
	_robot = robot
	_view = view
	_simulation_world = simulation_world
	_show_simulation_walls = show_simulation_walls


func start() -> void:
	_robot.start()


func process(direction: Vector2, delta: float) -> void:
	_pose.update(direction, delta)
	_robot.update(direction, _pose.robot_position, _pose.heading, delta)

	var distance: Variant = _robot.poll_distance()
	if distance != null:
		_last_distance = distance
		_map.integrate(_last_distance, _pose.robot_position, _pose.heading)

	var visible_walls: Array[PackedVector2Array] = []
	if _show_simulation_walls and _simulation_world != null:
		visible_walls.assign(_simulation_world.walls())

	_view.present(
		_map,
		_map.take_changed_cells(),
		_pose.robot_position,
		_pose.heading,
		_last_distance,
		visible_walls,
	)


func stop() -> void:
	_robot.stop()
