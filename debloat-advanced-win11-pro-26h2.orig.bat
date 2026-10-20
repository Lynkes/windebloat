@echo off
setlocal EnableExtensions
chcp 65001 >nul
title DEBLOAT AVAN. - Win11 Pro 26H2 (telemetria + RAM + anticheat)
color 0B

:: ====================================================================
::  FASE 2 - DEBLOAT AVANCADO (empilha em cima da fase 1)
::  Foco: tarefas de telemetria + memoria + anticheat kernel
::  Regra: NAO desinstala Defender nem Windows Update (Vanguard/EAC/BattlEye
::         precisam deles); so REDUZ o que rodam em background.
::  Execute como ADMINISTRADOR.
:: ====================================================================

:: --------------------------------------------------
::  CONFIGURACAO  (1 = ativo / 0 = desligado)
:: --------------------------------------------------
set "CFG_TASKS=1"      :: desativa TASKS de telemetria (CEIP, WER, Ait, usapvt, etc)
set "CFG_SYSMAIN=1"    :: desativa SysMain/Superfetch (inutil em SSD, libera RAM)
set "CFG_WSEARCH=1"    :: desativa Windows Search (indexador) - libera RAM/disco; PERDE busca do menu Inicio
set "CFG_WUA=1"        :: desativa WaaSMedicSvc + UsoSvc (agendamento do Update) - mantem o Update fun. manualmente
set "CFG_APPW=1"       :: desativa appwservice (Application Experience / telemetria de apps)
set "CFG_XBOX=1"       :: desativa servicos Xbox (AuthManager/GameSave) - so mexe em apps Xbox
set "CFG_DEFENDER=1"   :: reduz Defender (tempo real, PUA/adware, MAPS) - bom p/ anticheat kernel
set "CFG_BGAPPS=1"     :: desliga apps UWP em segundo plano (global)
set "CFG_MEMCOMP=0"    :: desativa Memoria Compactada (1 = tenta; so use se tiver RAM de sobra)
set "CFG_REPORT=1"     :: lista itens de inicializacao (so reporta, nao desativa nada)

:: --------------------------------------------------
::  ADMINISTRADOR
:: --------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [ERRO] Execute como ADMINISTRADOR.
    pause
    exit /b 1
)

:: backup do que vamos mexer
set "BKUP=%USERPROFILE%\Desktop\debloat-backup"
if not exist "%BKUP%" mkdir "%BKUP%" >nul 2>&1
for %%K in (
    "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender"
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
) do (
    reg export "%%~K" "%BKUP%\f2-%%~K.reg" /y >nul 2>&1
)

echo.
echo   ======================================================
echo   FASE 2  -  TELEMETRIA + RAM + ANTICHEAT  (26H2)
echo   ======================================================
echo.

:: ====================================================================
::  A) TASKS DE TELEMETRIA  (o foco do pedido)
::     schtasks /change ... /DISABLE  -> reversivel com /ENABLE
:: ====================================================================
if "%CFG_TASKS%"=="1" (
  echo   [A] Desativando TASKS de telemetria...
  set "T="
  for %%T in (
    "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "Microsoft\Windows\ApplicationExperience\AitAgent"
    "Microsoft\Windows\ApplicationExperience\AitClient"
    "Microsoft\Windows\Customer Experience Improvement Program\consolidator"
    "Microsoft\Windows\Customer Experience Improvement Program\kernelceip"
    "Microsoft\Windows\Customer Experience Improvement Program\usapivot"
    "Microsoft\Windows\Customer Experience Improvement Program\usapvtor"
    "Microsoft\Windows\Autochk\Proxy"
    "Microsoft\Windows\Autochk\AutochkRecover"
    "Microsoft\Windows\Autochk\AutochkScheduled"
    "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnostic\DiskDiagnostic"
    "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnostic\DiskDiagnostic-Analysis"
    "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnostic\DMR"
    "Microsoft\Windows\MapReduce\MapReduce"
    "Microsoft\Windows\Memory Diagnostic\DmiRearm"
    "Microsoft\Windows\ProductionAnnouncements\ProductionAnnouncementConsumer"
    "Microsoft\Windows\ProductionAnnouncements\ProductionAnnouncementConsumerAssistant"
    "Microsoft\Windows\WcmInfo\WcmInfo"
    "Microsoft\Windows\Windows Error Reporting\WerTaskCore"
    "Microsoft\Windows\Windows Error Reporting\AppxHwAnalysis"
    "Microsoft\Windows\Windows Error Reporting\WerTaskCore"
    "Microsoft\Windows\Windows Error Reporting\WerTaskCore"
    "Microsoft\Windows\WindowsFeedback\Microsoft-Samples\FeedbackTool"
    "Microsoft\Windows\WindowsFeedback\Microsoft-Samples\WFDiagnosticData"
  ) do (
    schtasks /change /TN "%%~T" /DISABLE >nul 2>&1
  )
  echo   -> Tasks de telemetria desativadas.
)

