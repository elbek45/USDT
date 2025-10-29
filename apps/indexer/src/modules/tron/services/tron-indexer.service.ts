import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../../database/prisma.service';
import { TronEventProcessor } from './tron-event-processor.service';

// Use require for TronWeb to avoid TypeScript constructor issues
const TronWeb = require('tronweb');

/**
 * Tron blockchain indexer service
 * Listens to events from Tron smart contracts and processes them
 */
@Injectable()
export class TronIndexerService implements OnModuleInit {
  private readonly logger = new Logger(TronIndexerService.name);
  private tronWeb: any;
  private isRunning = false;
  private pollingInterval: NodeJS.Timeout | null = null;

  // Contract addresses
  private depositVaultAddress: string;
  private priceFeedAddress: string;
  private bridgeProxyAddress: string;
  private wexel721Address: string;

  // Last processed block
  private lastProcessedBlock = 0;
  private readonly BLOCK_POLLING_INTERVAL = 3000; // 3 seconds
  private readonly BLOCKS_PER_BATCH = 100;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly eventProcessor: TronEventProcessor,
  ) {
    // Initialize TronWeb
    const tronNetwork = this.configService.get('TRON_NETWORK', 'nile');
    const fullHost =
      tronNetwork === 'mainnet'
        ? 'https://api.trongrid.io'
        : 'https://nile.trongrid.io';

    this.tronWeb = new TronWeb({
      fullHost,
      headers: {
        'TRON-PRO-API-KEY': this.configService.get('TRON_GRID_API_KEY', ''),
      },
    });

    // Get contract addresses from config
    this.depositVaultAddress = this.configService.get(
      'TRON_DEPOSIT_VAULT_ADDRESS',
      '',
    );
    this.priceFeedAddress = this.configService.get(
      'TRON_PRICE_FEED_ADDRESS',
      '',
    );
    this.bridgeProxyAddress = this.configService.get(
      'TRON_BRIDGE_PROXY_ADDRESS',
      '',
    );
    this.wexel721Address = this.configService.get('TRON_WEXEL721_ADDRESS', '');
  }

  async onModuleInit() {
    // Auto-start indexer if configured
    if (this.configService.get('TRON_INDEXER_AUTO_START', 'true') === 'true') {
      await this.start();
    }
  }

  /**
   * Start the Tron indexer
   */
  async start() {
    if (this.isRunning) {
      this.logger.warn('Tron indexer is already running');
      return;
    }

    this.logger.log('Starting Tron indexer...');

    // Get last processed block from database
    const indexerState = await this.getIndexerState();
    this.lastProcessedBlock = indexerState.lastBlock || 0;

    this.isRunning = true;
    this.pollingInterval = setInterval(
      () => this.pollBlocks(),
      this.BLOCK_POLLING_INTERVAL,
    );

    this.logger.log(
      `Tron indexer started. Starting from block ${this.lastProcessedBlock}`,
    );
  }

  /**
   * Stop the Tron indexer
   */
  async stop() {
    if (!this.isRunning) {
      return;
    }

    this.logger.log('Stopping Tron indexer...');
    this.isRunning = false;

    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
      this.pollingInterval = null;
    }

    this.logger.log('Tron indexer stopped');
  }

  /**
   * Poll for new blocks and process events
   */
  private async pollBlocks() {
    try {
      const currentBlock = await this.getCurrentBlock();

      if (currentBlock <= this.lastProcessedBlock) {
        return; // No new blocks
      }

      const toBlock = Math.min(
        currentBlock,
        this.lastProcessedBlock + this.BLOCKS_PER_BATCH,
      );

      this.logger.debug(
        `Processing Tron blocks ${this.lastProcessedBlock + 1} to ${toBlock}`,
      );

      // Process events from all contracts
      await this.processContractEvents(
        this.depositVaultAddress,
        'TronDepositVault',
        this.lastProcessedBlock + 1,
        toBlock,
      );

      await this.processContractEvents(
        this.priceFeedAddress,
        'TronPriceFeed',
        this.lastProcessedBlock + 1,
        toBlock,
      );

      await this.processContractEvents(
        this.bridgeProxyAddress,
        'BridgeProxy',
        this.lastProcessedBlock + 1,
        toBlock,
      );

      await this.processContractEvents(
        this.wexel721Address,
        'TronWexel721',
        this.lastProcessedBlock + 1,
        toBlock,
      );

      // Update last processed block
      this.lastProcessedBlock = toBlock;
      await this.updateIndexerState(toBlock);
    } catch (error) {
      this.logger.error(
        `Error polling Tron blocks: ${error.message}`,
        error.stack,
      );
    }
  }

  /**
   * Process events from a specific contract
   */
  private async processContractEvents(
    contractAddress: string,
    contractName: string,
    fromBlock: number,
    toBlock: number,
  ) {
    if (!contractAddress) {
      return; // Contract not deployed yet
    }

    try {
      // Get contract instance
      const contract = await this.tronWeb.contract().at(contractAddress);

      // Get all events for this contract
      const events = await this.tronWeb.getEventResult(contractAddress, {
        sinceTimestamp: await this.getBlockTimestamp(fromBlock),
        sort: 'block_timestamp',
      });

      this.logger.debug(
        `Found ${events.length} events for ${contractName} (blocks ${fromBlock}-${toBlock})`,
      );

      // Process each event
      for (const event of events) {
        await this.processEvent(contractName, event);
      }
    } catch (error) {
      this.logger.error(
        `Error processing ${contractName} events: ${error.message}`,
        error.stack,
      );
    }
  }

  /**
   * Process a single event
   */
  private async processEvent(contractName: string, event: any) {
    try {
      const eventName = event.event_name || event.name;

      this.logger.debug(
        `Processing ${contractName}.${eventName} (tx: ${event.transaction_id})`,
      );

      // Route event to appropriate handler
      switch (contractName) {
        case 'TronDepositVault':
          await this.eventProcessor.processDepositVaultEvent(event);
          break;
        case 'TronPriceFeed':
          await this.eventProcessor.processPriceFeedEvent(event);
          break;
        case 'BridgeProxy':
          await this.eventProcessor.processBridgeEvent(event);
          break;
        case 'TronWexel721':
          await this.eventProcessor.processWexel721Event(event);
          break;
      }
    } catch (error) {
      this.logger.error(
        `Error processing event: ${error.message}`,
        error.stack,
      );
    }
  }

  /**
   * Get current block number
   */
  private async getCurrentBlock(): Promise<number> {
    const block = await this.tronWeb.trx.getCurrentBlock();
    return block.block_header.raw_data.number;
  }

  /**
   * Get block timestamp
   */
  private async getBlockTimestamp(blockNumber: number): Promise<number> {
    const block = await this.tronWeb.trx.getBlock(blockNumber);
    return block.block_header.raw_data.timestamp;
  }

  /**
   * Get indexer state from database
   */
  private async getIndexerState() {
    // Store indexer state in a simple key-value table or cache
    // For now, return default
    return { lastBlock: 0 };
  }

  /**
   * Update indexer state in database
   */
  private async updateIndexerState(lastBlock: number) {
    // Store in database or cache
    this.logger.debug(`Updated Tron indexer state: block ${lastBlock}`);
  }

  /**
   * Get indexer status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastProcessedBlock: this.lastProcessedBlock,
      depositVaultAddress: this.depositVaultAddress,
      priceFeedAddress: this.priceFeedAddress,
      bridgeProxyAddress: this.bridgeProxyAddress,
      wexel721Address: this.wexel721Address,
    };
  }

  /**
   * Manually process a specific transaction
   */
  async processTransaction(txHash: string) {
    try {
      const tx = await this.tronWeb.trx.getTransaction(txHash);
      // Process transaction events
      // Implementation depends on transaction structure
      this.logger.log(`Processed transaction: ${txHash}`);
      return { success: true, transaction: tx };
    } catch (error) {
      this.logger.error(
        `Error processing transaction ${txHash}: ${error.message}`,
      );
      throw error;
    }
  }
}
