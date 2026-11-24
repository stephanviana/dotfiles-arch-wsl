# Run with Windows PowerShell 5.1; no Pester installation required.
# All scheduler operations and WSL commands are mocked. No real task is changed.
$ErrorActionPreference = 'Stop'
$windowsDir = Split-Path -Parent $PSScriptRoot
$migration = Join-Path $windowsDir 'disable-wsl-logon-tasks.ps1'
$global:DotfilesStartupTestState = @{ checks = 0 }

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $global:DotfilesStartupTestState.checks++
}

Get-ChildItem -LiteralPath $windowsDir -Filter '*.ps1' -Recurse | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    Assert-True (@($parseErrors).Count -eq 0) "PowerShell parse: $($_.FullName): $parseErrors"
}

function New-TestTask([string]$Name = 'ArchWSLKeepAlive', [switch]$Legacy) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $execute = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f
        (Join-Path $env:LOCALAPPDATA 'dotfiles-wsl-arch\keepalive.ps1')
    $description = ''
    if ($Legacy) {
        $execute = Join-Path $env:WINDIR 'System32\wsl.exe'
        $arguments = '-d archlinux --exec /usr/bin/sleep infinity'
    }
    if ($Name -eq 'DotfilesOpenUbuntu') {
        $execute = 'wsl.exe'
        $arguments = '-d Ubuntu'
        $description = 'Abre Ubuntu apos reboot do setup dotfiles'
    }
    [pscustomobject]@{
        TaskName = $Name; TaskPath = '\'; Description = $description; State = 'Ready'
        Actions = @([pscustomobject]@{
            Execute = $execute; Arguments = $arguments; WorkingDirectory = ''
            CimClass = [pscustomobject]@{ CimClassName = 'MSFT_TaskExecAction' }
        })
        Triggers = @([pscustomobject]@{
            UserId = $identity.Name
            CimClass = [pscustomobject]@{ CimClassName = 'MSFT_TaskLogonTrigger' }
        })
        Principal = [pscustomobject]@{ UserId = $identity.User.Value; LogonType = 'Interactive'; RunLevel = 'Limited' }
        Settings = [pscustomobject]@{ Enabled = $true }
    }
}

# These mocks shadow the Windows commands in scripts invoked from this scope.
function Get-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName, [string]$TaskPath)
    if ($global:DotfilesStartupTestState.queryFails) { throw 'Simulated scheduler query failure' }
    $global:DotfilesStartupTestState.tasks | Where-Object { $_.TaskPath -eq $TaskPath -and (-not $TaskName -or $_.TaskName -eq $TaskName) }
}
function Disable-ScheduledTask {
    [CmdletBinding()]
    param($InputObject)
    if ($global:DotfilesStartupTestState.disableFails) { throw 'Simulated access denied' }
    $global:DotfilesStartupTestState.disabled += $InputObject.TaskName
    if (-not $global:DotfilesStartupTestState.disableIneffective) { $InputObject.Settings.Enabled = $false }
    if ($InputObject.State -ne 'Running') { $InputObject.State = 'Disabled' }
    $InputObject
}
function Register-ScheduledTask { throw 'Unexpected task registration' }
function Set-ScheduledTask { throw 'Unexpected task update' }
function Enable-ScheduledTask { throw 'Unexpected task enabling' }
function Start-ScheduledTask { throw 'Unexpected task start' }
function Stop-ScheduledTask { throw 'Unexpected task stop' }
function Unregister-ScheduledTask { throw 'Unexpected task removal' }
function Stop-Process { throw 'Unexpected process termination' }
function wsl.exe { throw "Unexpected WSL command: $args" }

function Reset-Tasks($Tasks = @()) {
    $global:DotfilesStartupTestState.tasks = @($Tasks)
    $global:DotfilesStartupTestState.disabled = @()
    $global:DotfilesStartupTestState.queryFails = $false
    $global:DotfilesStartupTestState.disableFails = $false
    $global:DotfilesStartupTestState.disableIneffective = $false
}

Reset-Tasks
& $migration
Assert-True ($global:DotfilesStartupTestState.tasks.Count -eq 0 -and $global:DotfilesStartupTestState.disabled.Count -eq 0) 'Absent tasks stay absent'

