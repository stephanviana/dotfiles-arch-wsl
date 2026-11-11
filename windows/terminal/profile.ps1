# dotfiles-wsl-arch: Starship
# Distinguish typed options from ordinary command output on Solarized Dark.
if ($Host.Name -eq 'ConsoleHost') {
    Import-Module PSReadLine
    Set-PSReadLineOption -Colors @{ Parameter = '#56b6c2' }
}

if (-not (Get-Command starship.exe -ErrorAction SilentlyContinue)) {
    $starshipBin = Join-Path $env:ProgramFiles 'starship\bin'
    if (Test-Path -LiteralPath (Join-Path $starshipBin 'starship.exe')) {
        $env:Path = "$starshipBin;$env:Path"
    }
}
if (-not (Get-Command starship.exe -ErrorAction SilentlyContinue)) {
    throw 'Starship nao foi encontrado. Execute windows/setup-terminal.ps1 novamente.'
}
# Keep an existing user configuration; otherwise use the Windows timeout setting.
$configDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
$defaultConfig = Join-Path $configDir 'starship.toml'
$managedConfig = Join-Path $PSScriptRoot 'starship.toml'
if (-not $env:STARSHIP_CONFIG -and -not (Test-Path -LiteralPath $defaultConfig) -and (Test-Path -LiteralPath $managedConfig)) {
    $env:STARSHIP_CONFIG = $managedConfig
}
Invoke-Expression (& starship init powershell)
