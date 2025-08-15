@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ===============================
:: Define some variables
:: ===============================
set "SCRIPTDIR=%~dp0"
set "INSTALL_DEST=%SCRIPTDIR%lizmap"
set "INSTALL_SOURCE=%SCRIPTDIR%"

:: Ensure QGIS version tag matches .env.windows
if "%QGIS_VERSION_TAG%"=="" set "QGIS_VERSION_TAG=ltr-rc"

:: ===============================
:: Convert Windows paths to Docker Unix paths
:: Requires WSL (wsl.exe) installed
:: ===============================
for /f "usebackq delims=" %%i in (`wsl wslpath "%INSTALL_SOURCE%"`) do set "INSTALL_SOURCE_UNIX=%%i"
for /f "usebackq delims=" %%i in (`wsl wslpath "%INSTALL_DEST%"`) do set "INSTALL_DEST_UNIX=%%i"
for /f "usebackq delims=" %%i in (`wsl wslpath "%SCRIPTDIR%"`) do set "SCRIPTDIR_UNIX=%%i"

:: ===============================
:: Run Docker container
:: ===============================
docker run -it -u 1000:1000 --rm ^
    -e INSTALL_SOURCE=/install ^
    -e INSTALL_DEST=/lizmap ^
    -e LIZMAP_DIR=/lizmap ^
    -e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins ^
    -v "%INSTALL_SOURCE_UNIX%:/install" ^
    -v "%INSTALL_DEST_UNIX%:/lizmap" ^
    -v "%SCRIPTDIR_UNIX%:/src" ^
    --entrypoint /src/configure.sh ^
    3liz/qgis-map-server:%QGIS_VERSION_TAG% _configure

:: ===============================
:: Done
:: ===============================
echo setup finished, you can run 'docker-compose --env-file=.env.windows up'

endlocal
