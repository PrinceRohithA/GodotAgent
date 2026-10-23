@tool
extends EditorPlugin
## EditorPlugin: right drawer dock + topbar menu + in-editor agent server + client.

const DOCK_NAME := "Agent"
var _dock: Control
var _server: Node
var _client: Node

var _cfg: RefCounted
var _skills: RefCounted
var _tools: RefCounted
var _memory: RefCounted
var _reasoner: RefCounted
var _loop: RefCounted
var _mcp_server_pid := -1

var _mcp_dock: Control
var _mcp_dock_button: Button
var _mcp_bridge: Node
var _mcp_debugger: EditorDebuggerPlugin
var _mcp_router: RefCounted
var _mcp_status_icons: RefCounted
var _mcp_selection: EditorSelection
var _mcp_refresh_timer: Timer
var _mcp_server_version := ""


func _enter_tree() -> void:
	_cfg = preload("res://addons/godot_agent/agent_config.gd").new()
	_skills = preload("res://addons/godot_agent/agent_skills.gd").new()
	_tools = preload("res://addons/godot_agent/agent_tools_bridge.gd").new()
	_memory = preload("res://addons/godot_agent/agent_memory.gd").new()
	_reasoner = preload("res://addons/godot_agent/agent_reasoner_http.gd").new()
	_reasoner.set_config(_cfg)
	_loop = preload("res://addons/godot_agent/agent_core_loop.gd").new()
	_loop.tools_bridge = _tools
	_loop.memory = _memory
	_loop.skills = _skills
	_loop.reasoner = _reasoner
	_loop.cfg = _cfg

	_server = preload("res://addons/godot_agent/agent_server.gd").new()
	_server.cfg = _cfg
	_server.skills = _skills
	_server.tools_bridge = _tools
	_server.loop = _loop
	_server.memory = _memory
	_server.reasoner = _reasoner
	add_child(_server)
	_tools.attach(_server)
	_tools.set_config(_cfg)
	_tools.set_task_runtime(_server.task_runtime)
	_tools.tools_known_changed.connect(_server.refresh_tool_catalog)
	_tools.start()
	_ensure_mcp_server()

	_client = preload("res://addons/godot_agent/agent_client.gd").new()
	var dock_scene: Control = preload("res://addons/godot_agent/agent_dock.gd").new()
	dock_scene.set("client", _client)
	dock_scene.set("cfg", _cfg)
	dock_scene.set("skills", _skills)
	_dock = dock_scene
	# Godot 4: add_control_to_dock returns void (not a Button).
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	add_tool_menu_item("Agent/Models & Keys...", _on_models_keys)
	add_tool_menu_item("Agent/Skills...", _on_skills)
	add_tool_menu_item("Agent/Toggle Agent Dock", _on_toggle_dock)

	_client.message.connect(dock_scene.on_msg)
	_client.connected.connect(func() -> void: dock_scene.set_connected(true))
	_client.disconnected.connect(func(_r: String) -> void: dock_scene.set_connected(false))
	add_child(_client)
	_client.start()

	# Integrated MCP Subsystem
	_init_mcp_subsystem()


func _exit_tree() -> void:
	_cleanup_mcp_subsystem()
	remove_tool_menu_item("Agent/Models & Keys...")
	remove_tool_menu_item("Agent/Skills...")
	remove_tool_menu_item("Agent/Toggle Agent Dock")
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _client != null:
		_client.stop()
		_client.queue_free()
		_client = null
	if _server != null:
		_server.queue_free()
		_server = null
	if _tools != null:
		_tools.stop()


