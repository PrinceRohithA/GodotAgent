@tool
extends Node
## UI client: connects to in-editor agent WS with reconnect backoff.

signal connected()
signal disconnected(reason: String)
signal message(m: Dictionary)

var ws_url := "ws://127.0.0.1:9100"
var _peer: WebSocketPeer
var _connected := false
var _connecting := false
var _connecting_started_at := 0.0
var _retries := 0
var _retry_at := 0.0
var _retry_delay := 0.5
var _max_retry := 5.0


func _ready() -> void:
	set_process(true)


func start() -> void:
	if _connected or _connecting:
		return
	if Time.get_ticks_msec() / 1000.0 < _retry_at:
		return
	_connecting = true
	_connecting_started_at = Time.get_ticks_msec() / 1000.0
	_peer = WebSocketPeer.new()
	_peer.outbound_buffer_size = 4 * 1024 * 1024
	_peer.inbound_buffer_size = 4 * 1024 * 1024
	var err := _peer.connect_to_url(ws_url)
	if err != OK:
		_connecting = false
		_peer = null
		_schedule_retry()


func stop() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_connected = false
	_connecting = false
	_retries = 0


func _process(delta: float) -> void:
	poll(delta)


func poll(_delta: float) -> void:
	if _peer == null:
		if not _connected and not _connecting:
			if Time.get_ticks_msec() / 1000.0 >= _retry_at:
				start()
		return
	_peer.poll()
	var st := _peer.get_ready_state()
	match st:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				_connecting = false
				_retries = 0
				_retry_delay = 0.5
				connected.emit()
				send({"type": "tools.list"})
			while _peer.get_available_packet_count() > 0:
				var txt := _peer.get_packet().get_string_from_utf8()
				var j: Variant = JSON.parse_string(txt)
				if typeof(j) == TYPE_DICTIONARY:
					message.emit(j)
		WebSocketPeer.STATE_CONNECTING:
			if (Time.get_ticks_msec() / 1000.0) - _connecting_started_at > 3.0:
				if _peer != null:
					_peer.close()
					_peer = null
				_connecting = false
				_schedule_retry()
		WebSocketPeer.STATE_CLOSED, WebSocketPeer.STATE_CLOSING:
			if _connected:
				_connected = false
				disconnected.emit("closed")
			_peer = null
			_connecting = false
			_schedule_retry()


func _schedule_retry() -> void:
	if _connected:
		return
	_retries += 1
	var factor := 1.5 if _retries > 0 else 1.0
	_retry_delay = clampf(_retry_delay * factor, 0.5, _max_retry)
	_retry_at = Time.get_ticks_msec() / 1000.0 + _retry_delay


func send(d: Dictionary) -> void:
	if _connected and _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send_text(JSON.stringify(d))


func is_connected_to_agent() -> bool:
	return _connected
