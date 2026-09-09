param([Parameter(Mandatory)] [string] $Msi, [Parameter(Mandatory)] [string] $Out)
# Writes every row of every table, one line per row ("table | col1 | col2 ..."), sorted.
# Stream columns (Binary, Icon) are written as <stream>.
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($Msi, 0))

function Rows($sql) {
    $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @($sql))
    $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
    $cols = $view.GetType().InvokeMember('ColumnInfo', 'GetProperty', $null, $view, @(1))
    $n = $cols.GetType().InvokeMember('FieldCount', 'GetProperty', $null, $cols, $null)
    $types = for ($i = 1; $i -le $n; $i++) { $cols.GetType().InvokeMember('StringData', 'GetProperty', $null, $cols, @($i)) }
    $result = [System.Collections.Generic.List[string]]::new()
    while ($rec = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)) {
        $vals = for ($i = 1; $i -le $n; $i++) {
            if ($types[$i - 1] -match '^[vV]') { '<stream>' }
            else { ($rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, @($i))) -replace "`r?`n", '\n' }
        }
        $result.Add((@($vals) -join ' | '))
    }
    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null) | Out-Null
    return , $result
}

$tables = Rows 'SELECT `Name` FROM `_Tables`'
$lines = foreach ($t in $tables) {
    foreach ($r in (Rows "SELECT * FROM ``$t``")) { "$t | $r" }
}
$lines | Sort-Object | Set-Content -Path $Out -Encoding utf8
"$($tables.Count) tables, $($lines.Count) rows -> $Out"
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($db) | Out-Null
