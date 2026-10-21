$ErrorActionPreference = 'Stop'

$packages = (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'versions.psd1')).Desktop.Winget
$terminalConfig = Join-Path $PSScriptRoot 'terminal\settings.json'
$profileTemplate = Join-Path $PSScriptRoot 'terminal\profile.ps1'

function Install-WingetPackage([string]$Id) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget ausente; instale $Id manualmente."
    }
    & winget.exe install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar $Id (winget: $LASTEXITCODE)." }
    $env:Path = (@($env:Path,
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
}

if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    Install-WingetPackage $packages.WindowsTerminal
}

if (-not (Get-Command starship.exe -ErrorAction SilentlyContinue)) {
    $starshipBin = Join-Path $env:ProgramFiles 'starship\bin'
    if (Test-Path -LiteralPath (Join-Path $starshipBin 'starship.exe')) {
        $env:Path = "$starshipBin;$env:Path"
    }
}
$starshipReady = $false
if (Get-Command starship.exe -ErrorAction SilentlyContinue) {
    try {
        & starship.exe --version > $null
        $starshipReady = $LASTEXITCODE -eq 0
    } catch { $starshipReady = $false }
}
if (-not $starshipReady) { Install-WingetPackage $packages.Starship }
if (-not (Get-Command starship.exe -ErrorAction SilentlyContinue)) {
    $starshipBin = Join-Path $env:ProgramFiles 'starship\bin'
    if (Test-Path -LiteralPath (Join-Path $starshipBin 'starship.exe')) {
        $env:Path = "$starshipBin;$env:Path"
    }
}
if (-not (Get-Command starship.exe -ErrorAction SilentlyContinue)) {
    throw 'Starship nao foi encontrado apos a instalacao. Abra um novo terminal e execute o setup novamente.'
}

$fontFile = 'CaskaydiaCoveNerdFontMono-Regular.ttf'
$fontDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
    (Join-Path $env:WINDIR 'Fonts')
)
$fontInstalled = @($fontDirs | Where-Object { Test-Path -LiteralPath (Join-Path $_ $fontFile) }).Count -gt 0
if (-not $fontInstalled) {
    # Oh My Posh is used only as the official font installer; Starship owns the prompt.
    if (-not (Get-Command oh-my-posh.exe -ErrorAction SilentlyContinue)) {
        Install-WingetPackage $packages.OhMyPosh
    }
    if (-not (Get-Command oh-my-posh.exe -ErrorAction SilentlyContinue)) {
        throw 'Oh My Posh nao foi encontrado para instalar a CaskaydiaCove Nerd Font.'
    }
    & oh-my-posh.exe font install CascadiaCode
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar CaskaydiaCove Nerd Font.' }
}
if (-not @($fontDirs | Where-Object { Test-Path -LiteralPath (Join-Path $_ $fontFile) }).Count) {
    throw 'CaskaydiaCove NFM nao foi encontrada apos a instalacao.'
}

$profileDir = Join-Path $env:LOCALAPPDATA 'dotfiles-wsl-arch'
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
$profilePath = Join-Path $profileDir 'profile.ps1'
[IO.File]::WriteAllText($profilePath, [IO.File]::ReadAllText($profileTemplate), [Text.UTF8Encoding]::new($false))

$settingsCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)
$settingsPath = $settingsCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $settingsPath) { $settingsPath = $settingsCandidates[0] }
New-Item -ItemType Directory -Path (Split-Path -Parent $settingsPath) -Force | Out-Null

$desiredSettings = [IO.File]::ReadAllText($terminalConfig)
try { $settings = $desiredSettings | ConvertFrom-Json } catch {
    throw "Configuracao versionada do Windows Terminal invalida: $terminalConfig"
}
if ($settings.profiles.defaults.font.face -ne 'CaskaydiaCove NFM') {
    throw 'Fonte inesperada na configuracao versionada do Windows Terminal.'
}
if ($settings.profiles.defaults.colorScheme -ne 'iTerm2 Solarized Dark' -or
    @($settings.schemes | Where-Object name -eq 'iTerm2 Solarized Dark').Count -ne 1) {
    throw 'Esquema iTerm2 Solarized Dark ausente na configuracao versionada do Windows Terminal.'
}
$currentSettings = if (Test-Path -LiteralPath $settingsPath) { [IO.File]::ReadAllText($settingsPath) } else { '' }
if ($currentSettings -ne $desiredSettings) {
    if ($currentSettings -and -not (Test-Path -LiteralPath "$settingsPath.bak")) {
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak"
    }
    [IO.File]::WriteAllText($settingsPath, $desiredSettings, [Text.UTF8Encoding]::new($false))
}

Write-Host "Starship e Windows Terminal configurados: $settingsPath"
