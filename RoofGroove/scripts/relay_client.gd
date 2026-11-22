extends Node
## Tunnels the game's ENet (UDP) traffic through a WebSocket relay so online rooms work through any
## router, CGNAT or mobile network: every device only makes OUTGOING connections.
##   HOST mode:   relay sessions are forwarded to the local ENet server (one local UDP socket per player).
##   CLIENT mode: a local UDP port is opened; the ENet client connects to it and everything is
##                forwarded to the relay.

signal client_ready(port: int)
signal failed(reason: String)

const RETRY_SECONDS: = 3.0
const MAX_RETRIES: = 25
const HOST_RECONNECTS: = 6

var _ws: WebSocketPeer = null
var _url: = ""
var _is_host: = false
var _local_port: = 0
var _sessions: Dictionary = {}
var _udp: PacketPeerUDP = null
var _was_open: = false
var _announced: = false
var _retries: = 0
var _retry_in: = 0.0
var _stopped: = false


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_host(url: String, room_id: String, enet_port: int) -> void :
	_is_host = true
	_local_port = enet_port
	_url = "%s/host?room=%s" % [url.rstrip("/"), room_id]
	_connect()


func start_client(url: String, room_id: String) -> void :
	_is_host = false
	_url = "%s/join?room=%s" % [url.rstrip("/"), room_id]
	_udp = PacketPeerUDP.new()
	var bound: = false
	for p in range(24700, 24800):
		if _udp.bind(p, "127.0.0.1") == OK:
			_local_port = p
			bound = true
			break
	if not bound:
		failed.emit("No free local port")
		return
	_connect()


func stop() -> void :
	_stopped = true
	if _ws != null:
		_ws.close(1000)
		_ws = null
	for cid in _sessions:
		(_sessions[cid] as PacketPeerUDP).close()
	_sessions.clear()
	if _udp != null:
		_udp.close()
		_udp = null
	queue_free()


func _exit_tree() -> void :
	if _udp != null:
		_udp.close()
	for cid in _sessions:
		(_sessions[cid] as PacketPeerUDP).close()


func _connect() -> void :
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 262144
	_ws.outbound_buffer_size = 262144
	_was_open = false
	if _ws.connect_to_url(_url) != OK:
		_ws = null
		_schedule_retry()


func _schedule_retry() -> void :
	_retries += 1
	var limit: = HOST_RECONNECTS if (_is_host and _announced) else MAX_RETRIES
	if _retries > limit:
		_stopped = true
		failed.emit("Relay unreachable")
		return
	_retry_in = RETRY_SECONDS


func _process(delta: float) -> void :
	if _stopped:
		return
	if _ws == null:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
		return
	_ws.poll()
	var state: = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_announced = true
			_retries = 0
			if not _is_host:
				client_ready.emit(_local_port)
		while _ws.get_available_packet_count() > 0:
			var packet: PackedByteArray = _ws.get_packet()
			if _ws.was_string_packet():
				_on_control(packet.get_string_from_utf8())
			else:
				_on_data(packet)
		_pump_local()
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_open: = _was_open
		_ws = null
		_was_open = false
		if was_open and not _is_host:
			_stopped = true
			failed.emit("Relay closed")
			return
		_close_sessions()
		_schedule_retry()


func _close_sessions() -> void :
	for cid in _sessions:
		(_sessions[cid] as PacketPeerUDP).close()
	_sessions.clear()


func _on_control(text: String) -> void :
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var cid: = int(parsed.get("cid", 0))
	match str(parsed.get("t", "")):
		"open":
			_session(cid)
		"close":
			if _sessions.has(cid):
				(_sessions[cid] as PacketPeerUDP).close()
				_sessions.erase(cid)


func _session(cid: int) -> PacketPeerUDP:
	if not _sessions.has(cid):
		var s: = PacketPeerUDP.new()
		s.connect_to_host("127.0.0.1", _local_port)
		_sessions[cid] = s
	return _sessions[cid]


func _on_data(packet: PackedByteArray) -> void :
	if _is_host:
		if packet.size() < 5:
			return
		var cid: int = (packet[0] << 24) | (packet[1] << 16) | (packet[2] << 8) | packet[3]
		_session(cid).put_packet(packet.slice(4))
	elif _udp != null and _udp.get_packet_port() > 0:
		_udp.put_packet(packet)


func _pump_local() -> void :
	if _is_host:
		for cid in _sessions:
			var s: PacketPeerUDP = _sessions[cid]
			while s.get_available_packet_count() > 0:
				var data: PackedByteArray = s.get_packet()
				var out: = PackedByteArray()
				out.append((int(cid) >> 24) & 0xFF)
				out.append((int(cid) >> 16) & 0xFF)
				out.append((int(cid) >> 8) & 0xFF)
				out.append(int(cid) & 0xFF)
				out.append_array(data)
				_ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)
	elif _udp != null:
		while _udp.get_available_packet_count() > 0:
			var data: PackedByteArray = _udp.get_packet()
			_udp.set_dest_address(_udp.get_packet_ip(), _udp.get_packet_port())
			_ws.send(data, WebSocketPeer.WRITE_MODE_BINARY)
