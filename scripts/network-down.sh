#!/bin/bash

# Network shutdown script for Hyperledger Fabric Immutable Database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_help() {
    echo "Usage: network-down.sh [OPTIONS]"
    echo ""
    echo "Stop and clean up the Hyperledger Fabric network"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --volumes  Remove all volumes (including blockchain data)"
    echo "  -i, --images   Remove Docker images as well"
    echo "  -a, --all      Remove everything (volumes + images + crypto material)"
    echo ""
}

REMOVE_VOLUMES=false
REMOVE_IMAGES=false
REMOVE_ALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_help
            exit 0
            ;;
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -i|--images)
            REMOVE_IMAGES=true
            shift
            ;;
        -a|--all)
            REMOVE_ALL=true
            REMOVE_VOLUMES=true
            REMOVE_IMAGES=true
            shift
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

# Use docker compose v2 if available, fallback to docker-compose v1
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

print_status "Stopping Hyperledger Fabric network..."

# Stop and remove containers
if [ "$REMOVE_VOLUMES" = true ]; then
    print_status "Stopping containers and removing volumes..."
    $DOCKER_COMPOSE down --volumes --remove-orphans
else
    print_status "Stopping containers..."
    $DOCKER_COMPOSE down --remove-orphans
fi

# Remove Docker images if requested
if [ "$REMOVE_IMAGES" = true ]; then
    print_status "Removing Docker images..."
    
    # Get list of images to remove
    IMAGES=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(hyperledger/fabric|hyperledger/fabric-tools|hyperledger/fabric-peer|hyperledger/fabric-orderer|hyperledger/fabric-ca)" | tr '\n' ' ')
    
    if [ -n "$IMAGES" ]; then
        docker rmi $IMAGES 2>/dev/null || print_warning "Some images could not be removed (may be in use)"
    else
        print_status "No Hyperledger Fabric images found to remove"
    fi
fi

# Remove crypto material and artifacts if requested
if [ "$REMOVE_ALL" = true ]; then
    print_status "Removing crypto material and channel artifacts..."
    rm -rf network/organizations 2>/dev/null || true
    rm -rf network/channel-artifacts 2>/dev/null || true
    rm -rf chaincode/node_modules 2>/dev/null || true
    rm -rf chaincode/dist 2>/dev/null || true
    rm -rf application/node_modules 2>/dev/null || true
    rm -rf application/dist 2>/dev/null || true
fi

# Clean up Docker system
print_status "Cleaning up Docker system..."
docker system prune -f 2>/dev/null || true

# Remove unused networks
print_status "Removing unused Docker networks..."
docker network prune -f 2>/dev/null || true

print_status "Network cleanup completed!"

if [ "$REMOVE_ALL" = true ]; then
    print_status "All network data, crypto material, and build artifacts have been removed"
    print_status "To restart the network, run:"
    print_status "  ./scripts/network-up.sh"
    print_status "  ./scripts/deploy-chaincode.sh"
elif [ "$REMOVE_VOLUMES" = true ]; then
    print_status "All containers and volumes have been removed"
    print_status "Crypto material is preserved"
    print_status "To restart the network, run:"
    print_status "  $DOCKER_COMPOSE up -d"
else
    print_status "Containers stopped, volumes and crypto material preserved"
    print_status "To restart the network, run:"
    print_status "  $DOCKER_COMPOSE up -d"
fi

print_status ""
print_status "Container status: $DOCKER_COMPOSE ps"
print_status "Docker images: docker images | grep hyperledger"
print_status "Docker volumes: docker volume ls"