foreach ($variant in @('Arch', 'LegacyArch', 'Ubuntu', 'UbuntuFullPath')) {
    $task = if ($variant -like 'Ubuntu*') { New-TestTask 'DotfilesOpenUbuntu' } else {
        New-TestTask -Legacy:($variant -eq 'LegacyArch')
    }
    if ($variant -eq 'UbuntuFullPath') { $task.Actions[0].Execute = Join-Path $env:WINDIR 'System32\wsl.exe' }
    Reset-Tasks @($task)
    & $migration -WhatIf
    Assert-True ($task.Settings.Enabled -and $global:DotfilesStartupTestState.disabled.Count -eq 0) "$variant WhatIf is read-only"
    & $migration
    Assert-True (-not $task.Settings.Enabled -and $global:DotfilesStartupTestState.disabled.Count -eq 1) "$variant managed task disabled"
    & $migration
    Assert-True ($global:DotfilesStartupTestState.disabled.Count -eq 1) "$variant reapplication changes nothing"

    $task.Settings.Enabled = $true
    $task.State = 'Running'
    $messages = @(& $migration 3>&1)
    Assert-True (-not $task.Settings.Enabled -and $task.State -eq 'Running') "$variant running instance preserved"
    Assert-True ([bool]($messages -match 'instancia atual ainda precisa terminar')) "$variant pending instance reported"
    $messages = @(& $migration 3>&1)
    Assert-True ($global:DotfilesStartupTestState.disabled.Count -eq 2 -and [bool]($messages -match 'instancia atual ainda precisa terminar')) "$variant disabled running instance still reported"
}

