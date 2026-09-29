# =============================================================================
# Dotfiles — Setup Windows (PowerShell como Admin)
# Instala WSL 2 com Arch Linux, apps via Winget e configura .wslconfig
# =============================================================================
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor White
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Install-WingetApp {
    param(
        [string]$Id,
        [string]$Name
    )
    # Verificar se ja esta instalado antes de tentar instalar
    $installed = winget list --id $Id --accept-source-agreements 2>$null |
                 Where-Object { $_ -match [regex]::Escape($Id) }
    if ($installed) {
        Write-Host "   -> $Name ja instalado, pulando..." -ForegroundColor Yellow
        return
    }

    Write-Host "   -> Instalando $Name..." -ForegroundColor Gray
    try {
        winget install --id $Id --accept-source-agreements --accept-package-agreements --silent
        Write-Host "   OK $Name instalado!" -ForegroundColor Green
    }
    catch {
        Write-Host "   AVISO: Falha ao instalar ${Name}: $_" -ForegroundColor Red
    }
}

# ── Banner ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Magenta
Write-Host "  Dotfiles Windows + Arch Linux (WSL 2) -- Setup Automatizado" -ForegroundColor Magenta
Write-Host "  github.com/stephanviana/dotfiles-arch" -ForegroundColor Magenta
Write-Host "==================================================================" -ForegroundColor Magenta
Write-Host ""

# ── [1] WSL 2 + Arch Linux ──────────────────────────────────────────────────
Write-Step "[1] Verificando WSL 2 com Arch Linux..."

$needsReboot = $false

# Checar se Arch Linux ja existe no WSL
$wslList = wsl --list --quiet 2>$null
$archExists = $wslList | Where-Object { $_ -match "archlinux" }

if ($archExists) {
    Write-Host "   -> Arch Linux ja instalado no WSL, pulando instalacao..." -ForegroundColor Yellow
} else {
    Write-Host "   -> Instalando WSL 2 + Arch Linux..." -ForegroundColor Gray
    try {
        wsl --install archlinux --no-launch
        Write-Host "   OK WSL 2 + Arch Linux instalados! Reboot pode ser necessario." -ForegroundColor Green
        $needsReboot = $true
    }
    catch {
        Write-Host "   ERRO: $_" -ForegroundColor Red
        Write-Host "   -> Tente manualmente: wsl --install archlinux" -ForegroundColor Yellow
    }
}

# ── [2] .wslconfig ──────────────────────────────────────────────────────────
Write-Step "[2] Copiando .wslconfig..."

$ScriptDir = $null

if ($PSScriptRoot) {
    $ScriptDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
}

if ($ScriptDir -and (Test-Path "$ScriptDir\.wslconfig")) {
    Copy-Item "$ScriptDir\.wslconfig" "$env:USERPROFILE\.wslconfig" -Force
    Write-Host "   OK .wslconfig copiado de $ScriptDir" -ForegroundColor Green
} else {
    Write-Host "   -> Criando .wslconfig inline (execucao remota)..." -ForegroundColor Gray
    $wslConfigContent = "[wsl2]`nmemory=4GB`nprocessors=4`nnetworkingMode=mirrored`ndnsTunneling=true`n"
    Set-Content -Path "$env:USERPROFILE\.wslconfig" -Value $wslConfigContent -Encoding UTF8
    Write-Host "   OK .wslconfig criado em $env:USERPROFILE\" -ForegroundColor Green
}

# Aplicar .wslconfig reiniciando o WSL (sem reboot completo do Windows)
if (-not $needsReboot) {
    Write-Host "   -> Reiniciando WSL para aplicar .wslconfig..." -ForegroundColor Gray
    wsl --shutdown
    Write-Host "   OK WSL reiniciado com novas configuracoes!" -ForegroundColor Green
}

# ── [3] Apps via Winget ──────────────────────────────────────────────────────
Write-Step "[3] Instalando apps via Winget..."

