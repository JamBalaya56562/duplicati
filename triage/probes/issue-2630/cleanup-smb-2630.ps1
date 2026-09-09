<#
  test-smb-2630.ps1 が残したものを消す（duplicati/duplicati#2630 のテスト）。PowerShell 7 用。
  管理者の PowerShell 7 で実行:  pwsh -ExecutionPolicy Bypass -File .\cleanup-smb-2630.ps1
  テストの Duplicati の CLI を止め、\\127.0.0.1 への接続・共有 DupTest2630・アカウント dup2630test・C:\dup2630 を消す。
  ほかの接続・資格情報・共有には触れない。
#>
$ErrorActionPreference = 'Continue'
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'Duplicati\.CommandLine\.dll' -and $_.CommandLine -match 'dup2630' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; "stopped the test CLI (pid $($_.ProcessId))" }
Start-Sleep 2
net use '\\127.0.0.1\DupTest2630' /delete /y 2>&1 | Out-Null
net use '\\127.0.0.1\IPC$' /delete /y 2>&1 | Out-Null
if (Get-SmbShare -Name DupTest2630 -ErrorAction SilentlyContinue) { Remove-SmbShare -Name DupTest2630 -Force; 'removed share DupTest2630' }
if (Get-LocalUser -Name dup2630test -ErrorAction SilentlyContinue) { Remove-LocalUser -Name dup2630test; 'removed account dup2630test' }
if (Test-Path C:\dup2630) { Remove-Item C:\dup2630 -Recurse -Force; 'removed C:\dup2630' }
"check: account=" + [bool](Get-LocalUser -Name dup2630test -ErrorAction SilentlyContinue) + " share=" + [bool](Get-SmbShare -Name DupTest2630 -ErrorAction SilentlyContinue) + " folder=" + (Test-Path C:\dup2630) + " net-use-127=" + [bool](net use 2>&1 | Select-String -SimpleMatch '\\127.0.0.1')
Write-Host '片付けが終わりました。' -ForegroundColor Cyan
