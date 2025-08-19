@echo off
setlocal enabledelayedexpansion

REM Network shutdown script for Hyperledger Fabric Immutable Database (Windows)

set REMOVE_VOLUMES=false
set REMOVE_IMAGES=false
set REMOVE_ALL=false

if "%1"=="-h" goto :help
if "%1"=="--help" goto :help

:parse_args
if "%1"=="-v" set REMOVE_VOLUMES=true & shift & goto :parse_args
if "%1"=="--volumes" set REMOVE_VOLUMES=true & shift & goto :parse_args
if "%1"=="-i" set REMOVE_IMAGES=true & shift & goto :parse_args
if "%1"=="--images" set REMOVE_IMAGES=true & shift & goto :parse_args
if "%1"=="-a" set REMOVE_ALL=true & set REMOVE_VOLUMES=true & set REMOVE_IMAGES=true & shift & goto :parse_args
if "%1"=="--all" set REMOVE_ALL=true & set REMOVE_VOLUMES=true & set REMOVE_IMAGES=true & shift & goto :parse_args
if not "%1"=="" shift & goto :parse_args

echo [INFO] Stopping Hyperledger Fabric network...

if "%REMOVE_VOLUMES%"=="true" (
    echo [INFO] Stopping containers and removing volumes...
    docker-compose down --volumes --remove-orphans
) else (
    echo [INFO] Stopping containers...
    docker-compose down --remove-orphans
)

if "%REMOVE_IMAGES%"=="true" (
    echo [INFO] Removing Docker images...
    
    REM Get list of Hyperledger Fabric images
    for /f "tokens=*" %%i in ('docker images --format "{{.Repository}}:{{.Tag}}" ^| findstr hyperledger/fabric') do (
        echo Removing image: %%i
        docker rmi %%i >nul 2>&1 || echo [WARN] Could not remove image %%i
    )
)

if "%REMOVE_ALL%"=="true" (
    echo [INFO] Removing crypto material and channel artifacts...
    if exist network\organizations rmdir /s /q network\organizations >nul 2>&1
    if exist network\channel-artifacts rmdir /s /q network\channel-artifacts >nul 2>&1
    if exist chaincode\node_modules rmdir /s /q chaincode\node_modules >nul 2>&1
    if exist chaincode\dist rmdir /s /q chaincode\dist >nul 2>&1
    if exist application\node_modules rmdir /s /q application\node_modules >nul 2>&1
    if exist application\dist rmdir /s /q application\dist >nul 2>&1
)

echo [INFO] Cleaning up Docker system...
docker system prune -f >nul 2>&1

echo [INFO] Removing unused Docker networks...
docker network prune -f >nul 2>&1

echo [INFO] Network cleanup completed!

if "%REMOVE_ALL%"=="true" (
    echo [INFO] All network data, crypto material, and build artifacts have been removed
    echo [INFO] To restart the network, run:
    echo [INFO]   scripts\network-up.bat
    echo [INFO]   scripts\deploy-chaincode.bat
) else if "%REMOVE_VOLUMES%"=="true" (
    echo [INFO] All containers and volumes have been removed
    echo [INFO] Crypto material is preserved
    echo [INFO] To restart the network, run:
    echo [INFO]   docker-compose up -d
) else (
    echo [INFO] Containers stopped, volumes and crypto material preserved
    echo [INFO] To restart the network, run:
    echo [INFO]   docker-compose up -d
)

echo.
echo [INFO] Container status: docker-compose ps
echo [INFO] Docker images: docker images ^| findstr hyperledger
echo [INFO] Docker volumes: docker volume ls

goto :eof

:help
echo Usage: network-down.bat [OPTIONS]
echo.
echo Stop and clean up the Hyperledger Fabric network
echo.
echo OPTIONS:
echo   -h, --help     Show this help message
echo   -v, --volumes  Remove all volumes (including blockchain data)
echo   -i, --images   Remove Docker images as well
echo   -a, --all      Remove everything (volumes + images + crypto material)
echo.
exit /b 0
