@echo off
setlocal ENABLEDELAYEDEXPANSION

:: -------------------------------
:: Define variables
:: -------------------------------
set "SCRIPTDIR=%~dp0"
set "INSTALL_DEST=%SCRIPTDIR%lizmap"
set "INSTALL_SOURCE=%SCRIPTDIR%"
set "QGIS_VERSION_TAG=ltr-rc"

:: -------------------------------
:: Ensure install directory exists
:: -------------------------------
if not exist "%INSTALL_DEST%" mkdir "%INSTALL_DEST%"

:: -------------------------------
:: Fix line endings of configure.sh
:: -------------------------------
echo Converting configure.sh to LF line endings...
powershell -Command "(Get-Content '%SCRIPTDIR%configure.sh') -replace \"`r`n\",\"`n\" | Set-Content -NoNewline '%SCRIPTDIR%configure.sh'"

:: -------------------------------
:: Run Docker container
:: -------------------------------
docker run -it -u 1000:1000 --rm ^
  -e INSTALL_SOURCE=/install ^
  -e INSTALL_DEST=/lizmap ^
  -e "LIZMAP_DIR=C:\GitHub\lizmap-docker-compose\lizmap" ^
  -e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins ^
  -v "C:\GitHub\lizmap-docker-compose:/install" ^
  -v "C:\GitHub\lizmap-docker-compose\lizmap:/lizmap" ^
  -v "C:\GitHub\lizmap-docker-compose:/src" ^
  3liz/qgis-map-server:ltr-rc sh /src/configure.sh _configure


:: -------------------------------
:: Done
:: -------------------------------
echo.
echo Setup finished, you can now run:
echo docker-compose --env-file=.env.windows up
endlocal
