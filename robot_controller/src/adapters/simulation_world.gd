class_name SimulationWorld extends RefCounted

var _walls: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-2.0, -2.0), Vector2(2.0, -2.0)]),
	PackedVector2Array([Vector2(2.0, -2.0), Vector2(2.0, 2.0)]),
	PackedVector2Array([Vector2(2.0, 2.0), Vector2(-2.0, 2.0)]),
	PackedVector2Array([Vector2(-2.0, 2.0), Vector2(-2.0, -2.0)]),
	PackedVector2Array([Vector2(0.4, -0.6), Vector2(1.0, -0.6)]),
	PackedVector2Array([Vector2(1.0, -0.6), Vector2(1.0, 0.0)]),
]


func walls() -> Array[PackedVector2Array]:
	return _walls


func raycast(origin: Vector2, direction: Vector2) -> float:
	var nearest := -1.0
	for wall in _walls:
		var wall_start: Vector2 = wall[0]
		var wall_vector: Vector2 = wall[1] - wall_start
		var denominator := direction.x * wall_vector.y - direction.y * wall_vector.x
		if absf(denominator) < 1e-6:
			continue
		var offset := wall_start - origin
		var ray_distance := (offset.x * wall_vector.y - offset.y * wall_vector.x) / denominator
		var wall_position := (offset.x * direction.y - offset.y * direction.x) / denominator
		if ray_distance >= 0.0 and ray_distance <= OccupancyMap.SONAR_MAX_RANGE and wall_position >= 0.0 and wall_position <= 1.0:
			if nearest < 0.0 or ray_distance < nearest:
				nearest = ray_distance
	return nearest
