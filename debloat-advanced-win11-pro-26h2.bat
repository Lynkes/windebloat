@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title DEBLOAT AVAN. - Win11 Pro 26H2 (telemetria + RAM)
color 0B

:: ====================================================================
::  FASE 2 - DEBLOAT AVANCADO (empilha em cima da fase 1)
::  Foco: tasks de telemetria + servicos que ficam em segundo plano.
::  NAO remove o Defender nem o Windows Update; so reduz o que roda sozinho.
::
::  Uso:  debloat-advanced-win11-pro-26h2.bat           aplica (pede admin sozinho)
::        debloat-advanced-win11-pro-26h2.bat /dryrun   so mostra o que faria
::
::  Cada execucao cria  Desktop\debloat-backup\fase2-AAAAMMDD-HHMMSS\
::    RESTAURAR-fase2.bat  desfaz exatamente o que AQUELA execucao mudou
::    log.txt              registro do que foi feito
::
::  Regras de edicao (batch e chato):
::    - nunca use  >  <  |  &  em textos de echo / call :log
::    - comentario dentro de bloco ( ... ) quebra o script; deixe fora
:: ====================================================================

:: --------------------------------------------------------------------
::  CONFIGURACAO  (1 = ativo / 0 = desligado)
:: --------------------------------------------------------------------
:: Ponto de restauracao do sistema antes de qualquer mudanca
set "CFG_RESTOREPOINT=1"
:: Tasks agendadas de telemetria (CEIP, Compatibility Appraiser, WER, Device Census...)
set "CFG_TASKS=1"
:: SysMain/Superfetch - pouco ganho em SSD, libera RAM
set "CFG_SYSMAIN=1"
:: Windows Search (indexador) - libera RAM/disco; a busca do Iniciar/Explorer fica bem pior
set "CFG_WSEARCH=1"
:: Windows Update so baixa/instala quando VOCE clicar (por politica; o Update continua funcionando)
set "CFG_WUA=1"
:: PcaSvc - Assistente de Compatibilidade de Programas (substitui o antigo appwservice, que nao existe)
set "CFG_PCA=1"
:: Xbox AuthManager/GameSave - ja sao sob demanda; desativar quebra login do app Xbox/Game Pass
set "CFG_XBOX=1"
:: Reaplica servicos da fase 1 (DiagTrack, dmwappushservice) caso rode a fase 2 sozinha
set "CFG_FASE1=1"
:: Defender: nao envia amostras / MAPS (nuvem). Privacidade, mas detecta menos ameaca nova
set "CFG_DEFENDER_CLOUD=1"
:: Defender: desliga tempo real + bloqueio de PUA. Menos protecao; anticheat NAO exige isso
set "CFG_DEFENDER_RT=1"
:: Apps UWP em segundo plano (usuario atual)
set "CFG_BGAPPS=1"
:: Memoria Compactada - so com RAM de sobra (depende do SysMain; com ele desativado ja nao roda)
set "CFG_MEMCOMP=0"
:: Lista itens de inicializacao (so reporta, nao desativa nada)
set "CFG_REPORT=1"

:: --------------------------------------------------------------------
::  ARGUMENTOS
:: --------------------------------------------------------------------
set "DRYRUN=0"
if /i "%~1"=="/dryrun" set "DRYRUN=1"
if /i "%~1"=="-dryrun" set "DRYRUN=1"
if "%DRYRUN%"=="1" title DEBLOAT AVAN. - SIMULACAO

:: --------------------------------------------------------------------
::  ADMINISTRADOR (pede elevacao sozinho; /dryrun nao precisa)
:: --------------------------------------------------------------------
fltmc >nul 2>&1
if not errorlevel 1 goto :admin_ok
if "%DRYRUN%"=="1" goto :admin_ok
echo.
echo   Pedindo permissao de administrador...
set "SELF=%~f0"
set "SELFARGS=%*"
powershell -NoProfile -Command "$p = @{ FilePath = $env:SELF; Verb = 'RunAs' }; if ($env:SELFARGS) { $p.ArgumentList = $env:SELFARGS }; try { Start-Process @p -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
    echo   [ERRO] Sem permissao. Clique com o botao direito e escolha Executar como administrador.
    pause
)
exit /b
:admin_ok

