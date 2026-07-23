class_name OccupancyMap extends RefCounted

# マップ1セルの一辺の長さ [m]。
const CELL_SIZE := 0.05
# マップの横方向のセル数 [セル]。
const WIDTH := 480
# マップの縦方向のセル数 [セル]。
const HEIGHT := 480
# 超音波センサで壁として扱う最大測距距離 [m]。
const SONAR_MAX_RANGE := 4.0
# 超音波センサの視野の半角 [rad]。正面の左右にこの角度まで測距する。
const SONAR_HALF_FOV := deg_to_rad(3.0)
# 壁として占有を書き込む視野の半角 [rad]。現在はSONAR_HALF_FOVより広いため、全測距線が対象になる。
const OCCUPIED_HALF_FOV := deg_to_rad(3.0)
# 検出距離の手前側を壁として塗る帯の太さ [m]。
const OCCUPIED_BAND := 0.08
# 壁を観測したときにセルへ足す占有の確信度（対数オッズ）。
const OCCUPIED_UPDATE := 2.0
# 空き空間を観測したときにセルへ足す確信度（対数オッズ）。黒を急に消さないよう壁より小さくする。
const FREE_UPDATE := -0.8
# セルに保持する確信度（対数オッズ）の下限。
const MIN_LOG_ODDS := -5.0
# セルに保持する確信度（対数オッズ）の上限。
const MAX_LOG_ODDS := 5.0

# マップ左上端のワールド座標 [m]。
var origin := Vector2(-WIDTH * CELL_SIZE * 0.5, -HEIGHT * CELL_SIZE * 0.5)
# 各セルの占有確信度（対数オッズ）を1次元で保持した配列。
var _values := PackedFloat32Array()


func _init() -> void:
	_values.resize(WIDTH * HEIGHT)


func integrate(distance: float, robot_position: Vector2, heading: float) -> Array[Vector2i]:
	var changed_cells: Array[Vector2i] = []
	# 負の値は超音波が反射を受け取れなかったことを表す。空き空間の証拠ではない。
	if distance <= 0.0:
		return changed_cells
	var has_obstacle := distance > 0.0 and distance <= SONAR_MAX_RANGE
	var scan_range := distance if has_obstacle else SONAR_MAX_RANGE
	_stamp_fan(scan_range, has_obstacle, robot_position, heading, changed_cells)
	return changed_cells


func shade_at(cell: Vector2i) -> int:
	var value := _values[cell.y * WIDTH + cell.x]
	var probability := 1.0 / (1.0 + exp(-value))
	return roundi((1.0 - probability) * 255.0)


func _stamp_fan(distance: float, has_obstacle: bool, robot_position: Vector2, heading: float, changed_cells: Array[Vector2i]) -> void:
	var ray_count := maxi(1, int(ceil(distance * SONAR_HALF_FOV * 2.0 / CELL_SIZE)))
	var start := world_to_cell(robot_position)
	var forward := Vector2(sin(heading), -cos(heading))
	for ray in range(ray_count + 1):
		var angle := lerpf(-SONAR_HALF_FOV, SONAR_HALF_FOV, float(ray) / ray_count)
		var end := world_to_cell(robot_position + forward.rotated(angle) * distance)
		_stamp_ray(start, end, distance, has_obstacle, absf(angle) <= OCCUPIED_HALF_FOV, robot_position, changed_cells)


func _stamp_ray(start: Vector2i, end: Vector2i, distance: float, has_obstacle: bool, central: bool, robot_position: Vector2, changed_cells: Array[Vector2i]) -> void:
	for cell in _line_cells(start, end):
		var is_end_band := robot_position.distance_to(cell_to_world(cell)) >= distance - OCCUPIED_BAND
		if has_obstacle and is_end_band:
			if central:
				_update_cell(cell, OCCUPIED_UPDATE, changed_cells)
		else:
			_update_cell(cell, FREE_UPDATE, changed_cells)


func _update_cell(cell: Vector2i, update: float, changed_cells: Array[Vector2i]) -> void:
	if not _in_bounds(cell):
		return
	var index := cell.y * WIDTH + cell.x
	_values[index] = clampf(_values[index] + update, MIN_LOG_ODDS, MAX_LOG_ODDS)
	changed_cells.append(cell)


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - origin.x) / CELL_SIZE), floori((point.y - origin.y) / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func _line_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x: int = from.x
	var y: int = from.y
	var dx: int = absi(to.x - x)
	var dy: int = -absi(to.y - y)
	var step_x: int = 1 if x < to.x else -1
	var step_y: int = 1 if y < to.y else -1
	var error: int = dx + dy
	while true:
		cells.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			return cells
		var doubled_error: int = 2 * error
		if doubled_error >= dy:
			error += dy
			x += step_x
		if doubled_error <= dx:
			error += dx
			y += step_y
	return cells
