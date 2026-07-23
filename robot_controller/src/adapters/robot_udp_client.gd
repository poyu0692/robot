class_name RobotUdpClient extends RefCounted

signal link_event(message: String)

# Keep the robot watchdog fed while limiting UDP traffic to 6 Hz.
const CONTROL_PERIOD := 1.0 / 6.0
const MOTOR_LIMIT := 255
const INITIAL_RESPONSE_TIMEOUT := 8.0
const LINK_LOSS_TIMEOUT := 3.0

enum LinkState {
	DISCONNECTED,
	WAITING,
	CONFIRMED,
	TIMED_OUT,
	ERROR,
}

var _address: String
var _port: int
var _peer := PacketPeerUDP.new()
var _previous_direction := Vector2.ZERO
var _send_elapsed := CONTROL_PERIOD
var _response_elapsed := 0.0
var _link_state := LinkState.DISCONNECTED
var _send_error_reported := false

var packets_sent := 0
var packets_received := 0


func _init(address: String, port: int) -> void:
	_address = address
	_port = port


func start() -> void:
	var error := _peer.connect_to_host(_address, _port)
	if error != OK:
		_link_state = LinkState.ERROR
		link_event.emit("UDP setup failed: %s" % error_string(error))
		return
	_link_state = LinkState.WAITING
	_response_elapsed = 0.0
	link_event.emit("Checking robot at %s:%d" % [_address, _port])
	_send_wheels(Vector2i.ZERO)


func update(direction: Vector2, delta: float) -> void:
	if _link_state == LinkState.ERROR or _link_state == LinkState.DISCONNECTED:
		return
	_response_elapsed += delta
	var response_timeout := INITIAL_RESPONSE_TIMEOUT if _link_state == LinkState.WAITING else LINK_LOSS_TIMEOUT
	if _response_elapsed >= response_timeout and _link_state != LinkState.TIMED_OUT:
		_link_state = LinkState.TIMED_OUT
		link_event.emit("Robot response timed out (%.0f s)" % response_timeout)

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
			packets_received += 1
			var previous_state := _link_state
			var response_time_ms := roundi(_response_elapsed * 1000.0)
			_response_elapsed = 0.0
			_link_state = LinkState.CONFIRMED
			if previous_state == LinkState.WAITING:
				link_event.emit("Robot response received (%d ms)" % response_time_ms)
			elif previous_state == LinkState.TIMED_OUT:
				link_event.emit("Robot response restored")
	return latest


func stop() -> void:
	if _link_state != LinkState.DISCONNECTED:
		_send_wheels(Vector2i.ZERO)
	_peer.close()
	_link_state = LinkState.DISCONNECTED


func _wheel_speeds(direction: Vector2) -> Vector2i:
	var forward := -direction.y
	var turn := direction.x
	var left := roundi(clampf(forward + turn, -1.0, 1.0) * MOTOR_LIMIT)
	var right := roundi(clampf(forward - turn, -1.0, 1.0) * MOTOR_LIMIT)
	return Vector2i(left, right)


func _send_wheels(speeds: Vector2i) -> void:
	var error := _peer.put_packet(PackedInt32Array([speeds.x, speeds.y]).to_byte_array())
	if error == OK:
		packets_sent += 1
		_send_error_reported = false
	elif not _send_error_reported:
		_send_error_reported = true
		link_event.emit("UDP send failed: %s" % error_string(error))
