[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

# Match the complete known action, not just a task name or one action in a list.
# Unexpected descriptions, users, triggers or working directories are preserved.
function Test-DotfilesWslLogonTask($Task) {
    if ($Task.TaskPath -ne '\' -or @($Task.Actions).Count -ne 1 -or
        @($Task.Triggers).Count -ne 1) { return $false }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $users = @($identity.Name, $identity.User.Value, $env:USERNAME)
    $trigger = $Task.Triggers[0]
    if ($trigger.CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger' -or
        $users -notcontains $trigger.UserId -or
        $users -notcontains $Task.Principal.UserId -or
        $Task.Principal.LogonType -ne 'Interactive' -or
        $Task.Principal.RunLevel -ne 'Limited') { return $false }

    $action = $Task.Actions[0]
    if ($action.CimClass.CimClassName -ne 'MSFT_TaskExecAction' -or
        -not [string]::IsNullOrEmpty($action.WorkingDirectory)) { return $false }

    $wsl = Join-Path $env:WINDIR 'System32\wsl.exe'
    switch ($Task.TaskName) {
        'ArchWSLKeepAlive' {
            if (-not [string]::IsNullOrEmpty($Task.Description)) { return $false }
            $powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $script = Join-Path $env:LOCALAPPDATA 'dotfiles-wsl-arch\keepalive.ps1'
            $arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $script
            return (($action.Execute -eq $powershell -and $action.Arguments -eq $arguments) -or
                ($action.Execute -eq $wsl -and
                 $action.Arguments -eq '-d archlinux --exec /usr/bin/sleep infinity'))
        }
        'DotfilesOpenUbuntu' {
            return ($Task.Description -eq 'Abre Ubuntu apos reboot do setup dotfiles' -and
                $action.Execute -in @('wsl.exe', $wsl) -and $action.Arguments -eq '-d Ubuntu')
        }
    }
    return $false
}

# Enumerate the root folder so an absent task is normal, but access/query errors
# are not silently reported as absence. Never stop or unregister running tasks.
$tasks = @(Get-ScheduledTask -TaskPath '\' -ErrorAction Stop)
$failures = @()
foreach ($name in @('ArchWSLKeepAlive', 'DotfilesOpenUbuntu')) {
    $task = $tasks | Where-Object TaskName -eq $name
    if (-not $task) {
        Write-Host "Tarefa $name ausente; nenhuma tarefa sera criada."
        continue
    }
    if (-not (Test-DotfilesWslLogonTask $task)) {
        Write-Warning "Tarefa $name personalizada ou nao reconhecida; preservada. Revise-a manualmente se abrir janelas no logon."
        continue
    }

    $wasRunning = [string]$task.State -eq 'Running'
    try {
        if ($task.Settings.Enabled) {
            if (-not $PSCmdlet.ShouldProcess("\$name", 'Desabilitar tarefa de logon dos dotfiles')) { continue }
            Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
        }
        $current = Get-ScheduledTask -TaskName $name -TaskPath '\' -ErrorAction Stop
        if ($current.Settings.Enabled) { throw 'A tarefa continua habilitada.' }
        Write-Host "Tarefa $name desabilitada para os proximos logons."
        if ($wasRunning -or [string]$current.State -eq 'Running') {
            Write-Warning "Tarefa $name em execucao: instancia e processos filhos preservados. A desativacao nao encerra o keepalive ou terminal atual. Conclua o trabalho e saia da sessao Windows quando for conveniente; a instancia atual ainda precisa terminar."
        }
    } catch {
        $failures += $name
        Write-Warning "Nao foi possivel desabilitar ${name}: $_"
    }
}
if ($failures.Count) {
    throw "Falha na migracao: $($failures -join ', '). Se houve acesso negado, reexecute windows/disable-wsl-logon-tasks.ps1 em PowerShell elevado com a mesma conta Windows."
}