:: ====================================================================
::  B) SERVICOS QUE COMEM RAM / IDLE
:: ====================================================================
echo.
:: -- SysMain (Superfetch) - inutil em SSD, segura RAM a mais
if "%CFG_SYSMAIN%"=="1" (
  echo   [B1] SysMain (Superfetch) -> desativado (SSD)
  net stop SysMain >nul 2>&1
  sc config SysMain start= disabled
)
:: -- WSearch (indexador) - libera RAM + I/O de disco; perde busca no Inicio
if "%CFG_WSEARCH%"=="1" (
  echo   [B2] Windows Search (WSearch) -> desativado (libera RAM/disco)
  net stop WSearch >nul 2>&1
  sc config WSearch start= disabled
)
:: -- WaaSMedicSvc + UsoSvc - agendamento do Update (mantem Update manual)
if "%CFG_WUA%"=="1" (
  echo   [B3] WaaSMedicSvc + UsoSvc -> desativados (Update segue manual)
  sc config WaaSMedicSvc start= disabled
  sc config UsoSvc start= disabled
  net stop WaaSMedicSvc >nul 2>&1
  net stop UsoSvc >nul 2>&1
)
:: -- appwservice (Application Experience)
if "%CFG_APPW%"=="1" (
  echo   [B4] appwservice (Application Experience) -> desativado
  sc config appwservice start= disabled
  net stop appwservice >nul 2>&1
)
:: -- servicos Xbox (so mexe em apps Xbox / Game Bar)
if "%CFG_XBOX%"=="1" (
  echo   [B5] Xbox AuthManager + GameSave -> desativados
  sc config XblAuthManager start= disabled
  sc config XblGameSave start= disabled
  net stop XblAuthManager >nul 2>&1
  net stop XblGameSave >nul 2>&1
)
:: reafirma os da fase 1 (se rodar a fase 2 sozinha)
net stop DiagTrack >nul 2>&1
net stop dmwappushservice >nul 2>&1
net stop lfsvc >nul 2>&1
sc config DiagTrack start= disabled
sc config dmwappushservice start= disabled
sc config lfsvc start= demand

:: ====================================================================
::  C) DEFENDER REDUZIDO (anticheat kernel gosta disto)
::     NAO desinstala; so mata o que roda em background.
:: ====================================================================
if "%CFG_DEFENDER%"=="1" (
  echo.
  echo   [C] Reduzindo Windows Defender (mantem instalado)...
  :: tempo real
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorBlock /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableArchiveScanning /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanningMappedDrive /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRemovableDriveScanning /t REG_DWORD /d 1 /f >nul
  :: PUA (adware) desligado
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v PuaEnabled /t REG_DWORD /d 0 /f >nul
  :: MAPS / envio online de amostras (best-effort, pode variar por build)
  reg add "HKLM\SOFTWARE\Microsoft\Windows Defender" /v DisableAutoSampleSubmission /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows Defender" /v DisableMAPS /t REG_DWORD /d 1 /f >nul
  echo   -> Tempo real + PUA + MAPS desligados. (reinicie para aplicar)
)

:: ====================================================================
::  D) APPS UWP EM SEGUNDO PLANO  (global, atual usuario)
:: ====================================================================
if "%CFG_BGAPPS%"=="1" (
  echo.
  echo   [D] Apps UWP em segundo plano -> desligados
  reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul
)

:: ====================================================================
::  E) COMPRESSAO DE MEMORIA  (opcional - so com RAM de sobra)
:: ====================================================================
if "%CFG_MEMCOMP%"=="1" (
  echo.
  echo   [E] Memoria Compactada -> desativada (revisite se faltar RAM)
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\MemoryCompression" /v MemoryCompressionEnabled /t REG_DWORD /d 0 /f >nul
)

:: ====================================================================
::  F) RELATORIO DE INICIALIZACAO (so lista - voce decide o que matar)
:: ====================================================================
if "%CFG_REPORT%"=="1" (
  echo.
  echo   [F] Itens de inicializacao (use o Task Manager para desligar os indesejados):
  echo   -------------------------------------------------------------------
  set "PS2=%temp%\debloat-startup-%random%.ps1"
  >  "%PS2%" echo Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue ^
  ^| Sort-Object Name ^
  ^| ForEach-Object { Write-Host ("  {0}  -  {1}" -f $_.Name, $_.Command) }
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS2%"
  del "%PS2%" >nul 2>&1
)

:: --------------------------------------------------
echo.
echo   ======================================================
echo   FASE 2 CONCLUIDA
echo   - REINICIE o PC para aplicar (Defender, servicos, compressao).
echo   - Reverter um servico:  sc config NOMESERVICO start= auto
echo   - Reverter uma task:    schtasks /change /TN "caminho" /ENABLE
echo   - Backup do registro:   %BKUP%
echo   ======================================================
echo.
pause
endlocal
