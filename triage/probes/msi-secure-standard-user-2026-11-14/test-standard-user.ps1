<#
  fix/msi-wixl-secure-properties の確認: 標準ユーザーが MSI を入れるとき、コマンドラインのプロパティが
  昇格した側（サーバー）に届くか。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\test-standard-user.ps1

  比べる MSI（このフォルダー）:
    master.msi : 公式の 2.4.1.0 stable（wixl 製、SecureCustomProperties は PREVIOUSVERSIONSINSTALLED だけ）
    fixed.msi  : 同じ MSI に、ブランチの MsiSecureProperties が作る一覧（18 個）を書いたもの（違いはこの 1 行だけ）

  流れ（インストーラーの画面を 2 回操作する。UAC も 2 回出る）:
    1. 一時的な標準ユーザー duptest-std を作る（パスワードはスクリプトの中で乱数で作り、どこにも保存しない）
    2. そのユーザーとして各 MSI を普通の画面（full UI）で入れる。/qb だとクライアント側が動かず、
       プロパティの絞り込みが起きないため（1 回目の run1-qb で確認）
       画面では「Generate and use TLS (HTTPS) certificates」にだけチェックを入れ、あとは既定のまま進める
       → UAC が管理者の資格情報を求めるので、あなた（Jam）の資格情報で許可する
    3. ログから「Ignoring disallowed property」と、昇格した側の INSTALL_TLS_CERTS などの値を読む
    4. 管理者としてアンインストール
  最後に一時ユーザーとそのプロファイル、作業フォルダーを必ず消す。結果は .\result.txt（ログもこのフォルダーへ）
#>
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$user = 'duptest-std'
$pub  = 'C:\Users\Public\dup-msi-secure'
$inst = 'C:\Program Files\Duplicati 2'
$out  = Join-Path $here 'result.txt'
$props = 'NOSCRIPT=true'

function W([string]$t) { $t | Out-File -FilePath $out -Append -Encoding utf8 }
function Say([string]$t, [string]$c = 'Cyan') { Write-Host $t -ForegroundColor $c }

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 で実行してください。' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
foreach ($m in 'master', 'fixed') { if (-not (Test-Path (Join-Path $here "$m.msi"))) { throw "何も変えずに止めました: $m.msi がありません。" } }
if (Get-LocalUser -Name $user -ErrorAction SilentlyContinue) { throw "何も変えずに止めました: ユーザー $user がすでにあります（前回の残り）。" }
if (Test-Path $inst) { throw "何も変えずに止めました: $inst があります（Duplicati が入っている）。" }
if (Test-Path $pub) { throw "何も変えずに止めました: $pub がすでにあります（前回の残り）。" }

