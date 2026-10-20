@echo off
setlocal EnableExtensions
chcp 65001 >nul
title DEBLOAT - Windows 11 Pro 26H2
color 0E

:: ====================================================================
::  DEBLOAT COMPLETO - WINDOWS 11 PRO 26H2
::  Execute como ADMINISTRADOR (botao direito > Executar como administrador)
::  Feito para: pmaurer
:: ====================================================================

:: ------------------------------------------------------------------
::  CONFIGURACAO  (1 = ativo / 0 = desligado)  -- edite aqui
:: ------------------------------------------------------------------
set "CFG_CHECKD=1"          :: 1 = roda chkdsk /f /r no final (LENDARIO, pode demorar horas + reinicia)
set "CFG_WUCLEAN=1"         :: 1 = limpa cache do Windows Update (SoftwareDistribution/catroot2)
set "CFG_ONEDRIVE=0"        :: 1 = desinstala o OneDrive (desligado por padrao; 0 para nao mexer)
set "CFG_TELEMETRIA=1"      :: 1 = desativa telemetria / dados de diagnostico / id de publicidade
set "CFG_SERVICOS=1"        :: 1 = desativa servicos de telemetria (DiagTrack, dmwappush, lfsvc)
set "CFG_DISM=1"            :: 1 = DISM restorehealth + startcomponentcleanup /resetbase
set "CFG_SFC=1"             :: 1 = sfc /scannow

:: --------------------------------------------------
::  ADMINISTRADOR
:: --------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [ERRO] Execute este script como ADMINISTRADOR.
    echo.
    pause
    exit /b 1
)

:: --------------------------------------------------
::  BACKUP de registro (o que vamos mexer)
:: --------------------------------------------------
set "BKUP=%USERPROFILE%\Desktop\debloat-backup"
echo.
echo   [backup] Salvar configuracoes de registro em: %BKUP%
if not exist "%BKUP%" mkdir "%BKUP%" >nul 2>&1
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows"        "%BKUP%\policies-windows.reg"    /y >nul 2>&1
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" "%BKUP%\policies-defender.reg" /y >nul 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "%BKUP%\explorer.reg" /y >nul 2>&1

echo.
echo   ======================================================
echo   DEBLOAT COMPLETO  -  WINDOWS 11 PRO 26H2
echo   ======================================================
echo.

:: ====================================================================
::  1) REMOVE BLOATWARE (APPS UWP / MSIX)
::     - conta atual
::     - todos os usuarios
::     - provisionado (para nao voltar em contas novas)
:: ====================================================================
echo   [1/8] Removendo bloatware (apps UWP)...

set "PS1=%temp%\debloat-uwp-%random%.ps1"
>  "%PS1%" echo $apps = @(
>> "%PS1%" echo   'Microsoft.Microsoft3DBuilder','Microsoft.Microsoft3DViewer',
>> "%PS1%" echo   'Microsoft.BingNews','Microsoft.BingWeather',
>> "%PS1%" echo   'Microsoft.SkypeApp','Microsoft.Getstarted',
>> "%PS1%" echo   'Microsoft.WindowsFeedbackHub','Microsoft.People',
>> "%PS1%" echo   'Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
>> "%PS1%" echo   'Microsoft.Messaging','Microsoft.WindowsSoundRecorder',
>> "%PS1%" echo   'Microsoft.MixedReality.Portal','Microsoft.MixedReality.WindowManager',
>> "%PS1%" echo   'Microsoft.Print3D','Microsoft.Todos',
>> "%PS1%" echo   'Microsoft.OneConnect','Microsoft.Wallet','Microsoft.WindowsTips',
>> "%PS1%" echo   'Microsoft.MSPaint','Microsoft.WindowsMaps','Microsoft.WindowsAlbums',
>> "%PS1%" echo   'CorridorApps.CorrEvent','Microsoft.Windows.SafetyCenter'
>> "%PS1%" echo )
>> "%PS1%" echo # conta atual
>> "%PS1%" echo Get-AppxPackage -ErrorAction SilentlyContinue |
>> "%PS1%" echo   Where-Object { $apps -contains $_.Name } |
>> "%PS1%" echo   Remove-AppxPackage -ErrorAction SilentlyContinue
>> "%PS1%" echo # todos os usuarios
>> "%PS1%" echo Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
>> "%PS1%" echo   Where-Object { $apps -contains $_.Name } |
>> "%PS1%" echo   Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
>> "%PS1%" echo # provisionado (contas novas)
>> "%PS1%" echo Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
>> "%PS1%" echo   Where-Object { $apps -contains $_.PackageName } |
>> "%PS1%" echo   ForEach-Object {
>> "%PS1%" echo     Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
>> "%PS1%" echo   }
>> "%PS1%" echo Write-Host ("  -> UWP restantes na conta atual: " + @(Get-AppxPackage -ErrorAction SilentlyContinue).Count)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
del "%PS1%" >nul 2>&1

