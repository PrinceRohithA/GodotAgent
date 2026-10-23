@tool
extends RefCounted
## OpenAI-compatible reasoning client (chat completions + tool calling).

signal log(msg: String)
signal completion(chunk: String)
signal done(result: Dictionary)

var cfg_ref: RefCounted


func set_config(c: RefCounted) -> void:
	cfg_ref = c


func format_image_url(img: Variant) -> String:
	if typeof(img) == TYPE_STRING:
		var s := str(img).strip_edges()
		if s.begins_with("data:image/") or s.begins_with("http://") or s.begins_with("https://"):
			return s
		if s.begins_with("res://") or s.begins_with("user://") or s.contains("/") or s.contains("\\"):
			if FileAccess.file_exists(s):
				var bytes := FileAccess.get_file_as_bytes(s)
				if bytes.size() > 0:
					var mime := "image/png"
					var lower := s.to_lower()
					if lower.ends_with(".jpg") or lower.ends_with(".jpeg"):
						mime = "image/jpeg"
					elif lower.ends_with(".webp"):
						mime = "image/webp"
					elif lower.ends_with(".svg"):
						mime = "image/svg+xml"
					return "data:%s;base64,%s" % [mime, Marshalls.raw_to_base64(bytes)]
		if s.length() > 64 and not s.contains(" ") and not s.contains("\n"):
			return "data:image/png;base64," + s
		return s
	elif typeof(img) == TYPE_DICTIONARY:
		var d: Dictionary = img
		if d.has("url"):
			return str(d["url"])
		if d.has("image_url"):
			var iu_v: Variant = d["image_url"]
			if typeof(iu_v) == TYPE_DICTIONARY:
				return str((iu_v as Dictionary).get("url", ""))
			return str(iu_v)
		var b64 := str(d.get("base64", d.get("data", d.get("image", ""))))
		if b64 != "":
			if b64.begins_with("data:image/") or b64.begins_with("http://") or b64.begins_with("https://"):
				return b64
			var mime := str(d.get("mime_type", d.get("mimeType", d.get("format", "png"))))
			if not mime.contains("/"):
				mime = "image/" + mime
			return "data:%s;base64,%s" % [mime, b64]
		if d.has("path"):
			return format_image_url(str(d["path"]))
	elif typeof(img) == TYPE_OBJECT and img is Image:
		var png_bytes := (img as Image).save_png_to_buffer()
		return "data:image/png;base64," + Marshalls.raw_to_base64(png_bytes)
	return ""


func build_messages(system_prompt: String, user_prompt: Variant, history: Array = [], images: Array = []) -> Array:
	var msgs: Array = []
	if system_prompt != "":
		msgs.append({"role": "system", "content": system_prompt})
	for h in history:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var role := str(h.get("role", "user"))
		# Only replay plain user/assistant turns from dock history.
		if role in ["user", "assistant"]:
			var c: Variant = h.get("content", "")
			if typeof(c) == TYPE_ARRAY:
				msgs.append({"role": role, "content": c})
			elif typeof(c) == TYPE_DICTIONARY:
				msgs.append({"role": role, "content": [c]})
			else:
				var h_imgs: Variant = h.get("images", [])
				if typeof(h_imgs) == TYPE_ARRAY and not (h_imgs as Array).is_empty():
					var parts: Array = []
					if str(c) != "":
						parts.append({"type": "text", "text": str(c)})
					for img in (h_imgs as Array):
						var u := format_image_url(img)
						if u != "":
							parts.append({"type": "image_url", "image_url": {"url": u}})
					msgs.append({"role": role, "content": parts})
				else:
					msgs.append({"role": role, "content": str(c)})

	# Determine current user content
	var user_content: Variant
	if typeof(user_prompt) == TYPE_ARRAY:
		user_content = user_prompt
	elif images.size() > 0:
		var parts: Array = []
		if str(user_prompt) != "":
			parts.append({"type": "text", "text": str(user_prompt)})
		for img in images:
			var u := format_image_url(img)
			if u != "":
				parts.append({"type": "image_url", "image_url": {"url": u}})
		user_content = parts
	else:
		user_content = str(user_prompt)

	# Dock already includes the current user turn in history — don't duplicate.
	if msgs.size() > 0:
		var last: Variant = msgs[msgs.size() - 1]
		if typeof(last) == TYPE_DICTIONARY and str(last.get("role", "")) == "user":
			var last_content: Variant = last.get("content", "")
			if typeof(last_content) == typeof(user_content) and last_content == user_content:
				return msgs
			# If user_content has images but last_content was plain text, upgrade last message
			if typeof(user_content) == TYPE_ARRAY and typeof(last_content) == TYPE_STRING:
				if str(user_prompt) != "" and last_content == str(user_prompt):
					last["content"] = user_content
					return msgs

	msgs.append({"role": "user", "content": user_content})
	return msgs


