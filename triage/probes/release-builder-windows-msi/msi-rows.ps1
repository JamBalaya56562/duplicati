# Prints the rows that the wixl builds get from InstallTables.sql, from an MSI built with WiX, to compare them.
# Read-only: opens the database with msiOpenDatabaseModeReadOnly.
param([string]$Msi)
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($Msi, 0))
function Rows([string]$sql, [int]$cols) {
    try {
        $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @($sql))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
        while ($true) {
            $rec = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
            if (-not $rec) { break }
            $vals = foreach ($i in 1..$cols) { $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, @($i)) }
            '  ' + ($vals -join ' | ')
        }
        $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null) | Out-Null
    } catch { "  (no table or error: $($_.Exception.InnerException.Message))" }
}
"== $Msi"
"MsiServiceConfig (Name, Event, ConfigType, Argument, Component_):"
Rows 'SELECT `Name`, `Event`, `ConfigType`, `Argument`, `Component_` FROM `MsiServiceConfig`' 5
"MsiServiceConfigFailureActions (Name, Event, ResetPeriod, Actions, DelayActions, Component_):"
Rows 'SELECT `Name`, `Event`, `ResetPeriod`, `Actions`, `DelayActions`, `Component_` FROM `MsiServiceConfigFailureActions`' 6
"MsiLockPermissionsEx (LockObject, Table, SDDLText):"
Rows 'SELECT `LockObject`, `Table`, `SDDLText` FROM `MsiLockPermissionsEx`' 3
"MoveFile (FileKey, SourceName, DestName, SourceFolder, DestFolder, Options):"
Rows 'SELECT `FileKey`, `SourceName`, `DestName`, `SourceFolder`, `DestFolder`, `Options` FROM `MoveFile`' 6
"RemoveFile for preload.json (FileName, DirProperty, InstallMode):"
Rows "SELECT ``FileName``, ``DirProperty``, ``InstallMode`` FROM ``RemoveFile`` WHERE ``FileName`` = 'preload.json'" 3
"InstallExecuteSequence (Action, Condition, Sequence) for the injected actions:"
Rows "SELECT ``Action``, ``Condition``, ``Sequence`` FROM ``InstallExecuteSequence`` WHERE ``Action`` = 'ResolveSource' OR ``Action`` = 'MoveFiles' OR ``Action`` = 'MsiConfigureServices'" 3
