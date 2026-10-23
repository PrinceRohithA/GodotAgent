@tool
extends Node
## Streamable-HTTP MCP client. Public MCP tools never go to the Godot WS bridge.

signal connected(tools: Array)
signal disconnected(reason: String)
signal tool_finished(call_id: String, result: Dictionary)
signal tools_changed(tools: Array)

const DEFAULT_ENDPOINT := "http://127.0.0.1:9090/mcp"
const REQUEST_TIMEOUT_SECONDS := 120.0
const RETRY_SECONDS := 5.0

var endpoint := DEFAULT_ENDPOINT
var session_id := ""
var tools: Array = []
var _next_id := 1
var _in_flight := false
var _queue: Array = []
var _state := "idle" # idle|initializing|ready|failed
var _page_tools: Array = []
var _retry_timer: Timer
var _stopped := false

func _ready() -> void:
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(func() -> void:
		if not _stopped: start(endpoint)
	)
	add_child(_retry_timer)

func is_mcp_ready() -> bool:
	return _state == "ready"

func start(url: String = DEFAULT_ENDPOINT) -> void:
	endpoint = url.rstrip("/")
	_stopped = false
	if _state == "initializing" or is_mcp_ready(): return
	_state = "initializing"
	_page_tools.clear()
	_send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {"tools": {"listChanged": true}}, "clientInfo": {"name": "GodotAgent", "version": "0.3.0"}}, "__initialize")

func stop() -> void:
	_stopped = true
	_state = "idle"; session_id = ""; tools.clear(); _queue.clear(); _in_flight = false
	if _retry_timer != null: _retry_timer.stop()

func call_tool(name: String, arguments: Dictionary, call_id: String) -> void:
	if not is_mcp_ready():
		tool_finished.emit(call_id, {"ok": false, "error": "mcp_offline", "source": "mcp"})
		return
	_queue.append({"method": "tools/call", "params": {"name": name, "arguments": arguments}, "call_id": call_id})
	_pump()

func refresh_tools() -> void:
	if not is_mcp_ready() or _in_flight: return
	_page_tools.clear()
	_send("tools/list", {}, "__tools_list")

func _after_initialize(response: Dictionary) -> void:
	if not bool(response.get("ok", false)):
		_fail(str(response.get("error", "MCP initialize failed"))); return
	_notify("notifications/initialized", {})
	_page_tools.clear()
	_send("tools/list", {}, "__tools_list")

func _after_tools_list(response: Dictionary) -> void:
	if not bool(response.get("ok", false)):
		_fail(str(response.get("error", "MCP tools/list failed"))); return
	var payload: Dictionary = response.get("result", {})
	var listed: Variant = payload.get("tools", [])
	if typeof(listed) == TYPE_ARRAY:
		for entry in listed:
			if typeof(entry) == TYPE_DICTIONARY: _page_tools.append(entry)
	var next_cursor := str(payload.get("nextCursor", ""))
	if next_cursor != "":
		_send("tools/list", {"cursor": next_cursor}, "__tools_list")
		return
	tools = _dedupe_tools(_page_tools)
	var was_ready := is_mcp_ready()
	_state = "ready"
	if was_ready: tools_changed.emit(tools)
	else: connected.emit(tools)
	_pump()

func _pump() -> void:
	if _in_flight or _queue.is_empty() or not is_mcp_ready(): return
	var item: Dictionary = _queue.pop_front()
	_send(str(item["method"]), item["params"], str(item["call_id"]))

