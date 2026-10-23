param(
    [string]$ProjectDir = ""
)

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
# Let the server expose every toolset it supports. The Godot agent still keeps
# only an API-safe 128-tool *model window* active at a time; this setting is
# about server capability, not what is sent in one LLM request.
$env:GODOT_MCP_DEFAULT_TOOLSETS = "all"
$env:GODOT_MCP_GODOT_BIN = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if ($ProjectDir -ne "" -and (Test-Path $ProjectDir)) {
    $env:GODOT_MCP_PROJECT_DIR = $ProjectDir
} elseif (-not $env:GODOT_MCP_PROJECT_DIR) {
    $env:GODOT_MCP_PROJECT_DIR = Join-Path (Split-Path $PSScriptRoot -Parent) "project"
}
$env:GODOT_MCP_LOG_LEVEL = "INFO"

if (-not (Test-Path "$env:GODOT_MCP_PROJECT_DIR\project.godot")) {
    Write-Error "Godot project missing project.godot under $env:GODOT_MCP_PROJECT_DIR"
}

$probe = [System.Net.Sockets.TcpClient]::new()
try {
    $probe.Connect("127.0.0.1", [int]$env:GODOT_MCP_HTTP_PORT)
    Write-Host "MCP server already listening on http://127.0.0.1:$($env:GODOT_MCP_HTTP_PORT)/mcp"
    exit 0
} catch {
    # Expected when no server is running.
} finally {
    $probe.Dispose()
}

Write-Host "Starting godot-editor-mcp HTTP on http://127.0.0.1:9090/mcp"
Write-Host "Bridge listener: $($env:GODOT_MCP_BRIDGE_URL)"
Write-Host "Open project in Godot with the same GODOT_MCP_BRIDGE_URL (see start_smoke_godot.ps1)."
& $Exe
