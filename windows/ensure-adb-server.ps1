# Called on demand by the WSL bridge, never by a logon task.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Test-AdbEndpoint {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $pending = $client.BeginConnect('127.0.0.1', 5037, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(700)) { return $false }
        $client.EndConnect($pending)
        $stream = $client.GetStream()
        $stream.ReadTimeout = 700
        $stream.WriteTimeout = 700
        $request = [Text.Encoding]::ASCII.GetBytes('000chost:version')
        $stream.Write($request, 0, $request.Length)
        $reply = New-Object byte[] 12
        $offset = 0
        while ($offset -lt $reply.Length) {
            $read = $stream.Read($reply, $offset, $reply.Length - $offset)
            if ($read -eq 0) { return $false }
            $offset += $read
        }
        return [Text.Encoding]::ASCII.GetString($reply) -match '^OKAY0004[0-9a-fA-F]{4}$'
    } catch { return $false }
    finally { $client.Dispose() }
}

$mutex = [Threading.Mutex]::new($false, ('Local\DotfilesAdb-' + [Security.Principal.WindowsIdentity]::GetCurrent().User.Value))
$locked = $false
try {
    try { $locked = $mutex.WaitOne(5000) } catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Outra inicializacao ADB esta em andamento; tente novamente.' }
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object LocalPort -eq 5037)
    foreach ($listener in $listeners) {
        if ($listener.LocalAddress -notin @('127.0.0.1', '::1')) {
            throw 'Porta 5037 exposta fora do loopback; revise o servidor existente manualmente.'
        }
        if ((Get-Process -Id $listener.OwningProcess -ErrorAction Stop).ProcessName -ne 'adb') {
            throw 'Porta 5037 ocupada por outro programa; nenhum processo foi encerrado.'
        }
    }
    if (Test-AdbEndpoint) { Write-Output 'ADB Windows ja responde em 127.0.0.1:5037; preservado.'; exit 0 }
    if ($listeners.Count) { throw 'Existe listener em 5037, mas ADB nao responde; nenhum processo foi reiniciado.' }

    $adb = (Get-Command adb.exe -CommandType Application -ErrorAction Stop).Source
    # A host in -L or ADB_SERVER_SOCKET makes start-server a remote connection.
    # Use the Windows default local socket, with no -a, -H or -L.
    foreach ($name in @('ADB_SERVER_SOCKET', 'ANDROID_ADB_SERVER_ADDRESS', 'ANDROID_ADB_SERVER_PORT')) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    $errorLog = Join-Path $env:TEMP 'adb.log'
    # UseShellExecute (the Start-Process default without redirects) gives this
    # Windows process its own hidden console. Redirect* would switch it off and
    # can leave inherited pipes open in the daemon, blocking WSL's caller.
    # Wait only for the initial client, not all daemon descendants (-Wait).
    $starter = Start-Process -FilePath $adb -ArgumentList 'start-server' -WindowStyle Hidden -PassThru
    # Cache the handle before waiting; otherwise PowerShell 5.1 can return a
    # null ExitCode for a short-lived process even after WaitForExit succeeds.
    $null = $starter.Handle
    if (-not $starter.WaitForExit(6000)) {
        throw "O cliente inicial ADB excedeu 6s (PID $($starter.Id)); nao foi encerrado automaticamente. Log: $errorLog"
    }
    if ($starter.ExitCode -ne 0) { throw "adb start-server falhou ($($starter.ExitCode)); consulte $errorLog" }
    if (-not (Test-AdbEndpoint)) { throw "ADB iniciado, mas nao responde em 127.0.0.1:5037; consulte $errorLog" }
    Write-Output 'ADB Windows iniciado em 127.0.0.1:5037.'
} catch {
    Write-Error $_
    exit 1
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
