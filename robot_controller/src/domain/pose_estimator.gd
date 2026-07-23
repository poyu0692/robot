class_name PoseEstimator extends RefCounted

# Measured at full forward input: 6 m in 21.23 s.
const MAX_SPEED := 6.0 / 21.23
# Measured at full turn input: 10 rotations in 31.85 s.
const MAX_TURN_RATE := (20.0 * PI) / 33.85

var robot_position := Vector2.ZERO
var heading := 0.0


func update(direction: Vector2, delta: float) -> void:
	heading = wrapf(heading + direction.x * MAX_TURN_RATE * delta, -PI, PI)
	robot_position += forward_direction() * (-direction.y * MAX_SPEED) * delta


func forward_direction() -> Vector2:
	return Vector2(sin(heading), -cos(heading))
