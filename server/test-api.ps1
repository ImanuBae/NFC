param([string]$SqlServer = 'localhost', [int]$Port = 5081, [string]$ApiDll = 'bin\Debug\net10.0\Attendance.Api.dll', [switch]$WithEmail, [switch]$WithSmtp)
if ($WithSmtp) { $WithEmail = $true }
$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$apiRoot = Join-Path $PSScriptRoot 'Attendance.Api'
$localRoot = Join-Path $workspace '.local-data'
$database = 'NfcAttendance_Integration_' + [Guid]::NewGuid().ToString('N')
$credentialsFile = Join-Path $localRoot ($database + '.json')
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE'
$base = "http://127.0.0.1:$Port"
$script:checks = 0
function Check($condition, [string]$message) {
    if (-not $condition) { throw "FAILED: $message" }
    $script:checks++
}
function Api([string]$method, [string]$path, $body = $null, [string]$token = '') {
    $script:lastRequest = "$method $path"
    $parameters = @{ Method=$method; Uri="$base/api$path"; ContentType='application/json' }
    if ($token) { $parameters.Headers = @{Authorization="Bearer $token"} }
    if ($null -ne $body) { $parameters.Body = $body | ConvertTo-Json -Depth 10 -Compress }
    try { $data=Invoke-RestMethod @parameters; foreach($entry in $data){ $entry } } catch {
        $reader=New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
        $script:lastError=$reader.ReadToEnd(); $reader.Dispose()
        throw
    }
}
function Rejected([scriptblock]$operation, [int]$status) {
    try { & $operation | Out-Null } catch {
        Check ([int]$_.Exception.Response.StatusCode -eq $status) "Expected HTTP $status, received $($_.Exception.Response.StatusCode)"
        return
    }
    throw "Expected request rejection HTTP $status"
}
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = (Get-Command dotnet).Source
$processInfo.Arguments = "`"$ApiDll`" --urls $base"
$processInfo.WorkingDirectory = $apiRoot
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$processInfo.EnvironmentVariables['ConnectionStrings__Attendance'] = "Server=$SqlServer;Database=$database;Trusted_Connection=True;TrustServerCertificate=True"
$processInfo.EnvironmentVariables['Bootstrap__ImportFile'] = Join-Path $localRoot 'no-test-import.json'
$processInfo.EnvironmentVariables['Bootstrap__CredentialsFile'] = $credentialsFile
$processInfo.EnvironmentVariables['Logging__LogLevel__Default'] = 'Warning'
$processInfo.EnvironmentVariables['Email__ResendApiKey'] = ''
$processInfo.EnvironmentVariables['Email__Provider'] = 'Resend'
$processInfo.EnvironmentVariables['Email__Smtp__AppPassword'] = ''
$processInfo.EnvironmentVariables['Email__Enabled'] = 'false'
$processInfo.EnvironmentVariables['Email__From'] = ''
$processInfo.EnvironmentVariables['Email__ResendEndpoint'] = ''
$fakeEmailProcess = $null
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo
try {
    if ($WithEmail) {
        $fakeEmailPort = $Port + 1
        $fakeEmailRoot = "http://127.0.0.1:$fakeEmailPort"
        $fakeEmailInfo = New-Object System.Diagnostics.ProcessStartInfo
        $fakeEmailInfo.FileName = (Get-Command python).Source
        $fakeEmailScript = if ($WithSmtp) { 'fake-smtp-server.py' } else { 'fake-email-server.py' }
        $fakeEmailInfo.Arguments = "`"$(Join-Path $PSScriptRoot $fakeEmailScript)`" --port $fakeEmailPort"
        if ($WithSmtp) { $fakeEmailInfo.Arguments += " --smtp-port $($Port + 2)" }
        $fakeEmailInfo.UseShellExecute = $false
        $fakeEmailInfo.CreateNoWindow = $true
        $fakeEmailProcess = New-Object System.Diagnostics.Process
        $fakeEmailProcess.StartInfo = $fakeEmailInfo
        $null = $fakeEmailProcess.Start()
        for ($attempt=0; $attempt -lt 20; $attempt++) {
            if ($fakeEmailProcess.HasExited) { throw 'Fake email server exited' }
            try { $null=Invoke-RestMethod "$fakeEmailRoot/health" -TimeoutSec 1; break } catch { Start-Sleep -Milliseconds 200 }
        }
        $processInfo.EnvironmentVariables['Email__ResendApiKey'] = 'test-key'
        $processInfo.EnvironmentVariables['Email__Enabled'] = 'true'
        $processInfo.EnvironmentVariables['Email__From'] = 'Attendance <no-reply@company.example>'
        $processInfo.EnvironmentVariables['Email__ResendEndpoint'] = "$fakeEmailRoot/emails"
        if ($WithSmtp) {
            $processInfo.EnvironmentVariables['Email__Provider'] = 'Gmail'
            $processInfo.EnvironmentVariables['Email__From'] = 'Attendance <company@company.example>'
            $processInfo.EnvironmentVariables['Email__Smtp__Host'] = '127.0.0.1'
            $processInfo.EnvironmentVariables['Email__Smtp__Port'] = [string]($Port + 2)
            $processInfo.EnvironmentVariables['Email__Smtp__Username'] = 'company@company.example'
            $processInfo.EnvironmentVariables['Email__Smtp__AppPassword'] = 'test-app-password'
            $processInfo.EnvironmentVariables['Email__Smtp__AllowLocalPlaintext'] = 'true'
        }
    }
    $null = $process.Start()
    $output = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    $ready = $false
    for ($attempt=0; $attempt -lt 40; $attempt++) {
        if ($process.HasExited) { throw "Test API exited: $($errors.Result)" }
        try { $null=Invoke-RestMethod "$base/health" -TimeoutSec 1; $ready=$true; break } catch { Start-Sleep -Milliseconds 200 }
    }
    Check $ready 'SQL Server test API starts'
    $swaggerUi=Invoke-WebRequest -UseBasicParsing "$base/swagger/index.html"
    Check ($swaggerUi.StatusCode -eq 200 -and $swaggerUi.Content -match 'swagger-ui') 'Swagger UI is accessible before login'
    $swagger=Invoke-RestMethod "$base/swagger/v1/swagger.json"
    $documented=@{}
    foreach ($path in $swagger.paths.PSObject.Properties) {
        foreach ($verb in $path.Value.PSObject.Properties) {
            if ($verb.Name -in @('get','post','put','delete','patch')) {
                $documented["$($verb.Name.ToUpper()) $($path.Name)"]=$verb.Value
            }
        }
    }
    $routeSources=(Get-Content -Raw (Join-Path $apiRoot 'Endpoints.cs')) + (Get-Content -Raw (Join-Path $apiRoot 'EmployeeImport.cs'))
    $routes=[regex]::Matches($routeSources,'app\.Map(Get|Post|Put|Delete|Patch)\("([^"]+)"')
    Check ($routes.Count -eq $documented.Count) 'Swagger covers every registered API operation'
    foreach ($route in $routes) {
        $key=$route.Groups[1].Value.ToUpper()+' '+$route.Groups[2].Value.Replace(':guid','')
        Check ($documented.ContainsKey($key)) "Swagger documents $key"
        $operation=$documented[$key]
        Check ([bool]$operation.summary -and [bool]$operation.description -and $operation.tags.Count -gt 0) "Swagger labels $key"
        $public=$key -in @('GET /health','POST /api/auth/login')
        Check ($public -or ($operation.security.Count -eq 1 -and $null -ne $operation.security[0].Bearer)) "Swagger requires token for $key"
    }
    Check ($swagger.components.securitySchemes.Bearer.type -eq 'http' -and $swagger.components.securitySchemes.Bearer.scheme -eq 'bearer') 'Authorize sends HTTP Bearer session tokens'
    Check ($documented['POST /api/auth/login'].security.Count -eq 0) 'Login does not require an existing token'
    $businessDoc=$documented['POST /api/business'].requestBody.content.'application/json'
    Check (@($businessDoc.examples.PSObject.Properties).Count -eq 8 -and $businessDoc.schema.oneOf.Count -eq 8) 'Swagger exposes all business actions and camera purpose examples'
    Check ($documented['POST /api/scans'].requestBody.content.'application/json'.schema.required -contains 'device_id') 'NFC request schema describes required device identity'
    Check ($documented['POST /api/employees/import/commit'].requestBody.content.'application/json'.schema.required -contains 'import_id') 'Excel commit documents idempotent import identity'
    $credentials = Get-Content -Raw $credentialsFile | ConvertFrom-Json
    $admin = $credentials | Where-Object Role -eq 'admin' | Select-Object -First 1
    $kiosk = $credentials | Where-Object Role -eq 'kiosk' | Select-Object -First 1
    $adminToken = (Api POST '/auth/login' @{email=$admin.Email; password=$admin.Password}).token
    $kioskToken = (Api POST '/auth/login' @{email=$kiosk.Email; password=$kiosk.Password}).token
    Rejected { Api GET '/employees' } 401
    Rejected { Api POST '/auth/login' @{email=$admin.Email;password='incorrect'} } 401
    $employee = Api POST '/employees' @{code='E1';full_name='Test employee';active=$true;hourly_rate=60000} $adminToken
    $other = Api POST '/employees' @{code='E2';full_name='Other employee';active=$true;hourly_rate=30000} $adminToken
    $employeeAccount = Api POST '/business' @{action='save_account';email='e1@test.local';password='Integration!12345';role='employee';active=$true;employee_id=$employee.id} $adminToken
    $employeeToken = (Api POST '/auth/login' @{email='e1@test.local';password='Integration!12345'}).token
    Check (@(Api GET '/employees' $null $employeeToken).Count -eq 1) 'Employee sees only own profile'
    Rejected { Api GET "/employees/$($other.id)" $null $employeeToken } 403
    Rejected { Api GET '/accounts' $null $employeeToken } 403
    Rejected { Api POST '/business' @{action='save_account';id=(Api GET '/auth/me' $null $kioskToken).id;email=$kiosk.Email;role='kiosk';active=$true;employee_id=$employee.id} $adminToken } 400
    Check ($null -eq (Api GET '/auth/me' $null $kioskToken).employee_id) 'Kiosk has no employee link'
    $device = Api POST '/devices' @{name='Integration kiosk'} $kioskToken
    $null=Api POST '/cards' @{uid='04AABB';employee_id=$employee.id} $adminToken
    $scan=@{uid='04AABB';device_id=$device.id;client_scan_id=[Guid]::NewGuid().ToString();device_time=[DateTimeOffset]::UtcNow.ToString('o');is_replay=$false}
    $first=Api POST '/scans' $scan $kioskToken
    Check ($first.status -eq 'ok' -and $first.type -eq 'check_in') 'NFC records employee check-in'
    Check ((Api POST '/scans' $scan $kioskToken).status -eq 'duplicate') 'Offline retry is idempotent'
    $scan.client_scan_id=[Guid]::NewGuid().ToString()
    Check ((Api POST '/scans' $scan $kioskToken).status -eq 'ignored') 'Rapid repeat does not toggle checkout'
    $scan.device_id=[Guid]::NewGuid().ToString()
    Rejected { Api POST '/scans' $scan $kioskToken } 403
    Rejected { Api POST '/devices' @{name='bad'} $employeeToken } 403
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='check_in';device_id=$device.id} $kioskToken } 400
    Check ($script:lastError -match 'Nhân viên') 'Empty face database asks employees to enroll'
    $vector=@(1.0)+@(0.0)*127
    $different=@(0.0,1.0)+@(0.0)*126
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='enroll'} $employeeToken
    $enrolled=Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$vector;last=$vector} $employeeToken
    Check ($enrolled.status -eq 'enrolled') 'Self enrollment activates the face immediately'
    $faceStatus=Api GET '/faces' $null $employeeToken
    Check ($faceStatus.approved -eq $true) 'New face is active without admin approval'
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='enroll'} $employeeToken } 409
    Check ($null -eq $faceStatus.embedding) 'Face embeddings are never returned to employees'
    $originalFaceId=$faceStatus.id
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='reenroll'} $adminToken } 400
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='reenroll';device_id=$device.id} $kioskToken } 400
    $cancelledReplacement=Api POST '/business' @{action='begin_face_camera';purpose='reenroll'} $employeeToken
    $activeFaces=@(Api GET '/faces' $null $employeeToken | Where-Object { -not $_.revoked })
    Check ($activeFaces.Count -eq 1 -and $activeFaces[0].id -eq $originalFaceId) 'Starting or cancelling replacement keeps old face active'
    $replacement=Api POST '/business' @{action='begin_face_camera';purpose='reenroll'} $employeeToken
    Rejected { Api POST '/business' @{action='finish_face_camera';challenge_id=$replacement.id;model='sface-2021dec-v1';first=$vector;last=$different} $employeeToken } 400
    $activeFaces=@(Api GET '/faces' $null $employeeToken | Where-Object { -not $_.revoked })
    Check ($activeFaces.Count -eq 1 -and $activeFaces[0].id -eq $originalFaceId) 'Failed replacement keeps old face active'
    $replacement=Api POST '/business' @{action='begin_face_camera';purpose='reenroll'} $employeeToken
    $replaced=Api POST '/business' @{action='finish_face_camera';challenge_id=$replacement.id;model='sface-2021dec-v1';first=$vector;last=$vector} $employeeToken
    $allFaces=@(Api GET '/faces' $null $employeeToken)
    $activeFaces=@($allFaces | Where-Object { -not $_.revoked })
    Check ($replaced.status -eq 'enrolled' -and $activeFaces.Count -eq 1 -and $activeFaces[0].approved -and $activeFaces[0].id -ne $originalFaceId) 'Self replacement activates exactly one new face'
    Check (($allFaces | Where-Object id -eq $originalFaceId).revoked) 'Old face is revoked only after successful replacement'
    Rejected { Api POST '/business' @{action='finish_face_camera';challenge_id=$replacement.id;model='sface-2021dec-v1';first=$vector;last=$vector} $employeeToken } 400
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='check_in'} $employeeToken } 403
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='enroll';device_id=$device.id} $kioskToken } 400
    Rejected { Api POST '/business' @{action='begin_face_camera';purpose='check_in';device_id=[Guid]::NewGuid().ToString()} $kioskToken } 403
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='check_out';device_id=$device.id} $kioskToken
    $bad=@{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$different;last=$different}
    Rejected { Api POST '/business' $bad $kioskToken } 400
    $bad.first=$vector; $bad.last=$vector
    Rejected { Api POST '/business' $bad $kioskToken } 400
    # Test fixture only: make the successful NFC check-in old enough to check out.
    Check ([bool]$first.event_id) 'Scan returns persistent event identity'
    & $sqlcmd -S $SqlServer -E -C -d $database -Q "SET QUOTED_IDENTIFIER ON; SET NOCOUNT ON; UPDATE Events SET OccurredAt=DATEADD(minute,-2,OccurredAt) WHERE Id='$($first.event_id)';" -b | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fixture SQL update failed" }
    $eventRows=Api GET '/attendance/events' $null $adminToken
    $fixtureEvent=$eventRows | Where-Object { $_.id -eq $first.event_id }
    Check (([DateTimeOffset]::UtcNow-[DateTimeOffset]$fixtureEvent.occurred_at).TotalSeconds -ge 60) 'Fixture makes NFC scan older than cooldown'
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='check_out';device_id=$device.id} $kioskToken
    $completed=Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$vector;last=$vector} $kioskToken
    Check ($completed.status -eq 'ok' -and $completed.employee_code -eq 'E1') 'Shared kiosk identifies employee and records face checkout after NFC entry'
    $recorded=@(Api GET '/attendance/events' $null $adminToken) | Where-Object id -eq $completed.event_id
    Check ($recorded.source -eq 'face_camera' -and $recorded.device_id -eq $device.id) 'Face and NFC share attendance table with device and source'
    Rejected { Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$vector;last=$vector} $kioskToken } 400
    # Distinct employee template: identify by camera, not by kiosk account employee link.
    $null=Api POST '/business' @{action='save_account';email='e2@test.local';password='Integration!12345';role='employee';active=$true;employee_id=$other.id} $adminToken
    $otherToken=(Api POST '/auth/login' @{email='e2@test.local';password='Integration!12345'}).token
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='enroll'} $otherToken
    $otherFace=Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$different;last=$different} $otherToken
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='check_in';device_id=$device.id} $kioskToken
    $second=Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$different;last=$different} $kioskToken
    Check ($second.status -eq 'ok' -and $second.employee_code -eq 'E2') 'Same kiosk identifies a different employee'
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='check_in';device_id=$device.id} $kioskToken
    $ambiguous=@([Math]::Sqrt(.5),[Math]::Sqrt(.5))+@(0.0)*126
    Rejected { Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$ambiguous;last=$ambiguous} $kioskToken } 400
    $challenge=Api POST '/business' @{action='begin_face_camera';purpose='check_out';device_id=$device.id} $kioskToken
    & $sqlcmd -S $SqlServer -E -C -d $database -Q "SET QUOTED_IDENTIFIER ON; UPDATE Devices SET Active=0 WHERE Id='$($device.id)';" -b | Out-Null
    Rejected { Api POST '/business' @{action='finish_face_camera';challenge_id=$challenge.id;model='sface-2021dec-v1';first=$different;last=$different} $kioskToken } 403
    $null=Api POST '/business' @{action='revoke_face';id=$otherFace.credential_id} $adminToken
    $null=Api POST '/attendance/manual' @{employee_id=$other.id;type='check_in';occurred_at='2025-01-31T23:00:00+07:00';reason='Overnight test'} $adminToken
    $null=Api POST '/attendance/manual' @{employee_id=$other.id;type='check_out';occurred_at='2025-02-01T02:00:00+07:00';reason='Overnight test'} $adminToken
    $january=@(Api GET '/reports?start=2025-01-01&end=2025-02-01' $null $adminToken) | Where-Object employee_id -eq $other.id
    $february=@(Api GET '/reports?start=2025-02-01&end=2025-03-01' $null $adminToken) | Where-Object employee_id -eq $other.id
    Check ($january.worked_minutes -eq 60 -and $january.gross_pay -eq 30000) 'January includes only pre-midnight hour'
    Check ($february.worked_minutes -eq 120) 'February includes only post-midnight hours'
    foreach ($entry in @(
        @{type='check_in';at='09:30'}, @{type='check_out';at='11:00'},
        @{type='check_in';at='11:30'}, @{type='check_out';at='19:00'}
    )) {
        $null=Api POST '/attendance/manual' @{employee_id=$other.id;type=$entry.type;occurred_at="2025-04-02T$($entry.at):00+07:00";reason='Break and interruption test'} $adminToken
    }
    $dayRows=@(Api GET '/attendance/days?date=2025-04-02' $null $adminToken)
    $day=$dayRows | Where-Object employee_id -eq $other.id
    Check ($day.worked_minutes -eq 480 -and $day.remaining_minutes -eq 0 -and $day.required_minutes -eq 480) 'Dashboard subtracts lunch and interruption and credits makeup time'
    Check ($day.sessions.Count -eq 2 -and $day.late_minutes -eq 30 -and -not $day.needs_review) 'Dashboard exposes intervals and late minutes'
    Check ($day.last_event_source -eq 'manual' -and $day.last_event_type -eq 'check_out' -and $day.last_event_id) 'Dashboard exposes latest attendance notification'
    $april=@(Api GET '/reports?start=2025-04-01&end=2025-05-01' $null $adminToken) | Where-Object employee_id -eq $other.id
    Check ($april.worked_minutes -eq $day.completed_minutes -and $april.gross_pay -eq 240000) 'Dashboard and payroll report use the same completed work calculation'
    $ownDays=@(Api GET '/attendance/days?date=2025-04-02' $null $otherToken)
    Check ($ownDays.Count -eq 1 -and $ownDays[0].employee_id -eq $other.id) 'Employee summary is restricted to own attendance'
    Rejected { Api GET '/attendance/days?date=2025-04-02' $null $kioskToken } 403
    Check (@(Api GET "/attendance/events?employeeId=$($other.id)&date=2025-04-02" $null $adminToken).Count -eq 4) 'Calculation preserves all original attendance events'
    $null=Api POST '/payroll/close' @{start='2025-01-01';period='month'} $adminToken
    Rejected { Api POST '/attendance/manual' @{employee_id=$other.id;type='check_out';occurred_at='2025-01-31T23:30:00+07:00';reason='Closed payroll test'} $adminToken } 409
    Rejected { Api POST '/payroll/close' @{start='2025-01-27';period='week'} $adminToken } 409
    $importFixture = Join-Path $PSScriptRoot 'Attendance.Tests/Fixtures/employees-valid.xlsx'
    $importBytes = [IO.File]::ReadAllBytes($importFixture)
    $upload = @{file_name='employees.xlsx';content_base64=[Convert]::ToBase64String($importBytes);department='Sales';import_id=[Guid]::NewGuid().ToString()}
    Rejected { Api POST '/employees/import/preview' $upload $employeeToken } 403
    Rejected { Api POST '/employees/import/commit' $upload $kioskToken } 403
    $preview = Api POST '/employees/import/preview' $upload $adminToken
    Check ($preview.can_import -and $preview.create_count -eq 4 -and $preview.error_count -eq 0) 'Excel preview recognizes four new employees'
    Check (@(Api GET '/employees' $null $adminToken).Count -eq 2) 'Preview never inserts employees'
    $imported = Api POST '/employees/import/commit' $upload $adminToken
    Check ($imported.created_count -eq 4 -and $imported.credentials.Count -eq 4) 'Commit creates employee and account together'
    Check (@($imported.credentials | Where-Object password -ne '12345678').Count -eq 0) 'Imported accounts use requested initial password'
    $kd01 = @(Api GET '/employees?query=KD01' $null $adminToken)[0]
    Check ($kd01.phone -eq '0901234567' -and $kd01.hire_date -eq '2023-01-15' -and $kd01.job_title) 'Imported profile retains phone, hire date and position'
    $kd02 = @(Api GET '/employees?query=KD02' $null $adminToken)[0]
    Check ($kd02.department -eq 'Sales' -and $kd02.phone -eq '0902345678') 'Department fallback and phone zero format are preserved'
    $newLogin = Api POST '/auth/login' @{email=$imported.credentials[0].email;password=$imported.credentials[0].password}
    Check ($newLogin.user.role -eq 'employee' -and $newLogin.user.employee_id -eq $kd01.id) 'Imported account logs in with employee role regardless of job title'
    Check $newLogin.user.must_change_password 'Imported account carries first-login password reminder'
    Check (@(Api GET '/faces' $null $newLogin.token).Count -eq 0) 'Import does not fabricate a face enrollment'
    $retried = Api POST '/employees/import/commit' $upload $adminToken
    Check ($retried.created_count -eq 4 -and $retried.credentials[0].password -eq $imported.credentials[0].password) 'Retry returns original receipt without changing passwords'
    Check (@(Api GET '/employees' $null $adminToken).Count -eq 6) 'Retry does not duplicate profiles'
    $emails = Api GET "/employees/import/$($imported.import_id)/emails" $null $adminToken
    Check ($emails.rows.Count -eq 4) 'Import retry does not duplicate queued welcome emails'
    if ($WithEmail) {
        Check $emails.configured 'Email test sender settings reach the running API'
        if ($WithSmtp) {
            Check ((Api POST '/employees/import/email-test' @{} $adminToken).status -eq 'connected') 'Admin can verify SMTP authentication without sending a message'
        }
        for ($attempt=0; $attempt -lt 40; $attempt++) {
            $emails = Api GET "/employees/import/$($imported.import_id)/emails" $null $adminToken
            $processedCount = @($emails.rows | Where-Object { $_.status -eq 'sent' -or $_.status -eq 'needs_review' }).Count
            if (@($emails.rows | Where-Object status -eq 'failed').Count -gt 0 -and $processedCount -ge 3) { break }
            Start-Sleep -Milliseconds 300
        }
        Check (@($emails.rows | Where-Object status -eq 'failed').Count -eq 1) ('Provider rejection is shown as a failed email rather than success: ' + (($emails.rows | Select-Object status,attempts,last_error) | ConvertTo-Json -Compress))
        $null = Api POST "/employees/import/$($imported.import_id)/emails/retry" @{} $adminToken
        for ($attempt=0; $attempt -lt 40; $attempt++) {
            $emails = Api GET "/employees/import/$($imported.import_id)/emails" $null $adminToken
            $targetSent = if ($WithSmtp) { 3 } else { 4 }
            if (@($emails.rows | Where-Object status -eq 'sent').Count -eq $targetSent) { break }
            Start-Sleep -Milliseconds 300
        }
        Check (@($emails.rows | Where-Object status -eq 'sent').Count -eq $targetSent) 'Background worker automatically sends welcome emails and supports retry'
        $emailStats = Invoke-RestMethod "$fakeEmailRoot/stats"
        Check ($emailStats.accepted -eq 4 -and $emailStats.valid_messages) 'Welcome emails contain individual username, default password and password and face instructions'
        if ($WithSmtp) {
            Check (@($emails.rows | Where-Object status -eq 'needs_review').Count -eq 1 -and $emailStats.uncertain_attempts -eq 1) 'Ambiguous SMTP acceptance is flagged for review and is not automatically retried'
            $reportBody = @{action='email_report';employee_id=$kd01.id;start='2025-04-01';end='2025-05-01'}
            Check ((Api POST '/business' $reportBody $adminToken).status -eq 'sent') 'Attendance reports use the same SMTP sender'
            Check ((Api POST '/business' $reportBody $adminToken).status -eq 'already_sent') 'A completed SMTP report is not sent again'
            $kd03 = @(Api GET '/employees?query=KD03' $null $adminToken)[0]
            $uncertainReport = @{action='email_report';employee_id=$kd03.id;start='2025-04-01';end='2025-05-01'}
            Rejected { Api POST '/business' $uncertainReport $adminToken } 400
            Rejected { Api POST '/business' $uncertainReport $adminToken } 409
        }
    } else {
        Check (-not $emails.configured -and @($emails.rows | Where-Object status -eq 'sent').Count -eq 0) 'Missing sender configuration keeps mail pending and never reports sent'
        Rejected { Api POST "/employees/import/$($imported.import_id)/emails/retry" @{} $adminToken } 400
    }
    $duplicatePreview = Api POST '/employees/import/preview' $upload $adminToken
    Check (-not $duplicatePreview.can_import -and $duplicatePreview.skip_count -eq 4 -and $duplicatePreview.error_count -eq 0) 'Reupload identifies existing code and email and skips unchanged accounts'
    $conflictBytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Attendance.Tests/Fixtures/employees-conflict.xlsx'))
    $conflictUpload = @{file_name='conflict.xlsx';content_base64=[Convert]::ToBase64String($conflictBytes);department='Sales';import_id=[Guid]::NewGuid().ToString()}
    $conflictPreview = Api POST '/employees/import/preview' $conflictUpload $adminToken
    Check (-not $conflictPreview.can_import -and $conflictPreview.error_count -eq 1 -and $conflictPreview.create_count -eq 1) 'Preview distinguishes a new employee from an existing code conflict'
    Rejected { Api POST '/employees/import/commit' $conflictUpload $adminToken } 409
    Check (@(Api GET '/employees?query=KD05' $null $adminToken).Count -eq 0) 'One invalid row blocks all rows, including earlier valid employees'
    $credentialFile = Api GET "/employees/import/$($imported.import_id)/credentials" $null $adminToken
    Check ($credentialFile.file_name.EndsWith('.xlsx') -and $credentialFile.content_base64.Length -gt 100) 'Admin can download initial credentials as an Excel workbook'
    Rejected { Api GET "/employees/import/$($imported.import_id)/credentials" $null $newLogin.token } 403
    $recent = @(Api GET '/employees/import/recent' $null $adminToken)
    Check ($recent.Count -eq 1 -and $recent[0].created_count -eq 4) 'Recent imports recover credential download after leaving the page'
    $template = Api GET '/employees/import/template' $null $adminToken
    Check ($template.file_name.EndsWith('.xlsx') -and $template.content_base64.Length -gt 100) 'Admin can download XLSX import template'
    $conflictingAccount = Api POST '/business' @{action='save_account';email='another-admin@test.local';role='admin';active=$true;password='AnotherAdminPassword!'} $adminToken
    $anotherAdmin = Api POST '/auth/login' @{email='another-admin@test.local';password='AnotherAdminPassword!'}
    Rejected { Api GET "/employees/import/$($imported.import_id)/credentials" $null $anotherAdmin.token } 404
    Rejected { Api POST '/employees/import/commit' $upload $anotherAdmin.token } 403
    $differentFile = $upload.Clone(); $differentFile.department='Different';
    Rejected { Api POST '/employees/import/commit' $differentFile $adminToken } 409
    Rejected { Api GET "/employees/import/$($imported.import_id)/emails" $null $employeeToken } 403
    $secondLogin = Api POST '/auth/login' @{email=$imported.credentials[0].email;password='12345678'}
    Rejected { Api POST '/auth/change-password' @{current_password='wrong-password';new_password='NewEmployeePassword!'} $newLogin.token } 400
    Rejected { Api POST '/auth/change-password' @{current_password='12345678';new_password='12345678'} $newLogin.token } 400
    $null = Api POST '/auth/change-password' @{current_password='12345678';new_password='NewEmployeePassword!'} $newLogin.token
    Check (-not (Api GET '/auth/me' $null $newLogin.token).must_change_password) 'Password change clears initial password reminder and keeps current session'
    Rejected { Api GET '/auth/me' $null $secondLogin.token } 401
    Rejected { Api POST '/auth/login' @{email=$imported.credentials[0].email;password='12345678'} } 401
    Check ((Api POST '/auth/login' @{email=$imported.credentials[0].email;password='NewEmployeePassword!'}).user.role -eq 'employee') 'New password authenticates successfully'
    if (-not $WithEmail) {
        $emails = Api GET "/employees/import/$($imported.import_id)/emails" $null $adminToken
        Check (@($emails.rows | Where-Object status -eq 'cancelled').Count -eq 1) 'Do not send stale initial password after employee has changed it'
    }
    $null=Api POST '/business' @{action='save_account';id=$employeeAccount.id;email='e1@test.local';role='employee';active=$false;employee_id=$employee.id} $adminToken
    Rejected { Api GET '/auth/me' $null $employeeToken } 401
    Check (@(Api GET '/faces' $null $adminToken | Where-Object { -not $_.revoked }).Count -eq 0) 'Disabling account revokes its face template'
    # Reimport the supplied layout to repair a profile and bind its UID together.
    $profileBytes=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Attendance.Tests/Fixtures/employees-profile-update.xlsx'))
    $profileUpload=@{file_name='nhanvien.xlsx';content_base64=[Convert]::ToBase64String($profileBytes);department='Must not override IT';import_id=[Guid]::NewGuid().ToString()}
    $profilePreview=Api POST '/employees/import/preview' $profileUpload $adminToken
    Check ($profilePreview.can_import -and $profilePreview.update_count -eq 1 -and $profilePreview.create_count -eq 0 -and $profilePreview.card_count -eq 1) 'Reimport previews profile correction and UID binding without another account'
    Check ($profilePreview.rows[0].department -eq 'IT' -and $profilePreview.rows[0].updated_fields.Count -gt 0) 'Department comes from employee cell and changed fields are explicit'
    $eventsBefore=@(Api GET '/attendance/events' $null $adminToken).Count
    $profileResult=Api POST '/employees/import/commit' $profileUpload $adminToken
    Check ($profileResult.updated_count -eq 1 -and $profileResult.cards_assigned_count -eq 1 -and $profileResult.credentials.Count -eq 0) 'Profile repair and card link commit together without resetting credentials'
    $ownProfile=@(Api GET '/employees' $null $newLogin.token)[0]
    Check ($ownProfile.department -eq 'IT' -and $ownProfile.full_name -eq 'Ten da cap nhat' -and $ownProfile.job_title -eq 'Lap trinh vien' -and $ownProfile.phone -eq '0909999888' -and $ownProfile.hire_date -eq '2024-02-20' -and $ownProfile.hourly_rate -eq 70000) 'Employee reads corrected profile fields from the same database'
    Check (@(Api GET '/cards' $null $newLogin.token | Where-Object uid -eq '0004BB01').Count -eq 1) 'Employee account sees its imported UID'
    Check (@((Api GET "/employees/import/$($profileResult.import_id)/emails" $null $adminToken).rows).Count -eq 0) 'Correcting a profile does not send another default password'
    Check (@(Api GET '/attendance/events' $null $adminToken).Count -eq $eventsBefore) 'Profile correction creates no attendance events'
    $profileUpload.import_id=[Guid]::NewGuid().ToString()
    Check (-not (Api POST '/employees/import/preview' $profileUpload $adminToken).can_import) 'Reimporting the corrected profile is a no-op'
    # Excel NFC binding is atomic with account creation and idempotent on retry.
    function NfcUpload($name) {
        return @{file_name=$name;content_base64=[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot "Attendance.Tests/Fixtures/$name")));import_id=[Guid]::NewGuid().ToString()}
    }
    $nfcUpload=NfcUpload 'employees-nfc.xlsx'
    $nfcPreview=Api POST '/employees/import/preview' $nfcUpload $adminToken
    Check ($nfcPreview.can_import -and $nfcPreview.create_count -eq 3 -and $nfcPreview.card_count -eq 2) 'Preview counts optional NFC bindings'
    $nfcResult=Api POST '/employees/import/commit' $nfcUpload $adminToken
    Check ($nfcResult.created_count -eq 3 -and $nfcResult.cards_assigned_count -eq 2) 'Excel creates employees accounts and cards together'
    $nfcEmployees=@(Api GET '/employees' $null $adminToken)
    $nfcOne=$nfcEmployees | Where-Object code -eq 'NFC01'
    $nfcCards=@(Api GET "/cards?employeeId=$($nfcOne.id)" $null $adminToken)
    Check ($nfcCards.Count -eq 1 -and $nfcCards[0].uid -eq '0400AA01' -and $nfcCards[0].active) 'Card is bound to the correct employee with canonical UID'
    Check ((Api POST '/employees/import/commit' $nfcUpload $adminToken).cards_assigned_count -eq 2) 'Retry returns original card result without rebinding'
    Check (-not (Api POST '/employees/import/preview' $nfcUpload $adminToken).can_import) 'Reimport of identical accounts and cards is a no-op'
    $linkUpload=NfcUpload 'employees-nfc-link.xlsx'
    $linkPreview=Api POST '/employees/import/preview' $linkUpload $adminToken
    Check ($linkPreview.can_import -and $linkPreview.create_count -eq 0 -and $linkPreview.card_count -eq 1 -and $linkPreview.rows[0].status -eq 'link_card') 'Existing employee without card can receive one via Excel'
    $linkResult=Api POST '/employees/import/commit' $linkUpload $adminToken
    Check ($linkResult.created_count -eq 0 -and $linkResult.cards_assigned_count -eq 1 -and $linkResult.credentials.Count -eq 0) 'Card-only import creates no new credentials'
    Check (@((Api GET "/employees/import/$($linkResult.import_id)/emails" $null $adminToken).rows).Count -eq 0) 'Card-only import does not resend onboarding email'
    foreach ($fixture in @('employees-nfc-conflict.xlsx','employees-nfc-replace.xlsx','employees-nfc-duplicate.xlsx')) {
        $badUpload=NfcUpload $fixture
        Check (-not (Api POST '/employees/import/preview' $badUpload $adminToken).can_import) "Reject conflicting NFC file $fixture"
        Rejected { Api POST '/employees/import/commit' $badUpload $adminToken } 409
    }
    Check (@(Api GET '/employees' $null $adminToken | Where-Object code -eq 'NFC04').Count -eq 0) 'UID conflict rolls back the entire employee batch'
    $null=Api PUT '/cards/0400AA01' @{active=$false} $adminToken
    Check (-not (Api POST '/employees/import/preview' $nfcUpload $adminToken).can_import) 'Excel cannot reactivate a revoked card'
    Write-Output "$script:checks API checks passed against isolated SQL Server database."
} catch {
    Write-Output "Test stopped after $script:checks checks at $script:lastRequest"
    Write-Output $script:lastError
    Write-Output $_.ErrorDetails.Message
    Write-Output $_.ScriptStackTrace
    throw
} finally {
    if ($fakeEmailProcess -and -not $fakeEmailProcess.HasExited) { $fakeEmailProcess.Kill(); $fakeEmailProcess.WaitForExit() }
    if ($process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    if ($output) { [IO.File]::WriteAllText((Join-Path $localRoot 'api-test.log'), $output.Result + $errors.Result) }
    if ($database -notmatch '^NfcAttendance_Integration_[a-f0-9]{32}$') { throw 'Unsafe test database cleanup target' }
    & $sqlcmd -S $SqlServer -E -C -d master -Q "IF DB_ID('$database') IS NOT NULL BEGIN ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$database]; END" -b | Out-Null
    if (Test-Path -LiteralPath $credentialsFile) { Remove-Item -LiteralPath $credentialsFile }
}