:: --------------------------------------------------------------------
::  PASTA DE BACKUP + SCRIPT DE RESTAURACAO
:: --------------------------------------------------------------------
set "DESK="
set "STAMP="
for /f "usebackq tokens=1,2 delims=|" %%a in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop') + '|' + (Get-Date -Format 'yyyyMMdd-HHmmss')"`) do (
    set "DESK=%%a"
    set "STAMP=%%b"
)
if not defined DESK set "DESK=%USERPROFILE%\Desktop"
if not defined STAMP set "STAMP=%RANDOM%"
set "BKUP=%DESK%\debloat-backup\fase2-%STAMP%"
set "RESTORE=%BKUP%\RESTAURAR-fase2.bat"
set "LOG=%BKUP%\log.txt"
if "%DRYRUN%"=="1" goto :dry_paths
mkdir "%BKUP%" >nul 2>&1
if exist "%BKUP%\" goto :paths_ok
echo   [ERRO] Nao consegui criar a pasta de backup: "%BKUP%"
pause
exit /b 1
:dry_paths
set "RESTORE=nul"
set "LOG=nul"
:paths_ok
call :restore_header

set /a N_OK=0, N_SKIP=0, N_FAIL=0

call :log ""
call :log "  ======================================================"
call :log "  FASE 2  -  TELEMETRIA + RAM  (Win11 Pro 26H2)"
if "%DRYRUN%"=="1" call :log "  MODO SIMULACAO: nada sera alterado"
call :log "  ======================================================"

call :sec_restorepoint
call :sec_tasks
call :sec_services
call :sec_wu
call :sec_defender
call :sec_bgapps
call :sec_memcomp
call :sec_report
call :finish
endlocal
exit /b 0


:: ====================================================================
::  [0] PONTO DE RESTAURACAO
:: ====================================================================
:sec_restorepoint
if not "%CFG_RESTOREPOINT%"=="1" goto :eof
call :title "[0] Ponto de restauracao"
if "%DRYRUN%"=="1" (
    call :log "  [SIM] criaria um ponto de restauracao"
    goto :eof
)
call :log "  Criando, pode levar um minuto..."
powershell -NoProfile -Command "try { Checkpoint-Computer -Description 'Antes do debloat fase 2' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
    call :log "  [!!] Nao deu para criar: a Restauracao do Sistema pode estar desligada no C:."
    call :log "       Seguindo mesmo assim - o RESTAURAR-fase2.bat continua valendo."
) else (
    call :log "  [OK] Feito. O Windows pula a criacao se ja houver um das ultimas 24h."
)
goto :eof


:: ====================================================================
::  [A] TASKS DE TELEMETRIA
::  Lista conferida no build 26300. Nomes que nao existirem sao so
::  reportados. Tasks que ja estavam desativadas nao entram no restaurar.
::    Compatibility Appraiser / ProgramDataUpdater / MareBackup = inventario de apps
::    Autochk\Proxy / CEIP = Programa de Aperfeicoamento (SQM)
::    Device Information = DeviceCensus.exe
::    DiskDiagnosticDataCollector / DiskFootprint = diagnostico de disco enviado a MS
::    Feedback\Siuf = pesquisas de feedback
::    UsageDataReporting = uso de recursos (flighting)
::    Power Efficiency Diagnostics = analise de energia
::    QueueReporting = fila do Relatorio de Erros (WER)
:: ====================================================================
:sec_tasks
if not "%CFG_TASKS%"=="1" goto :eof
call :title "[A] Tasks agendadas de telemetria"
set "TLIST=%TEMP%\debloat-f2-tasks-%RANDOM%.txt"
> "%TLIST%" (
    for %%T in (
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp"
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
        "\Microsoft\Windows\Application Experience\MareBackup"
        "\Microsoft\Windows\Autochk\Proxy"
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
        "\Microsoft\Windows\Device Information\Device"
        "\Microsoft\Windows\Device Information\Device User"
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        "\Microsoft\Windows\DiskFootprint\Diagnostics"
        "\Microsoft\Windows\Feedback\Siuf\DmClient"
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
        "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting"
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    ) do echo %%~T
)
:: uma unica chamada ao PowerShell devolve "ESTADO|caminho" de cada task
for /f "usebackq tokens=1,* delims=|" %%a in (`powershell -NoProfile -Command "Get-Content -LiteralPath $env:TLIST | ForEach-Object { $i = $_.LastIndexOf('\'); $t = Get-ScheduledTask -TaskPath $_.Substring(0, $i + 1) -TaskName $_.Substring($i + 1) -ErrorAction SilentlyContinue; if (-not $t) { 'NONE|' + $_ } elseif ($t.State -eq 'Disabled') { 'OFF|' + $_ } else { 'ON|' + $_ } }"`) do call :task_off %%a "%%b"
del "%TLIST%" >nul 2>&1
goto :eof


