param([Parameter(Mandatory)] [string] $Image, [Parameter(Mandatory)] [string] $Cli, [Parameter(Mandatory)] [string] $Name, [switch] $KeepStatistics)
# Two backups of 100,000 small files, then every number in sqlite_stat1 is set to 1 (the stale
# statistics of issue #7127), then a third backup with a 15 minute limit.
$ErrorActionPreference = 'Stop'
$d = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$dir = Split-Path -Parent $PSCommandPath
$tool = Join-Path $dir 'stalestats\bin\Debug\net10.0\stalestats.exe'
$db = Join-Path $dir "$Name.sqlite"
$cliArgs = $Cli -split ' '

& $d rm -f $Name 2>$null | Out-Null
& $d run -d --name $Name --entrypoint sleep $Image infinity | Out-Null
& $d cp (Join-Path $dir 'prep.sh') "${Name}:/tmp/prep.sh"
& $d cp (Join-Path $dir 'third.sh') "${Name}:/tmp/third.sh"

& $d exec $Name sh /tmp/prep.sh @cliArgs

& $d cp "${Name}:/tmp/db.sqlite" $db
"--- statistics after run 2"
& $tool $db
if (-not $KeepStatistics) {
    "--- every number set to 1"
    & $tool $db stale
    & $d cp $db "${Name}:/tmp/db.sqlite"
}

& $d exec $Name sh /tmp/third.sh @cliArgs

& $d rm -f $Name | Out-Null
Remove-Item $db -ErrorAction SilentlyContinue
