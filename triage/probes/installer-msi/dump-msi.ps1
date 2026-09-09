param([Parameter(Mandatory)] [string] $Msi, [Parameter(Mandatory)] [string] $Out)
# Writes the rows of the tables the startup change touches, one line per row, sorted
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($Msi, 0))
$tables = 'Feature', 'FeatureComponents', 'Component', 'Registry', 'Condition', 'AppSearch', 'RegLocator', 'Control', 'ControlEvent', 'Shortcut', 'Directory', 'CustomAction', 'InstallExecuteSequence'
$lines = foreach ($t in $tables) {
    $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @("SELECT * FROM ``$t``"))
    $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
    $cols = $view.GetType().InvokeMember('ColumnInfo', 'GetProperty', $null, $view, @(0))
    $n = $cols.GetType().InvokeMember('FieldCount', 'GetProperty', $null, $cols, $null)
    while ($rec = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)) {
        $vals = for ($i = 1; $i -le $n; $i++) { $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, @($i)) }
        "$t | " + ($vals -join ' | ')
    }
    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null) | Out-Null
}
$lines | Sort-Object | Set-Content -Path $Out -Encoding utf8
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($db) | Out-Null
