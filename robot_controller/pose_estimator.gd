class_name PoseEstimator
extends RefCounted

const MAX_SPEED := 0.30
const MAX_TURN_RATE := PI * 0.5

var robot_position := Vector2.ZERO
var heading := 0.0


func update(direction: Vector2, delta: float) -> void:
	heading = wrapf(heading + direction.x * MAX_TURN_RATE * delta, -PI, PI)
	robot_position += forward_direction() * (-direction.y * MAX_SPEED) * delta


func forward_direction() -> Vector2:
	return Vector2(sin(heading), -cos(heading))
