# End-to-end check of --sync-keep-modification-time against a local Nextcloud container (fictional account).
param([Parameter(Mandatory)][string]$Cli)
$ErrorActionPreference = 'Stop'
$env:DOTNET_ROOT = 'C:\Users\Jam\AppData\Local\mise\dotnet-root'
$dotnet = Join-Path $env:DOTNET_ROOT 'dotnet.exe'
$work = Join-Path $PSScriptRoot 'work'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory $work, "$work\src\sub" | Out-Null
$env:DUPLICATI_HOME = Join-Path $work 'home'
$user = 'tester'; $pass = 'fake-nc-pass-7702'
$dav = 'http://127.0.0.1:8085/remote.php/dav/files/tester'
$cred = [pscredential]::new($user, (ConvertTo-SecureString $pass -AsPlainText -Force))

Set-Content "$work\src\a.txt" 'first file'
Set-Content "$work\src\sub\b.txt" 'second file'
(Get-Item "$work\src\a.txt").LastWriteTimeUtc = [datetime]::new(2020, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)
(Get-Item "$work\src\sub\b.txt").LastWriteTimeUtc = [datetime]::new(2021, 6, 7, 8, 9, 10, [DateTimeKind]::Utc)
"source times (UTC): a.txt=$((Get-Item "$work\src\a.txt").LastWriteTimeUtc.ToString('u'))  sub/b.txt=$((Get-Item "$work\src\sub\b.txt").LastWriteTimeUtc.ToString('u'))"

function Sync([string]$folder, [string[]]$extra) {
    $url = "webdav://127.0.0.1:8085/remote.php/dav/files/tester/$folder" + "?auth-username=$user&auth-password=$pass"
    $out = & $dotnet $Cli sync $url "$work\src\" --no-encryption @extra 2>&1 | ForEach-Object { "$_" }
    "  sync exit $LASTEXITCODE; " + (($out | Where-Object { $_ -match 'Upload|upload|Error|error|Warning|Sync' } | Select-Object -Last 4) -join ' | ')
}
function Props([string]$folder) {
    $body = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getlastmodified/><d:getetag/></d:prop></d:propfind>'
    $r = Invoke-WebRequest -Uri "$dav/$folder/" -CustomMethod PROPFIND -Headers @{ Depth = 'infinity' } -Body $body -ContentType 'application/xml' -Credential $cred -AllowUnencryptedAuthentication
    $x = [xml]$r.Content
    $ns = New-Object Xml.XmlNamespaceManager $x.NameTable; $ns.AddNamespace('d', 'DAV:')
    foreach ($resp in $x.SelectNodes('//d:response', $ns)) {
        $href = [uri]::UnescapeDataString($resp.SelectSingleNode('d:href', $ns).InnerText)
        if ($href.EndsWith('/')) { continue }
        $lm = $resp.SelectSingleNode('.//d:getlastmodified', $ns).InnerText
        $etag = $resp.SelectSingleNode('.//d:getetag', $ns).InnerText
        [pscustomobject]@{ File = ($href -replace '^.*/' + $folder + '/', ''); Modified = ([datetime]::Parse($lm).ToUniversalTime().ToString('u')); ETag = $etag }
    }
}

foreach ($folder in 'mtime-off', 'mtime-on') {
    try { Invoke-WebRequest -Uri "$dav/$folder" -CustomMethod DELETE -Credential $cred -AllowUnencryptedAuthentication | Out-Null } catch { }
    Invoke-WebRequest -Uri "$dav/$folder" -CustomMethod MKCOL -Credential $cred -AllowUnencryptedAuthentication | Out-Null
}

"`n=== 1. without --sync-keep-modification-time (how it behaves today)"
Sync 'mtime-off' @()
Props 'mtime-off' | Format-Table -AutoSize | Out-String

"=== 2. with --sync-keep-modification-time=true"
Sync 'mtime-on' @('--sync-keep-modification-time=true')
$first = @(Props 'mtime-on')
$first | Format-Table -AutoSize | Out-String

"=== 3. the same sync again (nothing changed, so nothing should be uploaded)"
Start-Sleep 2
Sync 'mtime-on' @('--sync-keep-modification-time=true')
$second = @(Props 'mtime-on')
$second | Format-Table -AutoSize | Out-String
foreach ($f in $first) { $s = $second | Where-Object File -eq $f.File; "  $($f.File): etag $(if ($s.ETag -eq $f.ETag) { 'unchanged (not uploaded again)' } else { "CHANGED $($f.ETag) -> $($s.ETag)" })" }

"`n=== 4. local folder destination with the option"
$dest = Join-Path $work 'dest'
$out = & $dotnet $Cli sync "file://$dest" "$work\src\" --no-encryption --sync-keep-modification-time=true 2>&1 | ForEach-Object { "$_" }
"  sync exit $LASTEXITCODE"
Get-ChildItem $dest -Recurse -File | ForEach-Object { "  $($_.FullName.Substring($dest.Length + 1)): $($_.LastWriteTimeUtc.ToString('u'))" }
