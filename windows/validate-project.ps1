param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Project,
    [ValidateSet('Sync', 'Validate')][string]$Mode = 'Validate',
    [string]$TargetRoot = 'C:\Dev\.targets'
)

$ErrorActionPreference = 'Stop'

if ($Project -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $Project -in @('.', '..')) {
    throw "Unsafe project name: $Project"
}

$sourceFull = (Resolve-Path -LiteralPath $Source).ProviderPath.TrimEnd('\')
if ($sourceFull -notmatch '^\\\\wsl(?:\.localhost|\$)\\archlinux\\home\\[^\\]+\\dev\\[^\\]+$') {
    throw 'Source must be a project directly under ~/dev in the archlinux WSL distribution.'
}
if ((Split-Path -Leaf $sourceFull) -ine $Project) {
    throw 'Project name must match the source directory.'
}

$rootFull = [IO.Path]::GetFullPath($TargetRoot).TrimEnd('\')
if ((Split-Path -Leaf $rootFull) -ne '.targets' -or
    $rootFull -eq [IO.Path]::GetPathRoot($rootFull)) {
    throw 'Target root must be a .targets directory below a local drive.'
}
if (-not (Test-Path -LiteralPath $rootFull)) {
    New-Item -ItemType Directory -Path $rootFull -Force | Out-Null
}
if ((Get-Item -LiteralPath $rootFull).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Target root cannot be a junction or symlink.'
}

$target = Join-Path $rootFull ("$Project-win")
$workspace = Join-Path $target 'workspace'
$marker = Join-Path $target '.dotfiles-wsl-arch-target.json'
if (Test-Path -LiteralPath $target) {
    if ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Target cannot be a junction or symlink.'
    }
    if (-not (Test-Path -LiteralPath $marker)) {
        throw "Existing target lacks the dotfiles marker; refusing to mirror into $target"
    }
    $saved = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
    if ($saved.project -ine $Project -or $saved.source -ine $sourceFull) {
        throw "Existing target belongs to a different source: $target"
    }
} else {
    New-Item -ItemType Directory -Path $target | Out-Null
    @{ project = $Project; source = $sourceFull } |
        ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
}
if (Test-Path -LiteralPath $workspace) {
    if ((Get-Item -LiteralPath $workspace).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Workspace cannot be a junction or symlink.'
    }
}
New-Item -ItemType Directory -Path $workspace -Force | Out-Null

$excludedDirs = @(
    '.git', 'node_modules', 'target', '.gradle', '.cache', '.turbo',
    '.next', '.nuxt', '.output', '.svelte-kit', '.venv', 'venv',
    '__pycache__', 'coverage', 'dist', 'build', 'out'
)
$excludedFiles = @('.DS_Store', 'Thumbs.db')
$copyArgs = @(
    $sourceFull, $workspace, '/MIR', '/COPY:DAT', '/DCOPY:DAT',
    '/R:2', '/W:1', '/XJ', '/NP', '/NFL', '/NDL', '/NJH', '/NJS',
    '/XD'
) + $excludedDirs + @('/XF') + $excludedFiles

& robocopy.exe @copyArgs
$syncCode = $LASTEXITCODE
if ($syncCode -ge 8) {
    throw "Source sync failed: robocopy exit code $syncCode"
}
Write-Host "Synced $sourceFull -> $workspace (robocopy $syncCode)"
if ($Mode -eq 'Sync') { exit 0 }

$validator = Join-Path $workspace 'scripts\validate-windows.ps1'
if (-not (Test-Path -LiteralPath $validator)) {
    throw 'Add scripts/validate-windows.ps1 to the project to run Windows builds and tests.'
}

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = @(@($machinePath, $userPath) | Where-Object { $_ }) -join ';'
$gstRoot = [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', 'Machine')
if (-not $gstRoot) {
    $gstRoot = [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', 'User')
}
if ($gstRoot) {
    $gstBin = Join-Path $gstRoot 'bin'
    if (Test-Path -LiteralPath (Join-Path $gstBin 'gst-inspect-1.0.exe')) {
        $env:GSTREAMER_1_0_ROOT_MSVC_X86_64 = $gstRoot
        $env:Path = "$gstBin;$env:Path"
    }
}
$llvmBin = Join-Path $env:ProgramFiles 'LLVM\bin'
if (Test-Path -LiteralPath (Join-Path $llvmBin 'libclang.dll')) {
    $env:LIBCLANG_PATH = $llvmBin
    $env:Path = "$llvmBin;$env:Path"
}

$cudaRoot = [Environment]::GetEnvironmentVariable('CUDA_PATH', 'User')
if (-not $cudaRoot) { $cudaRoot = [Environment]::GetEnvironmentVariable('CUDA_PATH', 'Machine') }
if ($cudaRoot -and (Test-Path -LiteralPath (Join-Path $cudaRoot 'bin\nvcc.exe'))) {
    $env:CUDA_PATH = $cudaRoot
    $env:Path = "$(Join-Path $cudaRoot 'bin');$env:Path"
}

Push-Location $workspace
try {
    $env:WINDOWS_VALIDATION_WORKSPACE = $workspace
    $global:LASTEXITCODE = 0
    & $validator
    if ($LASTEXITCODE -ne 0) {
        throw "Project Windows validation failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}
Write-Host "Windows validation passed: $Project"
