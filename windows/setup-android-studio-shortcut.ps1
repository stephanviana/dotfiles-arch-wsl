# Repair a missing WSLg shortcut after retiring a same-name legacy app ID.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9_.-]+$')][string]$Distro,
    [Parameter(Mandatory)][ValidatePattern('^/home/[^"\r\n]+/\.local/bin/android-studio-wsl$')][string]$Launcher
)
$ErrorActionPreference = 'Stop'
$directory = Join-Path ([Environment]::GetFolderPath('Programs')) $Distro
$path = Join-Path $directory "Android Studio (Arch WSL) ($Distro).lnk"
$target = Join-Path $env:WINDIR 'System32\wslg.exe'
$arguments = '-d "{0}" --cd "~" -- "{1}"' -f $Distro, $Launcher
$shell = New-Object -ComObject WScript.Shell
# Allow the preceding WSLg legacy-delete notification to reach Windows first.
Start-Sleep -Milliseconds 700
if (Test-Path -LiteralPath $path) {
    $link = $shell.CreateShortcut($path)
    if ($link.TargetPath -ne $target -or $link.Arguments -ne $arguments) {
        # WSLg can produce a different quoting style. Preserve any existing
        # shortcut rather than overwrite an unrecognized/custom command.
        Write-Warning "Atalho existente com outro comando/estilo de argumentos preservado; confira-o manualmente: $path"
        return
    }
    Write-Host "Atalho Android Studio ja correto: $path"
    return
}

$null = New-Item -ItemType Directory -Path $directory -Force
$iconDir = Join-Path $env:LOCALAPPDATA 'dotfiles-wsl-arch'
$null = New-Item -ItemType Directory -Path $iconDir -Force
$iconPath = Join-Path $iconDir 'android-studio.ico'
Add-Type -AssemblyName System.Drawing
$bitmap = [Drawing.Bitmap]::new("\\wsl.localhost\$Distro\opt\android-studio\bin\studio.png")
$icon = $null
$stream = $null
try {
    $icon = [Drawing.Icon]::FromHandle($bitmap.GetHicon())
    $stream = [IO.File]::Create($iconPath)
    $icon.Save($stream)
} finally {
    if ($stream) { $stream.Dispose() }
    if ($icon) { $icon.Dispose() }
    $bitmap.Dispose()
}
$link = $shell.CreateShortcut($path)
$link.TargetPath = $target
$link.Arguments = $arguments
$link.IconLocation = $iconPath
$link.Description = 'Android Studio (Arch WSL) - dotfiles-wsl-arch'
$link.Save()
Write-Host "Atalho Android Studio restaurado apos migracao WSLg: $path"