:: ====================================================================
::  2) TELEMETRIA / DADOS DE DIAGNOSTICO / ID DE PUBLICIDADE
:: ====================================================================
if "%CFG_TELEMETRIA%"=="1" (
  echo.
  echo   [2/8] Desativando telemetria e dados de diagnostico...
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\TailoredExperiencesAndContentActivation" /v TailoredExperiencesAndContentActivationAllowed /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v Disabled /t REG_DWORD /d 1 /f >nul
  echo   -> AllowTelemetry=1 (Seguranca), telemetria minima.
)

:: ====================================================================
::  3) SERVICOS DE TELEMETRIA / LOCALIZACAO
:: ====================================================================
if "%CFG_SERVICOS%"=="1" (
  echo.
  echo   [3/8] Desativando servicos de telemetria...
  sc config DiagTrack        start= disabled
  sc config dmwappushservice start= disabled
  sc config lfsvc            start= demand
  net stop DiagTrack        >nul 2>&1
  net stop dmwappushservice >nul 2>&1
  net stop lfsvc            >nul 2>&1
  echo   -> DiagTrack/dmwappush = desativados, lfsvc = manual.
)

:: ====================================================================
::  4) CORTANA / BUSCA WEB / GAME DVR
:: ====================================================================
echo.
echo   [4/8] Desativando Cortana, busca web e Game DVR...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul
reg add "HKCU\SYSTEM\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
echo   -> Cortana e busca web desligados; Game DVR desligado.

:: ====================================================================
::  5) ONEDRIVE (opcional)
:: ====================================================================
if "%CFG_ONEDRIVE%"=="1" (
  echo.
  echo   [5/8] Desinstalando OneDrive...
  taskkill /f /im OneDrive.exe >nul 2>&1
  if exist "C:\Program Files\Microsoft OneDrive\OneDrive.exe" (
    "C:\Program Files\Microsoft OneDrive\OneDrive.exe" /uninstall
  )
  reg delete "HKCR\Explorer\ShellFolders\AppDataNames\OneDrive" /f >nul 2>&1
  echo   -> OneDrive removido do menu Explorer.
)

:: ====================================================================
::  6) LIMPEZA DO WINDOWS UPDATE + TEMP/PREFETCH
:: ====================================================================
if "%CFG_WUCLEAN%"=="1" (
  echo.
  echo   [6/8] Limpando cache do Windows Update...
  net stop wuauserv >nul 2>&1
  net stop bits     >nul 2>&1
  if exist "C:\Windows\SoftwareDistribution.old" rmdir /s /q "C:\Windows\SoftwareDistribution.old"
  if exist "C:\Windows\SoftwareDistribution"      move "C:\Windows\SoftwareDistribution" "C:\Windows\SoftwareDistribution.old"
  if exist "C:\Windows\System32\catroot2"        rd /s /q "C:\Windows\System32\catroot2"
  net start wuauserv >nul 2>&1
  net start bits     >nul 2>&1
  del /s /f /q "C:\Windows\Prefetch\*.bin" >nul 2>&1
  del /s /f /q "%TEMP%\*.*" >nul 2>&1
  echo   -> Cache do WU, Prefetch e TEMP limpos.
)

:: ====================================================================
::  7) DISM (imagem do Windows + limpeza de componentes)
:: ====================================================================
if "%CFG_DISM%"=="1" (
  echo.
  echo   [7/8] DISM restorehealth + startcomponentcleanup /resetbase (demorado)...
  dism /online /cleanup-image /restorehealth
  dism /online /cleanup-image /startcomponentcleanup /resetbase
)

:: ====================================================================
::  8) SFC
:: ====================================================================
if "%CFG_SFC%"=="1" (
  echo.
  echo   [8/8] Executando sfc /scannow...
  sfc /scannow
)

:: ====================================================================
::  CHEKDSK (final - requer reinicio)
:: ====================================================================
if "%CFG_CHECKD%"=="1" (
  echo.
  echo   [chkdsk] Verificando disco C: /f /r (requer REINICIO)...
  chkdsk C: /f /r
)

:: --------------------------------------------------
echo.
echo   ======================================================
echo   DEBLOAT CONCLUIDO
echo   - Reinicie o PC para finalizar (chkdsk pendente, se rodou).
echo   - Backup do registro em: %BKUP%
echo   - Para reverter: importar os .reg do backup + rodar "chkdsk" de novo se quiser.
echo   ======================================================
echo.
pause
endlocal
