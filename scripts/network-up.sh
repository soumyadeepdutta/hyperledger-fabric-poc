#!/bin/bash

# Network startup script for Hyperledger Fabric Immutable Database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_help() {
    echo "Usage: network-up.sh [OPTIONS]"
    echo ""
    echo "Start the Hyperledger Fabric network for immutable database"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --channel  Channel name (default: mychannel)"
    echo "  -d, --delay    Delay in seconds between operations (default: 3)"
    echo ""
}

CHANNEL_NAME="mychannel"
DELAY=3

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_help
            exit 0
            ;;
        -c|--channel)
            CHANNEL_NAME="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option $1"
            print_help
            exit 1
            ;;
    esac
done

function print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose > /dev/null 2>&1; then
    print_error "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

print_status "Starting Hyperledger Fabric network..."

# Clean up any existing containers and volumes
print_status "Cleaning up existing containers and volumes..."
docker-compose down --volumes --remove-orphans 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Remove existing crypto material and channel artifacts
print_status "Removing existing crypto material..."
rm -rf network/organizations 2>/dev/null || true
rm -rf network/channel-artifacts 2>/dev/null || true

# Create directories
mkdir -p network/organizations
mkdir -p network/channel-artifacts

# Generate crypto material
print_status "Generating crypto material..."
cd network

# Generate certificates
if ! command -v cryptogen > /dev/null 2>&1; then
    print_warning "cryptogen not found in PATH, using Docker container..."
    docker run --rm -v $(pwd):/work -w /work hyperledger/fabric-tools:latest cryptogen generate --config=crypto-config.yaml
else
    cryptogen generate --config=crypto-config.yaml
fi

# Generate genesis block and channel transaction
print_status "Generating genesis block and channel configuration..."
export FABRIC_CFG_PATH=$(pwd)/configtx

if ! command -v configtxgen > /dev/null 2>&1; then
    print_warning "configtxgen not found in PATH, using Docker container..."
    docker run --rm -v $(pwd):/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputBlock ./channel-artifacts/genesis.block -channelID system-channel
    docker run --rm -v $(pwd):/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
    docker run --rm -v $(pwd):/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
    docker run --rm -v $(pwd):/work -w /work -e FABRIC_CFG_PATH=/work/configtx hyperledger/fabric-tools:latest configtxgen -profile TwoOrgsApplicationGenesis -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
else
    configtxgen -profile TwoOrgsApplicationGenesis -outputBlock ./channel-artifacts/genesis.block -channelID system-channel
    configtxgen -profile TwoOrgsApplicationGenesis -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
    configtxgen -profile TwoOrgsApplicationGenesis -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
    configtxgen -profile TwoOrgsApplicationGenesis -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
fi

cd ..

# Start the network
print_status "Starting Docker containers..."
docker-compose up -d

# Wait for containers to be ready
print_status "Waiting for containers to start..."
sleep $DELAY

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
    print_error "Failed to start containers. Check Docker logs for details."
    docker-compose logs
    exit 1
fi

print_status "Network containers started successfully"

# Create channel
print_status "Creating channel '$CHANNEL_NAME'..."
docker-compose exec cli bash -c "
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
    
    peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.tx --outputBlock /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
"

sleep $DELAY

# Join Org1 peer to channel
print_status "Joining Org1 peer to channel..."
docker-compose exec cli bash -c "
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
    
    peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block
"

sleep $DELAY

# Join Org2 peer to channel
print_status "Joining Org2 peer to channel..."
docker-compose exec cli bash -c "
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=peer0.org2.example.com:9051
    
    peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/${CHANNEL_NAME}.block
"

sleep $DELAY

# Update anchor peers
print_status "Updating anchor peers..."
docker-compose exec cli bash -c "
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
    
    peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/Org1MSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
"

docker-compose exec cli bash -c "
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=peer0.org2.example.com:9051
    
    peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/Org2MSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
"

print_status "Network setup completed successfully!"
print_status "Channel '$CHANNEL_NAME' created and peers joined"
print_status ""
print_status "Next steps:"
print_status "1. Deploy chaincode: ./scripts/deploy-chaincode.sh"
print_status "2. Start the API server: cd application && npm install && npm run dev"
print_status ""
print_status "Network status: docker-compose ps"
print_status "View logs: docker-compose logs -f [service_name]"
