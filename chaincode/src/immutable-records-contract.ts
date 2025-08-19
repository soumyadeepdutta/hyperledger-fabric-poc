/*
 * SPDX-License-Identifier: Apache-2.0
 */

import { Context, Contract, Info, Returns, Transaction } from 'fabric-contract-api';
import stringify from 'json-stringify-deterministic';
import sortKeysRecursive from 'sort-keys-recursive';

/**
 * Interface representing an immutable record in the ledger
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
 * Interface for record creation input
 */
export interface CreateRecordInput {
    id: string;
    name: string;
    email: string;
    department: string;
}

/**
 * Interface for pagination parameters
 */
export interface PaginationParams {
    bookmark?: string;
    pageSize?: number;
}

/**
 * Interface for paginated query results
 */
export interface PaginatedQueryResult<T> {
    records: T[];
    bookmark: string;
    totalCount: number;
}

/**
 * Interface for record history entry
 */
export interface RecordHistoryEntry {
    txId: string;
    timestamp: string;
    isDelete: boolean;
    value: ImmutableRecord | null;
}

@Info({ title: 'ImmutableRecordsContract', description: 'Smart contract for managing immutable records' })
export class ImmutableRecordsContract extends Contract {

    /**
     * Initialize the ledger with sample data
     */
    @Transaction()
    public async InitLedger(ctx: Context): Promise<void> {
        const sampleRecords: CreateRecordInput[] = [
            {
                id: 'record1',
                name: 'John Doe',
                email: 'john.doe@example.com',
                department: 'Engineering'
            },
            {
                id: 'record2',
                name: 'Jane Smith',
                email: 'jane.smith@example.com',
                department: 'Marketing'
            },
            {
                id: 'record3',
                name: 'Bob Johnson',
                email: 'bob.johnson@example.com',
                department: 'Finance'
            },
            {
                id: 'record4',
                name: 'Alice Brown',
                email: 'alice.brown@example.com',
                department: 'Engineering'
            },
            {
                id: 'record5',
                name: 'Charlie Wilson',
                email: 'charlie.wilson@example.com',
                department: 'HR'
            }
        ];

        for (const recordInput of sampleRecords) {
            await this.CreateRecord(
                ctx,
                recordInput.id,
                recordInput.name,
                recordInput.email,
                recordInput.department
            );
        }

        console.log('Ledger initialized with sample records');
    }

    /**
     * Create a new immutable record
     * @param ctx - Transaction context
     * @param id - Unique identifier for the record
     * @param name - Name field
     * @param email - Email field
     * @param department - Department field
     * @returns The created record
     */
    @Transaction()
    public async CreateRecord(
        ctx: Context,
        id: string,
        name: string,
        email: string,
        department: string
    ): Promise<ImmutableRecord> {
        // Validate input parameters
        this.validateInput(id, 'ID');
        this.validateInput(name, 'Name');
        this.validateInput(email, 'Email');
        this.validateInput(department, 'Department');

        // Validate email format
        if (!this.isValidEmail(email)) {
            throw new Error(`Invalid email format: ${email}`);
        }

        // Check if record with this ID already exists
        const existingRecord = await this.RecordExists(ctx, id);
        if (existingRecord) {
            throw new Error(`Record with ID ${id} already exists`);
        }

        // Create the immutable record
        const record: ImmutableRecord = {
            id,
            name,
            email,
            department,
            timestamp: new Date().toISOString(),
            txId: ctx.stub.getTxID(),
            creator: ctx.clientIdentity.getID()
        };

        // Store the record in the ledger
        await ctx.stub.putState(id, Buffer.from(stringify(sortKeysRecursive(record))));

        // Emit event for record creation
        ctx.stub.setEvent('RecordCreated', Buffer.from(stringify(record)));

        console.log(`Record created: ${id}`);
        return record;
    }

    /**
     * Read a record by ID
     * @param ctx - Transaction context
     * @param id - Record ID
     * @returns The record if found
     */
    @Transaction(false)
    @Returns('ImmutableRecord')
    public async ReadRecord(ctx: Context, id: string): Promise<ImmutableRecord> {
        this.validateInput(id, 'ID');

        const recordJSON = await ctx.stub.getState(id);
        if (!recordJSON || recordJSON.length === 0) {
            throw new Error(`Record with ID ${id} does not exist`);
        }

        const record = JSON.parse(recordJSON.toString()) as ImmutableRecord;
        return record;
    }