func _init_mcp_subsystem() -> void:
	if not _file_exists_global("res://addons/godot_mcp/mcp_dock.gd"):
		return
	var StatusIconsClass = load("res://addons/godot_mcp/mcp_status_icons.gd")
	if StatusIconsClass != null:
		_mcp_status_icons = StatusIconsClass.new()
	var MCPStatusDockClass = load("res://addons/godot_mcp/mcp_dock.gd")
	if MCPStatusDockClass != null:
		_mcp_dock = MCPStatusDockClass.new()
		_mcp_dock_button = add_control_to_bottom_panel(_mcp_dock, "MCP")
		if _mcp_dock_button != null:
			_mcp_dock_button.button_pressed = true
			_update_mcp_button_icon(0)
		make_bottom_panel_item_visible(_mcp_dock)

	var MCPDebuggerClass = load("res://addons/godot_mcp/mcp_debugger.gd")
	if MCPDebuggerClass != null:
		_mcp_debugger = MCPDebuggerClass.new()
		add_debugger_plugin(_mcp_debugger)

	var MCPCommandRouterClass = load("res://addons/godot_mcp/command_router.gd")
	if MCPCommandRouterClass != null:
		_mcp_router = MCPCommandRouterClass.new()
		if _mcp_debugger != null and _mcp_router.has_method("set_debugger"):
			_mcp_router.set_debugger(_mcp_debugger)

	var MCPBridgeClass = load("res://addons/godot_mcp/mcp_bridge.gd")
	if MCPBridgeClass != null and _mcp_router != null:
		_mcp_bridge = MCPBridgeClass.new(_mcp_router)
		if _mcp_dock != null:
			_mcp_bridge.connection_changed.connect(_on_mcp_connection_changed)
			_mcp_bridge.command_completed.connect(_on_mcp_command_completed)
			_mcp_bridge.event_logged.connect(_on_mcp_bridge_event)
		add_child(_mcp_bridge)
		var bridge_url := OS.get_environment("GODOT_MCP_BRIDGE_URL")
		if bridge_url == "":
			bridge_url = "ws://127.0.0.1:19080"
		if _mcp_dock != null:
			_mcp_dock.set_bridge_url(bridge_url)
		_mcp_bridge.start(bridge_url)

	_mcp_selection = EditorInterface.get_selection()
	if _mcp_selection != null:
		_mcp_selection.selection_changed.connect(_on_mcp_selection_changed)
	scene_changed.connect(_on_mcp_scene_changed)

	_mcp_refresh_timer = Timer.new()
	_mcp_refresh_timer.wait_time = 2.0
	_mcp_refresh_timer.autostart = true
	_mcp_refresh_timer.timeout.connect(_on_mcp_refresh_timer)
	add_child(_mcp_refresh_timer)

	_refresh_mcp_all()


func _cleanup_mcp_subsystem() -> void:
	if _mcp_refresh_timer != null:
		_mcp_refresh_timer.stop()
		_mcp_refresh_timer.queue_free()
		_mcp_refresh_timer = null
	if _mcp_selection != null and _mcp_selection.selection_changed.is_connected(_on_mcp_selection_changed):
		_mcp_selection.selection_changed.disconnect(_on_mcp_selection_changed)
	_mcp_selection = null
	if scene_changed.is_connected(_on_mcp_scene_changed):
		scene_changed.disconnect(_on_mcp_scene_changed)
	if _mcp_bridge != null:
		_mcp_bridge.dispose()
		_mcp_bridge.queue_free()
		_mcp_bridge = null
	_mcp_router = null
	if _mcp_debugger != null:
		_mcp_debugger.dispose()
		remove_debugger_plugin(_mcp_debugger)
		_mcp_debugger = null
	if _mcp_dock != null:
		remove_control_from_bottom_panel(_mcp_dock)
		_mcp_dock.queue_free()
		_mcp_dock = null
		_mcp_dock_button = null
	_mcp_status_icons = null


func _refresh_mcp_all() -> void:
	if _mcp_dock == null:
		return
	_mcp_dock.set_project_path(ProjectSettings.globalize_path("res://"))
	var bridge_url := OS.get_environment("GODOT_MCP_BRIDGE_URL")
	if bridge_url == "":
		bridge_url = "ws://127.0.0.1:19080"
	_mcp_dock.set_bridge_url(bridge_url)
	_mcp_dock.set_server_version(_mcp_server_version_label())
	_on_mcp_scene_changed(EditorInterface.get_edited_scene_root())
	_on_mcp_selection_changed()


func _mcp_server_version_label() -> String:
	var gv := Engine.get_version_info()
	var godot_ver := "Godot %d.%d.%s" % [int(gv.get("major", 0)), int(gv.get("minor", 0)), str(gv.get("patch", ""))]
	if _mcp_server_version.is_empty():
		return godot_ver
	return "godot-mcp %s / %s" % [_mcp_server_version, godot_ver]


func _mcp_scene_label(scene_root: Node) -> String:
	if scene_root == null:
		return ""
	if not scene_root.scene_file_path.is_empty():
		return scene_root.scene_file_path.get_file()
	return scene_root.name


func _update_mcp_editor_state_rows() -> void:
	if _mcp_dock == null:
		return
	var root := EditorInterface.get_edited_scene_root()
	var scene := _mcp_scene_label(root)
	var dirty := false
	if root != null and not root.scene_file_path.is_empty():
		dirty = root.scene_file_path in EditorInterface.get_unsaved_scenes()
	_mcp_dock.set_scene_dirty(scene, dirty)
	var playing: bool = EditorInterface.is_playing_scene()
	var probe: bool = _mcp_debugger != null and _mcp_debugger.is_connected_to_probe()
	_mcp_dock.set_play_state(playing, probe, scene)


func _update_mcp_last_action() -> void:
	if _mcp_dock == null:
		return
	var snapshot: Dictionary = _mcp_router.history_snapshot() if _mcp_router != null else {}
	var action := str(snapshot.get("action", "")) if bool(snapshot.get("has_undo", false)) else ""
	_mcp_dock.set_last_action(action)