func chat(system_prompt: String, user_prompt: Variant, history: Array = [], tools: Array = [], images: Array = []) -> Dictionary:
	var msgs := build_messages(system_prompt, user_prompt, history, images)
	return request_messages(msgs, tools)


func request_messages(messages: Array, tools: Array = []) -> Dictionary:
	if cfg_ref == null:
		return {"ok": false, "error": "no_config"}
	var d: Dictionary = cfg_ref.data()
	var pid := str(d.get("active_provider", "ollama"))
	var p_v: Variant = d.providers.get(pid, {})
	var p: Dictionary = p_v if typeof(p_v) == TYPE_DICTIONARY else {}
	var base := str(p.get("base_url", "")).rstrip("/")
	var key := str(p.get("api_key", ""))
	var model := str(d.get("active_model", ""))
	var agent_v: Variant = d.get("agent", {})
	var agent: Dictionary = agent_v if typeof(agent_v) == TYPE_DICTIONARY else {}
	var temp := float(agent.get("temperature", 0.2))
	var max_tokens := int(agent.get("max_tokens", 4096))
	var reasoning_effort := str(agent.get("reasoning_effort", "medium" if bool(agent.get("reasoning", false)) else "none"))

	if base == "":
		return {"ok": false, "error": "no_base_url — set provider base URL in Models & Keys"}
	if model == "":
		return {"ok": false, "error": "no_model — pick an active model in Models & Keys"}
	if bool(p.get("requires_key", false)) and key.strip_edges() == "":
		return {
			"ok": false,
			"error": "no_api_key — add the provider API key in Models & Keys",
			"error_type": "auth_required",
			"provider": pid,
			"provider_name": str(p.get("name", pid)),
			"model": model,
		}

	var url := "%s/chat/completions" % base
	var hdrs: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if key != "":
		hdrs.append("Authorization: Bearer %s" % key)

	var body := {
		"model": model,
		"messages": messages,
		"stream": false,
	}
	var m_lower := model.to_lower()
	var is_reasoning := (
		m_lower.begins_with("o1") or m_lower.begins_with("o3") or m_lower.begins_with("o4")
		or m_lower.contains("gpt-5") or m_lower.contains("gpt-6")
		or m_lower.contains("reasoning") or m_lower.contains("reasoner")
		or m_lower.contains("deepseek-r1") or m_lower.contains("/r1") or m_lower.begins_with("r1")
		or m_lower.contains("qwq") or m_lower.contains("claude-3-7")
		or m_lower.contains("thinking")
	)
	var use_completion_tokens := pid in ["openai", "openrouter", "groq", "fireworks", "together"] or is_reasoning
	if use_completion_tokens:
		body["max_completion_tokens"] = max_tokens
		if not is_reasoning:
			body["temperature"] = temp
	else:
		body["temperature"] = temp
		body["max_tokens"] = max_tokens
	if tools.size() > 0:
		body["tools"] = tools
		body["tool_choice"] = "auto"
	# Chat Completions rejects function tools plus non-none reasoning for Luna.
	# Keep the selected effort for ordinary completions and compatible models.
	var is_luna := model.to_lower().contains("gpt-5.6-luna")
	if tools.size() > 0 and is_luna:
		body["reasoning_effort"] = "none"
	elif reasoning_effort != "none" and is_reasoning:
		if pid == "openrouter":
			body["reasoning"] = {"effort": reasoning_effort}
		else:
			body["reasoning_effort"] = reasoning_effort

	return {
		"ok": true,
		"method": "POST",
		"url": url,
		"headers": hdrs,
		"body": JSON.stringify(body),
	}


