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
Invoke-Expression (& starship init powershell)
