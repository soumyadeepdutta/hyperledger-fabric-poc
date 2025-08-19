@echo off
setlocal enabledelayedexpansion

REM Chaincode deployment script for Hyperledger Fabric Immutable Database (Windows)

set CHANNEL_NAME=mychannel
set CHAINCODE_NAME=immutable-records
set CHAINCODE_VERSION=1.0
set SEQUENCE=1

if "%1"=="-h" goto :help
if "%1"=="--help" goto :help

:parse_args
if "%1"=="-c" set CHANNEL_NAME=%2 & shift & shift & goto :parse_args
if "%1"=="--channel" set CHANNEL_NAME=%2 & shift & shift & goto :parse_args
if "%1"=="-n" set CHAINCODE_NAME=%2 & shift & shift & goto :parse_args
if "%1"=="--name" set CHAINCODE_NAME=%2 & shift & shift & goto :parse_args
if "%1"=="-v" set CHAINCODE_VERSION=%2 & shift & shift & goto :parse_args
if "%1"=="--version" set CHAINCODE_VERSION=%2 & shift & shift & goto :parse_args
if "%1"=="-s" set SEQUENCE=%2 & shift & shift & goto :parse_args
if "%1"=="--sequence" set SEQUENCE=%2 & shift & shift & goto :parse_args
if not "%1"=="" shift & goto :parse_args

echo [INFO] Deploying chaincode '%CHAINCODE_NAME%' version %CHAINCODE_VERSION%...

REM Check if network is running
docker-compose ps | findstr "Up" >nul
if errorlevel 1 (
    echo [ERROR] Network is not running. Please start the network first with scripts\network-up.bat
    exit /b 1
)

echo [INFO] Building chaincode...
cd chaincode
call npm install
call npm run build
cd ..

echo [INFO] Packaging chaincode...
docker-compose exec -T cli bash -c "cd /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode && peer lifecycle chaincode package %CHAINCODE_NAME%.tar.gz --path . --lang node --label %CHAINCODE_NAME%_%CHAINCODE_VERSION%"

echo [INFO] Installing chaincode on Org1 peer...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/%CHAINCODE_NAME%.tar.gz"

echo [INFO] Installing chaincode on Org2 peer...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org2MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp && export CORE_PEER_ADDRESS=peer0.org2.example.com:9051 && peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/%CHAINCODE_NAME%.tar.gz"

echo [INFO] Querying installed chaincodes...
for /f "tokens=*" %%i in ('docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer lifecycle chaincode queryinstalled --output json" ^| jq -r ".installed_chaincodes[] | select(.label==\"%CHAINCODE_NAME%_%CHAINCODE_VERSION%\") | .package_id"') do set PACKAGE_ID=%%i

if "%PACKAGE_ID%"=="" (
    echo [ERROR] Failed to get package ID for chaincode
    exit /b 1
)

echo [INFO] Package ID: %PACKAGE_ID%

echo [INFO] Approving chaincode for Org1...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --channelID %CHANNEL_NAME% --name %CHAINCODE_NAME% --version %CHAINCODE_VERSION% --package-id %PACKAGE_ID% --sequence %SEQUENCE% --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

echo [INFO] Approving chaincode for Org2...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org2MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp && export CORE_PEER_ADDRESS=peer0.org2.example.com:9051 && peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --channelID %CHANNEL_NAME% --name %CHAINCODE_NAME% --version %CHAINCODE_VERSION% --package-id %PACKAGE_ID% --sequence %SEQUENCE% --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

echo [INFO] Checking commit readiness...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer lifecycle chaincode checkcommitreadiness --channelID %CHANNEL_NAME% --name %CHAINCODE_NAME% --version %CHAINCODE_VERSION% --sequence %SEQUENCE% --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --output json"

echo [INFO] Committing chaincode...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer lifecycle chaincode commit -o orderer.example.com:7050 --channelID %CHANNEL_NAME% --name %CHAINCODE_NAME% --version %CHAINCODE_VERSION% --sequence %SEQUENCE% --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

echo [INFO] Querying committed chaincodes...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer lifecycle chaincode querycommitted --channelID %CHANNEL_NAME% --name %CHAINCODE_NAME% --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

echo [INFO] Initializing ledger with sample data...
docker-compose exec -T cli bash -c "export CORE_PEER_TLS_ENABLED=true && export CORE_PEER_LOCALMSPID=Org1MSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && export CORE_PEER_ADDRESS=peer0.org1.example.com:7051 && peer chaincode invoke -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C %CHANNEL_NAME% -n %CHAINCODE_NAME% --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c \"{\"function\":\"InitLedger\",\"Args\":[]}\""

echo [INFO] Chaincode deployment completed successfully!
echo.
echo [INFO] Test the chaincode:
echo [INFO] 1. Query all records:
echo [INFO]    docker-compose exec cli peer chaincode query -C %CHANNEL_NAME% -n %CHAINCODE_NAME% -c "{\"function\":\"GetAllRecords\",\"Args\":[]}"
echo.
echo [INFO] Next step: Start the API server
echo [INFO]   cd application ^&^& npm install ^&^& npm run dev

goto :eof

:help
echo Usage: deploy-chaincode.bat [OPTIONS]
echo.
echo Deploy chaincode to the Hyperledger Fabric network
echo.
echo OPTIONS:
echo   -h, --help      Show this help message
echo   -c, --channel   Channel name (default: mychannel)
echo   -n, --name      Chaincode name (default: immutable-records)
echo   -v, --version   Chaincode version (default: 1.0)
echo   -s, --sequence  Chaincode sequence (default: 1)
echo.
exit /b 0
