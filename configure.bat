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
:: Convert Windows paths to Docker-friendly Unix paths
:: ===============================
call :toUnixPath "%INSTALL_SOURCE%" INSTALL_SOURCE_UNIX
call :toUnixPath "%INSTALL_DEST%" INSTALL_DEST_UNIX
call :toUnixPath "%SCRIPTDIR%" SCRIPTDIR_UNIX

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

echo setup finished, you can run 'docker-compose --env-file=.env.windows up'
endlocal
goto :eof


:toUnixPath
set "p=%~1"
:: Replace backslashes with forward slashes
set "p=%p:\=/%"
:: Extract drive letter
set "drive=%p:~0,1%"
:: Remove drive letter and colon
set "p=%p:~2%"
:: Lowercase drive letter (Docker style)
for %%d in (%drive%) do set "drive=%%d"
set "drive=%drive:A=a%"
set "drive=%drive:B=b%"
set "drive=%drive:C=c%"
set "drive=%drive:D=d%"
set "drive=%drive:E=e%"
set "drive=%drive:F=f%"
:: Combine into /drive/path form
set "%~2=/%drive%%p%"
goto :eof
