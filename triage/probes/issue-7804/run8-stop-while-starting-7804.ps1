<#
  duplicati/duplicati#7804 の続き（run7 の次）: アンインストールがサービスの停止で 4 分待って 1921 で失敗した件。
  run3 では、アンインストールの REMOVE-CERTS（サービスを止めて起動し直す）の直後に MSI がサービスを止めようとして止まらなかった。
  起動した直後のサービスが停止を受け付けるかを、時間をずらして調べる。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\run8-stop-while-starting-7804.ps1

  全自動（画面も質問も出ない）。公式の 2.4.1.0 の MSI をサービス付きで入れて:
    1. 起動して 0・1・3・10 秒後、サーバーが答えてからに停止を送り、止まるまでの秒数と AcceptStop を記録（各 3 回）
    2. REMOVE-CERTS を実行してすぐ停止を送る（アンインストールと同じ順番、3 回）
    3. サービスを動かしたままアンインストールする（run3 と同じ）
  止まらないときは 90 秒でプロセスを終わらせる。C:\ProgramData\Duplicati は退避して最後に必ず戻し、Duplicati も必ず消す。
  結果は .\run8\result.txt
#>
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$msi   = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$work  = Join-Path $here 'run8'
$out   = Join-Path $work 'result.txt'
$pd    = 'C:\ProgramData\Duplicati'
$pdBak = 'C:\ProgramData\Duplicati.before-run8'
$inst  = 'C:\Program Files\Duplicati 2'

function W([string]$t) { "$(Get-Date -Format 'HH:mm:ss.fff') $t" | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Get-Installed {
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'Duplicati' }
}
function Get-Svc { Get-CimInstance Win32_Service -Filter "Name='Duplicati'" -ErrorAction SilentlyContinue }
function Svc-Text { $s = Get-Svc; if ($s) { "$($s.State) AcceptStop=$($s.AcceptStop) pid=$($s.ProcessId)" } else { 'no service' } }
function Test-Http {
    try { Invoke-WebRequest -Uri 'http://127.0.0.1:8200/' -Method Head -TimeoutSec 2 -SkipHttpErrorCheck -MaximumRedirection 0 -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}
function Wait-Stopped([int]$seconds) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $seconds) {
        if ((Get-Svc).State -eq 'Stopped') { return [math]::Round($sw.Elapsed.TotalSeconds, 1) }
        Start-Sleep -Milliseconds 250
    }
    return -1
}
function Force-Stop([string]$label) {
    $s = Get-Svc
    if ($s -and $s.State -ne 'Stopped') {
        W "  [$label] still $(Svc-Text) - ending pid $($s.ProcessId)"
        if ($s.ProcessId) { Stop-Process -Id $s.ProcessId -Force -ErrorAction SilentlyContinue }
        Wait-Stopped 30 | Out-Null
    }
}
# Sends a stop and reports how sc answered and how long the service took to stop
function Send-Stop([string]$label) {
    $before = Svc-Text
    $sc = (& sc.exe stop Duplicati 2>&1 | Out-String) -replace '\s+', ' '
    $code = $LASTEXITCODE
    $took = Wait-Stopped 90
    W "  [$label] before stop: $before; sc stop exit $code; stopped after $(if ($took -ge 0) { "${took}s" } else { 'NO (90s)' })$(if ($code -ne 0) { "; sc said: $($sc.Trim())" })"
    if ($took -lt 0) { Force-Stop $label }
}
function Start-AndStopAfter([double]$delay, [int]$round) {
    & sc.exe start Duplicati | Out-Null
    $label = "start, stop after $(if ($delay -lt 0) { 'server answers' } else { "${delay}s" }) #$round"
    if ($delay -lt 0) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Http) -and $sw.Elapsed.TotalSeconds -lt 120) { Start-Sleep -Milliseconds 500 }
        W "  [$label] server answered after $([int]$sw.Elapsed.TotalSeconds)s"
    } else { Start-Sleep -Milliseconds ([int]($delay * 1000)) }
    Send-Stop $label
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
W "run8 started"
$moved = $false
try {
    if (Test-Path $pd) { Rename-Item $pd $pdBak; $moved = $true; W "moved $pd aside to $pdBak" }

    Say '1/4: サービス付きで入れます...'
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn ADDLOCAL=DuplicatiCore,DuplicatiServiceFeature /l*v `"$work\install.log`"" -Wait -PassThru
    W "install -> exit $($p.ExitCode); $(Svc-Text)"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Http) -and $sw.Elapsed.TotalSeconds -lt 120) { Start-Sleep 1 }
    W "first start: server answered after $([int]$sw.Elapsed.TotalSeconds)s; $(Svc-Text)"
    Send-Stop 'first start, server answering'

    Say '2/4: 起動の直後に停止を送ります（数分かかります）...'
    W ''; W '----- 1. stop at different times after a start'
    foreach ($round in 1..3) { foreach ($d in 0, 1, 3, 10, -1) { Start-AndStopAfter $d $round } }

    Say '3/4: REMOVE-CERTS のあとすぐ停止を送ります...'
    W ''; W '----- 2. REMOVE-CERTS, then stop at once (as the uninstall does)'
    foreach ($round in 1..3) {
        & sc.exe start Duplicati | Out-Null
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Http) -and $sw.Elapsed.TotalSeconds -lt 120) { Start-Sleep -Milliseconds 500 }
        $sw.Restart()
        $o = & "$inst\Duplicati.WindowsService.exe" REMOVE-CERTS 2>&1 | Out-String
        W "  [REMOVE-CERTS #$round] exit $LASTEXITCODE after $([math]::Round($sw.Elapsed.TotalSeconds,1))s: $($o.Trim() -replace '\s+', ' '); now $(Svc-Text)"
        Send-Stop "after REMOVE-CERTS #$round"
    }

    Say '4/4: サービスを動かしたままアンインストールします（最大 5 分ほど）...'
    W ''; W '----- 3. uninstall with the service running (as in run3)'
    & sc.exe start Duplicati | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Http) -and $sw.Elapsed.TotalSeconds -lt 120) { Start-Sleep -Milliseconds 500 }
    W "  service started, server answered after $([int]$sw.Elapsed.TotalSeconds)s; $(Svc-Text)"
    $sw.Restart()
    $p = Start-Process msiexec.exe -ArgumentList "/x `"$msi`" /qn /l*v `"$work\uninstall.log`"" -Wait -PassThru
    W "  uninstall -> exit $($p.ExitCode) after $([int]$sw.Elapsed.TotalSeconds)s; $(Svc-Text)"
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '後片付け: Duplicati を消して、ProgramData を元に戻します...'
    Force-Stop 'cleanup'
    if (Get-Installed) {
        $p = Start-Process msiexec.exe -ArgumentList "/x `"$msi`" /qn /l*v `"$work\uninstall-cleanup.log`"" -Wait -PassThru
        W "cleanup uninstall -> exit $($p.ExitCode)"
    }
    if ($moved) {
        if (Test-Path $pd) { Remove-Item $pd -Recurse -Force }
        Rename-Item $pdBak $pd
        W "restored $pd"
    }
    W "cleanup: installed=$([bool](Get-Installed)); service=$([bool](Get-Service Duplicati -ErrorAction SilentlyContinue)); install folder=$(Test-Path $inst); ProgramData restored=$((Test-Path $pd) -and -not (Test-Path $pdBak))"
    W 'done'
    Say '全部終わりました。結果は run8\result.txt です。'
}
