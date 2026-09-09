<#
  duplicati/duplicati#7804 の続き: MSI で修復したあと、サービスが Running のまま 8200 番に答えず、
  アンインストールがサービスの停止で 4 分待って 1921 で失敗した件（11-13 の run3）の原因を調べる。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\run7-repair-hang-7804.ps1

  全自動（画面も質問も出ない）。公式の 2.4.1.0 の MSI を使い、次の 2 通りを順に試す:
    A. サービス付きで入れる → 修復（REINSTALL=ALL）
    B. サービス付きで入れる → REMOVE-CERTS → 修復
  それぞれ、サーバーの詳しいログをファイルに出す（サービスのレジストリの Environment に DUPLICATI__LOG_FILE を足す）。
  修復のあとは、8200 番が 60 秒以内に答えるか、サービスが 60 秒以内に止まるかを記録し、止まらなければプロセスを終わらせる。
  C:\ProgramData\Duplicati は最初に名前を変えて退避し、最後に必ず元に戻す。Duplicati も最後に必ずアンインストールする。
  結果は .\run7\result.txt、サーバーのログと msiexec のログも .\run7 に出る。
#>
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$msi    = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$work   = Join-Path $here 'run7'
$out    = Join-Path $work 'result.txt'
$pd     = 'C:\ProgramData\Duplicati'
$pdBak  = 'C:\ProgramData\Duplicati.before-run7'
$inst   = 'C:\Program Files\Duplicati 2'
$svcKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\Duplicati'

