# Hyperledger Fabric Immutable Database Prototype

A complete production-ready Hyperledger Fabric immutable database system with TypeScript/Node.js implementation, featuring append-only operations, complete audit trails, and RESTful API access.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Testing](#testing)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This project implements an immutable database system using Hyperledger Fabric blockchain technology. All operations are append-only, ensuring complete data integrity and providing comprehensive audit trails for regulatory compliance and data governance.

### Key Components

- **Chaincode**: Smart contract implementing immutable record operations
- **REST API**: Express.js application providing HTTP endpoints
- **Network Configuration**: Docker-based Fabric network with 2 organizations
- **Database Schema**: Records with ID, name, email, department, and metadata

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Apps   │    │   REST API      │    │   Fabric Network│
│                 │    │                 │    │                 │
│ Web/Mobile Apps │◄──►│ Express.js      │◄──►│ Hyperledger     │
│ External APIs   │    │ TypeScript      │    │ Fabric 2.x      │
│                 │    │ Fabric Gateway  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Chaincode     │
                       │                 │
                       │ TypeScript      │
                       │ Immutable Ops   │
                       │ Audit Trail     │
                       └─────────────────┘
```

### Network Architecture

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Orderer    │  │    Org1      │  │    Org2      │
│              │  │              │  │              │
│ Consensus    │  │ Peer0        │  │ Peer0        │
│ Transaction  │  │ CouchDB      │  │ CouchDB      │
│ Ordering     │  │ CA           │  │ CA           │
└──────────────┘  └──────────────┘  └──────────────┘
```

## Features

### Core Functionality

- ✅ **Immutable Records**: Append-only operations, no updates or deletes
- ✅ **Complete Audit Trail**: Track all changes with transaction IDs and timestamps
- ✅ **Rich Querying**: Query by ID, department, with pagination support
- ✅ **Data Integrity**: Cryptographic verification and blockchain immutability
- ✅ **Multi-Organization**: Support for multiple organizations and endorsement policies

### API Features

- ✅ **RESTful Interface**: HTTP/JSON API with OpenAPI documentation
- ✅ **Input Validation**: Comprehensive data validation using Joi
- ✅ **Error Handling**: Structured error responses and logging
- ✅ **Rate Limiting**: DDoS protection and fair usage policies
- ✅ **Security Headers**: Helmet.js security middleware
- ✅ **CORS Support**: Cross-origin resource sharing configuration

### Development Features

- ✅ **TypeScript**: Full type safety and modern JavaScript features
- ✅ **Docker Compose**: Local development environment
- ✅ **Automated Scripts**: Network setup and chaincode deployment
- ✅ **Hot Reload**: Development server with automatic restart
- ✅ **Comprehensive Logging**: Winston logging with multiple levels

## Prerequisites

### System Requirements

- **Operating System**: Linux, macOS, or Windows with WSL2
- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Node.js**: Version 18 or higher
- **npm**: Version 9 or higher

### Development Tools (Optional)

- **Git**: For version control
- **VS Code**: Recommended IDE with extensions:
  - Hyperledger Fabric
  - TypeScript and JavaScript
  - Docker
  - REST Client

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker-compose --version

# Check Node.js
node --version
npm --version

# Check system resources
docker system df
free -h  # Linux/macOS
```

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd hlf-crud
```

### 2. Start Network

```bash
# Make scripts executable (Linux/macOS)
chmod +x scripts/*.sh

# Start the Fabric network
./scripts/network-up.sh

# Deploy chaincode
./scripts/deploy-chaincode.sh
```

### 3. Start API Server

```bash
cd application
npm install
npm run dev
```

### 4. Test the API

```bash
# Health check
curl http://localhost:3000/api/health

# Get all records
curl http://localhost:3000/api/records

# Create a new record
curl -X POST http://localhost:3000/api/records \
  -H "Content-Type: application/json" \
  -d '{
    "id": "user123",
    "name": "John Doe",
    "email": "john.doe@example.com",
    "department": "Engineering"
  }'

# Get record by ID
curl http://localhost:3000/api/records/user123

# Get record history
curl http://localhost:3000/api/records/user123/history

# Query by department
curl http://localhost:3000/api/records/department/Engineering
```

## Project Structure

```
hlf-crud/
├── docker-compose.yml              # Docker services configuration
├── README.md                       # This file
│
├── network/                        # Fabric network configuration
│   ├── configtx/
│   │   └── configtx.yaml          # Channel and consortium configuration
│   └── crypto-config.yaml         # Certificate authority configuration
│
├── chaincode/                      # Smart contract implementation
│   ├── package.json               # Node.js dependencies
│   ├── tsconfig.json              # TypeScript configuration
│   └── src/
│       ├── index.ts               # Chaincode entry point
│       └── immutable-records-contract.ts  # Main contract logic
│
├── application/                    # REST API application
│   ├── package.json               # Node.js dependencies
│   ├── tsconfig.json              # TypeScript configuration
│   └── src/
│       ├── app.ts                 # Express application
│       ├── fabric-gateway.ts      # Fabric SDK integration
│       ├── models/
│       │   └── record.ts          # Data models and interfaces
│       └── routes/
│           └── records.ts         # API route handlers
│
└── scripts/                       # Automation scripts
    ├── network-up.sh              # Start Fabric network
    ├── deploy-chaincode.sh        # Deploy and initialize chaincode
    └── network-down.sh            # Stop and cleanup network
```

## Configuration

### Environment Variables

Create a `.env` file in the application directory:

```bash
# Server Configuration
PORT=3000
NODE_ENV=development

# Fabric Network Configuration
FABRIC_NETWORK_NAME=fabric-network
CHANNEL_NAME=mychannel
CHAINCODE_NAME=immutable-records

# Logging Configuration
LOG_LEVEL=info
LOG_FILE=logs/app.log

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100

# CORS Configuration
CORS_ORIGIN=*
```

### Network Configuration

Edit `network/configtx/configtx.yaml` to modify:

- Organization definitions
- Channel policies
- Consensus parameters
- Anchor peer configuration

### Chaincode Configuration

Edit `chaincode/src/immutable-records-contract.ts` to customize:

- Data validation rules
- Business logic
- Access control policies
- Event definitions

## API Documentation

### Base URL

```
http://localhost:3000/api
```

### Authentication

Currently, the API doesn't implement authentication. For production deployment, implement:

- JWT tokens
- API keys
- OAuth 2.0
- mTLS certificates

### Endpoints

#### Health Check

```http
GET /health
```

Returns system health status including Fabric connectivity.

#### Records Management

##### Create Record

```http
POST /records
Content-Type: application/json

{
  "id": "string",        // Required: 1-50 chars, alphanumeric
  "name": "string",      // Required: 1-100 chars
  "email": "string",     // Required: valid email format
  "department": "string" // Required: 1-50 chars
}
```

##### Get All Records

```http
GET /records?pageSize=10&bookmark=string
```

Parameters:
- `pageSize`: Number of records per page (1-100, default: 10)
- `bookmark`: Pagination bookmark for next page

##### Get Record by ID

```http
GET /records/:id
```

##### Get Record History

```http
GET /records/:id/history
```

Returns complete audit trail with all historical changes.

##### Query by Department

```http
GET /records/department/:dept?pageSize=10&bookmark=string
```

#### API Documentation

```http
GET /docs
```

Returns complete API documentation in JSON format.

### Response Format

All API responses follow this structure:

```json
{
  "success": boolean,
  "data": any,           // Present on success
  "message": "string",   // Optional success message
  "error": "string"      // Present on error
}
```

### Error Codes

- **400**: Bad Request - Invalid input data
- **404**: Not Found - Resource doesn't exist
- **409**: Conflict - Resource already exists
- **429**: Too Many Requests - Rate limit exceeded
- **500**: Internal Server Error - System error
- **503**: Service Unavailable - System unhealthy

## Development

### Setup Development Environment

```bash
# Install dependencies
cd chaincode && npm install
cd ../application && npm install

# Build chaincode
cd chaincode && npm run build

# Start development server
cd application && npm run dev
```

### Code Style and Linting

```bash
# Install development tools
npm install -g typescript ts-node

# Type checking
cd chaincode && npx tsc --noEmit
cd application && npx tsc --noEmit
```

### Hot Reload

The development server supports hot reload for both chaincode and application:

```bash
# Application hot reload
cd application && npm run watch

# Chaincode development
cd chaincode && npm run build:watch
```

### Database Queries

#### CouchDB Rich Queries

The chaincode supports CouchDB rich queries for complex data retrieval:

```typescript
// Example: Query records by date range
const queryString = JSON.stringify({
  selector: {
    timestamp: {
      $gte: "2023-01-01T00:00:00Z",
      $lte: "2023-12-31T23:59:59Z"
    },
    department: "Engineering"
  },
  sort: [{"timestamp": "desc"}]
});
```

#### Pagination

All query operations support pagination:

```typescript
// Get records with pagination
const result = await contract.evaluateTransaction(
  'GetAllRecords',
  bookmark,     // Previous page bookmark
  pageSize.toString()
);
```

## Testing

### Manual Testing

Use the provided test scripts to validate functionality:

```bash
# Test network connectivity
docker-compose exec cli peer channel list

# Test chaincode installation
docker-compose exec cli peer lifecycle chaincode queryinstalled

# Test chaincode functionality
docker-compose exec cli peer chaincode query \
  -C mychannel -n immutable-records \
  -c '{"function":"GetAllRecords","Args":[]}'
```

### API Testing

Use curl or Postman to test API endpoints:

```bash
# Create multiple test records
for i in {1..5}; do
  curl -X POST http://localhost:3000/api/records \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"test$i\",\"name\":\"Test User $i\",\"email\":\"test$i@example.com\",\"department\":\"Testing\"}"
done

# Test pagination
curl "http://localhost:3000/api/records?pageSize=2"

# Test department queries
curl "http://localhost:3000/api/records/department/Testing"
```

### Load Testing

For performance testing, use tools like Apache Bench or Artillery:

```bash
# Install Apache Bench
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpie                  # macOS

# Simple load test
ab -n 100 -c 10 http://localhost:3000/api/health
```

## Production Deployment

### Security Considerations

1. **Network Security**
   - Use TLS/SSL certificates
   - Configure firewall rules
   - Implement network segmentation
   - Use VPN for inter-organization communication

2. **Application Security**
   - Implement authentication and authorization
   - Use environment variables for secrets
   - Enable request logging and monitoring
   - Regular security updates

3. **Blockchain Security**
   - Secure key management
   - Hardware Security Modules (HSM)
   - Regular backup of certificates
   - Access control policies

### High Availability

1. **Multiple Peers per Organization**
   ```yaml
   # Add additional peers in docker-compose.yml
   peer1.org1.example.com:
     # Configuration similar to peer0
   ```

2. **Multiple Orderers**
   ```yaml
   # Implement Raft consensus with multiple orderers
   orderer1.example.com:
   orderer2.example.com:
   orderer3.example.com:
   ```

3. **Load Balancing**
   - API load balancer (nginx, HAProxy)
   - Database connection pooling
   - Horizontal scaling of API servers

### Monitoring and Logging

1. **Application Monitoring**
   - Prometheus metrics
   - Grafana dashboards
   - Health check endpoints
   - Performance monitoring

2. **Blockchain Monitoring**
   - Peer node status
   - Transaction throughput
   - Block height synchronization
   - Chaincode performance

3. **Log Management**
   - Centralized logging (ELK stack)
   - Log rotation
   - Error alerting
   - Audit trail preservation

### Backup and Recovery

1. **Blockchain Data**
   - Regular peer database backup
   - Ledger snapshot creation
   - Certificate backup
   - Configuration backup

2. **Application Data**
   - Database backup (if using external DB)
   - Configuration backup
   - Log file backup
   - Disaster recovery procedures

## Troubleshooting

### Common Issues

#### Network Startup Problems

```bash
# Check Docker status
docker system df
docker-compose ps

# View container logs
docker-compose logs orderer.example.com
docker-compose logs peer0.org1.example.com

# Restart network
./scripts/network-down.sh --all
./scripts/network-up.sh
```

#### Chaincode Deployment Issues

```bash
# Check chaincode container logs
docker logs $(docker ps -q --filter "name=dev-peer")

# Rebuild and redeploy
cd chaincode
npm run build
cd ..
./scripts/deploy-chaincode.sh --version 1.1 --sequence 2
```

#### API Connection Problems

```bash
# Check API logs
cd application
npm run dev

# Test Fabric connectivity
node -e "
const { FabricGatewayService } = require('./dist/fabric-gateway.js');
const service = new FabricGatewayService();
service.initialize().then(() => console.log('Connected')).catch(console.error);
"
```

### Performance Optimization

1. **Chaincode Optimization**
   - Efficient data structures
   - Minimal world state queries
   - Proper indexing
   - Batch operations

2. **API Optimization**
   - Connection pooling
   - Response caching
   - Request validation
   - Async operations

3. **Network Optimization**
   - Proper peer discovery
   - Efficient endorsement policies
   - Block size optimization
   - Transaction batching

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
# Fabric debug logs
export FABRIC_LOGGING_SPEC=DEBUG

# Application debug logs
export LOG_LEVEL=debug
cd application && npm run dev
```

## Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

### Code Standards

- Follow TypeScript best practices
- Use meaningful variable names
- Add comprehensive comments
- Write unit tests for new features
- Update documentation

### Commit Messages

Use conventional commit format:

```
feat: add new record validation
fix: resolve pagination bug
docs: update API documentation
test: add integration tests
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

For questions and support:

- Create an issue in the repository
- Check existing documentation
- Review troubleshooting guide
- Contact the development team

## Acknowledgments

- Hyperledger Fabric community
- Express.js ecosystem
- TypeScript community
- Docker and containerization tools

---

**Note**: This is a prototype implementation for learning and development purposes. For production use, additional security hardening, testing, and operational procedures should be implemented.
"# hyperledger-fabric-poc" 
