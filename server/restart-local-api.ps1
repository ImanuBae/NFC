param([int]$Port = 5080)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$apiRoot = Join-Path $PSScriptRoot 'Attendance.Api'
$buildBase = Join-Path $projectRoot '.local-data/current-api'
$buildRoot = Join-Path $buildBase (Get-Date -Format 'yyyyMMdd-HHmmssfff')
$apiDll = Join-Path $buildRoot 'Attendance.Api.dll'
$stdout = Join-Path $projectRoot '.local-data/current-api.stdout.log'
$stderr = Join-Path $projectRoot '.local-data/current-api.stderr.log'
$baseUrl = "http://127.0.0.1:$Port"

# Compile first so a failed build cannot take the existing server offline.
& dotnet build $apiRoot -o $buildRoot -p:UseAppHost=false
if ($LASTEXITCODE -ne 0) { throw 'Backend build failed; existing server was not stopped.' }

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique)
foreach ($listenerId in $listeners) {
    $server = Get-CimInstance Win32_Process -Filter "ProcessId = $listenerId"
    $ownedExe = $server.ExecutablePath -and
        $server.ExecutablePath.StartsWith($apiRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($server.ExecutablePath) -eq 'Attendance.Api.exe'
    $ownedDll = $server.Name -eq 'dotnet.exe' -and $server.CommandLine -and
        $server.CommandLine.Contains($buildBase + [IO.Path]::DirectorySeparatorChar) -and
        $server.CommandLine -match 'Attendance\.Api\.dll'
    if (-not ($ownedExe -or $ownedDll)) {
        throw "Port $Port belongs to another process ($listenerId); nothing was stopped."
    }
}
foreach ($listenerId in $listeners) {
    Stop-Process -Id $listenerId
    Wait-Process -Id $listenerId -Timeout 10 -ErrorAction SilentlyContinue
}

$process = Start-Process -FilePath (Get-Command dotnet).Source `
    -ArgumentList @("`"$apiDll`"", '--urls', $baseUrl) `
    -WorkingDirectory $apiRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = (Get-Date).AddSeconds(30)
do {
    if ($process.HasExited) { throw "Backend stopped. Check $stderr and $stdout." }
    try {
        $health = Invoke-RestMethod "$baseUrl/health" -TimeoutSec 2
        $swagger = Invoke-RestMethod "$baseUrl/swagger/v1/swagger.json" -TimeoutSec 2
        if ($health.status -eq 'ok' -and $swagger.paths.'/api/employees/{id}'.delete -and $swagger.paths.'/api/attendance/tickets') {
            Write-Output "Backend updated on $baseUrl (PID $($process.Id)). Delete and ticket APIs are available."
            exit 0
        }
    } catch { }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)
throw "Updated backend did not become ready. Check $stderr and $stdout."
