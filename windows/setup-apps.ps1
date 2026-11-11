param()

$ErrorActionPreference = 'Stop'
$catalog = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'versions.psd1')
$apps = $catalog.Apps

function Install-App([string]$Id, [string]$Source = 'winget', [string]$Version = '', [string]$Override = '', [switch]$SkipInstalledCheck) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'winget ausente.' }
    if (-not $Version -and -not $SkipInstalledCheck) {
        & winget.exe list --id $Id --exact --source $Source --accept-source-agreements --disable-interactivity > $null 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Host "Preservando pacote instalado: $Id"; return }
    }
    $arguments = @('install', '--id', $Id, '--exact', '--source', $Source,
        '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity')
    if ($Version) { $arguments += @('--version', $Version, '--force') }
    if ($Override) { $arguments += @('--override', $Override) }
    & winget.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar $Id (winget: $LASTEXITCODE)." }
}

function Test-VCRedistSet {
    $roots = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $runtimes = @(Get-ItemProperty $roots -ErrorAction SilentlyContinue | Where-Object DisplayName -match 'Visual C\+\+')
    foreach ($major in 8,9,10,11,12,14) {
        foreach ($architecture in 'x86','x64') {
            if (-not @($runtimes | Where-Object {
                $_.DisplayVersion -match "^$major\." -and $_.DisplayName -match $architecture
            }).Count) { return $false }
        }
    }
    return $true
}

foreach ($id in @($catalog.Desktop.Winget.VSCode, $apps.Winget.IntelliJ,
    $apps.Winget.Bitwarden, $apps.Winget.VCRedist,
    $apps.Winget.WinRAR, $apps.Winget.SevenZip, $apps.Winget.VLC, $apps.Winget.YouTubeMusic)) {
    if ($id -eq $apps.Winget.VCRedist) {
        if (Test-VCRedistSet) { Write-Host 'Preservando runtimes Visual C++ x86/x64 completos.' }
        else {
            Install-App $id
            if (-not (Test-VCRedistSet)) { throw 'Runtimes Visual C++ 2005-2013/v14 x86/x64 incompletos apos a instalacao AIO.' }
        }
    } else { Install-App $id }
}

$env:Path = (@($env:Path, [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
# Node.js is retained for Windows tools; these checks do not configure a compiler toolchain.
$nodeValid = $false
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeValid = [version]((& node --version).TrimStart('v')) -ge [version]$catalog.Desktop.NodeMinimum
}
if (-not $nodeValid -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Install-App $catalog.Desktop.Winget.Node -SkipInstalledCheck
    $env:Path = (@($env:Path, [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
}
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw 'Node.js ou npm nao encontrado; abra outro terminal e reaplique o setup.'
}
if ([version]((& node --version).TrimStart('v')) -lt [version]$catalog.Desktop.NodeMinimum) {
    throw "Node.js abaixo da versao minima $($catalog.Desktop.NodeMinimum)."
}
$webViewRoots = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeWebView\Application'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\EdgeWebView\Application')
)
if (-not @($webViewRoots | Where-Object { Test-Path -LiteralPath $_ }).Count) {
    Install-App $catalog.Desktop.Winget.WebView2 -SkipInstalledCheck
}
if (-not @($webViewRoots | Where-Object { Test-Path -LiteralPath $_ }).Count) {
    throw 'WebView2 Runtime nao foi encontrado apos a instalacao.'
}

if (-not (Get-Command adb.exe -ErrorAction SilentlyContinue)) {
    Install-App $apps.Winget.PlatformTools
    $env:Path = (@([Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
    if (-not (Get-Command adb.exe -ErrorAction SilentlyContinue)) { throw 'ADB ausente apos a instalacao de Platform Tools.' }
}
if (-not (Get-Command code.cmd -ErrorAction SilentlyContinue)) { throw 'VS Code nao encontrado apos a instalacao.' }
& code.cmd --install-extension ms-vscode-remote.remote-wsl
if ($LASTEXITCODE -ne 0) { throw 'Falha ao configurar a extensao WSL do VS Code.' }

# Keep Codex execution inside WSL when its Windows editor UI is used.
$settingsPath = Join-Path $env:APPDATA 'Code\User\settings.json'
$settings = if (Test-Path -LiteralPath $settingsPath) {
    try { [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json }
    catch { throw "Configure chatgpt.runCodexInWindowsSubsystemForLinux=true em $settingsPath (JSON com comentarios preservado)." }
} else { [pscustomobject]@{} }
if ($settings.'chatgpt.runCodexInWindowsSubsystemForLinux' -ne $true) {
    if ((Test-Path -LiteralPath $settingsPath) -and -not (Test-Path -LiteralPath "$settingsPath.bak")) {
        Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak"
    }
    $settings | Add-Member -NotePropertyName 'chatgpt.runCodexInWindowsSubsystemForLinux' -NotePropertyValue $true -Force
    New-Item -ItemType Directory -Path (Split-Path -Parent $settingsPath) -Force | Out-Null
    [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
}

if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw 'Abra o PowerShell como Administrador para instalar o Chocolatey.' }
    $installer = Join-Path $env:TEMP 'dotfiles-chocolatey-install.ps1'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installer
    & $installer
    if (-not (Test-Path -LiteralPath (Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'))) {
        throw 'Chocolatey ausente apos a instalacao.'
    }
}

$video = @(Get-CimInstance Win32_VideoController)
$cpu = @(Get-CimInstance Win32_Processor)
if (@($video | Where-Object PNPDeviceID -match 'VEN_8086').Count -or
    @($cpu | Where-Object Manufacturer -eq 'GenuineIntel').Count) {
    Install-App $apps.Winget.IntelDSA
}
if (@($video | Where-Object PNPDeviceID -match 'VEN_10DE').Count) {
    if (-not (Get-AppxPackage -Name 'NVIDIACorp.NVIDIAControlPanel' -ErrorAction Stop)) {
        Install-App $apps.NvidiaControlPanelStoreId 'msstore'
        if (-not (Get-AppxPackage -Name 'NVIDIACorp.NVIDIAControlPanel' -ErrorAction Stop)) {
            throw 'Painel de Controle NVIDIA ausente apos a instalacao; confira a Microsoft Store e o driver NVIDIA.'
        }
    } else {
        Write-Host 'Preservando Painel de Controle NVIDIA instalado.'
    }
    $nvidiaModels = @($video | Where-Object PNPDeviceID -match 'VEN_10DE' | ForEach-Object Name)
    $supportedModels = @($nvidiaModels | Where-Object { $_ -notin $apps.NvidiaAppUnsupportedModels })
    if ($supportedModels.Count) { Install-App $apps.NvidiaAppStoreId 'msstore' }
    else { Write-Warning "NVIDIA App indisponivel para $($nvidiaModels -join ', '): GPU recusada pelo instalador oficial." }

}

Write-Host 'Aplicativos Windows configurados. Agentes de codigo e SDK Android ficam no Arch.'