func extract_reasoning_and_content(msg: Dictionary, fallback_text: String = "") -> Dictionary:
	var reasoning := ""
	var content := ""

	if msg.has("reasoning_content") and msg["reasoning_content"] != null:
		reasoning = str(msg["reasoning_content"]).strip_edges()
	elif msg.has("reasoning") and msg["reasoning"] != null:
		reasoning = str(msg["reasoning"]).strip_edges()
	elif msg.has("thought") and msg["thought"] != null:
		reasoning = str(msg["thought"]).strip_edges()

	var raw_content_v: Variant = msg.get("content", fallback_text)
	var raw_content := "" if raw_content_v == null else str(raw_content_v)
	if raw_content == "<null>":
		raw_content = ""

	# Check for embedded <think>...</think> or <thought>...</thought> tags in raw_content
	while true:
		var think_start := raw_content.find("<think>")
		if think_start == -1:
			break
		var think_end := raw_content.find("</think>", think_start + 7)
		if think_end != -1:
			var embedded_think := raw_content.substr(think_start + 7, think_end - (think_start + 7)).strip_edges()
			if reasoning == "":
				reasoning = embedded_think
			else:
				reasoning += "\n" + embedded_think
			raw_content = (raw_content.substr(0, think_start) + " " + raw_content.substr(think_end + 8)).strip_edges()
		else:
			var embedded_think := raw_content.substr(think_start + 7).strip_edges()
			if reasoning == "":
				reasoning = embedded_think
			else:
				reasoning += "\n" + embedded_think
			raw_content = raw_content.substr(0, think_start).strip_edges()
			break

	while true:
		var thought_start := raw_content.find("<thought>")
		if thought_start == -1:
			break
		var thought_end := raw_content.find("</thought>", thought_start + 9)
		if thought_end != -1:
			var embedded_thought := raw_content.substr(thought_start + 9, thought_end - (thought_start + 9)).strip_edges()
			if reasoning == "":
				reasoning = embedded_thought
			else:
				reasoning += "\n" + embedded_thought
			raw_content = (raw_content.substr(0, thought_start) + " " + raw_content.substr(thought_end + 10)).strip_edges()
		else:
			var embedded_thought := raw_content.substr(thought_start + 9).strip_edges()
			if reasoning == "":
				reasoning = embedded_thought
			else:
				reasoning += "\n" + embedded_thought
			raw_content = raw_content.substr(0, thought_start).strip_edges()
			break

	content = raw_content
	return {"content": content, "reasoning": reasoning}


func parse_completion(body: PackedByteArray) -> Dictionary:
	var t := body.get_string_from_utf8()
	var j: Variant = JSON.parse_string(t)
	if typeof(j) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json", "raw": t.substr(0, 400)}
	var d: Dictionary = j
	if d.has("error"):
		var err_v: Variant = d["error"]
		var err_txt := str(err_v)
		if typeof(err_v) == TYPE_DICTIONARY:
			err_txt = str(err_v.get("message", err_txt))
		return {"ok": false, "error": err_txt}
	var choices_v: Variant = d.get("choices", [])
	if typeof(choices_v) == TYPE_ARRAY and (choices_v as Array).size() > 0:
		var c0: Variant = (choices_v as Array)[0]
		if typeof(c0) == TYPE_DICTIONARY:
			var msg_v: Variant = c0.get("message", {})
			if typeof(msg_v) == TYPE_DICTIONARY:
				var msg: Dictionary = msg_v
				var extracted := extract_reasoning_and_content(msg)
				var content: String = extracted.get("content", "")
				var reasoning: String = extracted.get("reasoning", "")
				var tool_calls: Array = []
				var tc_v: Variant = msg.get("tool_calls", [])
				if typeof(tc_v) == TYPE_ARRAY:
					tool_calls = tc_v
				# OpenAI requires assistant tool_call messages to omit null content.
				if tool_calls.size() > 0:
					msg = msg.duplicate()
					if content == "":
						msg.erase("content")
					else:
						msg["content"] = content
					msg["tool_calls"] = tool_calls
					msg["role"] = "assistant"
				if tool_calls.size() > 0 or content != "" or reasoning != "":
					return {
						"ok": true,
						"text": content,
						"reasoning": reasoning,
						"tool_calls": tool_calls,
						"message": msg,
						"finish_reason": str(c0.get("finish_reason", "")),
					}
			var text := str(c0.get("text", ""))
			if text != "":
				var extracted_text := extract_reasoning_and_content({}, text)
				return {
					"ok": true,
					"text": str(extracted_text.get("content", "")),
					"reasoning": str(extracted_text.get("reasoning", "")),
					"tool_calls": []
				}
	if d.has("message") and typeof(d["message"]) == TYPE_DICTIONARY:
		var extracted2 := extract_reasoning_and_content(d["message"])
		var content2 := str(extracted2.get("content", ""))
		var reasoning2 := str(extracted2.get("reasoning", ""))
		if content2 != "" or reasoning2 != "":
			return {"ok": true, "text": content2, "reasoning": reasoning2, "tool_calls": []}
	if str(d.get("response", "")) != "":
		var extracted3 := extract_reasoning_and_content({}, str(d["response"]))
		return {"ok": true, "text": str(extracted3.get("content", "")), "reasoning": str(extracted3.get("reasoning", "")), "tool_calls": []}
	return {"ok": false, "error": "empty_completion", "raw": t.substr(0, 400)}


