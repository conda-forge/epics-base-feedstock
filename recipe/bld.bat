if %ARCH%==32 (
    set EPICS_HOST_ARCH=win32-x86
) else if %ARCH%==64 (
    set EPICS_HOST_ARCH=windows-x64
)

set EPICS_BASE=%PREFIX%\epics
echo INSTALL_LOCATION = %EPICS_BASE:\=/%> configure\CONFIG_SITE.local

REM SCRIPTS causes failure of GNU make
set SCRIPTS=

echo Building at %CD%
make -j %CPU_COUNT%
if errorlevel 1 (
    echo MAKE FAILED
    exit /b 1
)

xcopy "%EPICS_BASE%\bin\%EPICS_HOST_ARCH%\*.dll" "%PREFIX%\Library\bin\" /Y
xcopy "%EPICS_BASE%\lib\%EPICS_HOST_ARCH%\*.lib" "%PREFIX%\Library\lib\" /Y

if not exist "%PREFIX%\etc\conda\activate.d" mkdir "%PREFIX%\etc\conda\activate.d"
if not exist "%PREFIX%\etc\conda\deactivate.d" mkdir "%PREFIX%\etc\conda\deactivate.d"

echo @echo off> "%PREFIX%\etc\conda\activate.d\epics-base_activate.bat"
echo set "EPICS_BASE=%%CONDA_PREFIX%%\epics">> "%PREFIX%\etc\conda\activate.d\epics-base_activate.bat"
echo set "EPICS_HOST_ARCH=%EPICS_HOST_ARCH%">> "%PREFIX%\etc\conda\activate.d\epics-base_activate.bat"
echo set "EPICS_BASE_VERSION=%PKG_VERSION%">> "%PREFIX%\etc\conda\activate.d\epics-base_activate.bat"
echo set "EPICS_BASE_HOST_BIN=%%CONDA_PREFIX%%\epics\bin\%EPICS_HOST_ARCH%">> "%PREFIX%\etc\conda\activate.d\epics-base_activate.bat"
echo set "PATH=%%EPICS_BASE_HOST_BIN%%;%%PATH%%">> "%PREFIX%\etc\conda\activate.d\epics-base_activate.bat"

echo @echo off> "%PREFIX%\etc\conda\deactivate.d\epics-base_deactivate.bat"
echo set "PATH=%%PATH:%%EPICS_BASE_HOST_BIN%%;=%%">> "%PREFIX%\etc\conda\deactivate.d\epics-base_deactivate.bat"
echo set "EPICS_BASE=">> "%PREFIX%\etc\conda\deactivate.d\epics-base_deactivate.bat"
echo set "EPICS_HOST_ARCH=">> "%PREFIX%\etc\conda\deactivate.d\epics-base_deactivate.bat"
echo set "EPICS_BASE_HOST_BIN=">> "%PREFIX%\etc\conda\deactivate.d\epics-base_deactivate.bat"
echo set "EPICS_BASE_VERSION=">> "%PREFIX%\etc\conda\deactivate.d\epics-base_deactivate.bat"
