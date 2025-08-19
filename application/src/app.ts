import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { FabricGatewayService } from './fabric-gateway';
import recordsRouter from './routes/records';
import { ApiResponse, HealthCheckResponse } from './models/record';

const app = express();
const PORT = process.env.PORT || 3000;

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: {
        success: false,
        error: 'Too many requests from this IP, please try again later.'
    }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(limiter);

// Initialize Fabric Gateway Service
const fabricService = new FabricGatewayService();
app.locals.fabricService = fabricService;

// Health check endpoint
app.get('/api/health', async (req, res) => {
    try {
        const fabricHealthy = await fabricService.checkHealth();
        
        const healthResponse: HealthCheckResponse = {
            status: fabricHealthy ? 'healthy' : 'unhealthy',
            timestamp: new Date().toISOString(),
            services: {
                fabric: fabricHealthy ? 'connected' : 'disconnected',
                api: 'running'
            }
        };

        const response: ApiResponse<HealthCheckResponse> = {
            success: true,
            data: healthResponse,
            message: 'Health check completed'
        };

        res.status(fabricHealthy ? 200 : 503).json(response);
    } catch (error) {
        console.error('Health check error:', error);
        
        const healthResponse: HealthCheckResponse = {
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            services: {
                fabric: 'disconnected',
                api: 'running'
            }
        };

        const response: ApiResponse<HealthCheckResponse> = {
            success: false,
            data: healthResponse,
            error: 'Health check failed'
        };

        res.status(503).json(response);
    }
});

// API routes
app.use('/api/records', recordsRouter);

// API documentation endpoint
app.get('/api/docs', (req, res) => {
    const apiDocs = {
        title: 'Immutable Records API',
        version: '1.0.0',
        description: 'REST API for managing immutable records on Hyperledger Fabric',
        baseUrl: `http://localhost:${PORT}/api`,
        endpoints: {
            'POST /records': {
                description: 'Create a new record',
                requestBody: {
                    id: 'string (required, 1-50 chars, alphanumeric)',
                    name: 'string (required, 1-100 chars)',
                    email: 'string (required, valid email format)',
                    department: 'string (required, 1-50 chars)'
                },
                responses: {
                    201: 'Record created successfully',
                    400: 'Validation error',
                    409: 'Record already exists',
                    500: 'Internal server error'
                }
            },
            'GET /records': {
                description: 'Get all records with pagination',
                queryParams: {
                    bookmark: 'string (optional, pagination bookmark)',
                    pageSize: 'number (optional, 1-100, default: 10)'
                },
                responses: {
                    200: 'Records retrieved successfully',
                    400: 'Validation error',
                    500: 'Internal server error'
                }
            },
            'GET /records/:id': {
                description: 'Get a specific record by ID',
                pathParams: {
                    id: 'string (required, record ID)'
                },
                responses: {
                    200: 'Record retrieved successfully',
                    400: 'Validation error',
                    404: 'Record not found',
                    500: 'Internal server error'
                }
            },
            'GET /records/:id/history': {
                description: 'Get complete audit history for a record',
                pathParams: {
                    id: 'string (required, record ID)'
                },
                responses: {
                    200: 'Record history retrieved successfully',
                    400: 'Validation error',
                    404: 'Record not found',
                    500: 'Internal server error'
                }
            },
            'GET /records/department/:dept': {
                description: 'Query records by department',
                pathParams: {
                    dept: 'string (required, department name)'
                },
                queryParams: {
                    bookmark: 'string (optional, pagination bookmark)',
                    pageSize: 'number (optional, 1-100, default: 10)'
                },
                responses: {
                    200: 'Records retrieved successfully',
                    400: 'Validation error',
                    500: 'Internal server error'
                }
            },
            'GET /health': {
                description: 'Check API and Fabric network health',
                responses: {
                    200: 'System healthy',
                    503: 'System unhealthy'
                }
            }
        }
    };

    const response: ApiResponse<typeof apiDocs> = {
        success: true,
        data: apiDocs,
        message: 'API documentation retrieved successfully'
    };

    res.json(response);
});

// Root endpoint
app.get('/', (req, res) => {
    const response: ApiResponse<{ message: string; documentation: string }> = {
        success: true,
        data: {
            message: 'Immutable Records API is running',
            documentation: '/api/docs'
        }
    };
    res.json(response);
});

// 404 handler
app.use('*', (req, res) => {
    const response: ApiResponse = {
        success: false,
        error: 'Endpoint not found'
    };
    res.status(404).json(response);
});

// Global error handler
app.use((error: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Unhandled error:', error);
    
    const response: ApiResponse = {
        success: false,
        error: 'Internal server error'
    };
    
    res.status(500).json(response);
});

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('Received SIGINT. Graceful shutdown...');
    
    try {
        await fabricService.close();
        console.log('Fabric Gateway connection closed');
    } catch (error) {
        console.error('Error closing Fabric Gateway:', error);
    }
    
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('Received SIGTERM. Graceful shutdown...');
    
    try {
        await fabricService.close();
        console.log('Fabric Gateway connection closed');
    } catch (error) {
        console.error('Error closing Fabric Gateway:', error);
    }
    
    process.exit(0);
});

// Start server
async function startServer() {
    try {
        console.log('Initializing Fabric Gateway connection...');
        await fabricService.initialize();
        
        app.listen(PORT, () => {
            console.log(`Server is running on http://localhost:${PORT}`);
            console.log(`API documentation available at http://localhost:${PORT}/api/docs`);
            console.log(`Health check available at http://localhost:${PORT}/api/health`);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
}

startServer();