foreach ($name in @('ArchWSLKeepAlive', 'DotfilesOpenUbuntu')) {
    foreach ($customization in @('Action', 'Arguments', 'Description', 'ExtraAction', 'WorkingDirectory', 'Trigger', 'ExtraTrigger', 'User', 'Principal', 'RunLevel', 'Folder')) {
        $task = New-TestTask $name
        switch ($customization) {
            'Action' { $task.Actions[0].Execute = 'custom.exe' }
            'Arguments' { $task.Actions[0].Arguments += ' --custom' }
            'Description' { $task.Description = 'Personal task' }
            'ExtraAction' { $task.Actions += $task.Actions[0] }
            'WorkingDirectory' { $task.Actions[0].WorkingDirectory = 'C:\Custom' }
            'Trigger' { $task.Triggers[0].CimClass.CimClassName = 'MSFT_TaskBootTrigger' }
            'ExtraTrigger' { $task.Triggers += $task.Triggers[0] }
            'User' { $task.Triggers[0].UserId = 'OTHER\user' }
            'Principal' { $task.Principal.UserId = 'OTHER\user' }
            'RunLevel' { $task.Principal.RunLevel = 'Highest' }
            'Folder' { $task.TaskPath = '\Custom\' }
        }
        Reset-Tasks @($task)
        & $migration
        Assert-True ($task.Settings.Enabled -and $global:DotfilesStartupTestState.disabled.Count -eq 0) "$name custom $customization preserved"
    }
}

Reset-Tasks @((New-TestTask), (New-TestTask 'DotfilesOpenUbuntu'))
& $migration
Assert-True ($global:DotfilesStartupTestState.disabled.Count -eq 2) 'Both managed tasks disabled together'

foreach ($failure in @('queryFails', 'disableFails', 'disableIneffective')) {
    Reset-Tasks @((New-TestTask))
    $global:DotfilesStartupTestState[$failure] = $true
    $caught = $false
    try { & $migration } catch { $caught = $true }
    Assert-True $caught "$failure is surfaced"
}

# Exercise the complete setup with local stubs: no apps, real tasks or WSL starts.
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-startup-tests-' + [guid]::NewGuid())
$savedUserProfile = $env:USERPROFILE
$savedLocalAppData = $env:LOCALAPPDATA
try {
    $null = New-Item -ItemType Directory -Path $tempRoot
    $env:USERPROFILE = Join-Path $tempRoot 'user'
    $env:LOCALAPPDATA = Join-Path $tempRoot 'local'
    $null = New-Item -ItemType Directory -Path $env:USERPROFILE
    foreach ($file in @('setup.ps1', 'disable-wsl-logon-tasks.ps1', 'keepalive.ps1', 'validate-project.ps1', '.wslconfig')) {
        Copy-Item -LiteralPath (Join-Path $windowsDir $file) -Destination $tempRoot
    }
    Set-Content -LiteralPath (Join-Path $tempRoot 'setup-apps.ps1') -Value '$global:DotfilesStartupTestState.appsCalled = $true'
    Set-Content -LiteralPath (Join-Path $tempRoot 'setup-terminal.ps1') -Value '$global:DotfilesStartupTestState.terminalCalled = $true'
    function Get-CimInstance { [pscustomobject]@{ TotalPhysicalMemory = 32GB; NumberOfLogicalProcessors = 16 } }
    function wsl.exe {
        if (($args -join ' ') -ne '--list --quiet') { throw "Unexpected WSL command: $args" }
        $global:LASTEXITCODE = 0
        'archlinux'
    }
    Reset-Tasks @((New-TestTask), (New-TestTask 'DotfilesOpenUbuntu'))
    & (Join-Path $tempRoot 'setup.ps1')
    Assert-True ($global:DotfilesStartupTestState.appsCalled -and $global:DotfilesStartupTestState.terminalCalled) 'Setup keeps apps/terminal steps'
    Assert-True ($global:DotfilesStartupTestState.disabled.Count -eq 2) 'Setup invokes task migration'
    $configPath = Join-Path $env:USERPROFILE '.wslconfig'
    Assert-True (Test-Path -LiteralPath $configPath) 'Setup creates missing config without shutdown'
    $configContent = [IO.File]::ReadAllText($configPath)
    foreach ($file in @('keepalive.ps1', 'validate-project.ps1')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA "dotfiles-wsl-arch\$file")) "Setup installs $file"
    }
    & (Join-Path $tempRoot 'setup.ps1')
    Assert-True ($global:DotfilesStartupTestState.disabled.Count -eq 2) 'Setup reapplication does not reactivate tasks'
    Assert-True ([IO.File]::ReadAllText($configPath) -eq $configContent) 'Setup preserves existing config'
} finally {
    $env:USERPROFILE = $savedUserProfile
    $env:LOCALAPPDATA = $savedLocalAppData
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

# Verify RepairOnly runs diagnostics and the known repair without sleep infinity.
# Even the repair/shutdown commands below are mocks, never real WSL operations.
foreach ($needsRepair in @($false, $true)) {
    $global:DotfilesStartupTestState.wslCalls = @()
    $global:DotfilesStartupTestState.graphicsReads = 0
    function wsl.exe {
        $command = $args -join ' '
        $global:DotfilesStartupTestState.wslCalls += $command
        $global:LASTEXITCODE = 0
        if ($command -like '*grep RDP backend:*') {
            $global:DotfilesStartupTestState.graphicsReads++
            if ($needsRepair -and $global:DotfilesStartupTestState.graphicsReads -eq 1) { 'RDP backend: use_gfxredir = 0' }
            else { 'RDP backend: use_gfxredir = 1' }
        } elseif ($command -like '*sleep*') { throw 'RepairOnly must not start a permanent session' }
    }
    & (Join-Path $windowsDir 'keepalive.ps1') -RepairOnly
    Assert-True (-not [bool]($global:DotfilesStartupTestState.wslCalls -match 'sleep infinity')) 'RepairOnly avoids keepalive'
    Assert-True (($global:DotfilesStartupTestState.wslCalls -contains '--shutdown') -eq $needsRepair) 'RepairOnly restarts WSL only for the known fault (mocked)'
    if ($needsRepair) {
        Assert-True ([bool]($global:DotfilesStartupTestState.wslCalls -match '--exec /usr/bin/mount -t tmpfs tmpfs /mnt/shared_memory')) 'Known graphics repair mounts temporary shared memory'
        Assert-True ([bool]($global:DotfilesStartupTestState.wslCalls -match '--exec /usr/bin/umount /mnt/shared_memory')) 'Known graphics repair restores original mount'
    }
}
Write-Host "PASS: $($global:DotfilesStartupTestState.checks) checks; no real tasks or WSL sessions changed."