:: ====================================================================
::  [B] SERVICOS EM SEGUNDO PLANO
::  O estado original de cada servico vai para o RESTAURAR-fase2.bat.
:: ====================================================================
:sec_services
call :title "[B] Servicos em segundo plano"
if "%CFG_SYSMAIN%"=="1" call :svc SysMain disabled
if "%CFG_WSEARCH%"=="1" call :svc WSearch disabled
if "%CFG_PCA%"=="1"     call :svc PcaSvc disabled
if "%CFG_XBOX%"=="1"    call :svc XblAuthManager disabled
if "%CFG_XBOX%"=="1"    call :svc XblGameSave disabled
if "%CFG_FASE1%"=="1"   call :svc DiagTrack disabled
if "%CFG_FASE1%"=="1"   call :svc dmwappushservice disabled
goto :eof


:: ====================================================================
::  [C] WINDOWS UPDATE SOB DEMANDA
::  Antes: desativava WaaSMedicSvc (protegido, sempre dava acesso negado)
::  e UsoSvc (sem ele o botao Verificar atualizacoes para de funcionar).
::  Agora: politica oficial - avisa que ha update, voce decide quando baixar.
::  Se a fase 1 ja desligou o update automatico (NoAutoUpdate=1), mantem.
:: ====================================================================
:sec_wu
if not "%CFG_WUA%"=="1" goto :eof
call :title "[C] Windows Update: so baixa e instala quando voce clicar"
set "K=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
set "NAU="
for /f "tokens=3" %%v in ('reg query "%K%" /v NoAutoUpdate 2^>nul ^| findstr /i "REG_DWORD"') do set "NAU=%%v"
if "%NAU%"=="0x1" (
    call :log "  [==] Atualizacao automatica ja esta DESLIGADA por politica (fase 1?) - mantida."
    set /a N_SKIP+=1
) else (
    call :regdw "%K%" NoAutoUpdate 0
    call :regdw "%K%" AUOptions 2
)
call :regdw "%K%" NoAutoRebootWithLoggedOnUsers 1
set "USO="
for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2^>nul ^| findstr /i "REG_DWORD"') do set "USO=%%v"
if not "%USO%"=="0x4" goto :eof
call :log "  [!!] O servico UsoSvc esta DESATIVADO (versao antiga deste script?)."
call :log "       Sem ele a busca manual de atualizacoes costuma falhar. Para religar:"
call :log "       sc config UsoSvc start= delayed-auto"
goto :eof


:: ====================================================================
::  [D] DEFENDER REDUZIDO (continua instalado)
::  Com a Protecao contra Adulteracao (Tamper Protection) ligada o
::  Windows IGNORA estas politicas, entao o script verifica antes.
:: ====================================================================
:sec_defender
if not "%CFG_DEFENDER_CLOUD%"=="1" if not "%CFG_DEFENDER_RT%"=="1" goto :eof
call :title "[D] Windows Defender reduzido (continua instalado)"
set "TAMPER="
for /f "usebackq" %%a in (`powershell -NoProfile -Command "try { (Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected } catch { 'ERR' }"`) do set "TAMPER=%%a"
if /i "%TAMPER%"=="True" (
    call :log "  [!!] A Protecao contra Adulteracao esta LIGADA - o Windows ignoraria tudo aqui."
    call :log "       Desligue em: Seguranca do Windows, Protecao contra virus e ameacas,"
    call :log "       Gerenciar configuracoes. Depois rode o script de novo. Nada foi alterado."
    set /a N_SKIP+=1
    goto :eof
)
if /i "%TAMPER%"=="ERR" call :log "  [..] Defender nao respondeu (outro antivirus?). Aplicando mesmo assim."
set "K=HKLM\SOFTWARE\Policies\Microsoft\Windows Defender"
if "%CFG_DEFENDER_CLOUD%"=="1" (
    call :regdw "%K%\Spynet" SpynetReporting 0
    call :regdw "%K%\Spynet" SubmitSamplesConsent 2
)
if "%CFG_DEFENDER_RT%"=="1" (
    call :regdw "%K%\Real-Time Protection" DisableRealtimeMonitoring 1
    call :regdw "%K%\Real-Time Protection" DisableBehaviorMonitoring 1
    call :regdw "%K%\Real-Time Protection" DisableOnAccessProtection 1
    call :regdw "%K%\Real-Time Protection" DisableScanOnRealtimeEnable 1
    call :regdw "%K%\Real-Time Protection" DisableIOAVProtection 1
    call :regdw "%K%" PUAProtection 0
    call :log "  [..] O tempo real so desliga de fato depois de REINICIAR o PC."
)
goto :eof


