@tool
extends RefCounted
## Agent configuration: loads/saves models, keys, providers, UI prefs.
## Secrets stored in user config JSON (user-only). Never logged.

const CONFIG_DIR_NAME := "GodotAgent"
const CONFIG_FILE_NAME := "config.json"

# Provider defaults (OpenAI-compatible)
const PROVIDERS := {
	"ollama": {
		"name": "Ollama (Local)",
		"type": "local",
		"base_url": "http://127.0.0.1:11434/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": false,
		"streaming": true,
	},
	"lmstudio": {
		"name": "LM Studio (Local)",
		"type": "local",
		"base_url": "http://127.0.0.1:1234/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": false,
		"streaming": true,
	},
	"vllm": {
		"name": "vLLM (Local)",
		"type": "local",
		"base_url": "http://127.0.0.1:8000/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": false,
		"streaming": true,
	},
	"llamacpp": {
		"name": "llama.cpp Server (Local)",
		"type": "local",
		"base_url": "http://127.0.0.1:8080/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": false,
		"streaming": true,
	},
	"openrouter": {
		"name": "OpenRouter",
		"type": "cloud",
		"base_url": "https://openrouter.ai/api/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": true,
		"streaming": true,
	},
	"openai": {
		"name": "OpenAI",
		"type": "cloud",
		"base_url": "https://api.openai.com/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": true,
		"streaming": true,
	},
	"fireworks": {
		"name": "Fireworks AI",
		"type": "cloud",
		"base_url": "https://api.fireworks.ai/inference/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": true,
		"streaming": true,
	},
	"together": {
		"name": "Together AI",
		"type": "cloud",
		"base_url": "https://api.together.xyz/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": true,
		"streaming": true,
	},
	"groq": {
		"name": "Groq",
		"type": "cloud",
		"base_url": "https://api.groq.com/openai/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": true,
		"streaming": true,
	},
	"litellm": {
		"name": "LiteLLM (Proxy)",
		"type": "proxy",
		"base_url": "http://127.0.0.1:4000/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": false,
		"streaming": true,
	},
	"custom": {
		"name": "Custom (OpenAI-compatible)",
		"type": "custom",
		"base_url": "http://127.0.0.1:8000/v1",
		"api_key": "",
		"models_endpoint": "/models",
		"requires_key": false,
		"streaming": true,
	},
}

var _data: Dictionary = {}

func _init() -> void:
	_data = {
		"version": "0.1.0",
		"active_provider": "ollama",
		"active_model": "",
		"providers": _clone_providers(),
		"ui": {
			"chat_font_size": 12,
			"show_thoughts": true,
			"streaming": true,
		},
		"agent": {
			"temperature": 0.2,
			"top_p": 1.0,
			"max_tokens": 4096,
			"max_tool_calls": 0,
			"reasoning": false,
			"reasoning_effort": "none",
			"task_max_minutes": 0,
			"task_max_tool_calls": 0,
			"task_max_llm_rounds": 0,
			"task_request_timeout_seconds": 120,
			"task_auto_compact_threshold": 80000,
		},
		"web_search": {
			"provider": "firecrawl",
			"endpoint": "https://api.firecrawl.dev/v2/search",
			"api_key": "",
			"scrape_content": true,
		},
		"mcp": {
			"enabled": true,
			"endpoint": "http://127.0.0.1:9090/mcp",
			"auto_start_server": true,
		},
		"model_metadata": {},
	}
	_load()

const MODEL_CONTEXT_FALLBACKS := {
	"gemini-1.5": 1000000,
	"gemini-2.0": 1000000,
	"claude-3-7": 200000,
	"claude-3-5": 200000,
	"claude-3": 200000,
	"claude-2": 200000,
	"o1": 200000,
	"o3": 200000,
	"gpt-4o": 128000,
	"gpt-4-turbo": 128000,
	"gpt-5.6-luna": 128000,
	"gpt-4.1": 128000,
	"llama-3.3": 128000,
	"llama-3.2": 128000,
	"llama-3.1": 128000,
	"llama-3": 8192,
	"deepseek": 64000,
	"qwen-2.5": 128000,
	"mistral-large": 128000,
	"mistral-small": 32000,
	"mistral": 32000,
	"codestral": 32000,
	"gpt-4": 8192,
	"gpt-3.5": 16385,
}

static func _clone_providers() -> Dictionary:
	var out := {}
	for k in PROVIDERS:
		var v: Dictionary = PROVIDERS[k]
		out[k] = {
			"name": v.get("name",""),
			"type": v.get("type","custom"),
			"base_url": v.get("base_url",""),
			"api_key": v.get("api_key",""),
			"models_endpoint": v.get("models_endpoint","/models"),
			"requires_key": v.get("requires_key", false),
			"streaming": v.get("streaming", true),
		}
	return out

