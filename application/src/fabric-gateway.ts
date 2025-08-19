import { Gateway, Network, Contract, Identity, Signer, signers, connect } from '@hyperledger/fabric-gateway';
import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { 
    ImmutableRecord, 
    CreateRecordInput, 
    PaginatedQueryResult, 
    RecordHistoryEntry 
} from './models/record';

/**
 * Fabric Gateway service for interacting with the Hyperledger Fabric network
 */
export class FabricGatewayService {
    private gateway?: Gateway;
    private network?: Network;
    private contract?: Contract;
    private readonly channelName = 'mychannel';
    private readonly chaincodeName = 'immutable-records';

    /**
     * Initialize the connection to the Fabric network
     */
    public async initialize(): Promise<void> {
        try {
            // Create gRPC connection
            const client = await this.newGrpcConnection();

            // Create gateway connection
            this.gateway = connect({
                client,
                identity: await this.newIdentity(),
                signer: await this.newSigner(),
                evaluateOptions: () => {
                    return { deadline: Date.now() + 5000 }; // 5 seconds
                },
                endorseOptions: () => {
                    return { deadline: Date.now() + 15000 }; // 15 seconds
                },
                submitOptions: () => {
                    return { deadline: Date.now() + 5000 }; // 5 seconds
                },
                commitStatusOptions: () => {
                    return { deadline: Date.now() + 60000 }; // 1 minute
                },
            });

            // Get network and contract
            if (!this.gateway) {
                throw new Error('Failed to create gateway connection');
            }
            this.network = this.gateway.getNetwork(this.channelName);
            this.contract = this.network.getContract(this.chaincodeName);

            console.log('Successfully connected to Fabric network');
        } catch (error) {
            console.error('Failed to initialize Fabric Gateway:', error);
            throw error;
        }
    }

    /**
     * Close the gateway connection
     */
    public async close(): Promise<void> {
        if (this.gateway) {
            this.gateway.close();
            console.log('Gateway connection closed');
        }
    }

    /**
     * Initialize the ledger with sample data
     */
    public async initLedger(): Promise<void> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            await this.contract!.submitTransaction('InitLedger');
            console.log('Ledger initialized successfully');
        } catch (error) {
            console.error('Failed to initialize ledger:', error);
            throw error;
        }
    }

    /**
     * Create a new record
     */
    public async createRecord(input: CreateRecordInput): Promise<ImmutableRecord> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const result = await this.contract!.submitTransaction(
                'CreateRecord',
                input.id,
                input.name,
                input.email,
                input.department
            );

            return JSON.parse(result.toString()) as ImmutableRecord;
        } catch (error) {
            console.error('Failed to create record:', error);
            throw error;
        }
    }

    /**
     * Read a record by ID
     */
    public async readRecord(id: string): Promise<ImmutableRecord> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const result = await this.contract!.evaluateTransaction('ReadRecord', id);
            return JSON.parse(result.toString()) as ImmutableRecord;
        } catch (error) {
            console.error('Failed to read record:', error);
            throw error;
        }
    }

    /**
     * Get all records with pagination
     */
    public async getAllRecords(bookmark?: string, pageSize?: number): Promise<PaginatedQueryResult<ImmutableRecord>> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const args: string[] = [];
            if (bookmark) args.push(bookmark);
            if (pageSize) args.push(pageSize.toString());

            const result = await this.contract!.evaluateTransaction('GetAllRecords', ...args);
            return JSON.parse(result.toString()) as PaginatedQueryResult<ImmutableRecord>;
        } catch (error) {
            console.error('Failed to get all records:', error);
            throw error;
        }
    }

    /**
     * Get record history
     */
    public async getRecordHistory(id: string): Promise<RecordHistoryEntry[]> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const result = await this.contract!.evaluateTransaction('GetRecordHistory', id);
            return JSON.parse(result.toString()) as RecordHistoryEntry[];
        } catch (error) {
            console.error('Failed to get record history:', error);
            throw error;
        }
    }

    /**
     * Query records by department
     */
    public async queryRecordsByDepartment(
        department: string, 
        bookmark?: string, 
        pageSize?: number
    ): Promise<PaginatedQueryResult<ImmutableRecord>> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const args: string[] = [department];
            if (bookmark) args.push(bookmark);
            if (pageSize) args.push(pageSize.toString());

            const result = await this.contract!.evaluateTransaction('QueryRecordsByDepartment', ...args);
            return JSON.parse(result.toString()) as PaginatedQueryResult<ImmutableRecord>;
        } catch (error) {
            console.error('Failed to query records by department:', error);
            throw error;
        }
    }

    /**
     * Check if a record exists
     */
    public async recordExists(id: string): Promise<boolean> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const result = await this.contract!.evaluateTransaction('RecordExists', id);
            return result.toString() === 'true';
        } catch (error) {
            console.error('Failed to check record existence:', error);
            throw error;
        }
    }

    /**
     * Get total record count
     */
    public async getRecordCount(): Promise<number> {
        if (!this.contract) {
            throw new Error('Contract not initialized');
        }

        try {
            const result = await this.contract!.evaluateTransaction('GetRecordCount');
            return parseInt(result.toString(), 10);
        } catch (error) {
            console.error('Failed to get record count:', error);
            throw error;
        }
    }

    /**
     * Check network health
     */
    public async checkHealth(): Promise<boolean> {
        try {
            if (!this.contract) {
                return false;
            }

            // Try to get record count as a health check
            await this.getRecordCount();
            return true;
        } catch (error) {
            console.error('Health check failed:', error);
            return false;
        }
    }

    /**
     * Create a new gRPC connection
     */
    private async newGrpcConnection(): Promise<grpc.Client> {
        const tlsRootCert = await fs.promises.readFile(
            path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', 'org1.example.com', 'peers', 'peer0.org1.example.com', 'tls', 'ca.crt')
        );
        const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
        return new grpc.Client('localhost:7051', tlsCredentials, {
            'grpc.ssl_target_name_override': 'peer0.org1.example.com',
        });
    }

    /**
     * Create a new identity
     */
    private async newIdentity(): Promise<Identity> {
        const credentials = await fs.promises.readFile(
            path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', 'org1.example.com', 'users', 'User1@org1.example.com', 'msp', 'signcerts', 'cert.pem')
        );
        const mspId = 'Org1MSP';
        return { mspId, credentials };
    }

    /**
     * Create a new signer
     */
    private async newSigner(): Promise<Signer> {
        const privateKeyPem = await fs.promises.readFile(
            path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', 'org1.example.com', 'users', 'User1@org1.example.com', 'msp', 'keystore', 'priv_sk')
        );
        const privateKey = crypto.createPrivateKey(privateKeyPem);
        return signers.newPrivateKeySigner(privateKey);
    }
}