:: ====================================================================
::  [E] APPS UWP EM SEGUNDO PLANO (usuario atual - rode logado no SEU usuario)
:: ====================================================================
:sec_bgapps
if not "%CFG_BGAPPS%"=="1" goto :eof
call :title "[E] Apps UWP em segundo plano"
call :regdw "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" GlobalUserDisabled 1
goto :eof


:: ====================================================================
::  [F] MEMORIA COMPACTADA (opcional)
:: ====================================================================
:sec_memcomp
if not "%CFG_MEMCOMP%"=="1" goto :eof
call :title "[F] Memoria Compactada"
set "MC="
for /f "usebackq" %%a in (`powershell -NoProfile -Command "try { (Get-MMAgent -ErrorAction Stop).MemoryCompression } catch { 'ERR' }"`) do set "MC=%%a"
if /i "%MC%"=="False" (
    call :log "  [==] ja estava desativada"
    set /a N_SKIP+=1
    goto :eof
)
if "%DRYRUN%"=="1" (
    call :log "  [SIM] desativaria a Memoria Compactada"
    set /a N_OK+=1
    goto :eof
)
powershell -NoProfile -Command "try { Disable-MMAgent -MemoryCompression -ErrorAction Stop } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    call :log "  [!!] FALHOU. Se o SysMain estiver desativado, ela ja nao roda de qualquer forma."
    set /a N_FAIL+=1
    goto :eof
)
>> "%RESTORE%" echo powershell -NoProfile -Command "Enable-MMAgent -MemoryCompression"
call :log "  [OK] Memoria Compactada desativada"
set /a N_OK+=1
goto :eof


:: ====================================================================
::  [G] RELATORIO DE INICIALIZACAO (so lista - voce decide o que matar)
:: ====================================================================
:sec_report
if not "%CFG_REPORT%"=="1" goto :eof
call :title "[G] Itens de inicializacao - desligue os indesejados no Gerenciador de Tarefas"
powershell -NoProfile -Command "Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { '    {0,-32} {1}' -f $_.Name, $_.Command }"
goto :eof


:: ====================================================================
::  FIM
:: ====================================================================
:finish
>> "%RESTORE%" echo echo Pronto. Reinicie o PC para concluir.
>> "%RESTORE%" echo pause
call :log ""
call :log "  ======================================================"
if "%DRYRUN%"=="1" (
    call :log "  SIMULACAO CONCLUIDA - nada foi alterado."
    call :log "  Seriam alterados: %N_OK%    Ja ok ou inexistentes: %N_SKIP%"
) else (
    call :log "  FASE 2 CONCLUIDA"
    call :log "  Alterados: %N_OK%    Ja ok ou inexistentes: %N_SKIP%    Falhas: %N_FAIL%"
    call :log "  - REINICIE o PC para aplicar tudo."
    call :log "  - Para desfazer, rode como admin: %RESTORE%"
    call :log "  - Log: %LOG%"
)
call :log "  ======================================================"
echo.
pause
goto :eof


:: ====================================================================
::  SUBROTINAS
:: ====================================================================

