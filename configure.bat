@echo off
setlocal ENABLEDELAYEDEXPANSION

:: -------------------------------
:: Define variables
:: -------------------------------
set "SCRIPTDIR=%~dp0"
if "%SCRIPTDIR:~-1%"=="\" set "SCRIPTDIR=%SCRIPTDIR:~0,-1%"

set "INSTALL_DEST=%SCRIPTDIR%\lizmap"
set "INSTALL_SOURCE=%SCRIPTDIR%"

:: Ensure install directory exists
if not exist "%INSTALL_DEST%" mkdir "%INSTALL_DEST%"

:: -------------------------------
:: Load environment variables from env.default
:: -------------------------------
for /f "usebackq tokens=1,2 delims==" %%A in ("%INSTALL_SOURCE%\env.default") do (
    set "%%A=%%B"
)

:: -------------------------------
:: Create directories (mirrors _makedirs)
:: -------------------------------
for %%D in (
    plugins
    processing
    wps-data
    www
    var\log\nginx
    var\nginx-cache
    var\lizmap-theme-config
    var\lizmap-db
    var\lizmap-config
    var\lizmap-log
    var\lizmap-modules
    var\lizmap-my-packages
) do (
    if not exist "%INSTALL_DEST%\%%D" mkdir "%INSTALL_DEST%\%%D"
)

:: -------------------------------
:: Create .env file (mirrors _makenv)
:: -------------------------------
(
echo LIZMAP_PROJECTS=%LIZMAP_PROJECTS%
echo LIZMAP_DIR=%LIZMAP_DIR%
echo LIZMAP_UID=%LIZMAP_UID%
echo LIZMAP_GID=%LIZMAP_GID%
echo LIZMAP_VERSION_TAG=%LIZMAP_VERSION_TAG%
echo QGIS_VERSION_TAG=%QGIS_VERSION_TAG%
echo POSTGIS_VERSION=%POSTGIS_VERSION%
echo POSTGRES_PASSWORD=%POSTGRES_PASSWORD%
echo POSTGRES_LIZMAP_DB=%POSTGRES_LIZMAP_DB%
echo POSTGRES_LIZMAP_USER=%POSTGRES_LIZMAP_USER%
echo POSTGRES_LIZMAP_PASSWORD=%POSTGRES_LIZMAP_PASSWORD%
echo QGIS_MAP_WORKERS=%QGIS_MAP_WORKERS%
echo WPS_NUM_WORKERS=%WPS_NUM_WORKERS%
echo LIZMAP_PORT=%LIZMAP_PORT%
echo OWS_PORT=%OWS_PORT%
echo WPS_PORT=%WPS_PORT%
echo POSTGIS_PORT=%POSTGIS_PORT%
echo POSTGIS_ALIAS=%POSTGIS_ALIAS%
) > "%INSTALL_DEST%\.env"

:: -------------------------------
:: Copy lizmap.dir content
:: -------------------------------
xcopy "%INSTALL_SOURCE%\lizmap.dir\*" "%INSTALL_DEST%\" /E /I /Y

:: -------------------------------
:: Create pg_service.conf (mirrors _makepgservice)
:: -------------------------------
if not exist "%INSTALL_DEST%\etc" mkdir "%INSTALL_DEST%\etc"
(
echo [lizmap_local]
echo host=%POSTGIS_ALIAS%
echo port=5432
echo dbname=%POSTGRES_LIZMAP_DB%
echo user=%POSTGRES_LIZMAP_USER%
echo password=%POSTGRES_LIZMAP_PASSWORD%
echo.
echo [postgis1]
echo host=%POSTGIS_ALIAS%
echo port=5432
echo dbname=%POSTGRES_LIZMAP_DB%
echo user=%POSTGRES_LIZMAP_USER%
echo password=%POSTGRES_LIZMAP_PASSWORD%
) > "%INSTALL_DEST%\etc\pg_service.conf"

:: -------------------------------
:: Create lizmap_local.ini.php (mirrors _makelizmapprofiles)
:: -------------------------------
if not exist "%INSTALL_DEST%\etc\profiles.d" mkdir "%INSTALL_DEST%\etc\profiles.d"
(
echo [jdb:jauth]
echo driver=pgsql
echo host=%POSTGIS_ALIAS%
echo port=5432
echo database=%POSTGRES_LIZMAP_DB%
echo user=%POSTGRES_LIZMAP_USER%
echo password="%POSTGRES_LIZMAP_PASSWORD%"
echo search_path=lizmap,public
) > "%INSTALL_DEST%\etc\profiles.d\lizmap_local.ini.php"

:: -------------------------------
:: Plugin installation placeholder
:: -------------------------------
echo [INFO] Please install Lizmap plugin manually or via container script: install-lizmap-plugin.sh

echo.
echo Setup finished. Files created in %INSTALL_DEST%
endlocal
