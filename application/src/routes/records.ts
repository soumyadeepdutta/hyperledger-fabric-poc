import { Router, Request, Response } from 'express';
import Joi from 'joi';
import { FabricGatewayService } from '../fabric-gateway';
import { 
    ApiResponse, 
    CreateRecordInput, 
    ImmutableRecord, 
    PaginatedQueryResult, 
    RecordHistoryEntry,
    QueryParams
} from '../models/record';

const router = Router();

// Validation schemas
const createRecordSchema = Joi.object({
    id: Joi.string().required().min(1).max(50).pattern(/^[a-zA-Z0-9-_]+$/),
    name: Joi.string().required().min(1).max(100),
    email: Joi.string().email().required().max(255),
    department: Joi.string().required().min(1).max(50)
});

const queryParamsSchema = Joi.object({
    bookmark: Joi.string().optional(),
    pageSize: Joi.number().integer().min(1).max(100).optional().default(10)
});

const idParamSchema = Joi.object({
    id: Joi.string().required().min(1).max(50)
});

const departmentParamSchema = Joi.object({
    dept: Joi.string().required().min(1).max(50)
});

/**
 * Create a new record
 * POST /api/records
 */
router.post('/', async (req: Request, res: Response) => {
    try {
        // Validate request body
        const { error, value } = createRecordSchema.validate(req.body);
        if (error) {
            const response: ApiResponse = {
                success: false,
                error: `Validation error: ${error.details[0].message}`
            };
            return res.status(400).json(response);
        }

        const input: CreateRecordInput = value;
        const fabricService = req.app.locals.fabricService as FabricGatewayService;

        // Check if record already exists
        const exists = await fabricService.recordExists(input.id);
        if (exists) {
            const response: ApiResponse = {
                success: false,
                error: `Record with ID '${input.id}' already exists`
            };
            return res.status(409).json(response);
        }

        // Create the record
        const record = await fabricService.createRecord(input);
        
        const response: ApiResponse<ImmutableRecord> = {
            success: true,
            data: record,
            message: 'Record created successfully'
        };

        return res.status(201).json(response);
    } catch (error) {
        console.error('Error creating record:', error);
        const response: ApiResponse = {
            success: false,
            error: 'Internal server error while creating record'
        };
        return res.status(500).json(response);
    }
});

/**
 * Get all records with pagination
 * GET /api/records?bookmark=...&pageSize=...
 */
router.get('/', async (req: Request, res: Response) => {
    try {
        // Validate query parameters
        const { error, value } = queryParamsSchema.validate(req.query);
        if (error) {
            const response: ApiResponse = {
                success: false,
                error: `Validation error: ${error.details[0].message}`
            };
            return res.status(400).json(response);
        }

        const params: QueryParams = value;
        const fabricService = req.app.locals.fabricService as FabricGatewayService;

        const result = await fabricService.getAllRecords(params.bookmark, params.pageSize);
        
        const response: ApiResponse<PaginatedQueryResult<ImmutableRecord>> = {
            success: true,
            data: result,
            message: 'Records retrieved successfully'
        };

        return res.json(response);
    } catch (error) {
        console.error('Error getting all records:', error);
        const response: ApiResponse = {
            success: false,
            error: 'Internal server error while retrieving records'
        };
        return res.status(500).json(response);
    }
});

/**
 * Get a record by ID
 * GET /api/records/:id
 */
router.get('/:id', async (req: Request, res: Response) => {
    try {
        // Validate path parameter
        const { error, value } = idParamSchema.validate(req.params);
        if (error) {
            const response: ApiResponse = {
                success: false,
                error: `Validation error: ${error.details[0].message}`
            };
            return res.status(400).json(response);
        }

        const fabricService = req.app.locals.fabricService as FabricGatewayService;
        
        const record = await fabricService.readRecord(value.id);
        
        const response: ApiResponse<ImmutableRecord> = {
            success: true,
            data: record,
            message: 'Record retrieved successfully'
        };

        return res.json(response);
    } catch (error) {
        console.error('Error getting record:', error);
        
        // Check if it's a "not found" error
        if (error instanceof Error && error.message.includes('does not exist')) {
            const response: ApiResponse = {
                success: false,
                error: 'Record not found'
            };
            return res.status(404).json(response);
        }

        const response: ApiResponse = {
            success: false,
            error: 'Internal server error while retrieving record'
        };
        return res.status(500).json(response);
    }
});

/**
 * Get record history by ID
 * GET /api/records/:id/history
 */
router.get('/:id/history', async (req: Request, res: Response) => {
    try {
        // Validate path parameter
        const { error, value } = idParamSchema.validate(req.params);
        if (error) {
            const response: ApiResponse = {
                success: false,
                error: `Validation error: ${error.details[0].message}`
            };
            return res.status(400).json(response);
        }

        const fabricService = req.app.locals.fabricService as FabricGatewayService;
        
        const history = await fabricService.getRecordHistory(value.id);
        
        const response: ApiResponse<RecordHistoryEntry[]> = {
            success: true,
            data: history,
            message: 'Record history retrieved successfully'
        };

        return res.json(response);
    } catch (error) {
        console.error('Error getting record history:', error);
        
        // Check if it's a "not found" error
        if (error instanceof Error && error.message.includes('does not exist')) {
            const response: ApiResponse = {
                success: false,
                error: 'Record not found'
            };
            return res.status(404).json(response);
        }

        const response: ApiResponse = {
            success: false,
            error: 'Internal server error while retrieving record history'
        };
        return res.status(500).json(response);
    }
});

/**
 * Query records by department
 * GET /api/records/department/:dept?bookmark=...&pageSize=...
 */
router.get('/department/:dept', async (req: Request, res: Response) => {
    try {
        // Validate path parameter
        const { error: paramError, value: paramValue } = departmentParamSchema.validate(req.params);
        if (paramError) {
            const response: ApiResponse = {
                success: false,
                error: `Validation error: ${paramError.details[0].message}`
            };
            return res.status(400).json(response);
        }

        // Validate query parameters
        const { error: queryError, value: queryValue } = queryParamsSchema.validate(req.query);
        if (queryError) {
            const response: ApiResponse = {
                success: false,
                error: `Validation error: ${queryError.details[0].message}`
            };
            return res.status(400).json(response);
        }

        const fabricService = req.app.locals.fabricService as FabricGatewayService;
        
        const result = await fabricService.queryRecordsByDepartment(
            paramValue.dept, 
            queryValue.bookmark, 
            queryValue.pageSize
        );
        
        const response: ApiResponse<PaginatedQueryResult<ImmutableRecord>> = {
            success: true,
            data: result,
            message: `Records for department '${paramValue.dept}' retrieved successfully`
        };

        return res.json(response);
    } catch (error) {
        console.error('Error querying records by department:', error);
        const response: ApiResponse = {
            success: false,
            error: 'Internal server error while querying records by department'
        };
        return res.status(500).json(response);
    }
});

export default router;
