@tool
extends Node
## Web search & scraping adapter supporting Firecrawl v2 and Brave Search.
## Firecrawl works keyless out of the box or with an optional API key (fc-...).
## Credentials stay in AgentConfig's user-only config.

var cfg: RefCounted


func search(args: Dictionary, completed: Callable) -> void:
	var query := str(args.get("query", "")).strip_edges()
	var direct_url := str(args.get("url", "")).strip_edges()
	if query == "" and direct_url == "":
		completed.call_deferred({"ok": false, "error": "missing_query_or_url", "source": "web"})
		return

	var data: Dictionary = cfg.data() if cfg != null else {}
	var web: Dictionary = data.get("web_search", {})
	var provider := str(web.get("provider", "firecrawl")).to_lower()
	var key := str(web.get("api_key", "")).strip_edges()

	if provider == "brave":
		_search_brave(query, args, web, key, completed)
	else:
		_search_firecrawl(query, direct_url, args, web, key, completed)


func _search_firecrawl(query: String, direct_url: String, args: Dictionary, web: Dictionary, key: String, completed: Callable) -> void:
	var is_direct_scrape := false
	var target_url := direct_url
	if target_url == "" and (query.begins_with("http://") or query.begins_with("https://")) and not query.contains(" "):
		target_url = query
		is_direct_scrape = true

	var request := HTTPRequest.new()
	request.timeout = 25.0
	add_child(request)

	var hdrs := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if key != "":
		hdrs.append("Authorization: Bearer %s" % key)

	if is_direct_scrape or direct_url != "":
		var scrape_endpoint := "https://api.firecrawl.dev/v2/scrape"
		var scrape_payload := {
			"url": target_url,
			"formats": ["markdown"]
		}
		request.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			var out := _normalize_firecrawl_scrape(result, code, body, target_url)
			completed.call(out)
			request.queue_free()
		)
		var err := request.request(scrape_endpoint, hdrs, HTTPClient.METHOD_POST, JSON.stringify(scrape_payload))
		if err != OK:
			request.queue_free()
			completed.call_deferred({"ok": false, "error": "firecrawl_scrape_request_failed:%d" % err, "source": "firecrawl"})
		return

	var endpoint := str(web.get("endpoint", "https://api.firecrawl.dev/v2/search"))
	var count := clampi(int(args.get("count", args.get("limit", 5))), 1, 10)
	var scrape_content := bool(args.get("scrape_content", web.get("scrape_content", true)))

	var search_payload := {
		"query": query,
		"limit": count
	}
	if scrape_content:
		search_payload["scrapeOptions"] = {"formats": ["markdown"]}

	request.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		var out := _normalize_firecrawl_search(result, code, body, query)
		completed.call(out)
		request.queue_free()
	)
	var err := request.request(endpoint, hdrs, HTTPClient.METHOD_POST, JSON.stringify(search_payload))
	if err != OK:
		request.queue_free()
		completed.call_deferred({"ok": false, "error": "firecrawl_search_request_failed:%d" % err, "source": "firecrawl"})


func _normalize_firecrawl_scrape(result: int, code: int, body: PackedByteArray, target_url: String) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "firecrawl_transport:%d" % result, "source": "firecrawl"}
	if code < 200 or code >= 300:
		var err_snippet := body.get_string_from_utf8().substr(0, 160)
		return {"ok": false, "error": "firecrawl_http:%d (%s)" % [code, err_snippet], "source": "firecrawl"}
	var raw: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "firecrawl_invalid_json", "source": "firecrawl"}
	var data: Dictionary = (raw as Dictionary).get("data", {})
	var meta: Dictionary = data.get("metadata", {})
	var title := str(meta.get("title", ""))
	var description := str(meta.get("description", ""))
	var md := str(data.get("markdown", ""))
	if md.length() > 8000:
		md = md.substr(0, 8000) + "\n\n...(content truncated to preserve context budget)..."
	return {
		"ok": true,
		"data": {
			"url": str(meta.get("sourceURL", target_url)),
			"title": title,
			"description": description,
			"markdown": md,
			"citation": str(meta.get("sourceURL", target_url))
		},
		"source": "firecrawl"
	}


func _normalize_firecrawl_search(result: int, code: int, body: PackedByteArray, query: String) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "firecrawl_transport:%d" % result, "source": "firecrawl"}
	if code < 200 or code >= 300:
		var err_snippet := body.get_string_from_utf8().substr(0, 160)
		return {"ok": false, "error": "firecrawl_http:%d (%s)" % [code, err_snippet], "source": "firecrawl"}
	var raw: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "firecrawl_invalid_json", "source": "firecrawl"}
	var dict: Dictionary = raw
	var raw_items: Array = []
	if dict.has("data"):
		var d_val: Variant = dict["data"]
		if typeof(d_val) == TYPE_DICTIONARY:
			raw_items = (d_val as Dictionary).get("web", [])
		elif typeof(d_val) == TYPE_ARRAY:
			raw_items = d_val
	var results: Array = []
	for item in raw_items:
		if typeof(item) != TYPE_DICTIONARY: continue
		var item_dict: Dictionary = item
		var title := str(item_dict.get("title", ""))
		var url := str(item_dict.get("url", ""))
		var snippet := str(item_dict.get("description", item_dict.get("snippet", "")))
		var res_obj := {
			"title": title,
			"url": url,
			"snippet": snippet,
			"citation": url
		}
		if item_dict.has("markdown") and str(item_dict["markdown"]).strip_edges() != "":
			var md := str(item_dict["markdown"]).strip_edges()
			if md.length() > 2500:
				md = md.substr(0, 2500) + "\n...(truncated)..."
			res_obj["markdown"] = md
		results.append(res_obj)
	return {
		"ok": true,
		"data": {
			"results": results,
			"query": query,
			"count": results.size()
		},
		"source": "firecrawl"
	}


func _search_brave(query: String, args: Dictionary, web: Dictionary, key: String, completed: Callable) -> void:
	if key == "":
		completed.call_deferred({"ok": false, "error": "web_search_not_configured", "hint": "Brave Search requires an API key. You can also switch to Firecrawl in Models & Keys for keyless access.", "source": "web"})
		return
	var endpoint := str(web.get("endpoint", "https://api.search.brave.com/res/v1/web/search"))
	var count := clampi(int(args.get("count", 5)), 1, 10)
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var out := _normalize_brave(result, code, body)
		completed.call(out)
		request.queue_free()
	)
	var err := request.request(endpoint + "?q=" + query.uri_encode() + "&count=" + str(count), PackedStringArray(["Accept: application/json", "X-Subscription-Token: " + key]), HTTPClient.METHOD_GET)
	if err != OK:
		request.queue_free()
		completed.call_deferred({"ok": false, "error": "web_request_start_failed:%d" % err, "source": "web"})


func _normalize_brave(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "error": "web_transport:%d" % result, "source": "web"}
	if code < 200 or code >= 300: return {"ok": false, "error": "web_http:%d" % code, "source": "web"}
	var raw: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(raw) != TYPE_DICTIONARY: return {"ok": false, "error": "web_invalid_json", "source": "web"}
	var web: Dictionary = raw.get("web", {})
	var raw_results: Array = web.get("results", [])
	var results: Array = []
	for item in raw_results:
		if typeof(item) != TYPE_DICTIONARY: continue
		results.append({"title": str(item.get("title", "")), "url": str(item.get("url", "")), "snippet": str(item.get("description", "")), "citation": str(item.get("url", ""))})
	return {"ok": true, "data": {"results": results}, "source": "web"}