if (Test-Path $out) { Remove-Item $out }
W "test started $(Get-Date -Format s); properties: $props"
$created = $false
try {
    Say "1. 一時的な標準ユーザー $user を作ります..."
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!#%+=?'
    $plain = -join (1..24 | ForEach-Object { $chars[[Security.Cryptography.RandomNumberGenerator]::GetInt32($chars.Length)] })
    $secure = ConvertTo-SecureString $plain -AsPlainText -Force
    $plain = $null
    New-LocalUser -Name $user -Password $secure -PasswordNeverExpires -UserMayNotChangePassword -Description 'Temporary standard user for a Duplicati MSI test' | Out-Null
    $created = $true
    Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $user
    $groups = (Get-LocalGroup | Where-Object { Get-LocalGroupMember $_ -ErrorAction SilentlyContinue | Where-Object Name -like "*\$user" }).Name -join ', '
    W "user $user groups: $groups"
    $cred = [PSCredential]::new("$env:COMPUTERNAME\$user", $secure)

    New-Item -ItemType Directory $pub | Out-Null
    Copy-Item (Join-Path $here 'master.msi'), (Join-Path $here 'fixed.msi') $pub
    & icacls.exe $pub /grant "${user}:(OI)(CI)M" | Out-Null

    $n = 0
    foreach ($m in 'master', 'fixed') {
        $n++
        Say "$($n + 1). $user として $m.msi のインストーラーを開きます。次のように操作してください:" 'Yellow'
        Say '   「Next」→ ライセンスに同意して「Next」→ オプションの画面で「Generate and use TLS (HTTPS) certificates」にチェック' 'Yellow'
        Say '   → ほかは既定のまま「Next」→「Install」→ UAC はあなたの管理者の資格情報で許可 → 最後の画面で起動のチェックを外して「Finish」' 'Yellow'
        $log = Join-Path $pub "$m-install.log"
        $p = Start-Process msiexec.exe -Credential $cred -LoadUserProfile -WorkingDirectory $pub -ArgumentList "/i `"$pub\$m.msi`" $props /l*v `"$log`"" -Wait -PassThru
        W ''; W "----- $m.msi installed by $user"
        W "  msiexec exit code: $($p.ExitCode)"
        if (Test-Path $log) {
            $text = Get-Content $log -Encoding unicode
            $ignored = @($text | Select-String 'Ignoring disallowed property (\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique)
            W "  'Ignoring disallowed property': $($ignored.Count)$(if ($ignored) { ' -> ' + ($ignored -join ', ') })"
            W "  $((@($text | Select-String 'Client-side and UI is|Switching to server').Line) -join ' / ')"
            foreach ($k in 'AdminUser', 'Privileged', 'LogonUser', 'INSTALL_TLS_CERTS', 'LAUNCH_AS_SERVICE', 'INSTALLASSERVICE', 'ADD_DESKTOP_SHORTCUT', 'NOSCRIPT', 'ADDLOCAL', 'REMOVE') {
                $c = @($text | Select-String "^Property\(C\): $k = " | Select-Object -Last 1).Line
                $s = @($text | Select-String "^Property\(S\): $k = " | Select-Object -Last 1).Line
                W "  $k  client: $(if ($c) { $c -replace '^Property\(C\): \S+ = ' } else { '(none)' })  server: $(if ($s) { $s -replace '^Property\(S\): \S+ = ' } else { '(none)' })"
            }
            Copy-Item $log $here
        } else { W '  no log was written' }
        $lnk = @(Get-ChildItem 'C:\Users\Public\Desktop', "C:\Users\$user\Desktop", 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup', "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Filter '*Duplicati*' -ErrorAction SilentlyContinue).FullName
        W "  Duplicati shortcuts on a desktop or in a Startup folder: $(if ($lnk) { $lnk -join ', ' } else { 'none' })"

        if (Test-Path $inst) {
            Say "   管理者としてアンインストールします..."
            $u = Start-Process msiexec.exe -ArgumentList "/x `"$pub\$m.msi`" /qn NOSCRIPT=true /l*v `"$(Join-Path $here "$m-uninstall.log")`"" -Wait -PassThru
            W "  uninstall exit code: $($u.ExitCode); install folder left: $(Test-Path $inst)"
            $certs = @(Get-ChildItem Cert:\LocalMachine\Root, Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.Subject -like '*Duplicati*' -or $_.Issuer -like '*Duplicati*' })
            W "  Duplicati certificates left in LocalMachine Root/My: $($certs.Count)$(if ($certs) { ' -> ' + (($certs | ForEach-Object { "$($_.PSParentPath -replace '.*::') $($_.Subject) $($_.Thumbprint)" }) -join '; ') })"
        }
    }
} catch {
    W "stopped with an error: $($_.Exception.Message)"
    Say "エラーで止まりました: $($_.Exception.Message)" 'Red'
} finally {
    $ErrorActionPreference = 'Continue'
    Say '後片付け: 一時ユーザーと作業フォルダーを消します...'
    Get-Process -IncludeUserName -ErrorAction SilentlyContinue | Where-Object { $_.UserName -like "*\$user" } | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($created) {
        $sid = (Get-LocalUser -Name $user).SID.Value
        Remove-LocalUser -Name $user
        Get-CimInstance Win32_UserProfile | Where-Object SID -eq $sid | Remove-CimInstance -ErrorAction SilentlyContinue
    }
    Remove-Item $pub -Recurse -Force -ErrorAction SilentlyContinue
    W ''; W "cleanup: user left=$([bool](Get-LocalUser -Name $user -ErrorAction SilentlyContinue)); profile left=$(Test-Path "C:\Users\$user"); work folder left=$(Test-Path $pub); install folder left=$(Test-Path $inst)"
    W "done $(Get-Date -Format s)"
    Say '全部終わりました。結果は result.txt です。'
}
