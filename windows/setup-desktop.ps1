param()

$ErrorActionPreference = 'Stop'
$versions = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'versions.psd1')
$packages = $versions.Desktop.Winget

function Has-Tool([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Require-Tool([string]$Name) {
    if (-not (Has-Tool $Name)) {
        throw "$Name nao foi encontrado apos a instalacao. Abra um novo terminal e execute o setup novamente."
    }
}
function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($env:Path, $machinePath, $userPath) | Where-Object { $_ }) -join ';'
}
function Add-UserPath([string]$Directory) {
    if (-not (Test-Path -LiteralPath $Directory)) { return }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if (@($entries | Where-Object { $_.TrimEnd('\') -ieq $Directory.TrimEnd('\') }).Count -eq 0) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $Directory) -join ';'), 'User')
    }
    if (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $Directory.TrimEnd('\') }).Count -eq 0) {
        $env:Path += ";$Directory"
    }
}
function Install-Winget([string]$Id, [string]$Override = '') {
    if (-not (Has-Tool 'winget.exe')) { throw "winget ausente; instale $Id manualmente." }
    $arguments = @('install', '--id', $Id, '--exact', '--source', 'winget',
        '--accept-source-agreements', '--accept-package-agreements', '--silent')
    if ($Override) { $arguments += @('--override', $Override) }
    & winget.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar $Id (winget: $LASTEXITCODE)." }
    Refresh-ProcessPath
}

if (-not (Has-Tool 'code.cmd')) { Install-Winget $packages.VSCode }
Require-Tool 'code.cmd'
$vsCodeExtensions = @(& code.cmd --list-extensions)
if ($LASTEXITCODE -ne 0) { throw 'Falha ao listar extensoes do VS Code.' }
if ($vsCodeExtensions -notcontains 'ms-vscode-remote.remote-wsl') {
    & code.cmd --install-extension ms-vscode-remote.remote-wsl
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar a extensao WSL do VS Code.' }
}

if (-not (Has-Tool 'git')) { Install-Winget $packages.Git }
$nodeValid = $false
if (Has-Tool 'node') {
    $nodeValid = [version]((node --version).TrimStart('v')) -ge
        [version]$versions.Desktop.NodeMinimum
}
if (-not $nodeValid -or -not (Has-Tool 'npm')) { Install-Winget $packages.Node }
if (-not (Has-Tool 'rustup')) { Install-Winget $packages.Rustup }
Require-Tool 'rustup'
if (Has-Tool 'rustup') {
    if ((& rustup toolchain list | Out-String) -notmatch 'stable-x86_64-pc-windows-msvc') {
        & rustup toolchain install stable-x86_64-pc-windows-msvc --profile default
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar Rust MSVC x64.' }
    }
    if ((& rustup component list --installed --toolchain stable-x86_64-pc-windows-msvc | Out-String) -notmatch 'rustfmt') {
        & rustup component add rustfmt --toolchain stable-x86_64-pc-windows-msvc
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar rustfmt.' }
    }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPresent = (Test-Path -LiteralPath $vswhere) -and
    [bool]@(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath)
if (-not $vsPresent) {
    Install-Winget $packages.BuildTools '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
}
if (-not (Test-Path -LiteralPath $vswhere) -or
    -not @(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath)) {
    throw 'Visual Studio Build Tools sem Desktop development with C++ apos a instalacao.'
}
$webViewRoots = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeWebView\Application'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\EdgeWebView\Application')
)
if (-not @($webViewRoots | Where-Object { Test-Path -LiteralPath $_ }).Count) {
    Install-Winget $packages.WebView2
}
if (-not @($webViewRoots | Where-Object { Test-Path -LiteralPath $_ }).Count) {
    throw 'WebView2 Runtime nao foi encontrado apos a instalacao.'
}

if (-not (Has-Tool 'ffmpeg') -or -not (Has-Tool 'ffprobe')) { Install-Winget $packages.FFmpeg }
if (-not (Has-Tool 'cmake')) { Install-Winget $packages.CMake }
$llvmBin = Join-Path $env:ProgramFiles 'LLVM\bin'
if (-not (Test-Path -LiteralPath (Join-Path $llvmBin 'clang.exe')) -or
    -not (Test-Path -LiteralPath (Join-Path $llvmBin 'libclang.dll'))) {
    Install-Winget $packages.LLVM
}
if (-not (Test-Path -LiteralPath (Join-Path $llvmBin 'clang.exe')) -or
    -not (Test-Path -LiteralPath (Join-Path $llvmBin 'libclang.dll'))) {
    throw 'LLVM/Clang ou libclang.dll ausente apos a instalacao.'
}
Add-UserPath $llvmBin
[Environment]::SetEnvironmentVariable('LIBCLANG_PATH', $llvmBin, 'User')
$env:LIBCLANG_PATH = $llvmBin
if (-not (Has-Tool 'llama-server')) { Install-Winget $packages.LlamaCpp }

$gstRoot = [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', 'Machine')
if (-not $gstRoot) { $gstRoot = [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', 'User') }
$gstReady = $gstRoot -and
    (Test-Path -LiteralPath (Join-Path $gstRoot 'bin\ges-launch-1.0.exe')) -and
    (Test-Path -LiteralPath (Join-Path $gstRoot 'lib\pkgconfig\gst-editing-services-1.0.pc'))
if (-not $gstReady) {
    $installer = Join-Path $env:TEMP "gstreamer-msvc-x64-$($versions.Desktop.GStreamer).exe"
    Invoke-WebRequest -Uri $versions.Desktop.GStreamerInstaller -OutFile $installer
    $process = Start-Process -FilePath $installer -ArgumentList '/TYPE=devel', '/CURRENTUSER', '/VERYSILENT', '/NORESTART' -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "Instalador GStreamer terminou com $($process.ExitCode)." }
    $gstRoot = Join-Path $env:LOCALAPPDATA 'Programs\gstreamer\1.0\msvc_x86_64'
    [Environment]::SetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', $gstRoot, 'User')
    $env:GSTREAMER_1_0_ROOT_MSVC_X86_64 = $gstRoot
}
if ($gstRoot) { Add-UserPath (Join-Path $gstRoot 'bin') }

$gstInspect = if ($gstRoot) { Join-Path $gstRoot 'bin\gst-inspect-1.0.exe' }
if (-not $gstInspect -or -not (Test-Path -LiteralPath $gstInspect)) {
    throw 'GStreamer MSVC x64 nao foi encontrado apos a instalacao.'
}
foreach ($file in @(
    (Join-Path $gstRoot 'bin\ges-launch-1.0.exe'),
    (Join-Path $gstRoot 'lib\pkgconfig\gst-editing-services-1.0.pc'),
    (Join-Path $gstRoot 'include')
)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "GStreamer GES/runtime/desenvolvimento ausente: $file" }
}
foreach ($plugin in 'glshader', 'pitch', 'wasapi2sink') {
    & $gstInspect --exists $plugin 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Plugin GStreamer ausente: $plugin. Instale o pacote MSVC x64 de desenvolvimento." }
}

foreach ($tool in 'git', 'node', 'npm.cmd', 'rustc', 'cargo', 'rustfmt',
        'ffmpeg', 'ffprobe', 'cmake', 'llama-server') { Require-Tool $tool }
if ([version]((node --version).TrimStart('v')) -lt [version]$versions.Desktop.NodeMinimum) {
    throw "Node.js abaixo da versao minima $($versions.Desktop.NodeMinimum)."
}
if ((rustc -vV | Out-String) -notmatch 'host: x86_64-pc-windows-msvc') {
    throw 'Rust nao esta usando o toolchain MSVC x64.'
}

Write-Host 'Instalacao Windows concluida. Abra um novo terminal para atualizar o PATH.'
