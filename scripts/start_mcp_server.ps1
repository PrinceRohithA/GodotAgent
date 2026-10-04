# Start hybridindie godot-editor-mcp (HTTP) for live smoke harness.
# Bridge uses 19080 because Steam/Nahimic often owns 9080 on this machine.

$ErrorActionPreference = "Stop"
$Exe = Join-Path $env:LOCALAPPDATA "Packages\PythonSoftwareFoundation.Python.3.12_qbz5n2kfra8p0\LocalCache\local-packages\Python312\Scripts\godot-editor-mcp.exe"
if (-not (Test-Path $Exe)) {
    Write-Error "godot-editor-mcp.exe not found at $Exe. Install: py -3 -m pip install godot-editor-mcp==2026.9.30"
}

$env:GODOT_MCP_TRANSPORT = "http"
$env:GODOT_MCP_HTTP_HOST = "127.0.0.1"
$env:GODOT_MCP_HTTP_PORT = "9090"
$env:GODOT_MCP_BRIDGE_URL = "ws://127.0.0.1:19080"
$env:GODOT_MCP_DEFAULT_TOOLSETS = "inspection,scene_edit,scripts,input_map,animation,tilemap,runtime,input,editor,debugger,project,resources_edit,composite"
$env:GODOT_MCP_GODOT_BIN = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$env:GODOT_MCP_PROJECT_DIR = "C:\Rohith\Projects\GodotAgentTest"
$env:GODOT_MCP_LOG_LEVEL = "INFO"

Write-Host "Starting godot-editor-mcp HTTP on http://127.0.0.1:9090/mcp"
Write-Host "Bridge listener: $($env:GODOT_MCP_BRIDGE_URL)"
Write-Host "Open smoke_project in Godot with the same GODOT_MCP_BRIDGE_URL (see start_smoke_godot.ps1)."
& $Exe