func get_user_config_dir() -> String:
	if OS.get_name() == "Windows":
		var appdata := OS.get_environment("APPDATA")
		if appdata == "": appdata = OS.get_user_data_dir()
		return appdata.path_join(CONFIG_DIR_NAME)
	else:
		var home := OS.get_environment("HOME")
		if home == "": home = OS.get_user_data_dir().get_base_dir()
		return home.path_join(".config").path_join(CONFIG_DIR_NAME.to_lower())

func get_user_config_path() -> String:
	return get_user_config_dir().path_join(CONFIG_FILE_NAME)

func _load() -> void:
	var path := get_user_config_path()
	if not FileAccess.file_exists(path):
		_save()
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return
	var txt := f.get_as_text()
	f.close()
	var j := JSON.parse_string(txt)
	if typeof(j) == TYPE_DICTIONARY:
		var d := j as Dictionary
		_merge_dict(_data, d)

func _merge_dict(base: Dictionary, src: Dictionary) -> void:
	for k in src:
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(src[k]) == TYPE_DICTIONARY:
			_merge_dict(base[k], src[k])
		else:
			base[k] = src[k]

func _save() -> void:
	var dir := get_user_config_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var path := get_user_config_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()

func data() -> Dictionary: return _data

func register_models_metadata(models_array: Array, provider_id: String = "") -> void:
	if not _data.has("model_metadata") or typeof(_data["model_metadata"]) != TYPE_DICTIONARY:
		_data["model_metadata"] = {}
	for mm in models_array:
		var mid := ""
		var mname := ""
		var ctx_len := 0
		if typeof(mm) == TYPE_DICTIONARY:
			var d := mm as Dictionary
			mid = str(d.get("id", d.get("name", d.get("model", ""))))
			mname = str(d.get("name", mid))
			if d.has("context_length"):
				ctx_len = int(d["context_length"])
			elif d.has("context_window"):
				ctx_len = int(d["context_window"])
			elif d.has("max_context_length"):
				ctx_len = int(d["max_context_length"])
			elif d.has("max_model_len"):
				ctx_len = int(d["max_model_len"])
			elif d.has("max_position_embeddings"):
				ctx_len = int(d["max_position_embeddings"])
			elif d.has("top_provider") and typeof(d["top_provider"]) == TYPE_DICTIONARY:
				var tp: Dictionary = d["top_provider"]
				ctx_len = int(tp.get("context_length", tp.get("max_completion_tokens", 0)))
		elif typeof(mm) == TYPE_STRING:
			mid = str(mm)
			mname = mid

		if mid != "":
			if ctx_len <= 0:
				ctx_len = get_model_context_fallback(mid, provider_id)
			_data["model_metadata"][mid] = {
				"id": mid,
				"name": mname,
				"context_length": ctx_len,
				"provider": provider_id,
			}
	_save()

func get_model_context_fallback(model_id: String, provider_id: String = "") -> int:
	var lower := model_id.to_lower()
	for prefix in MODEL_CONTEXT_FALLBACKS:
		if lower.contains(prefix):
			return int(MODEL_CONTEXT_FALLBACKS[prefix])
	match provider_id.to_lower():
		"ollama", "lmstudio", "vllm", "llamacpp":
			return 32768
		"openrouter", "openai", "groq", "together", "fireworks":
			return 128000
		_:
			return 32768

func get_model_context_window(model_id: String = "", provider_id: String = "") -> int:
	if model_id == "":
		model_id = str(_data.get("active_model", ""))
	if provider_id == "":
		provider_id = str(_data.get("active_provider", "ollama"))
	var meta: Dictionary = _data.get("model_metadata", {})
	if meta.has(model_id):
		var d: Dictionary = meta[model_id]
		var l := int(d.get("context_length", 0))
		if l > 0:
			return l
	return get_model_context_fallback(model_id, provider_id)

func compute_context_budget(context_tokens: int) -> Dictionary:
	var tokens := maxi(4096, context_tokens)
	var compact_chars := clampi(int(tokens * 0.65 * 4), 16000, 800000)
	var max_tool_chars := clampi(int(tokens * 0.15 * 4), 3000, 24000)
	var history_turns := clampi(int(tokens / 4000), 8, 40)
	var max_tokens := clampi(int(tokens * 0.08), 2048, 8192)

	return {
		"context_window_tokens": tokens,
		"task_auto_compact_threshold": compact_chars,
		"max_tool_output_chars": max_tool_chars,
		"max_history_turns": history_turns,
		"max_tokens": max_tokens,
	}

