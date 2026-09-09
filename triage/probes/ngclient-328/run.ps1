# Starts an isolated server built from the working copy, runs probe.mjs, stops the server.
# usage: pwsh run.ps1 <label>
param([string]$label, [string]$probe = "probe.mjs")
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$server = 'C:\Users\Jam\Documents\duplicati\Executables\Duplicati.Server\bin\Debug\net10.0\Duplicati.Server.exe'
$node = Join-Path $env:USERPROFILE 'AppData\Local\mise\installs\node\lts\node.exe'
$env:DOTNET_ROOT = Join-Path $env:USERPROFILE 'AppData\Local\mise\dotnet-root'
$port = 8640
if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw "port $port in use" }
$data = Join-Path $root "data-$label"
$src = Join-Path $root 'source'
if (Test-Path $data) { Remove-Item -Recurse -Force $data }
New-Item -ItemType Directory -Force $data, $src | Out-Null
Set-Content (Join-Path $src 'a.txt') 'x'
$pw = 'p328-isolated-only'
$a = @("--server-datafolder=$data", '--allow-insecure-datafolder=true', '--disable-db-encryption=true', "--webservice-port=$port", '--webservice-interface=loopback', "--webservice-password=$pw", "--log-file=$root\server-$label.log", '--log-level=Information')
$p = Start-Process -FilePath $server -ArgumentList $a -WorkingDirectory (Split-Path $server) -WindowStyle Hidden -RedirectStandardOutput "$root\stdout-$label.log" -RedirectStandardError "$root\stderr-$label.log" -PassThru
try {
  $ok = $false
  for ($i = 0; $i -lt 100; $i++) { try { $x = Invoke-WebRequest "http://127.0.0.1:$port/api/v1/systeminfo" -TimeoutSec 1 -SkipHttpErrorCheck; if ($x.StatusCode -in 200, 401) { $ok = $true; break } } catch {}; Start-Sleep -Milliseconds 300 }
  if (-not $ok) { throw 'server not ready' }
  & $node (Join-Path $root $probe) "http://127.0.0.1:$port" $pw $data $src (Join-Path $root "result-$label.json")
  if ($LASTEXITCODE) { throw "probe failed $LASTEXITCODE" }
} finally {
  if (-not $p.HasExited) { Stop-Process -Id $p.Id; $p.WaitForExit() }
}