function W([string]$t) { "$(Get-Date -Format 'HH:mm:ss') $t" | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Get-Installed {
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'Duplicati' }
}
function Test-Http {
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8200/' -Method Head -TimeoutSec 5 -SkipHttpErrorCheck -MaximumRedirection 0 -ErrorAction Stop
        return "answers ($([int]$r.StatusCode))"
    } catch { return "no answer ($($_.Exception.GetType().Name))" }
}
# Waits up to $seconds for the server to answer on 8200; returns the seconds it took, or -1
function Wait-Http([int]$seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $seconds) {
        if ((Test-Http) -like 'answers*') { return [int]$sw.Elapsed.TotalSeconds }
        Start-Sleep 2
    }
    return -1
}
function Get-ServicePid { (Get-CimInstance Win32_Service -Filter "Name='Duplicati'" -ErrorAction SilentlyContinue).ProcessId }
function Snapshot([string]$label) {
    $s = Get-CimInstance Win32_Service -Filter "Name='Duplicati'" -ErrorAction SilentlyContinue
    W "[$label] service: $(if ($s) { "$($s.State), pid=$($s.ProcessId), path=$($s.PathName)" } else { 'none' })"
    if ($s -and $s.ProcessId) {
        $p = Get-Process -Id $s.ProcessId -ErrorAction SilentlyContinue
        if ($p) { W "[$label] process: threads=$($p.Threads.Count) cpu=$([math]::Round($p.CPU,1))s ws=$([int]($p.WorkingSet64/1MB))MB started=$($p.StartTime.ToString('HH:mm:ss'))" }
        $ports = (Get-NetTCPConnection -OwningProcess $s.ProcessId -State Listen -ErrorAction SilentlyContinue).LocalPort -join ','
        W "[$label] listening ports: $(if ($ports) { $ports } else { 'none' })"
    }
    W "[$label] http 8200: $(Test-Http)"
    W "[$label] Service registry key exists: $(Test-Path 'HKLM:\SOFTWARE\DuplicatiTeam\Duplicati\Service')"
}
function Run-Msi([string]$label, [string]$arguments) {
    W "msiexec $arguments"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    W "$label -> exit code $($p.ExitCode) after $([int]$sw.Elapsed.TotalSeconds)s"
    return $p.ExitCode
}
# Makes the service write a verbose server log, and restarts it so the setting is used
function Enable-ServerLog([string]$case) {
    $logFile = Join-Path $work "server-$case.log"
    New-ItemProperty -Path $svcKey -Name Environment -PropertyType MultiString -Force -Value @("DUPLICATI__LOG_FILE=$logFile", 'DUPLICATI__LOG_LEVEL=Verbose') | Out-Null
    Restart-Service Duplicati -Force
    W "server log: $logFile; environment set, service restarted"
}
function Stop-ServiceWithTimeout([string]$label, [int]$seconds) {
    $svcPid = Get-ServicePid
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & sc.exe stop Duplicati | Out-Null
    while ($sw.Elapsed.TotalSeconds -lt $seconds) {
        if ((Get-Service Duplicati -ErrorAction SilentlyContinue).Status -eq 'Stopped') { W "[$label] service stopped after $([int]$sw.Elapsed.TotalSeconds)s"; return $true }
        Start-Sleep 1
    }
    W "[$label] service did NOT stop within ${seconds}s (status $((Get-Service Duplicati).Status)); ending pid $svcPid"
    if ($svcPid) { Stop-Process -Id $svcPid -Force -ErrorAction SilentlyContinue; Start-Sleep 3 }
    return $false
}
function Write-Events([string]$label, [datetime]$since) {
    W "[$label] events since $($since.ToString('HH:mm:ss')):"
    foreach ($log in 'Duplicati 2', 'Application', 'System') {
        Get-WinEvent -FilterHashtable @{ LogName = $log; StartTime = $since } -ErrorAction SilentlyContinue |
            Where-Object { ($log -eq 'Duplicati 2') -or (($_.ProviderName -match 'Duplicati|MsiInstaller|Service Control Manager') -and ($_.Message -match 'Duplicati')) } |
            Sort-Object TimeCreated | ForEach-Object { W "    $log | $($_.TimeCreated.ToString('HH:mm:ss')) $($_.LevelDisplayName) $($_.ProviderName) $($_.Id): $(($_.Message -replace '\s+', ' ').Substring(0, [Math]::Min(300, ($_.Message -replace '\s+', ' ').Length)))" }
    }
}
function Write-LogTail([string]$case, [int]$lines) {
    $f = Join-Path $work "server-$case.log"
    if (Test-Path $f) { W "[$case] last $lines lines of the server log:"; Get-Content $f -Tail $lines | ForEach-Object { W "    | $_" } }
    else { W "[$case] no server log was written" }
}
function Uninstall-All([string]$label) {
    if (Get-Service Duplicati -ErrorAction SilentlyContinue) {
        if ((Get-Service Duplicati).Status -ne 'Stopped') { Stop-ServiceWithTimeout "$label/pre-uninstall" 60 | Out-Null }
    }
    if (Get-Installed) { Run-Msi "$label uninstall" "/x `"$msi`" /qn /l*v `"$work\$label-uninstall.log`"" | Out-Null }
    if (Test-Path $inst) { W "install folder still present after uninstall: $inst" }
}

function Run-Case([string]$case, [bool]$removeCerts) {
    Say "== ケース $case を始めます（$(if ($removeCerts) { 'REMOVE-CERTS あり' } else { 'REMOVE-CERTS なし' })）"
    W ''; W "========== case $case (REMOVE-CERTS: $removeCerts)"
    Run-Msi "$case install" "/i `"$msi`" /qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature /l*v `"$work\$case-install.log`"" | Out-Null
    Enable-ServerLog $case
    W "[$case] after install: server answered after $(Wait-Http 60)s (-1 = not within 60s)"
    Snapshot "$case after install"
    if ($removeCerts) {
        $o = & "$inst\Duplicati.WindowsService.exe" REMOVE-CERTS 2>&1 | Out-String
        W "[$case] REMOVE-CERTS -> exit ${LASTEXITCODE}: $($o.Trim() -replace '\s+', ' ')"
        W "[$case] after REMOVE-CERTS: server answered after $(Wait-Http 30)s"
        Snapshot "$case after REMOVE-CERTS"
    }
    Say "   修復します..."
    $t = Get-Date
    Run-Msi "$case repair" "/i `"$msi`" REINSTALL=ALL REINSTALLMODE=omus /qn /l*v `"$work\$case-repair.log`"" | Out-Null
    W "[$case] environment value after repair: $((Get-ItemProperty $svcKey -Name Environment -ErrorAction SilentlyContinue).Environment -join ' ; ')"
    $answered = Wait-Http 60
    W "[$case] after repair: server answered after ${answered}s (-1 = not within 60s)"
    Snapshot "$case after repair"
    Write-Events $case $t
    Write-LogTail $case 60
    Stop-ServiceWithTimeout "$case after repair" 60 | Out-Null
    Write-LogTail "$case" 15
    Uninstall-All $case
}

# ---------------------------------------------------------------- checks
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (-not (Test-Path $msi)) { throw "何も変えずに止めました: MSI がありません: $msi" }
if (Get-Installed) { throw '何も変えずに止めました: Duplicati がインストールされています。' }
if (Get-Service Duplicati -ErrorAction SilentlyContinue) { throw '何も変えずに止めました: Duplicati のサービスがあります。' }
if (Test-Path $pdBak) { throw "何も変えずに止めました: $pdBak がすでにあります（前回の残り）。" }
if (Test-Path $work) { throw "何も変えずに止めました: $work がすでにあります（前回の残り）。" }

New-Item -ItemType Directory $work | Out-Null
W "run7 started; msi $msi"
$moved = $false
try {
    if (Test-Path $pd) { Rename-Item $pd $pdBak; $moved = $true; W "moved $pd aside to $pdBak" }
    Run-Case 'A' $false
    if (Test-Path $pd) { Remove-Item $pd -Recurse -Force }   # the data folder case A made
    Run-Case 'B' $true
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '後片付け: Duplicati をアンインストールして、ProgramData を元に戻します...'
    try { Uninstall-All 'final' } catch { W "final uninstall failed: $($_.Exception.Message)" }
    if ($moved) {
        if (Test-Path $pd) { Remove-Item $pd -Recurse -Force }
        Rename-Item $pdBak $pd
        W "restored $pd"
    }
    W "cleanup: installed=$([bool](Get-Installed)); service=$([bool](Get-Service Duplicati -ErrorAction SilentlyContinue)); install folder=$(Test-Path $inst); ProgramData restored=$((Test-Path $pd) -and -not (Test-Path $pdBak))"
    W 'done'
    Say '全部終わりました。結果は run7\result.txt です。'
}
