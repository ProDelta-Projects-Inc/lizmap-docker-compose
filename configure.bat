@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ===============================
REM Defaults
REM ===============================
set "SCRIPTDIR=%~dp0"
set "INSTALL_DEST=%SCRIPTDIR%lizmap"
set "INSTALL_SOURCE=%SCRIPTDIR%"
if "%QGIS_VERSION_TAG%"=="" set "QGIS_VERSION_TAG=ltr-rc"

REM ===============================
REM Helpers
REM ===============================
:trim_trailing_bs
REM %1 = var name
for /f "tokens=1,* delims==" %%A in ('set %1') do set "TMP=%%B"
:trim_loop
if "%TMP:~-1%"=="\" set "TMP=%TMP:~0,-1%" & goto trim_loop
if "%TMP:~-1%"=="/" set "TMP=%TMP:~0,-1%" & goto trim_loop
set "%~1=%TMP%"
goto :eof

:toUnixPath
REM Convert "C:\Users\Me\dir" -> "/c/Users/Me/dir"
set "p=%~1"
set "p=%p:\=/%"
set "drive=%p:~0,1%"
set "p=%p:~2%"
for %%d in (%drive%) do set "drive=%%d"
set "drive=%drive:A=a%"
set "drive=%drive:B=b%"
set "drive=%drive:C=c%"
set "drive=%drive:D=d%"
set "drive=%drive:E=e%"
set "drive=%drive:F=f%"
set "%~2=/%drive%%p%"
goto :eof

REM ===============================
REM Normalize paths (remove trailing \ or /)
REM ===============================
call :trim_trailing_bs SCRIPTDIR
call :trim_trailing_bs INSTALL_SOURCE
call :trim_trailing_bs INSTALL_DEST

REM Ensure install dest exists
if not exist "%INSTALL_DEST%" mkdir "%INSTALL_DEST%"

REM Verify configure.sh exists beside this .bat
if not exist "%SCRIPTDIR%\configure.sh" (
  echo [ERROR] "%SCRIPTDIR%\configure.sh" not found. Make sure configure.bat and configure.sh are in the same folder.
  exit /b 1
)

REM Build Unix fallback paths
call :toUnixPath "%INSTALL_SOURCE%" INSTALL_SOURCE_UNIX
call :toUnixPath "%INSTALL_DEST%"   INSTALL_DEST_UNIX
call :toUnixPath "%SCRIPTDIR%"      SCRIPTDIR_UNIX

echo === Running Docker (Windows path mounts) ===
echo Host mounts:
echo   INSTALL_SOURCE = "%INSTALL_SOURCE%"
echo   INSTALL_DEST   = "%INSTALL_DEST%"
echo   SCRIPTDIR      = "%SCRIPTDIR%"
echo.

docker run -it -u 1000:1000 --rm ^
  -e INSTALL_SOURCE=/install ^
  -e INSTALL_DEST=/lizmap ^
  -e "LIZMAP_DIR=%INSTALL_DEST%" ^
  -e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins ^
  -v "%INSTALL_SOURCE%":/install ^
  -v "%INSTALL_DEST%":/lizmap ^
  -v "%SCRIPTDIR%":/src ^
  --entrypoint /src/configure.sh ^
  3liz/qgis-map-server:%QGIS_VERSION_TAG% _configure

if %ERRORLEVEL% EQU 0 goto done

echo.
echo === First attempt failed (ERRORLEVEL %ERRORLEVEL%). Retrying with /c/ style mounts ===
echo Fallback mounts:
echo   INSTALL_SOURCE = %INSTALL_SOURCE_UNIX%
echo   INSTALL_DEST   = %INSTALL_DEST_UNIX%
echo   SCRIPTDIR      = %SCRIPTDIR_UNIX%
echo.

docker run -it -u 1000:1000 --rm ^
  -e INSTALL_SOURCE=/install ^
  -e INSTALL_DEST=/lizmap ^
  -e "LIZMAP_DIR=%INSTALL_DEST%" ^
  -e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins ^
  -v %INSTALL_SOURCE_UNIX%:/install ^
  -v %INSTALL_DEST_UNIX%:/lizmap ^
  -v %SCRIPTDIR_UNIX%:/src ^
  --entrypoint /src/configure.sh ^
  3liz/qgis-map-server:%QGIS_VERSION_TAG% _configure

if %ERRORLEVEL% NEQ 0 (
  echo.
  echo [ERROR] Both volume styles failed. Common causes:
  echo   - Path contains a trailing backslash (now handled).
  echo   - Docker Desktop not allowed to access this drive (check Settings ^> Resources ^> File sharing).
  echo   - File permissions or antivirus blocking mount.
  echo   - configure.sh not in the same folder as configure.bat.
  exit /b %ERRORLEVEL%
)

:done
echo.
echo setup finished, you can run "docker-compose --env-file=.env.windows up"
endlocal