    /**
     * Get all records with pagination support
     * @param ctx - Transaction context
     * @param bookmark - Pagination bookmark (optional)
     * @param pageSize - Number of records per page (optional, default: 10)
     * @returns Paginated query result
     */
    @Transaction(false)
    @Returns('PaginatedQueryResult')
    public async GetAllRecords(
        ctx: Context,
        bookmark?: string,
        pageSize?: string
    ): Promise<PaginatedQueryResult<ImmutableRecord>> {
        const pageSizeNum = pageSize ? parseInt(pageSize, 10) : 10;
        
        if (pageSizeNum <= 0 || pageSizeNum > 100) {
            throw new Error('Page size must be between 1 and 100');
        }

        const queryString = '{"selector":{}}';
        const queryResult = await ctx.stub.getQueryResultWithPagination(
            queryString,
            pageSizeNum,
            bookmark || ''
        );

        const records: ImmutableRecord[] = [];
        let result = await queryResult.iterator.next();

        while (!result.done) {
            const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
            const record = JSON.parse(strValue) as ImmutableRecord;
            records.push(record);
            result = await queryResult.iterator.next();
        }

        await queryResult.iterator.close();

        return {
            records,
            bookmark: queryResult.metadata.bookmark,
            totalCount: records.length
        };
    }

    /**
     * Get the complete history of a record
     * @param ctx - Transaction context
     * @param id - Record ID
     * @returns Array of history entries
     */
    @Transaction(false)
    @Returns('RecordHistoryEntry[]')
    public async GetRecordHistory(ctx: Context, id: string): Promise<RecordHistoryEntry[]> {
        this.validateInput(id, 'ID');

        const historyIterator = await ctx.stub.getHistoryForKey(id);
        const history: RecordHistoryEntry[] = [];

        let result = await historyIterator.next();
        while (!result.done) {
            const historyRecord = result.value;
            
            let value: ImmutableRecord | null = null;
            if (historyRecord.value && historyRecord.value.length > 0) {
                value = JSON.parse(historyRecord.value.toString()) as ImmutableRecord;
            }

            const historyEntry: RecordHistoryEntry = {
                txId: historyRecord.txId,
                timestamp: new Date(historyRecord.timestamp.seconds.low * 1000).toISOString(),
                isDelete: historyRecord.isDelete,
                value
            };

            history.push(historyEntry);
            result = await historyIterator.next();
        }

        await historyIterator.close();
        return history;
    }

    /**
     * Query records by department
     * @param ctx - Transaction context
     * @param department - Department to search for
     * @param bookmark - Pagination bookmark (optional)
     * @param pageSize - Number of records per page (optional, default: 10)
     * @returns Paginated query result
     */
    @Transaction(false)
    @Returns('PaginatedQueryResult')
    public async QueryRecordsByDepartment(
        ctx: Context,
        department: string,
        bookmark?: string,
        pageSize?: string
    ): Promise<PaginatedQueryResult<ImmutableRecord>> {
        this.validateInput(department, 'Department');

        const pageSizeNum = pageSize ? parseInt(pageSize, 10) : 10;
        
        if (pageSizeNum <= 0 || pageSizeNum > 100) {
            throw new Error('Page size must be between 1 and 100');
        }

        const queryString = JSON.stringify({
            selector: {
                department: department
            }
        });

        const queryResult = await ctx.stub.getQueryResultWithPagination(
            queryString,
            pageSizeNum,
            bookmark || ''
        );

        const records: ImmutableRecord[] = [];
        let result = await queryResult.iterator.next();

        while (!result.done) {
            const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
            const record = JSON.parse(strValue) as ImmutableRecord;
            records.push(record);
            result = await queryResult.iterator.next();
        }

        await queryResult.iterator.close();

        return {
            records,
            bookmark: queryResult.metadata.bookmark,
            totalCount: records.length
        };
    }

    /**
     * Check if a record exists
     * @param ctx - Transaction context
     * @param id - Record ID
     * @returns True if record exists, false otherwise
     */
    @Transaction(false)
    @Returns('boolean')
    public async RecordExists(ctx: Context, id: string): Promise<boolean> {
        this.validateInput(id, 'ID');

        const recordJSON = await ctx.stub.getState(id);
        return recordJSON && recordJSON.length > 0;
    }

    /**
     * Get the total count of records in the ledger
     * @param ctx - Transaction context
     * @returns Total number of records
     */
    @Transaction(false)
    @Returns('number')
    public async GetRecordCount(ctx: Context): Promise<number> {
        const queryString = '{"selector":{}}';
        const queryResult = await ctx.stub.getQueryResult(queryString);

        let count = 0;
        let result = await queryResult.next();

        while (!result.done) {
            count++;
            result = await queryResult.next();
        }

        await queryResult.close();
        return count;
    }

    /**
     * Validate input parameter
     * @param value - Value to validate
     * @param fieldName - Name of the field for error messages
     */
    private validateInput(value: string, fieldName: string): void {
        if (!value || value.trim().length === 0) {
            throw new Error(`${fieldName} cannot be empty`);
        }
    }

    /**
     * Validate email format
     * @param email - Email to validate
     * @returns True if email is valid, false otherwise
     */
    private isValidEmail(email: string): boolean {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
}
