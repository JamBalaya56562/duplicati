<#
  duplicati/duplicati#2630 の確認（Windows 側）。PowerShell 7 用、画面なし・質問なしで全部自動。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\test-smb-2630.ps1

  一時的に、ローカルのアカウント dup2630test（パスワードはスクリプトの中で作り、表示も保存もしない）と、
  共有 DupTest2630（C:\dup2630\share、そのアカウントだけ読み書きできる）を作り、最後に必ず消す。
    A. 組み込みの SMB クライアント（smb://127.0.0.1/DupTest2630/...）でバックアップ・一覧・復元
    B. 比べるため、フォルダーの宛先に \\127.0.0.1\DupTest2630\... と資格情報を渡してバックアップ（従来の方法）
  それぞれの後で、Windows の接続（net use・Get-SmbConnection・Get-SmbMapping）と資格情報の名前（cmdkey）を記録し、
  このセッションが資格情報なしで共有を開けるか（報告の「ほかのアプリも見られる」）を試す。
  バックアップ中は、共有の側のセッション（Get-SmbSession）を記録する。
  利用者の %LOCALAPPDATA%\Duplicati と、もとからある接続・資格情報には触れない。結果は .\smb-2630-result.txt
#>
$ErrorActionPreference = 'Stop'
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$out    = Join-Path $here 'smb-2630-result.txt'
$cli    = 'C:\Users\Jam\Documents\dup-buildws\Executables\Duplicati.CommandLine\bin\Debug\net10.0\Duplicati.CommandLine.dll'
$dotnet = 'C:\Users\Jam\AppData\Local\mise\dotnet-root\dotnet.exe'
$user   = 'dup2630test'
$share  = 'DupTest2630'
$root   = 'C:\dup2630'
$unc    = "\\127.0.0.1\$share"

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }
function Snapshot([string]$label) {
    W "  --- $label"
    $nu = net use 2>&1 | Where-Object { $_ -match '\\\\' } | ForEach-Object { ($_ -replace '\s+', ' ').Trim() }
    W ("  net use: " + $(if ($nu) { $nu -join ' | ' } else { 'none' }))
    $sc = Get-SmbConnection -ErrorAction SilentlyContinue | ForEach-Object { "$($_.ServerName)\$($_.ShareName) as $($_.UserName)" }
    W ("  Get-SmbConnection: " + $(if ($sc) { $sc -join ' | ' } else { 'none' }))
    $sm = Get-SmbMapping -ErrorAction SilentlyContinue | ForEach-Object { "$($_.LocalPath) -> $($_.RemotePath)" }
    W ("  Get-SmbMapping: " + $(if ($sm) { $sm -join ' | ' } else { 'none' }))
    $ck = cmdkey /list | Select-String -Pattern '127\.0\.0\.1|dup2630' | ForEach-Object { ($_.Line -replace '^\s*\S+:\s*', '').Trim() }
    W ("  cmdkey (names only): " + $(if ($ck) { $ck -join ' | ' } else { 'none' }))
    $browse = try { $n = (Get-ChildItem $unc -ErrorAction Stop | Measure-Object).Count; "OPENS without credentials ($n entries)" } catch { "refused ($($_.Exception.GetType().Name): $(($_.Exception.Message -split "`n")[0]))" }
    W "  this session browsing $unc : $browse"
}
# Runs the CLI and records the server-side SMB sessions of the test account while it runs
function RunCli([string]$label, [string[]]$arguments, [string]$secret) {
    $log = Join-Path $root "$label.log"
    # An empty input makes a prompt fail at once instead of waiting in the hidden window
    $empty = Join-Path $root 'empty-input.txt'
    if (-not (Test-Path $empty)) { New-Item -ItemType File $empty | Out-Null }
    $p = Start-Process $dotnet -ArgumentList (@("`"$cli`"") + $arguments) -RedirectStandardInput $empty -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
    $seen = @{}
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while (-not $p.HasExited) {
        Get-SmbSession -ErrorAction SilentlyContinue | Where-Object { $_.ClientUserName -match $user } | ForEach-Object { $seen["$($_.ClientComputerName) $($_.ClientUserName) dialect=$($_.Dialect)"] = 1 }
        if ($watch.Elapsed.TotalMinutes -gt 3) { Stop-Process -Id $p.Id -Force; W "  $label did not finish in 3 minutes, stopped it"; break }
        Start-Sleep -Milliseconds 300
    }
    $p.WaitForExit()
    $tail = (Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Where-Object { $_ -match 'completed|Restored|error|Error|failed|Failed' } | Select-Object -Last 2) -join ' | '
    W "  $label exit $($p.ExitCode): $($tail.Replace($secret, '***'))"
    W ("  server-side sessions of $user during $label : " + $(if ($seen.Count) { $seen.Keys -join ' | ' } else { 'none' }))
}

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
if (-not (Test-Path $cli)) { throw "Duplicati の CLI がありません: $cli" }
if ((Get-Service LanmanServer).Status -ne 'Running') { throw '何も変えずに止めました: Windows のファイル共有（Server サービス）が動いていません。' }
if (Get-LocalUser -Name $user -ErrorAction SilentlyContinue) { throw "何も変えずに止めました: アカウント $user がすでにあります。" }
if (Get-SmbShare -Name $share -ErrorAction SilentlyContinue) { throw "何も変えずに止めました: 共有 $share がすでにあります。" }
if (Test-Path $root) { throw "何も変えずに止めました: $root がすでにあります。" }
if (net use 2>&1 | Select-String -SimpleMatch '\\127.0.0.1') { throw '何も変えずに止めました: \\127.0.0.1 への接続がすでにあります。' }

if (Test-Path $out) { Remove-Item $out }
W "test-smb-2630 started $(Get-Date -Format s), CLI $((Get-Item $cli).LastWriteTime.ToString('s'))"
$bytes = [byte[]]::new(18); [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$pass = 'Dp9!' + ([Convert]::ToBase64String($bytes) -replace '[+/=]', 'x')
$credKeysBefore = @(cmdkey /list | Select-String -Pattern '127\.0\.0\.1').Count
try {
    Say '準備: 一時的なアカウントと共有を作っています...'
    New-LocalUser -Name $user -Password (ConvertTo-SecureString $pass -AsPlainText -Force) -PasswordNeverExpires -AccountNeverExpires -Description 'Duplicati #2630 test (test-smb-2630.ps1)' | Out-Null
    New-Item -ItemType Directory "$root\share", "$root\src\docs" | Out-Null
    icacls "$root\share" /grant "${user}:(OI)(CI)M" | Out-Null
    New-SmbShare -Name $share -Path "$root\share" -FullAccess $user | Out-Null
    Set-Content "$root\src\a.txt" 'first file'; Set-Content "$root\src\docs\b.txt" 'second file'
    $env:DUPLICATI_HOME = "$root\home"
    W 'created account, share and source'
    Snapshot 'before'

    Say 'A. 組み込みの SMB クライアント（smb://）でバックアップ・一覧・復元しています...'
    W ''; W '===== A. smb:// (the built-in SMB client)'
    $url = "smb://127.0.0.1/$share/smbdest?auth-username=$user&auth-password=$([uri]::EscapeDataString($pass))"
    RunCli 'A-backup' @('backup', "`"$url`"", "`"$root\src\\`"", '--no-encryption', "--dbpath=`"$root\a.sqlite`"") $pass
    RunCli 'A-restore' @('restore', "`"$url`"", '*', '--no-encryption', "--dbpath=`"$root\a.sqlite`"", "--restore-path=`"$root\restoreA`"") $pass
    $same = -not (Compare-Object (Get-ChildItem "$root\src" -Recurse -File | ForEach-Object { "$($_.Name)=$(Get-Content $_.FullName)" }) (Get-ChildItem "$root\restoreA" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name)=$(Get-Content $_.FullName)" }))
    W "  restored files match the source: $same"
    W "  files on the share: $((Get-ChildItem "$root\share\smbdest" -File -ErrorAction SilentlyContinue | Measure-Object).Count)"
    Snapshot 'after A'

    Say 'B. 比べるため、従来の方法（フォルダーの宛先に \\127.0.0.1\... と資格情報）でバックアップしています...'
    W ''; W '===== B. folder destination with a \\server\share path and credentials (the old way)'
    RunCli 'B-backup' @('backup', "`"$unc\folderdest`"", "`"$root\src\\`"", '--no-encryption', "--dbpath=`"$root\b.sqlite`"", "--auth-username=$user", "--auth-password=$pass") $pass
    W "  files on the share: $((Get-ChildItem "$root\share\folderdest" -File -ErrorAction SilentlyContinue | Measure-Object).Count)"
    Snapshot 'after B'
} catch {
    W "stopped with an error: $($_.Exception.Message.Replace($pass, '***'))"
    Say "エラーで止まりました: $($_.Exception.Message.Replace($pass, '***'))" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '片付け: 接続・共有・アカウント・フォルダーを消しています...'
    net use $unc /delete /y 2>&1 | Out-Null
    net use '\\127.0.0.1\IPC$' /delete /y 2>&1 | Out-Null
    if (@(cmdkey /list | Select-String -Pattern '127\.0\.0\.1').Count -gt $credKeysBefore) { cmdkey /delete:127.0.0.1 2>&1 | Out-Null }
    Remove-SmbShare -Name $share -Force -ErrorAction SilentlyContinue
    Remove-LocalUser -Name $user -ErrorAction SilentlyContinue
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    $pass = $null
    W ''
    W ("cleanup: account=" + [bool](Get-LocalUser -Name $user -ErrorAction SilentlyContinue) + " share=" + [bool](Get-SmbShare -Name $share -ErrorAction SilentlyContinue) + " folder=" + (Test-Path $root) + " net-use-127=" + [bool](net use 2>&1 | Select-String -SimpleMatch '\\127.0.0.1'))
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。'
}