$Apps = @(
    @{ Id = "Bitwarden.Bitwarden";                     Name = "Bitwarden" },
    @{ Id = "Microsoft.VisualStudioCode";              Name = "VS Code" },
    @{ Id = "Google.AntigravityIDE";                   Name = "Antigravity IDE" },
    @{ Id = "JetBrains.IntelliJIDEA.Community";        Name = "IntelliJ IDEA Community" },
    @{ Id = "Google.AndroidStudio";                    Name = "Android Studio" },
    @{ Id = "dorssel.usbipd-win";                      Name = "USBIPD" },
    @{ Id = "Microsoft.DotNet.SDK.10";                 Name = ".NET 10 SDK" },
    @{ Id = "abbodi1406.vcredist";                      Name = "Visual C++ Redistributables (AIO 2005-2022+)" },
    @{ Id = "JRSoftware.InnoSetup";                    Name = "Inno Setup" },
    @{ Id = "Intel.IntelDriverAndSupportAssistant";    Name = "Intel Driver & Support Assistant" },
    @{ Id = "XP8CLZL93F5Z4P";                          Name = "NVIDIA App (Drivers)" },
    @{ Id = "Nvidia.CUDA";                             Name = "NVIDIA CUDA Toolkit" },
    @{ Id = "RARLab.WinRAR";                           Name = "WinRAR" },
    @{ Id = "7zip.7zip";                               Name = "7-Zip" },
    @{ Id = "VideoLAN.VLC";                            Name = "VLC media player" }
)

foreach ($App in $Apps) {
    Install-WingetApp -Id $App.Id -Name $App.Name
}

# ── [4] Chocolatey ────────────────────────────────────────────────────────────
Write-Step "[4] Verificando Chocolatey..."

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "   -> Chocolatey ja instalado, pulando..." -ForegroundColor Yellow
} else {
    Write-Host "   -> Instalando Chocolatey..." -ForegroundColor Gray
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "   OK Chocolatey instalado com sucesso!" -ForegroundColor Green
    }
    catch {
        Write-Host "   AVISO: Falha ao instalar Chocolatey: $_" -ForegroundColor Red
    }
}

# ── [5] Tarefa pos-reboot ────────────────────────────────────────────────────
Write-Step "[5] Registrando tarefa pos-reboot..."

$TaskName     = "DotfilesOpenArch"
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $ExistingTask) {
    $Action   = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d archlinux"
    $Trigger  = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
        -Settings $Settings -Description "Abre Arch Linux apos reboot do setup dotfiles" | Out-Null
    Write-Host "   OK Tarefa '$TaskName' registrada!" -ForegroundColor Green
} else {
    Write-Host "   -> Tarefa ja existe, pulando..." -ForegroundColor Yellow
}

# ── Resumo ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  RESUMO" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

if ($needsReboot) {
    Write-Host "  OK  WSL 2 + Arch Linux instalados    (reboot necessario)" -ForegroundColor Green
} else {
    Write-Host "  OK  WSL 2 + Arch Linux ja presentes  (sem reboot)" -ForegroundColor Green
}
Write-Host "  OK  .wslconfig aplicado" -ForegroundColor Green
Write-Host "  OK  Apps verificados/instalados via Winget" -ForegroundColor Green
Write-Host "  OK  Chocolatey verificado/instalado" -ForegroundColor Green
Write-Host "  OK  Tarefa pos-reboot registrada" -ForegroundColor Green
Write-Host ""

Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  PROXIMOS PASSOS (Configuracao Inicial do Arch Linux):" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Se for a primeira inicializacao do Arch (abrira como root):" -ForegroundColor Yellow
Write-Host "     useradd -m -g wheel -s /bin/bash <seu_usuario>" -ForegroundColor White
Write-Host "     passwd <seu_usuario>" -ForegroundColor White
Write-Host "     echo `"%wheel ALL=(ALL:ALL) ALL`" > /etc/sudoers.d/wheel" -ForegroundColor White
Write-Host "     passwd root" -ForegroundColor White
Write-Host "     pacman -Sy sudo" -ForegroundColor White
Write-Host ""
Write-Host "  2. Definir seu usuario como padrao do WSL:" -ForegroundColor Yellow
Write-Host "     Opcao A (no terminal do Arch): adicione ao /etc/wsl.conf:" -ForegroundColor White
Write-Host "       [user]" -ForegroundColor Gray
Write-Host "       default=<seu_usuario>" -ForegroundColor Gray
Write-Host "     Opcao B (no PowerShell):" -ForegroundColor White
Write-Host "       wsl --manage archlinux --set-default-user <seu_usuario>" -ForegroundColor White
Write-Host ""
Write-Host "  3. Entrar no Arch Linux com seu usuario e rodar o instalador:" -ForegroundColor Yellow
Write-Host "     git clone https://github.com/stephanviana/dotfiles-arch ~/.dotfiles" -ForegroundColor Cyan
Write-Host "     cd ~/.dotfiles && chmod +x wsl/install.sh wsl/tools/*.sh && ./wsl/install.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

# ── Reboot condicional ────────────────────────────────────────────────────────
if ($needsReboot) {
    Write-Host "Pressione Ctrl+C para cancelar o reboot..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "Setup concluido! Nenhum reboot necessario." -ForegroundColor Green
}
