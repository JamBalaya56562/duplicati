<#
  repro-7804.ps1 -SkipCleanup が入れたままにした Duplicati を取り除く（duplicati/duplicati#7804 のテスト）。
  管理者の PowerShell で実行:  pwsh -ExecutionPolicy Bypass -File .\cleanup-7804.ps1
  サービスのデータのフォルダー（systemprofile の下）と DuplicatiTeam のキーは、この PC で最初に試す前には
  無かった（2026-11-13 に repro-7804.ps1 で確認）ので消す。%LOCALAPPDATA%\Duplicati（利用者自身のデータ）と
  C:\ProgramData\Duplicati には触れない。
#>
$ErrorActionPreference = 'Continue'
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$newMsi  = Join-Path $here 'duplicati-2.4.1.0_stable_2026-10-29-win-x64-gui.msi'
$install = 'C:\Program Files\Duplicati 2'
$svcData = 'C:\Windows\System32\config\systemprofile\AppData\Local\Duplicati'
$regTeam = 'HKLM:\SOFTWARE\DuplicatiTeam'

$p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '管理者の PowerShell で実行してください。' }

Get-Process -Name 'Duplicati.GUI.TrayIcon' -ErrorAction SilentlyContinue | Stop-Process -Force
New-Item -ItemType Directory -Force (Join-Path $here 'logs') | Out-Null
$u = Start-Process msiexec.exe -ArgumentList "/x `"$newMsi`" /qn /l*v `"$here\logs\05-uninstall.log`"" -Wait -PassThru
"uninstall exit code: $($u.ExitCode)"
if (Test-Path $svcData) { Remove-Item $svcData -Recurse -Force; "removed $svcData" }
if (Test-Path $regTeam) { Remove-Item $regTeam -Recurse -Force; "removed $regTeam" }
cmdkey /delete:duplicati-trayicon-password 2>$null | Out-Null
cmdkey /delete:duplicati-trayicon-hosturl 2>$null | Out-Null
"service present: " + [bool](Get-Service -Name Duplicati -ErrorAction SilentlyContinue)
"install folder present: " + (Test-Path $install)
"cleanup done $(Get-Date -Format s)"
