@echo off
REM CI/CD Helper Scripts for Medicine Stock DevOps Project (Windows)

setlocal enabledelayedexpansion

REM Configuration
set DOCKER_IMAGE=%DOCKER_IMAGE:medicine-stock%
set DOCKER_TAG=%DOCKER_TAG:latest%
set KUBE_NAMESPACE=%KUBE_NAMESPACE:default%

REM Colors using Windows 10+ features
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set NC=[0m

:log_info
echo.
echo %GREEN%[INFO]%NC% %~1
exit /b 0

:log_warn
echo.
echo %YELLOW%[WARN]%NC% %~1
exit /b 0

:log_error
echo.
echo %RED%[ERROR]%NC% %~1
exit /b 0

REM Main command dispatch
if "%1"=="build" goto build_image
if "%1"=="test" goto run_tests
if "%1"=="test-image" goto test_image
if "%1"=="push" goto push_image
if "%1"=="deploy" goto deploy_k8s
if "%1"=="all" goto run_all
goto show_help

:build_image
echo Building Docker image: %DOCKER_IMAGE%:%DOCKER_TAG%
docker build -t %DOCKER_IMAGE%:%DOCKER_TAG% ^
             -t %DOCKER_IMAGE%:latest ^
             -f Dockerfile .
if errorlevel 1 (
    echo Build failed
    exit /b 1
)
echo Build completed successfully
goto end

:run_tests
echo Running unit tests...
cd app
python -m pytest test_app.py -v --tb=short
cd ..
echo Tests completed
goto end

:test_image
echo Testing Docker image...
for /f %%i in ('docker run -d -p 5001:5000 -e DB_PATH=/app/medicine.db %DOCKER_IMAGE%:%DOCKER_TAG%') do set CONTAINER_ID=%%i
timeout /t 3 /nobreak
curl -f http://localhost:5001/ > nul 2>&1
if errorlevel 1 (
    echo Container health check failed
    docker stop %CONTAINER_ID%
    docker rm %CONTAINER_ID%
    exit /b 1
)
echo Container health check passed
docker stop %CONTAINER_ID%
docker rm %CONTAINER_ID%
goto end

:push_image
echo Pushing image to registry...
docker push %DOCKER_IMAGE%:%DOCKER_TAG%
docker push %DOCKER_IMAGE%:latest
if errorlevel 1 (
    echo Push failed
    exit /b 1
)
echo Image pushed successfully
goto end

:deploy_k8s
echo Deploying to Kubernetes namespace: %KUBE_NAMESPACE%
kubectl set image deployment/medicine-stock ^
        medicine-stock=%DOCKER_IMAGE%:%DOCKER_TAG% ^
        -n %KUBE_NAMESPACE% ^
        || ^
kubectl apply -f k8s/deployment.yaml -n %KUBE_NAMESPACE%
kubectl apply -f k8s/service.yaml -n %KUBE_NAMESPACE%
kubectl rollout status deployment/medicine-stock ^
        -n %KUBE_NAMESPACE% --timeout=5m
if errorlevel 1 (
    echo Deployment failed
    exit /b 1
)
echo Deployment completed
goto end

:run_all
call :run_tests
call :build_image
call :test_image
goto end

:show_help
echo.
echo Usage: ci-pipeline.bat [COMMAND]
echo.
echo Commands:
echo     build       - Build Docker image
echo     test        - Run unit tests
echo     test-image  - Test Docker image
echo     push        - Push image to registry
echo     deploy      - Deploy to Kubernetes
echo     all         - Run build, test, and build image
echo.
echo Environment Variables:
echo     DOCKER_IMAGE     - Docker image name (default: medicine-stock)
echo     DOCKER_TAG       - Docker tag (default: latest)
echo     KUBE_NAMESPACE   - Kubernetes namespace (default: default)
echo.

:end
endlocal
