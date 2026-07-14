class_name SimulatedRobot
extends Robot

const SENSOR_HALF_FOV := deg_to_rad(1.0)
const MEASUREMENT_PERIOD := 0.06

var _world: SimulationWorld
var _elapsed := 0.0
var _pending_distance: Variant = null


func _init(world: SimulationWorld) -> void:
	_world = world


func update(_direction: Vector2, robot_position: Vector2, heading: float, delta: float) -> void:
	_elapsed += delta
	if _elapsed < MEASUREMENT_PERIOD:
		return
	_elapsed = 0.0
	_pending_distance = _distance_at(robot_position, heading)


func poll_distance() -> Variant:
	var distance: Variant = _pending_distance
	_pending_distance = null
	return distance


func _distance_at(robot_position: Vector2, heading: float) -> float:
	var nearest := -1.0
	var forward := Vector2(sin(heading), -cos(heading))
	for sample in range(9):
		var angle := lerpf(-SENSOR_HALF_FOV, SENSOR_HALF_FOV, float(sample) / 8.0)
		var distance := _world.raycast(robot_position, forward.rotated(angle))
		if distance > 0.0 and (nearest < 0.0 or distance < nearest):
			nearest = distance
	return nearest
