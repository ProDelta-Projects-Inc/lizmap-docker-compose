@echo off
setlocal ENABLEDELAYEDEXPANSION

:: -------------------------------
:: Define variables
:: -------------------------------
:: Make sure no trailing backslash
set "SCRIPTDIR=%~dp0"
if "%SCRIPTDIR:~-1%"=="\" set "SCRIPTDIR=%SCRIPTDIR:~0,-1%"

set "INSTALL_DEST=%SCRIPTDIR%\lizmap"
set "INSTALL_SOURCE=%SCRIPTDIR%"
set "QGIS_VERSION_TAG=ltr-rc"

:: Ensure install directory exists
if not exist "%INSTALL_DEST%" mkdir "%INSTALL_DEST%"

:: -------------------------------
:: Fix line endings of configure.sh
:: -------------------------------
if exist "%SCRIPTDIR%\configure.sh" (
    echo Converting configure.sh to LF line endings...
    powershell -Command "(Get-Content '%SCRIPTDIR%\configure.sh') -replace \"`r`n\",\"`n\" | Set-Content -NoNewline '%SCRIPTDIR%\configure.sh'"
) else (
    echo [ERROR] configure.sh not found in %SCRIPTDIR%
    exit /b 1
)

:: -------------------------------
:: Test mount visibility (optional debug)
:: -------------------------------
echo Testing if configure.sh is visible inside container...
docker run -it --rm -v "%INSTALL_SOURCE%:/src" alpine ls -l /src
echo.

:: -------------------------------
:: Run Lizmap Docker container with debug output
:: -------------------------------
echo Running configure.sh inside container...
docker run -it --rm ^
    -u 1000:1000 ^
    -e INSTALL_SOURCE=/install ^
    -e INSTALL_DEST=/lizmap ^
    -e "LIZMAP_DIR=%INSTALL_DEST%" ^
    -e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins ^
    -v "%INSTALL_SOURCE%:/install" ^
    -v "%INSTALL_DEST%:/lizmap" ^
    -v "%INSTALL_SOURCE%:/src" ^
    -v "%SCRIPTDIR%\qgis-data:/qgis-data" ^
    3liz/qgis-map-server:%QGIS_VERSION_TAG% ^
    sh -x /src/configure.sh _configure

:: -------------------------------
:: Done
:: -------------------------------
echo.
echo Setup finished. You can now run:
echo docker-compose --env-file=.env.windows up
endlocal