func _notify(method: String, params: Dictionary) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	var body := {"jsonrpc": "2.0", "method": method, "params": params}
	req.timeout = REQUEST_TIMEOUT_SECONDS
	req.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void: req.queue_free())
	var err := req.request(endpoint, _headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK: req.queue_free()

func _send(method: String, params: Dictionary, call_id: String) -> void:
	_in_flight = true
	var request_id := _next_id; _next_id += 1
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = REQUEST_TIMEOUT_SECONDS
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, bytes: PackedByteArray) -> void:
		_in_flight = false
		var response := _parse_response(result, code, headers, bytes, request_id)
		if bool(response.get("tools_list_changed", false)) and is_mcp_ready():
			call_deferred("refresh_tools")
		if call_id == "__initialize": _after_initialize(response)
		elif call_id == "__tools_list": _after_tools_list(response)
		else:
			tool_finished.emit(call_id, response)
			_pump()
		req.queue_free()
	)
	var body := {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
	var err := req.request(endpoint, _headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_in_flight = false
		var failed := {"ok": false, "error": "mcp_request_start_failed:%d" % err, "source": "mcp"}
		if call_id == "__initialize" or call_id == "__tools_list": _fail(str(failed.get("error", "request failed")))
		else: tool_finished.emit(call_id, failed)
		req.queue_free()

func _headers() -> PackedStringArray:
	var h := PackedStringArray(["Content-Type: application/json", "Accept: application/json, text/event-stream"])
	if session_id != "": h.append("Mcp-Session-Id: " + session_id)
	return h

func _parse_response(result: int, code: int, headers: PackedStringArray, bytes: PackedByteArray, request_id: int) -> Dictionary:
	for header in headers:
		if header.to_lower().begins_with("mcp-session-id:"):
			var pieces := header.split(":", false, 1)
			if pieces.size() == 2: session_id = pieces[1].strip_edges()
	if result != HTTPRequest.RESULT_SUCCESS:
		var err_str := "mcp_transport:%d" % result
		var hint := ""
		match result:
			HTTPRequest.RESULT_TIMEOUT:
				err_str = "mcp_timeout: Request timed out after %d seconds" % int(REQUEST_TIMEOUT_SECONDS)
				hint = "The MCP tool call took longer than %ds to complete. For fast project checks, prefer 'get_diagnostics'." % int(REQUEST_TIMEOUT_SECONDS)
			HTTPRequest.RESULT_CANT_CONNECT:
				err_str = "mcp_cant_connect"
				hint = "Could not connect to MCP endpoint at %s." % endpoint
			HTTPRequest.RESULT_CONNECTION_ERROR:
				err_str = "mcp_connection_error"
			HTTPRequest.RESULT_NO_RESPONSE:
				err_str = "mcp_no_response"
		return {"ok": false, "error": err_str, "raw_result": result, "hint": hint, "source": "mcp"}
	if code < 200 or code >= 300: return {"ok": false, "error": "mcp_http:%d %s" % [code, bytes.get_string_from_utf8().substr(0, 300)], "source": "mcp"}
	var messages := _parse_json_or_sse(bytes.get_string_from_utf8())
	var changed := false
	for msg in messages:
		if typeof(msg) != TYPE_DICTIONARY: continue
		var packet: Dictionary = msg
		if str(packet.get("method", "")) == "notifications/tools/list_changed": changed = true
		if int(packet.get("id", -1)) != request_id: continue
		if packet.has("error"): return {"ok": false, "error": packet.get("error"), "source": "mcp", "tools_list_changed": changed}
		return {"ok": true, "result": packet.get("result", {}), "source": "mcp", "tools_list_changed": changed}
	return {"ok": false, "error": "mcp_missing_response", "source": "mcp", "tools_list_changed": changed}

func _parse_json_or_sse(raw: String) -> Array:
	var out: Array = []
	var normalized := raw.replace("\r\n", "\n").strip_edges()
	# Streamable HTTP may send SSE frames beginning with `event:`. Calling
	# JSON.parse_string on that envelope logs a false parse error in Godot.
	if normalized.begins_with("{"):
		var direct: Variant = JSON.parse_string(normalized)
		if typeof(direct) == TYPE_DICTIONARY: return [direct]
	for frame in normalized.split("\n\n"):
		var data_lines: Array = []
		for line in frame.split("\n"):
			if line.begins_with("data:"): data_lines.append(line.trim_prefix("data:").strip_edges())
		if data_lines.is_empty(): continue
		var payload := "\n".join(data_lines).strip_edges()
		if not payload.begins_with("{"): continue
		var parsed: Variant = JSON.parse_string(payload)
		if typeof(parsed) == TYPE_DICTIONARY: out.append(parsed)
	return out

func _dedupe_tools(entries: Array) -> Array:
	var out: Array = []; var seen := {}
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY: continue
		var name := str(entry.get("name", ""))
		if name == "" or seen.has(name): continue
		seen[name] = true; out.append(entry)
	return out

func _fail(reason: String) -> void:
	var changed := _state != "failed"
	_state = "failed"; tools.clear(); _page_tools.clear()
	if changed: disconnected.emit(reason)
	if not _stopped and _retry_timer != null and _retry_timer.is_stopped(): _retry_timer.start(RETRY_SECONDS)
