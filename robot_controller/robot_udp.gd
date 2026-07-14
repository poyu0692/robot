class_name UdpRobot
extends Robot

const CONTROL_PERIOD := 0.05
const MOTOR_LIMIT := 255

var _address: String
var _port: int
var _peer := PacketPeerUDP.new()
var _previous_direction := Vector2.ZERO
var _send_elapsed := CONTROL_PERIOD


func _init(address: String, port: int) -> void:
	_address = address
	_port = port


func start() -> void:
	_peer.connect_to_host(_address, _port)
	_send_wheels(Vector2i.ZERO)


func update(direction: Vector2, _robot_position: Vector2, _heading: float, delta: float) -> void:
	_send_elapsed += delta
	if direction == _previous_direction and _send_elapsed < CONTROL_PERIOD:
		return
	_send_wheels(_wheel_speeds(direction))
	_previous_direction = direction
	_send_elapsed = 0.0


func poll_distance() -> Variant:
	var latest: Variant = null
	while _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		if packet.size() >= 4:
			# Arduino sends one IEEE 754 float measured in metres; negative is no echo.
			latest = packet.to_float32_array()[0]
	return latest


func stop() -> void:
	_send_wheels(Vector2i.ZERO)
	_peer.close()


func _wheel_speeds(direction: Vector2) -> Vector2i:
	var forward := -direction.y
	var turn := direction.x
	var left := roundi(clampf(forward + turn, -1.0, 1.0) * MOTOR_LIMIT)
	var right := roundi(clampf(forward - turn, -1.0, 1.0) * MOTOR_LIMIT)
	return Vector2i(left, right)


func _send_wheels(speeds: Vector2i) -> void:
	_peer.put_packet(PackedInt32Array([speeds.x, speeds.y]).to_byte_array())