func plan_for_model(model_id: String, provider_id: String = "") -> Dictionary:
	var ctx_tokens := get_model_context_window(model_id, provider_id)
	var budget := compute_context_budget(ctx_tokens)
	if not _data.has("agent") or typeof(_data["agent"]) != TYPE_DICTIONARY:
		_data["agent"] = {}
	_data["agent"]["task_auto_compact_threshold"] = budget["task_auto_compact_threshold"]
	_data["agent"]["max_tokens"] = budget["max_tokens"]
	return budget

func set_active(provider_id: String, model: String="") -> Dictionary:
	if _data.providers.has(provider_id):
		_data.active_provider = provider_id
	if model != "":
		_data.active_model = model
	var plan := plan_for_model(model, provider_id)
	_save()
	return plan

func get_compact_threshold() -> int:
	return int((_data.get("agent", {}) as Dictionary).get("task_auto_compact_threshold", 80000))

func get_max_tool_output_chars() -> int:
	var model_id := str(_data.get("active_model", ""))
	var prov_id := str(_data.get("active_provider", "ollama"))
	var ctx_tokens := get_model_context_window(model_id, prov_id)
	var budget := compute_context_budget(ctx_tokens)
	return int(budget.get("max_tool_output_chars", 12000))

func get_history_limit() -> int:
	var model_id := str(_data.get("active_model", ""))
	var prov_id := str(_data.get("active_provider", "ollama"))
	var ctx_tokens := get_model_context_window(model_id, prov_id)
	var budget := compute_context_budget(ctx_tokens)
	return int(budget.get("max_history_turns", 20))

func get_model_info(model_id: String = "") -> Dictionary:
	if model_id == "":
		model_id = str(_data.get("active_model", ""))
	var prov_id := str(_data.get("active_provider", "ollama"))
	var ctx_tokens := get_model_context_window(model_id, prov_id)
	var budget := compute_context_budget(ctx_tokens)
	budget["model_id"] = model_id
	budget["provider_id"] = prov_id
	return budget

func get_active_provider() -> Dictionary:
	var id := str(_data.get("active_provider", "ollama"))
	var from_data: Variant = _data.providers.get(id, null)
	if typeof(from_data) == TYPE_DICTIONARY:
		return from_data
	var from_defaults: Variant = PROVIDERS.get(id, {})
	return from_defaults if typeof(from_defaults) == TYPE_DICTIONARY else {}

func get_api_key(provider_id: String) -> String:
	var p: Variant = _data.providers.get(provider_id, {})
	if typeof(p) != TYPE_DICTIONARY:
		return ""
	return str((p as Dictionary).get("api_key", ""))

func set_api_key(provider_id: String, key: String) -> void:
	if not _data.providers.has(provider_id):
		var cloned: Variant = _clone_providers().get(provider_id, {})
		_data.providers[provider_id] = cloned if typeof(cloned) == TYPE_DICTIONARY else {}
	_data.providers[provider_id]["api_key"] = key
	_save()

func set_provider_base_url(provider_id: String, base_url: String) -> void:
	if not _data.providers.has(provider_id):
		var cloned: Variant = _clone_providers().get(provider_id, {})
		_data.providers[provider_id] = cloned if typeof(cloned) == TYPE_DICTIONARY else {}
	_data.providers[provider_id]["base_url"] = base_url.rstrip("/")
	_save()

func add_custom_provider(id: String, base_url: String, api_key: String = "", streaming: bool = true, requires_key: bool = false) -> void:
	_data.providers[id] = {
		"name": "Custom: "+id,
		"type": "custom",
		"base_url": base_url.rstrip("/"),
		"api_key": api_key,
		"models_endpoint": "/models",
		"requires_key": requires_key,
		"streaming": streaming,
	}
	_save()

func remove_provider(id: String) -> void:
	if id in ["ollama","lmstudio","openrouter","openai","custom"]: return # keep core
	_data.providers.erase(id)
	_save()

func set_ui(k: String, v: Variant) -> void:
	_data.ui[k] = v
	_save()

func set_agent(k: String, v: Variant) -> void:
	_data.agent[k] = v
	_save()

func set_web_search(endpoint: String, api_key: String, provider: String = "firecrawl", scrape_content: bool = true) -> void:
	_data.web_search = {
		"provider": provider,
		"endpoint": endpoint.rstrip("/"),
		"api_key": api_key,
		"scrape_content": scrape_content,
	}
	_save()

func set_mcp(enabled: bool, endpoint: String = "http://127.0.0.1:9090/mcp", auto_start_server: bool = true) -> void:
	_data.mcp = {"enabled": enabled, "endpoint": endpoint.rstrip("/"), "auto_start_server": auto_start_server}
	_save()
