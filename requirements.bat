@echo off
TITLE Install WinGet, VC++ Redistributable, CMake, and Visual Studio 2022

:: Check for Administrator privileges
NET SESSION >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [-] Error: Please right-click this batch file and select "Run as administrator".
    pause
    exit /b 1
)

echo [+] Bootstrapping and installing WinGet using Asheroto's installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm asheroto.com/winget | iex"

echo [+] Installing Microsoft Visual C++ Redistributable, CMake, and Visual Studio 2022 via WinGet...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); Write-Host 'Installing Microsoft Visual C++ Redistributable...'; winget install --id Microsoft.VCRedist.2015+.x64 --exact --accept-source-agreements --accept-package-agreements; Write-Host 'Installing CMake...'; winget install --id Kitware.CMake --exact --accept-source-agreements --accept-package-agreements; Write-Host 'Installing Visual Studio 2022 Community (This will take a few minutes)...'; winget install --id Microsoft.VisualStudio.2022.Community --exact --silent --accept-source-agreements --accept-package-agreements --override '--quiet --wait --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended'"

if %errorLevel% EQU 0 (
    echo [+] Success! WinGet, VC++ Redistributable, CMake, and Visual Studio 2022 have been installed successfully.
) else (
    echo [!] Installation completed with exit code %errorLevel%. A system restart may be required.
)

pause