# Android, ADB e WSLg

O SDK e o Android Studio são instalados no Arch. O telefone USB fica no Windows, que executa o servidor ADB. Os clientes Linux usam `tcp:127.0.0.1:5037` em rede WSL `mirrored`; USBIPD e emulador Linux não fazem parte dessa configuração.

## Instalar ou reaplicar

Com o Windows e a base Arch já configurados, feche a IDE e execute na raiz do checkout Arch:

```bash
bash wsl/install.sh --android-studio
```

Essa etapa instala o SDK, a ponte ADB, o pacote estável Android Studio, o launcher e suas preferências. Para instalar somente SDK e ponte, use `bash wsl/install.sh --android`. Não é preciso repetir esses comandos para trabalhar em um ambiente já configurado.

O SDK padrão fica em `~/Android/Sdk`. Os componentes e o hash do download inicial estão em [android-sdk.sh](../wsl/tools/android-sdk.sh). O instalador aceita as licenças e assegura Platform Tools, API 36 e Build Tools 36.0.0. O JDK padrão do ambiente é o 17; o JDK 21 também está disponível.

No Windows, [setup-apps.ps1](../windows/setup-apps.ps1) procura `adb.exe` no PATH e preserva a instalação encontrada; se faltar, instala `Google.PlatformTools` pelo winget. Confira a origem com `Get-Command adb.exe -All`. Conecte o telefone com depuração USB habilitada e aceite a autorização RSA. Drivers do fabricante, quando necessários, pertencem ao Windows.

## Abrir a IDE

Use `android-studio-wsl` no terminal Arch ou **Android Studio (Arch WSL)** no menu Iniciar. O launcher prepara `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `ADB_SERVER_SOCKET` e o tema GTK, verifica a ponte e chama o executável original do pacote.

Os nomes `android-studio` e `android-studio-wsl` no autocomplete são esperados: o primeiro pertence ao pacote; o segundo prepara o ambiente WSL. O comando recomendado é `android-studio-wsl`.

Conclua o assistente inicial da IDE usando o SDK Linux. Em **Settings → Build, Execution, Deployment → Debugger → ADB server lifecycle management**, confira:

- **Use existing manually managed server** habilitado.
- Porta **5037**.

A IDE consome o servidor Windows sem controlar seu ciclo de vida. O setup confirma o formato das preferências na versão instalada, preserva outras opções e cria um backup. Recusa editar configurações com a IDE aberta.

A entrada WSLg usa o `startupWmClass` do pacote, o ícone oficial e o launcher WSL. Sobreposições ocultam a entrada redundante do pacote no menu, preservando seu arquivo original e seu comando. Entradas legadas reconhecidas são retiradas antes da publicação da entrada principal; um auxiliar restaura o atalho Windows se ele ficar ausente por causa do cache do WSLg. Atalhos personalizados existentes são preservados.

## Verificar a ponte e o telefone

No Arch:

```bash
command -v adb
adb-bridge status
adb devices -l
```

`adb-bridge status` consulta o protocolo sem iniciar servidor. `adb devices -l` e o launcher chamam a recuperação quando necessário. O helper inicia somente o ADB Windows e mantém o listener no loopback; um servidor que responde é preservado. Versão, ajuda, geração de chaves e `kill-server` não iniciam o servidor.

A inicialização Windows usa `Start-Process` com console oculto independente, sem streams herdados do WSL. Espera até seis segundos pelo processo inicial, sem esperar pelo daemon descendente; a chamada PowerShell tem limite de 16 segundos. Ela limpa as variáveis de endereço ADB apenas nesse processo e usa o socket local padrão, sem host explícito em `-L`. Portas ocupadas e falhas da ponte são reportadas sem reiniciar processos existentes.

| Resultado | O que verificar |
| --- | --- |
| Sem processo/listener ADB no Windows | `adb devices -l` ou `adb-bridge ensure` recupera o servidor. |
| ADB responde no Windows, mas falha no Arch | Configuração mirrored, loopback e firewall. |
| Lista vazia também no Windows | Enumeração USB, cabo de dados, depuração e driver. A lista vazia não comprova desconexão física. |
| `unauthorized` | Desbloqueie o telefone e aceite a autorização RSA. |
| `offline` | Transporte USB e depuração; um servidor acessível não precisa ser reiniciado automaticamente. |
| `device` no terminal, mas ausente na IDE | Preferência de servidor manual em 5037; reabra a IDE após aplicar a configuração. |

O mesmo aparelho deve aparecer no PowerShell com `adb devices -l` e no Arch. O log Windows fica em `%TEMP%\adb.log`; o da IDE fica em `~/.cache/Google/<versao>/log/idea.log`. No Windows, `Get-NetTCPConnection -LocalPort 5037` mostra o listener e suas conexões.

## Preferências e backup

O auxiliar [android-studio-adb-settings.py](../wsl/tools/android-studio-adb-settings.py) verifica as classes da IDE antes de editar. No formato suportado, usa `PropertyService.keyToString` em `~/.config/Google/<versao>/options/other.xml`:

```text
AdbOptionsService.use.user.managed.adb = true
AdbOptionsService.user.managed.adb.port = 5037
```

Os valores são strings no JSON do componente. A pasta da versão vem de `product-info.json`; não crie um `adb.xml` nem suponha o formato antigo `PropertiesComponent`. Se a versão não for reconhecida, configure pela interface.

O primeiro conteúdo anterior é salvo em `other.xml.adb-bridge.bak`. Para restaurar somente as duas preferências ADB, feche a IDE e, na raiz do checkout, execute com o caminho da versão instalada:

```bash
/usr/bin/python wsl/tools/android-studio-adb-settings.py --restore-from /caminho/other.xml.adb-bridge.bak
```

Outras preferências são preservadas. Uma nova execução do instalador volta a aplicar o modo manual.

## Reparo gráfico manual

Para a falha conhecida de janelas vazias com `[WARN:COPY MODE]`, salve o trabalho e feche as sessões WSL. No PowerShell, no checkout Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\keepalive.ps1 -RepairOnly
```

O script verifica a falha de memória compartilhada e pode executar `wsl --shutdown`, encerrando todas as sessões WSL. É um reparo pontual, sem garantia de persistência; não é executado pelo setup nem no logon. `-RepairOnly` não mantém uma sessão permanente.

## Validação

Testes isolados, sem alterar servidores reais:

```bash
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python -m unittest discover -s wsl/tests -p 'test_adb_bridge.py' -v
```

No PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\tests\adb-server.Tests.ps1
```

Para testar recuperação real, feche a IDE e conclua sessões ADB em uso. Execute `adb kill-server`, confirme no Windows que não há processo/listener em 5037 e rode `adb devices -l` no Arch. O comando deve retornar ao terminal e recriar somente o servidor Windows em loopback. Repita a consulta e confira que o PID permanece. A listagem do aparelho depende de conexão e autorização; confira também o reconhecimento na IDE reaberta.

`bash wsl/tools/android-smoke.sh` testa separadamente a compilação de um APK temporário, sem exigir aparelho. Esse teste não comprova instalação, execução ou depuração no telefone.
