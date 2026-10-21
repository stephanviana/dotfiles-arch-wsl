param([switch]$RepairOnly)

$ErrorActionPreference = 'Stop'
$distro = 'archlinux'

function Assert-WslSuccess([string]$message) {
    if ($LASTEXITCODE -ne 0) { throw $message }
}

function Get-WslgGraphicsMode {
    $lines = @(wsl.exe -d $distro --exec /usr/bin/grep 'RDP backend: use_gfxredir =' /mnt/wslg/weston.log)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) { return $null }
    return $lines[-1]
}

wsl.exe -d $distro --exec /usr/bin/true | Out-Null
Assert-WslSuccess 'Falha ao iniciar o Arch no WSL.'

$graphicsMode = Get-WslgGraphicsMode
$sharedMemoryFailure = $false
if ($graphicsMode -match 'use_gfxredir = 0') {
    wsl.exe -d $distro --exec /usr/bin/grep -q 'rdp_allocate_shared_memory: Failed to open' /mnt/wslg/weston.log
    $sharedMemoryFailure = $LASTEXITCODE -eq 0
}
# Workaround for microsoft/wslg#1456; keep the original virtiofs mount afterward.
if ($sharedMemoryFailure) {
    Write-Host 'Recuperando a memoria compartilhada do WSLg...'
    wsl.exe --system -d $distro -u root --exec /usr/bin/mount -t tmpfs tmpfs /mnt/shared_memory
    Assert-WslSuccess 'Falha ao montar a memoria temporaria do WSLg.'
    wsl.exe --system -d $distro -u root --exec /usr/bin/umount /mnt/shared_memory
    Assert-WslSuccess 'Falha ao restaurar a montagem original do WSLg.'
    wsl.exe --shutdown
    Assert-WslSuccess 'Falha ao reiniciar o WSL apos a recuperacao grafica.'
    wsl.exe -d $distro --exec /usr/bin/true | Out-Null
    Assert-WslSuccess 'Falha ao reiniciar o Arch apos a recuperacao grafica.'
    $graphicsMode = Get-WslgGraphicsMode
    if ($graphicsMode -notmatch 'use_gfxredir = 1') {
        throw 'O WSLg continua em modo de copia; consulte /mnt/wslg/weston.log.'
    }
    Write-Host 'WSLg recuperado.'
} elseif (-not $graphicsMode) {
    Write-Warning 'Nao foi possivel confirmar o modo grafico do WSLg em /mnt/wslg/weston.log.'
}

if (-not $RepairOnly) {
    wsl.exe -d $distro --exec /usr/bin/sleep infinity
    Assert-WslSuccess 'A sessao permanente do Arch foi interrompida.'
}