func _on_mcp_command_completed(command: String, exec_ms: float, ok: bool, error_code: String) -> void:
	if _mcp_dock != null:
		_mcp_dock.log_command_result(command, ok, error_code)
		_mcp_dock.set_command_stats(_mcp_dock.get_command_count(), exec_ms)
	_update_mcp_last_action()
	if command == "cmd_write_script" or command == "cmd_patch_script":
		EditorInterface.get_resource_filesystem().scan.call_deferred()


func _on_mcp_bridge_event(message: String) -> void:
	if _mcp_dock != null:
		_mcp_dock.log_event(message)


func _on_mcp_refresh_timer() -> void:
	if _mcp_bridge != null and _mcp_dock != null:
		var status_val := int(_mcp_bridge.get_status())
		_mcp_dock.set_connection_status(status_val)
		_update_mcp_button_icon(status_val)
	if _mcp_router != null and _mcp_dock != null:
		if _mcp_router.server_version != _mcp_server_version:
			_mcp_server_version = _mcp_router.server_version
			_mcp_dock.set_server_version(_mcp_server_version_label())
		if _mcp_router.toolsets_known:
			_mcp_dock.set_enabled_toolsets(_mcp_router.enabled_toolsets)
	_update_mcp_last_action()
	_update_mcp_editor_state_rows()


func _on_mcp_connection_changed(status_val: int) -> void:
	_update_mcp_button_icon(status_val)
	if _mcp_dock != null:
		_mcp_dock.set_connection_status(status_val)


func _update_mcp_button_icon(status_val: int) -> void:
	if _mcp_dock_button != null and _mcp_status_icons != null:
		if _mcp_status_icons.has_method("texture"):
			_mcp_dock_button.icon = _mcp_status_icons.texture(status_val)
		elif _mcp_status_icons.has_method("icon_for"):
			_mcp_dock_button.icon = _mcp_status_icons.icon_for(status_val)


func _on_mcp_selection_changed() -> void:
	if _mcp_dock != null and _mcp_selection != null:
		var nodes := _mcp_selection.get_selected_nodes()
		_mcp_dock.set_selected_node(nodes[0].name if not nodes.is_empty() else "")


func _on_mcp_scene_changed(new_root: Node) -> void:
	if _mcp_dock != null:
		_mcp_dock.set_active_scene(_mcp_scene_label(new_root))
		_update_mcp_editor_state_rows()


func _on_models_keys() -> void:
	var d := preload("res://addons/godot_agent/models_dialog.gd").new()
	d.cfg = _cfg
	d.client = _client
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered()


func _on_skills() -> void:
	var d := preload("res://addons/godot_agent/skills_dialog.gd").new()
	d.skills = _skills
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered()


func _on_toggle_dock() -> void:
	if _dock != null:
		_dock.visible = not _dock.visible


func _file_exists_global(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		f.close()
		return true
	return false


func _ensure_mcp_server() -> void:
	if not _file_exists_global("res://addons/godot_mcp/plugin.cfg") and not _file_exists_global("res://mcp_fixture.json") and not _file_exists_global("res://addons/godot_agent/plugin.cfg"):
		return
	var data: Dictionary = _cfg.data() if _cfg != null else {}
	var mcp: Dictionary = data.get("mcp", {})
	if not bool(mcp.get("enabled", true)) or not bool(mcp.get("auto_start_server", true)):
		return

	# Quick check if server is already active on port 9090
	var probe: StreamPeerTCP = StreamPeerTCP.new()
	var err := probe.connect_to_host("127.0.0.1", 9090)
	if err == OK:
		var start_time := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start_time < 50:
			probe.poll()
			var st := probe.get_status()
			if st == StreamPeerTCP.STATUS_CONNECTED:
				probe.disconnect_from_host()
				print("GodotAgent: MCP server already active on port 9090")
				return
			elif st == StreamPeerTCP.STATUS_ERROR:
				break
			OS.delay_msec(5)
		probe.disconnect_from_host()

	var project_path := ProjectSettings.globalize_path("res://").rstrip("/\\")
	var repo_root := project_path.get_base_dir()
	var launcher := repo_root.path_join("scripts").path_join("start_mcp_server.ps1")
	if not _file_exists_global(launcher):
		launcher = project_path.path_join("scripts").path_join("start_mcp_server.ps1")
	if not _file_exists_global(launcher):
		launcher = repo_root.get_base_dir().path_join("scripts").path_join("start_mcp_server.ps1")
	if not _file_exists_global(launcher):
		push_warning("GodotAgent: MCP launcher missing: " + launcher)
		return
	_mcp_server_pid = OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
		"-File", launcher, "-ProjectDir", project_path
	]), false)
	if _mcp_server_pid < 0:
		push_warning("GodotAgent: could not start MCP server")
	else:
		print("GodotAgent: starting MCP server (pid %d)" % _mcp_server_pid)