func is_transient_network_error(result: int, code: int) -> bool:
	if result in [
		HTTPRequest.RESULT_CANT_CONNECT,
		HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_CONNECTION_ERROR,
		HTTPRequest.RESULT_NO_RESPONSE,
		HTTPRequest.RESULT_REQUEST_FAILED,
		HTTPRequest.RESULT_TIMEOUT,
	]:
		return true
	if code in [429, 500, 502, 503, 504]:
		return true
	return false


func is_auth_error(code: int, error_text: String = "") -> bool:
	if code in [401, 403]:
		return true
	var lower := error_text.to_lower()
	if "invalid_api_key" in lower or "incorrect api key" in lower or "invalid api key" in lower:
		return true
	if "unauthorized" in lower or "authentication" in lower or "token expired" in lower or "api key not provided" in lower:
		return true
	return false


func describe_network_error(result: int, code: int, body: PackedByteArray = PackedByteArray()) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_TIMEOUT:
				return "Request timed out waiting for LLM response"
			HTTPRequest.RESULT_CANT_CONNECT:
				return "Connection refused. Model server or network endpoint is unreachable"
			HTTPRequest.RESULT_CANT_RESOLVE:
				return "Cannot resolve model host (DNS lookup failed)"
			HTTPRequest.RESULT_CONNECTION_ERROR:
				return "Network connection interrupted or reset"
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				return "TLS/SSL handshake failed while contacting model server"
			HTTPRequest.RESULT_NO_RESPONSE:
				return "No response received from model server"
			_:
				return "Network transport failure (HTTPRequest error %d)" % result
	if code == 429:
		return "Rate limit exceeded (HTTP 429 - Too Many Requests). Model provider is throttling requests"
	elif code == 502:
		return "Bad Gateway (HTTP 502). Upstream model gateway or proxy is unreachable"
	elif code == 503:
		return "Service Unavailable (HTTP 503). Model provider is temporarily overloaded or undergoing maintenance"
	elif code == 504:
		return "Gateway Timeout (HTTP 504). Upstream model provider timed out"
	elif code == 500:
		return "Internal Server Error (HTTP 500) from model provider"
	elif code > 0:
		var snippet := body.get_string_from_utf8().substr(0, 150)
		return "HTTP %d error: %s" % [code, snippet]
	return "Unknown network error"


func describe_auth_error(code: int, body: PackedByteArray = PackedByteArray()) -> String:
	var msg := ""
	if body.size() > 0:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			var d: Dictionary = parsed
			if d.has("error"):
				var err_v: Variant = d["error"]
				if typeof(err_v) == TYPE_DICTIONARY:
					msg = str((err_v as Dictionary).get("message", ""))
				else:
					msg = str(err_v)
	if msg == "":
		if code == 401:
			msg = "Invalid or expired API key (HTTP 401 Unauthorized)"
		elif code == 403:
			msg = "Access forbidden or quota exhausted (HTTP 403 Forbidden)"
		else:
			msg = "Authentication failed (HTTP %d)" % code
	return msg

