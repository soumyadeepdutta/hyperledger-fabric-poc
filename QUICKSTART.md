# Quick Start Guide

## Windows Users - Getting Started

### Prerequisites Check

1. **Install Docker Desktop for Windows**
   - Download from: https://www.docker.com/products/docker-desktop
   - Ensure WSL2 integration is enabled
   - Verify installation:
     ```cmd
     docker --version
     docker-compose --version
     ```

2. **Install Node.js**
   - Download from: https://nodejs.org (LTS version)
   - Verify installation:
     ```cmd
     node --version
     npm --version
     ```

3. **Install Git (optional)**
   - Download from: https://git-scm.com/download/win

### Quick Setup (5 minutes)

1. **Start the Network**
   ```cmd
   cd hlf-crud
   scripts\network-up.bat
   ```
   Wait for completion (~2-3 minutes)

2. **Deploy Chaincode**
   ```cmd
   scripts\deploy-chaincode.bat
   ```
   Wait for completion (~1-2 minutes)

3. **Start API Server**
   ```cmd
   cd application
   npm install
   npm run dev
   ```

4. **Test the System**
   Open a new command prompt:
   ```cmd
   curl http://localhost:3000/api/health
   curl http://localhost:3000/api/records
   ```

### If You Encounter Issues

1. **Docker Issues**
   - Ensure Docker Desktop is running
   - Check WSL2 integration in Docker settings
   - Try: `docker system prune -f`

2. **Network Startup Issues**
   ```cmd
   scripts\network-down.bat --all
   scripts\network-up.bat
   ```

3. **Port Conflicts**
   - Check if ports 3000, 7050, 7051, 9051 are available
   - Stop other applications using these ports

4. **Permission Issues**
   - Run Command Prompt as Administrator
   - Ensure Docker has proper permissions

### Linux/macOS Users

Use the shell scripts instead:
```bash
chmod +x scripts/*.sh
./scripts/network-up.sh
./scripts/deploy-chaincode.sh
cd application && npm install && npm run dev
```

### Testing the API

1. **Health Check**
   ```cmd
   curl http://localhost:3000/api/health
   ```

2. **View Sample Data**
   ```cmd
   curl http://localhost:3000/api/records
   ```

3. **Create New Record**
   ```cmd
   curl -X POST http://localhost:3000/api/records ^
        -H "Content-Type: application/json" ^
        -d "{\"id\":\"user1\",\"name\":\"John Doe\",\"email\":\"john@example.com\",\"department\":\"IT\"}"
   ```

4. **View Record History**
   ```cmd
   curl http://localhost:3000/api/records/user1/history
   ```

### Next Steps

- Read the full README.md for detailed documentation
- Explore the API at http://localhost:3000/api/docs
- Check logs: `docker-compose logs -f`
- Monitor containers: `docker-compose ps`

### Cleanup

To stop and clean up everything:
```cmd
scripts\network-down.bat --all
```

This removes all containers, volumes, and generated files.

## Common Commands

### Network Management
```cmd
# Start network
scripts\network-up.bat

# Deploy chaincode
scripts\deploy-chaincode.bat

# Stop network (preserve data)
scripts\network-down.bat

# Stop network and remove everything
scripts\network-down.bat --all

# View network status
docker-compose ps

# View logs
docker-compose logs -f [service_name]
```

### Development
```cmd
# Install dependencies
cd chaincode && npm install
cd application && npm install

# Build chaincode
cd chaincode && npm run build

# Start development server
cd application && npm run dev

# Build for production
cd application && npm run build
```

### Troubleshooting
```cmd
# Check Docker status
docker info
docker system df

# Restart Docker containers
docker-compose restart

# Clean Docker system
docker system prune -f

# View container logs
docker-compose logs [service_name]

# Execute commands in CLI container
docker-compose exec cli bash
```

## Support

If you encounter issues:

1. Check the Troubleshooting section in README.md
2. Verify all prerequisites are installed correctly
3. Try the cleanup and restart procedure
4. Check Docker Desktop logs and container logs

For Windows-specific issues:
- Ensure WSL2 is properly installed and integrated
- Check Windows Defender/antivirus settings
- Verify Docker Desktop has proper permissions
