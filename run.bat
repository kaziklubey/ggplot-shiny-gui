@echo off
setlocal EnableExtensions

rem Move to the folder that contains this run.bat
cd /d "%~dp0"

set "RSCRIPT="

rem 1. Try Rscript from PATH
for /f "delims=" %%F in ('where Rscript.exe 2^>nul') do (
    if not defined RSCRIPT set "RSCRIPT=%%F"
)

rem 2. Try standard R installation folder
if not defined RSCRIPT (
    for /f "delims=" %%D in ('dir /b /ad /o-n "%ProgramFiles%\R\R-*" 2^>nul') do (
        if not defined RSCRIPT (
            if exist "%ProgramFiles%\R\%%D\bin\Rscript.exe" (
                set "RSCRIPT=%ProgramFiles%\R\%%D\bin\Rscript.exe"
            )
        )
    )
)

if not defined RSCRIPT (
    echo.
    echo ERROR: Rscript.exe was not found.
    echo Please install R.
    echo https://cran.r-project.org/
    echo.
    pause
    exit /b 1
)

if not exist "run.R" (
    echo ERROR: run.R was not found.
    pause
    exit /b 1
)

if not exist "req.txt" (
    echo ERROR: req.txt was not found.
    pause
    exit /b 1
)

echo.
echo Using Rscript:
echo "%RSCRIPT%"
echo.
echo App folder:
echo "%CD%"
echo.

"%RSCRIPT%" "run.R" "%CD%"

echo.
pause