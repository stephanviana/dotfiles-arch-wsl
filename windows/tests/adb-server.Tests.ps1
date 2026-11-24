# No real ADB process is started or stopped; test the orchestration with mocks.
$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'ensure-adb-server.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors -join ' ') }
$probe = $ast.Find({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-AdbEndpoint'
}, $true)
$text = [IO.File]::ReadAllText($source)
$mockProbe = 'function Test-AdbEndpoint { return ($global:AdbServerTestState.Healthy -or ($global:AdbServerTestState.Started -and $global:AdbServerTestState.BecomesHealthy)) }'
$text = $text.Substring(0, $probe.Extent.StartOffset) + $mockProbe + $text.Substring($probe.Extent.EndOffset)
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-adb-test-' + [guid]::NewGuid() + '.ps1')
[IO.File]::WriteAllText($temporary, $text)

function Get-NetTCPConnection {
    [CmdletBinding()]
    param($State)
    if ($global:AdbServerTestState.HasListener) {
        [pscustomobject]@{ LocalAddress=$global:AdbServerTestState.Address; LocalPort=5037; OwningProcess=123 }
    }
}
function Get-Process {
    [CmdletBinding()]
    param($Id)
    [pscustomobject]@{ ProcessName=$global:AdbServerTestState.Owner }
}
function Get-Command {
    [CmdletBinding()]
    param($Name, $CommandType)
    if ($Name -ne 'adb.exe') { throw 'Unexpected command lookup' }
    [pscustomobject]@{ Source='C:\Test\adb.exe' }
}
function Start-Process {
    [CmdletBinding()]
    param($FilePath, $ArgumentList, $WindowStyle, [switch]$PassThru)
    if ($ArgumentList -ne 'start-server' -or $WindowStyle -ne 'Hidden' -or -not $PassThru) {
        throw 'Unexpected process arguments'
    }
    # The mock does not accept Wait or RedirectStandard*: those must remain absent.
    if ($env:ADB_SERVER_SOCKET -or $env:ANDROID_ADB_SERVER_ADDRESS -or $env:ANDROID_ADB_SERVER_PORT) {
        throw 'Remote server environment was not cleared'
    }
    $global:AdbServerTestState.Starts++
    $global:AdbServerTestState.Started = $true
    $process = [pscustomobject]@{ Id=456; Handle=123; ExitCode=$global:AdbServerTestState.ExitCode }
    $process | Add-Member ScriptMethod WaitForExit {
        param($Milliseconds)
        if ($Milliseconds -ne 6000) { throw 'Expected a bounded initial-process wait' }
        return $global:AdbServerTestState.Finishes
    }
    $process
}

$saved = @{}
foreach ($key in @('ADB_SERVER_SOCKET', 'ANDROID_ADB_SERVER_ADDRESS', 'ANDROID_ADB_SERVER_PORT')) {
    $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
    $checks = 0
    foreach ($case in @('Healthy', 'Stopped', 'ForeignOwner', 'Exposed', 'Unresponsive', 'Timeout', 'BadExit', 'NoResponse')) {
        $global:AdbServerTestState = @{
            Healthy=$case -eq 'Healthy'; HasListener=$case -in @('Healthy','ForeignOwner','Exposed','Unresponsive')
            Address='127.0.0.1'; Owner='adb'; Started=$false; Starts=0; BecomesHealthy=$true; Finishes=$true; ExitCode=0
        }
        if ($case -eq 'ForeignOwner') { $global:AdbServerTestState.Owner = 'other' }
        if ($case -eq 'Exposed') { $global:AdbServerTestState.Address = '0.0.0.0' }
        if ($case -eq 'Timeout') { $global:AdbServerTestState.Finishes = $false }
        if ($case -eq 'BadExit') { $global:AdbServerTestState.ExitCode = 1 }
        if ($case -eq 'NoResponse') { $global:AdbServerTestState.BecomesHealthy = $false }
        $env:ADB_SERVER_SOCKET = 'tcp:elsewhere:5038'
        $env:ANDROID_ADB_SERVER_ADDRESS = 'elsewhere'
        $env:ANDROID_ADB_SERVER_PORT = '5038'
        $failed = $false
        try { & $temporary } catch { $failed = $true }
        $expectedStarts = [int]($case -in @('Stopped', 'Timeout', 'BadExit', 'NoResponse'))
        $expectedFailure = $case -notin @('Healthy', 'Stopped')
        if ($global:AdbServerTestState.Starts -ne $expectedStarts -or $failed -ne $expectedFailure) {
            throw "FAIL: $case (starts=$($global:AdbServerTestState.Starts), failed=$failed)"
        }
        $checks++
    }
    Write-Host "PASS: $checks Windows ADB scenarios; no real servers changed."
} finally {
    foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
    Remove-Item -LiteralPath $temporary -Force
}
