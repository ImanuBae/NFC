param([string]$Device = 'emulator-5554')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not (Test-Path -LiteralPath 'config.local.json')) {
        throw 'Create config.local.json from config.example.json and set KIOSK_PIN first.'
    }

    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    $adbPath = if ($adbCommand) { $adbCommand.Source } else {
        Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
    }
    if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Cannot find Android SDK platform-tools/adb.exe.' }
    $deviceState = & $adbPath -s $Device get-state 2>&1
    if ($LASTEXITCODE -ne 0 -or "$deviceState".Trim() -ne 'device') {
        throw "Device $Device is unavailable. Check adb devices and authorize USB debugging."
    }
    $isEmulator = ((& $adbPath -s $Device shell getprop ro.kernel.qemu) -join '').Trim() -eq '1'
    $apiBaseUrl = if ($isEmulator) { 'http://10.0.2.2:5080' } else { 'http://127.0.0.1:5080' }

    function Get-DemoHealth {
        try {
            Invoke-RestMethod 'http://127.0.0.1:5080/health' -TimeoutSec 3
        } catch {
            return $null
        }
    }

    $health = Get-DemoHealth
    if ($null -eq $health) {
        $logDirectory = Join-Path $projectRoot '.local-data'
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        $serverProcess = Start-Process -FilePath 'dotnet' -ArgumentList @(
            'run', '--project', 'server/Attendance.Api', '--no-launch-profile',
            '--urls', 'http://127.0.0.1:5080'
        ) -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $logDirectory 'demo-api.stdout.log') `
            -RedirectStandardError (Join-Path $logDirectory 'demo-api.stderr.log')
        $deadline = (Get-Date).AddSeconds(60)
        do {
            if ($serverProcess.HasExited) {
                throw 'Backend stopped. Check .local-data/demo-api.stderr.log and demo-api.stdout.log.'
            }
            Start-Sleep -Seconds 1
            $health = Get-DemoHealth
        } while ($null -eq $health -and (Get-Date) -lt $deadline)
    }
    if ($null -eq $health -or $health.status -ne 'ok' -or $health.database -ne 'SQL Server') {
        throw 'Backend or SQL Server is unavailable. Check SQL Server and .local-data/demo-api.*.log.'
    }

    if (-not $isEmulator) {
        & $adbPath -s $Device reverse tcp:5080 tcp:5080
        if ($LASTEXITCODE -ne 0) { throw "Cannot forward backend port over USB for $Device." }
    }
    Write-Host "Backend and SQL Server ready. Device $Device uses $apiBaseUrl."
    & flutter run -d $Device --dart-define-from-file=config.local.json "--dart-define=API_BASE_URL=$apiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
}
