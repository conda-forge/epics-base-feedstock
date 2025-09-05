if %ARCH%==32 (
    set EPICS_HOST_ARCH=win32-x86
) else if %ARCH%==64 (
    set EPICS_HOST_ARCH=windows-x64
)

set EPICS_BASE=%PREFIX%\epics

REM SCRIPTS causes failure of GNU make
set SCRIPTS=

REM set up build
copy %RECIPE_DIR%\pre-build.py %SRC_DIR%
python pre-build.py

echo Building at %CD%
make -j %CPU_COUNT%
if errorlevel 1 (
    echo MAKE FAILED
    exit /b 1
)

mkdir "%PREFIX%\Library\bin" >nul
mkdir "%PREFIX%\Library\lib" >nul

copy "%EPICS_BASE%\bin\%EPICS_HOST_ARCH%\*.dll" "%PREFIX%\Library\bin\" >nul
copy "%EPICS_BASE%\lib\%EPICS_HOST_ARCH%\*.lib" "%PREFIX%\Library\lib\" >nul
