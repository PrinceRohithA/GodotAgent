# Apply GodotAgent upstream patches onto the installed godot-editor-mcp package.
# Re-run after: py -3 -m pip install --force-reinstall godot-editor-mcp==2026.9.30

$ErrorActionPreference = "Stop"
$Site = Join-Path $env:LOCALAPPDATA "Packages\PythonSoftwareFoundation.Python.3.12_qbz5n2kfra8p0\LocalCache\local-packages\Python312\site-packages\mcp_server"
$PatchRoot = Join-Path $PSScriptRoot "..\bridges\hybridindie\upstream_patches" | Resolve-Path

if (-not (Test-Path $Site)) {
    Write-Error "mcp_server not found at $Site. Install: py -3 -m pip install godot-editor-mcp==2026.9.30"
}

$pairs = @(
    @{ Src = "models\scripts.py"; Dst = "models\scripts.py" },
    @{ Src = "tools\scripts.py"; Dst = "tools\scripts.py" },
    @{ Src = "models\runtime_session.py"; Dst = "models\runtime_session.py" },
    @{ Src = "tools\runtime_session.py"; Dst = "tools\runtime_session.py" },
    @{ Src = "models\tilemap.py"; Dst = "models\tilemap.py" },
    @{ Src = "tools\tilemap.py"; Dst = "tools\tilemap.py" },
    @{ Src = "models\composite.py"; Dst = "models\composite.py" },
    @{ Src = "tools\composite.py"; Dst = "tools\composite.py" },
    @{ Src = "models\animation.py"; Dst = "models\animation.py" },
    @{ Src = "tools\animation.py"; Dst = "tools\animation.py" },
    @{ Src = "models\spatial.py"; Dst = "models\spatial.py" },
    @{ Src = "tools\spatial.py"; Dst = "tools\spatial.py" },
    @{ Src = "models\debugger.py"; Dst = "models\debugger.py" },
    @{ Src = "tools\debugger.py"; Dst = "tools\debugger.py" },
    @{ Src = "models\runtime_inspect.py"; Dst = "models\runtime_inspect.py" },
    @{ Src = "tools\runtime_inspect.py"; Dst = "tools\runtime_inspect.py" },
    @{ Src = "categories.py"; Dst = "categories.py" },
    @{ Src = "toolsets.py"; Dst = "toolsets.py" },
    @{ Src = "server.py"; Dst = "server.py" },
    @{ Src = "toolset_protocol.py"; Dst = "toolset_protocol.py" },
    @{ Src = "safety.py"; Dst = "safety.py" }
)

foreach ($p in $pairs) {
    $src = Join-Path $PatchRoot $p.Src
    $dst = Join-Path $Site $p.Dst
    if (-not (Test-Path $src)) { Write-Error "Missing patch file: $src" }
    Copy-Item -Force $src $dst
    Write-Host "Patched $($p.Dst)"
}

Write-Host "Done. Restart godot-editor-mcp (scripts\start_mcp_server.ps1)."
