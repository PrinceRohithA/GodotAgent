# Open the Phase-0 smoke project in Steam Godot with the MCP bridge URL override.
# Required because ws://127.0.0.1:9080 is occupied by NahimicService on this PC.

$ErrorActionPreference = "Stop"
$Godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$Project = "C:\Rohith\Projects\GodotAgent\smoke_project"

if (-not (Test-Path $Godot)) {
    Write-Error "Steam Godot binary not found: $Godot"
}
if (-not (Test-Path (Join-Path $Project "project.godot"))) {
    Write-Error "smoke_project missing project.godot under $Project"
}

$BridgeUrl = "ws://127.0.0.1:19080"
$env:GODOT_MCP_BRIDGE_URL = $BridgeUrl
Write-Host "Launching Godot editor:"
Write-Host "  binary : $Godot"
Write-Host "  project: $Project"
Write-Host "  bridge : $BridgeUrl"
Write-Host ""
Write-Host "After import, confirm Project Settings → Plugins → Godot MCP is Enabled,"
Write-Host "Autoload MCPRuntimeProbe is present, and the MCP dock shows bridge connected."
Write-Host "Probe attach is automatic on Play once the debugger session is live."

# Explicit ProcessStartInfo so GODOT_MCP_BRIDGE_URL is not lost (Start-Process
# env inheritance is unreliable across some PowerShell / Steam launch paths).
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $Godot
$psi.Arguments = "--editor --path `"$Project`""
$psi.WorkingDirectory = $Project
$psi.UseShellExecute = $false
# Detach stdio so the editor does not glue Vulkan logs to this console.
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
# Copy current env, then force the bridge override the addon reads via OS.get_environment.
foreach ($key in [System.Environment]::GetEnvironmentVariables().Keys) {
    try { $psi.EnvironmentVariables[$key] = [string][System.Environment]::GetEnvironmentVariable($key) } catch {}
}
$psi.EnvironmentVariables["GODOT_MCP_BRIDGE_URL"] = $BridgeUrl
[void][System.Diagnostics.Process]::Start($psi)
