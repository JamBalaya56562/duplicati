# Run in an elevated (administrator) PowerShell.
# Issue #7740: what the Windows service does when the in-process server crashes while starting.
# For the master build and the branch build (fix/windows-service-report-server-failure):
#   - registers a temporary service "DuplicatiFailTest" running "Duplicati.WindowsService.exe SERVER"
#     with its own data folder and port 8299, as LocalSystem, manual start
#   - sets recovery actions like the branch MSI does, with short delays: restart after 5 s, twice
#     (sc failure + sc failureflag 1)
#   - holds port 8299 on 127.0.0.1 and ::1 so the server fails to start, as the server in #7740 did
#   - starts the service, waits 40 s, and reports the exit code, the restarts and the event log entries
#   - deletes the service again
# Nothing else on the machine is changed. The real "Duplicati" service is not touched.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $PSCommandPath
$out = Join-Path $dir 'service-failure-check-result.txt'
$name = 'DuplicatiFailTest'
$result = [System.Collections.Generic.List[string]]::new()
function Say($s) { $result.Add($s); $s }

Say "user: $env:USERDOMAIN\$env:USERNAME, elevated: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
if (Get-Service $name -ErrorAction SilentlyContinue) {
    Say "STOP: a service named $name already exists; nothing was changed."
    $result | Set-Content -Path $out -Encoding utf8
    return
}

# Hold the port the server is told to use
$listeners = @(
    [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 8299),
    [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::IPv6Loopback, 8299))
$listeners | ForEach-Object { $_.Start() }
Say 'port 8299 held on 127.0.0.1 and ::1'

try {
    foreach ($build in 'master', 'branch') {
        $exe = Join-Path $dir "$build\Duplicati.WindowsService.exe"
        $data = Join-Path $dir "data-$build"
        New-Item -ItemType Directory -Force $data | Out-Null
        Say "=== $build"
        $bin = "`"$exe`" SERVER --webservice-port=8299 --webservice-interface=loopback --server-datafolder=`"$data`""
        & sc.exe create $name binPath= $bin start= demand DisplayName= "Duplicati failure test" | Out-Null
        # The builds need the .NET runtime from the mise install; the value goes away with the service
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$name" -Name Environment -PropertyType MultiString -Value @('DOTNET_ROOT=C:\Users\Jam\AppData\Local\mise\dotnet-root') -Force | Out-Null
        & sc.exe failure $name reset= 86400 actions= restart/5000/restart/5000// | Out-Null
        & sc.exe failureflag $name 1 | Out-Null
        $since = Get-Date
        & sc.exe start $name | Out-Null
        Start-Sleep -Seconds 40

        $q = (& sc.exe query $name) -join ' '
        $state = if ($q -match 'STATE\s*:\s*\d+\s+(\w+)') { $Matches[1] } else { '?' }
        $exit = if ($q -match 'WIN32_EXIT_CODE\s*:\s*(\d+)') { $Matches[1] } else { '?' }
        Say "  after 40 s: state $state, WIN32_EXIT_CODE $exit"

        $scm = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Service Control Manager'; StartTime = $since } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match 'Duplicati failure test' })
        Say "  Service Control Manager events: $($scm.Count)"
        $scm | Sort-Object TimeCreated | ForEach-Object { Say ("    {0:HH:mm:ss} {1}: {2}" -f $_.TimeCreated, $_.Id, ($_.Message -replace '\s+', ' ')) }

        $dup = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $since } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match 'In-process execution ended|ended with exit code|Starting in-process' })
        Say "  Application log entries from the service: $($dup.Count)"
        $dup | Sort-Object TimeCreated | ForEach-Object { Say ("    {0:HH:mm:ss} {1}" -f $_.TimeCreated, (($_.Message -split "`n")[0]).Trim()) }

        & sc.exe stop $name 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        & sc.exe delete $name | Out-Null
        Start-Sleep -Seconds 2
        Say "  service deleted: $(-not (Get-Service $name -ErrorAction SilentlyContinue))"
    }
}
finally {
    $listeners | ForEach-Object { $_.Stop() }
    if (Get-Service $name -ErrorAction SilentlyContinue) { & sc.exe stop $name 2>&1 | Out-Null; & sc.exe delete $name | Out-Null }
}

$result | Set-Content -Path $out -Encoding utf8
"Written to $out"