:: call :log "texto"  - mostra na tela e grava no log
:log
echo(%~1
>> "%LOG%" echo(%~1
goto :eof

:title
call :log ""
call :log "  %~1"
goto :eof

:restore_header
>  "%RESTORE%" echo @echo off
>> "%RESTORE%" echo rem Gerado pelo debloat fase 2 em %STAMP%. Desfaz so o que aquela execucao mudou.
>> "%RESTORE%" echo rem Rode como ADMINISTRADOR, logado no MESMO usuario que rodou o debloat.
>> "%RESTORE%" echo fltmc ^>nul 2^>^&1 ^|^| (echo Execute como ADMINISTRADOR. ^& pause ^& exit /b 1)
>> "%RESTORE%" echo echo Restaurando...
goto :eof

:: call :task_off ON/OFF/NONE "\caminho\da\task"
:task_off
set "TN=%~2"
set "TN=%TN:\Microsoft\Windows\=%"
if /i "%~1"=="NONE" (
    call :log "  [--] nao existe neste build: %TN%"
    set /a N_SKIP+=1
    goto :eof
)
if /i "%~1"=="OFF" (
    call :log "  [==] ja desativada: %TN%"
    set /a N_SKIP+=1
    goto :eof
)
if "%DRYRUN%"=="1" (
    call :log "  [SIM] desativaria: %TN%"
    set /a N_OK+=1
    goto :eof
)
schtasks /change /TN "%~2" /DISABLE >nul 2>&1
if errorlevel 1 (
    call :log "  [!!] FALHOU: %TN%"
    set /a N_FAIL+=1
    goto :eof
)
>> "%RESTORE%" echo schtasks /change /TN "%~2" /ENABLE ^>nul
call :log "  [OK] desativada: %TN%"
set /a N_OK+=1
goto :eof

:: call :svc NOME auto/demand/disabled
:svc
set "S_NAME=%~1"
set "S_NEW=%~2"
sc query "%S_NAME%" >nul 2>&1
if errorlevel 1 (
    call :log "  [--] %S_NAME%: nao existe neste build"
    set /a N_SKIP+=1
    goto :eof
)
set "S_START="
set "S_DELAY="
for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\%S_NAME%" /v Start 2^>nul ^| findstr /i "REG_DWORD"') do set "S_START=%%v"
for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\%S_NAME%" /v DelayedAutostart 2^>nul ^| findstr /i "REG_DWORD"') do set "S_DELAY=%%v"
set "S_OLD="
if "%S_START%"=="0x2" set "S_OLD=auto"
if "%S_START%"=="0x2" if "%S_DELAY%"=="0x1" set "S_OLD=delayed-auto"
if "%S_START%"=="0x3" set "S_OLD=demand"
if "%S_START%"=="0x4" set "S_OLD=disabled"
if not defined S_OLD (
    call :log "  [!!] %S_NAME%: nao consegui ler o estado atual, pulando"
    set /a N_FAIL+=1
    goto :eof
)
if /i "%S_OLD%"=="%S_NEW%" (
    call :log "  [==] %S_NAME%: ja estava %S_NEW%"
    set /a N_SKIP+=1
    goto :eof
)
if "%DRYRUN%"=="1" (
    call :log "  [SIM] %S_NAME%: %S_OLD% para %S_NEW%"
    set /a N_OK+=1
    goto :eof
)
sc config "%S_NAME%" start= %S_NEW% >nul 2>&1
if errorlevel 1 (
    call :log "  [!!] %S_NAME%: FALHOU - servico protegido ou acesso negado"
    set /a N_FAIL+=1
    goto :eof
)
>> "%RESTORE%" echo sc config "%S_NAME%" start= %S_OLD% ^>nul
if /i "%S_NEW%"=="disabled" net stop "%S_NAME%" /y >nul 2>&1
call :log "  [OK] %S_NAME%: %S_OLD% para %S_NEW%"
set /a N_OK+=1
goto :eof

:: call :regdw "HKxx\chave" NomeDoValor NUMERO   - grava REG_DWORD guardando o valor antigo
:regdw
set "R_KEY=%~1"
set "R_VAL=%~2"
set "R_NEW=%~3"
set "R_OLD="
set "R_OLDN="
for /f "tokens=3" %%v in ('reg query "%R_KEY%" /v "%R_VAL%" 2^>nul ^| findstr /i "REG_DWORD"') do set "R_OLD=%%v"
if defined R_OLD set /a "R_OLDN=%R_OLD%"
set "R_SHOW=%R_OLDN%"
if not defined R_SHOW set "R_SHOW=ausente"
if "%R_OLDN%"=="%R_NEW%" (
    call :log "  [==] %R_VAL%: ja era %R_NEW%"
    set /a N_SKIP+=1
    goto :eof
)
if "%DRYRUN%"=="1" (
    call :log "  [SIM] %R_VAL%: %R_SHOW% para %R_NEW%"
    set /a N_OK+=1
    goto :eof
)
reg add "%R_KEY%" /v "%R_VAL%" /t REG_DWORD /d %R_NEW% /f >nul 2>&1
if errorlevel 1 (
    call :log "  [!!] %R_VAL%: FALHOU - chave protegida ou acesso negado"
    set /a N_FAIL+=1
    goto :eof
)
if defined R_OLDN (
    >> "%RESTORE%" echo reg add "%R_KEY%" /v "%R_VAL%" /t REG_DWORD /d %R_OLDN% /f ^>nul
) else (
    >> "%RESTORE%" echo reg delete "%R_KEY%" /v "%R_VAL%" /f ^>nul 2^>^&1
)
call :log "  [OK] %R_VAL%: %R_SHOW% para %R_NEW%"
set /a N_OK+=1
goto :eof
