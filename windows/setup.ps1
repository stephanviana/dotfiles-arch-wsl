param()

$ErrorActionPreference = 'Stop'

Write-Host 'Dotfiles Windows + Arch Linux (WSL 2)'
Write-Host 'github.com/stephanviana/dotfiles-wsl-arch'

$logonMigration = Join-Path $PSScriptRoot 'disable-wsl-logon-tasks.ps1'
if (-not (Test-Path -LiteralPath $logonMigration)) {
    throw 'Execute windows/setup.ps1 a partir do checkout completo (disable-wsl-logon-tasks.ps1 necessario).'
}
& $logonMigration

$computer = Get-CimInstance Win32_ComputerSystem
$ramGiB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
$logicalCpus = [int]$computer.NumberOfLogicalProcessors
Write-Host "Host: $ramGiB GiB RAM, $logicalCpus CPUs logicas"

$distros = @(wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() })
if ($distros -notcontains 'archlinux') {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw 'Abra o PowerShell como Administrador para instalar o Arch no WSL.' }
    Write-Host 'Instalando a distribuicao oficial archlinux no WSL 2...'
    wsl.exe --install archlinux --no-launch
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar archlinux no WSL.' }
    Write-Warning 'O Windows pode exigir reinicializacao antes do primeiro uso do Arch.'
} else {
    Write-Host 'Distribuicao archlinux presente; preservando a instalacao.'
}

$configPath = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path -LiteralPath $configPath) {
    Write-Host "Preservando configuracao existente: $configPath"
} elseif ($ramGiB -lt 16 -or $logicalCpus -lt 8) {
    Write-Warning 'A configuracao de referencia (8 GB/4 CPUs) requer revisao para este hardware.'
} else {
    $template = Join-Path $PSScriptRoot '.wslconfig'
    if (Test-Path -LiteralPath $template) {
        Copy-Item -LiteralPath $template -Destination $configPath
    } else {
        # Mesmo conteudo do template ao executar o script remotamente.
        @('[wsl2]', 'memory=8GB', 'processors=4', 'swap=2GB',
          'networkingMode=mirrored', 'dnsTunneling=true', 'guiApplications=true') |
            Set-Content -LiteralPath $configPath -Encoding Ascii
    }
    Write-Host "Criado: $configPath"
    Write-Warning 'A nova .wslconfig sera aplicada no proximo inicio do WSL. As sessoes atuais foram preservadas.'
}

Write-Host 'ADB: servidor e dispositivo USB no Windows; cliente Arch via TCP bridge 127.0.0.1:5037.'
Write-Host 'Docker Engine, Compose, Android SDK Linux, Supabase e AgentMemory sao configurados dentro do Arch.'
Write-Host 'Agentes de codigo sao instalados e executados apenas no Arch.'

$appsSetup = Join-Path $PSScriptRoot 'setup-apps.ps1'
if (-not (Test-Path -LiteralPath $appsSetup)) {
    throw 'Execute windows/setup.ps1 a partir do checkout completo (setup-apps.ps1 necessario).'
}
& $appsSetup

$terminalSetup = Join-Path $PSScriptRoot 'setup-terminal.ps1'
if (Test-Path -LiteralPath $terminalSetup) {
    & $terminalSetup
} else {
    Write-Warning 'Execute windows/setup-terminal.ps1 a partir do checkout para configurar o Windows Terminal.'
}

# Install only the manual WSLg repair, without a logon task.
$runtimeDir = Join-Path $env:LOCALAPPDATA 'dotfiles-wsl-arch'
$keepaliveSource = Join-Path $PSScriptRoot 'keepalive.ps1'
if (-not (Test-Path -LiteralPath $keepaliveSource)) {
    throw 'Execute windows/setup.ps1 a partir do checkout completo (keepalive.ps1 necessario).'
}
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$keepalivePath = Join-Path $runtimeDir 'keepalive.ps1'
Copy-Item -LiteralPath $keepaliveSource -Destination $keepalivePath -Force
Write-Host 'Arch sob demanda: abra um terminal ou aplicativo WSL quando precisar.'
Write-Host 'Docker e AgentMemory ficam disponiveis somente enquanto o Arch estiver ativo.'
Write-Host 'Reparo grafico manual: windows/keepalive.ps1 -RepairOnly (pode reiniciar o WSL).'
