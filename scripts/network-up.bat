@echo off
setlocal enabledelayedexpansion

REM Network startup script for Hyperledger Fabric Immutable Database (Windows)

set CHANNEL_NAME=mychannel
set DELAY=3

if "%1"=="-h" goto :help
if "%1"=="--help" goto :help
if "%1"=="-c" set CHANNEL_NAME=%2 & shift & shift & goto :parse_args
if "%1"=="--channel" set CHANNEL_NAME=%2 & shift & shift & goto :parse_args
if "%1"=="-d" set DELAY=%2 & shift & shift & goto :parse_args
if "%1"=="--delay" set DELAY=%2 & shift & shift & goto :parse_args

:parse_args
if not "%1"=="" goto :parse_args

echo [INFO] Starting Hyperledger Fabric network...

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Check if Docker Compose is available
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Compose is not installed. Please install Docker Compose and try again.
    exit /b 1
)

echo [INFO] Cleaning up existing containers and volumes...
docker-compose down --volumes --remove-orphans >nul 2>&1
docker system prune -f >nul 2>&1

echo [INFO] Removing existing crypto material...
if exist network\organizations rmdir /s /q network\organizations >nul 2>&1
if exist network\channel-artifacts rmdir /s /q network\channel-artifacts >nul 2>&1

mkdir network\organizations >nul 2>&1
mkdir network\channel-artifacts >nul 2>&1

echo [INFO] Generating crypto material...
cd network

docker run --rm -v %cd%:/work -w /work hyperledger/fabric-tools:latest cryptogen generate --config=crypto-config.yaml

echo [INFO] Generating genesis block and channel configuration...
set FABRIC_CFG_PATH=%cd%/configtx

docker run --rm -v %cd%:/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputBlock ./channel-artifacts/genesis.block -channelID system-channel
docker run --rm -v %cd%:/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputCreateChannelTx ./channel-artifacts/%CHANNEL_NAME%.tx -channelID %CHANNEL_NAME%
docker run --rm -v %cd%:/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID %CHANNEL_NAME% -asOrg Org1MSP
docker run --rm -v %cd%:/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID %CHANNEL_NAME% -asOrg Org2MSP

cd ..

echo [INFO] Starting Docker containers...
docker-compose up -d

echo [INFO] Waiting for containers to start...
timeout /t %DELAY% /nobreak >nul

echo [INFO] Network containers started successfully
echo [INFO] Creating channel '%CHANNEL_NAME%'...

docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer channel create -o orderer.example.com:7050 -c %CHANNEL_NAME% -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/%CHANNEL_NAME%.tx --outputBlock /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/%CHANNEL_NAME%.block --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

timeout /t %DELAY% /nobreak >nul

echo [INFO] Joining Org1 peer to channel...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/%CHANNEL_NAME%.block"

timeout /t %DELAY% /nobreak >nul

echo [INFO] Joining Org2 peer to channel...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org2MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp && export CORE_PEER_ADDRESS=peer0.org2.example.com:9051 && peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/%CHANNEL_NAME%.block"

timeout /t %DELAY% /nobreak >nul

echo [INFO] Network setup completed successfully!
echo [INFO] Channel '%CHANNEL_NAME%' created and peers joined
echo.
echo [INFO] Next steps:
echo [INFO] 1. Deploy chaincode: scripts\deploy-chaincode.bat
echo [INFO] 2. Start the API server: cd application ^&^& npm install ^&^& npm run dev
echo.
echo [INFO] Network status: docker-compose ps
echo [INFO] View logs: docker-compose logs -f [service_name]

goto :eof

:help
echo Usage: network-up.bat [OPTIONS]
echo.
echo Start the Hyperledger Fabric network for immutable database
echo.
echo OPTIONS:
echo   -h, --help     Show this help message
echo   -c, --channel  Channel name (default: mychannel)
echo   -d, --delay    Delay in seconds between operations (default: 3)
echo.
exit /b 0
