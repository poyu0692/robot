class_name RobotView extends Node2D

const PIXELS_PER_METER := 160.0
const GRID_SPACING := 0.5
const ROBOT_WIDTH := 0.18
const ROBOT_LENGTH := 0.3
const ROBOT_COLOR := Color.LAWN_GREEN

var _map: OccupancyMap
var _map_image: Image
var _map_texture: ImageTexture
var _robot_position := Vector2.ZERO
var _heading := 0.0
var _last_distance := -1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_image = Image.create(OccupancyMap.WIDTH, OccupancyMap.HEIGHT, false, Image.FORMAT_RGB8)
	_map_image.fill(Color8(128, 128, 128))
	_map_texture = ImageTexture.create_from_image(_map_image)


func present(frame: RobotFrame) -> void:
	_map = frame.map
	_robot_position = frame.robot_position
	_heading = frame.heading
	_last_distance = frame.distance
	_update_map_texture(frame.changed_cells, frame.replaces_previous_view)
	queue_redraw()


func _update_map_texture(changed_cells: Array[Vector2i], replaces_previous_view: bool) -> void:
	if changed_cells.is_empty() and not replaces_previous_view:
		return
	if replaces_previous_view:
		_map_image.fill(Color8(128, 128, 128))
	for cell in changed_cells:
		var shade := _map.shade_at(cell)
		_map_image.set_pixel(cell.x, cell.y, Color8(shade, shade, shade))
	_map_texture.update(_map_image)


func _draw() -> void:
	if _map == null:
		return
	_draw_map()
	_draw_grid()
	_draw_robot()
	_draw_hud()


func _view_center() -> Vector2:
	return Vector2(get_viewport_rect().size) * 0.5


func _world_to_screen(point: Vector2) -> Vector2:
	return _view_center() + (point - _robot_position) * PIXELS_PER_METER


func _forward_direction() -> Vector2:
	return Vector2(sin(_heading), -cos(_heading))


func _draw_map() -> void:
	var top_left := _world_to_screen(_map.origin)
	var size := Vector2(OccupancyMap.WIDTH, OccupancyMap.HEIGHT) * OccupancyMap.CELL_SIZE * PIXELS_PER_METER
	draw_texture_rect(_map_texture, Rect2(top_left, size), false)


func _draw_grid() -> void:
	var view_size := Vector2(get_viewport_rect().size)
	var color := Color.from_rgba8(60, 60, 60, 90)
	var top_left := _robot_position - _view_center() / PIXELS_PER_METER
	var first := (top_left / GRID_SPACING).floor() * GRID_SPACING
	var x := first.x
	while _world_to_screen(Vector2(x, 0)).x <= view_size.x:
		var screen_x := _world_to_screen(Vector2(x, 0)).x
		draw_line(Vector2(screen_x, 0), Vector2(screen_x, view_size.y), color)
		x += GRID_SPACING
	var y := first.y
	while _world_to_screen(Vector2(0, y)).y <= view_size.y:
		var screen_y := _world_to_screen(Vector2(0, y)).y
		draw_line(Vector2(0, screen_y), Vector2(view_size.x, screen_y), color)
		y += GRID_SPACING


func _draw_robot() -> void:
	var center := _view_center()
	var forward := _forward_direction()
	var side := Vector2(-forward.y, forward.x)
	var half_length := ROBOT_LENGTH * PIXELS_PER_METER * 0.5
	var half_width := ROBOT_WIDTH * PIXELS_PER_METER * 0.5
	var front_left := center + forward * half_length + side * half_width
	var front_right := center + forward * half_length - side * half_width
	var rear_right := center - forward * half_length - side * half_width
	var rear_left := center - forward * half_length + side * half_width
	draw_polyline(PackedVector2Array([front_left, front_right, rear_right, rear_left, front_left]), ROBOT_COLOR, 2.0, true)
	var nose := center + forward * (half_length + half_width * 0.6)
	draw_polyline(PackedVector2Array([front_left, nose, front_right]), ROBOT_COLOR, 2.0, true)


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var bottom := get_viewport_rect().size.y
	var distance_text := "Dist: --" if _last_distance < 0.0 else "Dist: %.2fm" % _last_distance
	var pose_text := "x=%.2f y=%.2f %.0f°" % [_robot_position.x, _robot_position.y, rad_to_deg(_heading)]
	draw_string(font, Vector2(8, bottom - 26), distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.from_rgba8(220, 220, 220))
	draw_string(font, Vector2(8, bottom - 8), pose_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.from_rgba8(160, 160, 160))
