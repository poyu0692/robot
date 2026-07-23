class_name RobotFrame extends RefCounted

var map: OccupancyMap
var changed_cells: Array[Vector2i]
var robot_position: Vector2
var heading: float
var distance: float
var replaces_previous_view: bool


func _init(
	occupancy_map: OccupancyMap,
	map_changed_cells: Array[Vector2i],
	position: Vector2,
	robot_heading: float,
	measured_distance: float,
	replace_previous_view := false,
) -> void:
	map = occupancy_map
	changed_cells = map_changed_cells
	robot_position = position
	heading = robot_heading
	distance = measured_distance
	replaces_previous_view = replace_previous_view
