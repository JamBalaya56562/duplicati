# Reads a few tables of the MSIs in this folder, read-only. No admin rights needed, nothing is installed.
param([string]$Folder = $PSScriptRoot)
$inst = New-Object -ComObject WindowsInstaller.Installer
function Query($db, [string]$sql) {
    $view = $db.OpenView($sql)
    $view.Execute()
    $rows = @()
    while ($null -ne ($rec = $view.Fetch())) {
        $cells = @()
        for ($i = 1; $i -le $rec.FieldCount; $i++) { $cells += $rec.StringData($i) }
        $rows += ($cells -join ' | ')
    }
    $view.Close()
    return $rows
}
foreach ($f in Get-ChildItem (Join-Path $Folder '*.msi')) {
    $db = $inst.OpenDatabase($f.FullName, 0)
    "===== $($f.Name)"
    "ProductVersion: " + ((Query $db "SELECT Value FROM Property WHERE Property='ProductVersion'") -join ', ')
    "Upgrade:"; Query $db "SELECT UpgradeCode, VersionMin, VersionMax, Attributes, ActionProperty FROM Upgrade" | % { "  $_" }
    "Features:"; Query $db "SELECT Feature, Level FROM Feature" | % { "  $_" }
    "Feature conditions:"; Query $db "SELECT Feature_, Level, Condition FROM Condition" | % { "  $_" }
    "UI sequence (TLS / AppSearch / MigrateFeatureStates):"; Query $db "SELECT Action, Condition, Sequence FROM InstallUISequence" | ? { $_ -match 'TLS|AppSearch|MigrateFeatureStates|FindRelatedProducts|LAUNCH_AS' } | % { "  $_" }
    "Execute sequence (MigrateFeatureStates / RemoveExistingProducts / Upgrade sentinel):"; Query $db "SELECT Action, Condition, Sequence FROM InstallExecuteSequence" | ? { $_ -match 'MigrateFeatureStates|RemoveExistingProducts|UpgradeSentinel|FindRelatedProducts|AppSearch|Set_INSTALL_TLS' } | % { "  $_" }
    "Properties (TLS / service):"; Query $db "SELECT Property, Value FROM Property" | ? { $_ -match 'TLS|SERVICE|SecureCustom' } | % { "  $_" }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($db) | Out-Null
}
