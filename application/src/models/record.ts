/**
 * Immutable Record model interface
 */
export interface ImmutableRecord {
    id: string;
    name: string;
    email: string;
    department: string;
    timestamp: string;
    txId: string;
    creator: string;
}

/**
 * Create Record input interface
 */
export interface CreateRecordInput {
    id: string;
    name: string;
    email: string;
    department: string;
}

/**
 * Paginated query result interface
 */
export interface PaginatedQueryResult<T> {
    records: T[];
    bookmark: string;
    totalCount: number;
}

/**
 * Record history entry interface
 */
export interface RecordHistoryEntry {
    txId: string;
    timestamp: string;
    isDelete: boolean;
    value: ImmutableRecord | null;
}

/**
 * API Response wrapper interface
 */
export interface ApiResponse<T = any> {
    success: boolean;
    data?: T;
    message?: string;
    error?: string;
}

/**
 * Health check response interface
 */
export interface HealthCheckResponse {
    status: 'healthy' | 'unhealthy';
    timestamp: string;
    services: {
        fabric: 'connected' | 'disconnected';
        api: 'running';
    };
}

/**
 * Query parameters interface
 */
export interface QueryParams {
    bookmark?: string;
    pageSize?: number;
}
