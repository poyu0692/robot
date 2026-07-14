extends Node

const ROBOT_IP = "10.119.23.109"
const ROBOT_PORT = 1240
const SIMULATION_MODE = true
const SHOW_SIMULATION_WALLS = false

@onready var view: RobotView = $RobotView

var controller: RobotController


func _ready() -> void:
	var simulation_world: SimulationWorld = null
	var robot: Robot
	if SIMULATION_MODE:
		simulation_world = SimulationWorld.new()
		robot = SimulatedRobot.new(simulation_world)
	else:
		robot = UdpRobot.new(ROBOT_IP, ROBOT_PORT)
	controller = RobotController.new(robot, view, simulation_world, SHOW_SIMULATION_WALLS)
	controller.start()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	controller.process(direction, delta)


func _exit_tree() -> void:
	if controller != null:
		controller.stop()
