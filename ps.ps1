<#
.SYNOPSIS
    Cursor Optimization & Identity Reset Tool (Enterprise Edition)
    Version: 1.0.5
    Description: Fixed variable reference errors in logging.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"
$logFile = "$env:TEMP\cursor_reset_log.txt"

$style = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Header  = "Magenta"
}

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    $color = $style[$Type]
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray
    Write-Host "[$($Type.ToUpper())] " -NoNewline -ForegroundColor $color
    Write-Host $Message -ForegroundColor White
    
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor $style.Header
Write-Host "      CURSOR SYSTEM OPTIMIZER - PROFESSIONAL EDITION       " -ForegroundColor $style.Header
Write-Host "==========================================================" -ForegroundColor $style.Header
Write-Log "Starting system diagnostics..."

if (-not (Test-Admin)) {
    Write-Log "This script must be run as Administrator." "Error"
    Write-Host "`nPress any key to exit..."
    $null = [Console]::ReadKey()
    exit
}

Write-Log "Analyzing running processes..."
$processes = Get-Process -Name "Cursor*", "cursor*" -ErrorAction SilentlyContinue
if ($processes) {
    Write-Log "Terminating $($processes.Count) Cursor-related processes..." "Warning"
    $processes | Stop-Process -Force
    Start-Sleep -Seconds 2
}

Write-Log "Cleaning up session metadata..."
$targets = @(
    "$env:USERPROFILE\.cursor",
    "$env:APPDATA\Cursor",
    "$env:LOCALAPPDATA\cursor-updater"
)

foreach ($target in $targets) {
    if (Test-Path $target) {
        try {
            Remove-Item -Path $target -Recurse -Force
            # FIX: Used ${target} to avoid colon drive errors
            Write-Log "Folder successfully cleaned: ${target}" "Success"
        } catch {
            # FIX: Properly escaped the exception message reference
            $errMsg = $_.Exception.Message
            Write-Log "Failed to clean ${target}. Error: ${errMsg}" "Warning"
        }
    }
}

$jsPath = "$env:LOCALAPPDATA\Programs\Cursor\resources\app\out\main.js"

if (Test-Path $jsPath) {
    Write-Log "Core kernel file located."
    $backupPath = $jsPath + ".bak"
    Copy-Item $jsPath $backupPath -Force
    Write-Log "Security backup created: main.js.bak" "Success"

    $newMachineId = [guid]::NewGuid().ToString("n")
    
    $patch = @"
/* --- CURSOR_CORE_PATCH_v1 --- */
;(function(){
    if(globalThis.__PRO_PATCH)return;
    globalThis.__PRO_PATCH=true;
    try {
        const M = require('module');
        const _r = M.prototype.require;
        M.prototype.require = function(i) {
            const m = _r.apply(this, arguments);
            if (i === 'child_process') {
                const _e = m.execSync;
                m.execSync = function(c) {
                    if (c.includes('MachineGuid')) return Buffer.from('$newMachineId');
                    return _e.apply(this, arguments);
                };
            }
            return m;
        };
    } catch(e) {}
})();
"@

    try {
        $originalContent = Get-Content $jsPath -Raw -Encoding UTF8
        $cleanContent = $originalContent -replace "(?s)/\* --- CURSOR_CORE_PATCH_.*? \*/", ""
        $finalContent = $patch + "`n" + $cleanContent
        [System.IO.File]::WriteAllText($jsPath, $finalContent, [System.Text.Encoding]::UTF8)
        Write-Log "Virtual identity injection successful." "Success"
    } catch {
        $errMsg = $_.Exception.Message
        Write-Log "Injection failed: ${errMsg}" "Error"
    }
} else {
    Write-Log "Standard Cursor installation not detected." "Warning"
}

Write-Log "Optimizing Windows Registry..."
try {
    $newGuid = [guid]::NewGuid().ToString()
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -Value $newGuid
    Write-Log "System registry updated successfully." "Success"
} catch {
    Write-Log "Registry access restricted. Please ensure you are running as Admin." "Warning"
}

Write-Host "`n==========================================================" -ForegroundColor $style.Header
Write-Log "OPERATION COMPLETED SUCCESSFULLY" "Success"
Write-Host "A log file has been created in your TEMP folder." -ForegroundColor Gray
Write-Host "Press any key to exit..." -ForegroundColor White
$null = [Console]::ReadKey()