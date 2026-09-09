# Runs usage.sh in a fresh container of each image, one after the other, and removes the containers
$d = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$dir = Split-Path -Parent $PSCommandPath
foreach ($r in @(@('2.3.0.0-stable', 'q2931-230'), @('latest', 'q2931-241'))) {
    $img, $name = $r
    "=== duplicati/duplicati:$img"
    & $d rm -f $name 2>$null | Out-Null
    & $d run -d --name $name --entrypoint sleep "duplicati/duplicati:$img" infinity | Out-Null
    & $d cp (Join-Path $dir 'usage.sh') "${name}:/tmp/usage.sh"
    & $d exec $name bash -c "tr -d '\r' < /tmp/usage.sh > /tmp/u.sh && bash /tmp/u.sh /opt/duplicati/duplicati-cli"
    & $d rm -f $name | Out-Null
}
