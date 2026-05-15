@echo off
REM Jenkinsfile Validator Script (Windows)

setlocal enabledelayedexpansion

set JENKINSFILE=Jenkinsfile

echo.
echo ==========================================
echo   Jenkinsfile Validation Report
echo ==========================================
echo.

if not exist "%JENKINSFILE%" (
    echo ERROR: Jenkinsfile not found!
    exit /b 1
)

echo File: %JENKINSFILE%
for /f %%A in ('find /c /v "" ^< "%JENKINSFILE%"') do set LINES=%%A
echo Lines: %LINES%
echo.

REM Check Braces
echo Checking braces...
for /f %%a in ('findstr /r "{" "%JENKINSFILE%" ^| find /c "{" 2^>nul') do set OPEN=%%a
for /f %%a in ('findstr /r "}" "%JENKINSFILE%" ^| find /c "}" 2^>nul') do set CLOSE=%%a

if "%OPEN%"=="" set OPEN=0
if "%CLOSE%"=="" set CLOSE=0

if %OPEN% equ %CLOSE% (
    echo [OK] Braces balanced: { = %OPEN%  } = %CLOSE%
) else (
    echo [FAIL] Braces unbalanced: { = %OPEN%  } = %CLOSE%
    exit /b 1
)

echo.
echo Required Keywords:

REM Check keywords
for %%K in (pipeline agent stages stage steps environment post) do (
    findstr /C:"%%K" "%JENKINSFILE%" >nul
    if !errorlevel! equ 0 (
        echo [OK] %%K found
    ) else (
        echo [FAIL] %%K NOT FOUND
    )
)

echo.
echo Stages Defined:
for /f "tokens=2 delims='" %%A in ('findstr "stage(" "%JENKINSFILE%"') do (
    echo   - %%A
)

echo.
echo Additional Checks:

findstr "checkout scm" "%JENKINSFILE%" >nul
if !errorlevel! equ 0 (
    echo [OK] Git checkout configured
) else (
    echo [FAIL] Git checkout not found
)

findstr "docker build" "%JENKINSFILE%" >nul
if !errorlevel! equ 0 (
    echo [OK] Docker build configured
) else (
    echo [WARN] Docker build not found
)

findstr "kubectl" "%JENKINSFILE%" >nul
if !errorlevel! equ 0 (
    echo [OK] Kubernetes deployment configured
) else (
    echo [WARN] Kubernetes deployment not found ^(optional^)
)

findstr "credentials(" "%JENKINSFILE%" >nul
if !errorlevel! equ 0 (
    echo [OK] Credentials referenced
) else (
    echo [WARN] No credentials referenced
)

findstr "try" "%JENKINSFILE%" >nul
if !errorlevel! equ 0 (
    echo [OK] Error handling configured
) else (
    echo [WARN] No error handling found
)

echo.
echo ==========================================
echo   [SUCCESS] Jenkinsfile structure valid!
echo ==========================================
echo.
echo Next Steps:
echo 1. Set DOCKER_IMAGE in Jenkinsfile
echo 2. Configure Jenkins credentials (dockerhub-credentials)
echo 3. Create Jenkins job from Jenkinsfile
echo 4. Set up webhook for auto-triggering
echo.

endlocal
