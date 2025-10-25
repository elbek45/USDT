export interface User {
  id: string;
  solanaAddress?: string;
  tronAddress?: string;
  email?: string;
  telegramId?: string;
  isKycVerified: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Pool {
  id: number;
  apyBaseBp: number;
  lockMonths: number;
  minDepositUsd: string;
  totalLiquidity: string;
  totalWexels: string;
  boostTargetBp: number;
  boostMaxBp: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Wexel {
  id: string;
  ownerSolana?: string;
  ownerTron?: string;
  poolId: number;
  principalUsd: string;
  apyBaseBp: number;
  apyBoostBp: number;
  startTs: string;
  endTs: string;
  isCollateralized: boolean;
  totalClaimedUsd: string;
  nftMintAddress?: string;
  nftTokenAddress?: string;
  createdAt: string;
  updatedAt: string;
  pool?: Pool;
  collateralPosition?: CollateralPosition;
  listings?: Listing[];
  claims?: Claim[];
  boosts?: Boost[];
}

export interface CollateralPosition {
  wexelId: string;
  loanUsd: string;
  startTs: string;
  repaid: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Listing {
  id: string;
  wexelId: string;
  askPriceUsd: string;
  auction: boolean;
  minBidUsd?: string;
  expiryTs?: string;
  status: "active" | "sold" | "cancelled";
  createdAt: string;
  updatedAt: string;
}

export interface Claim {
  id: string;
  wexelId: string;
  amountUsd: string;
  claimType: "daily" | "final" | "partial";
  txHash?: string;
  createdAt: string;
}

export interface Boost {
  id: string;
  wexelId: string;
  tokenMint: string;
  amount: string;
  valueUsd: string;
  apyBoostBp: number;
  priceUsd: string;
  createdAt: string;
}

export interface TokenPrice {
  id: string;
  tokenMint: string;
  priceUsd: string;
  source: string;
  updatedAt: string;
}

export interface AuthResponse {
  access_token: string;
  user: User;
}

export interface LoginRequest {
  solanaAddress: string;
  signature: string;
}

export interface CreatePoolRequest {
  apy_base_bp: number;
  lock_months: number;
  min_deposit_usd: string;
  boost_target_bp?: number;
  boost_max_bp?: number;
}

export interface UpdatePoolRequest {
  apy_base_bp?: number;
  lock_months?: number;
  min_deposit_usd?: string;
  boost_target_bp?: number;
  boost_max_bp?: number;
  is_active?: boolean;
}

export interface ClaimRewardsRequest {
  amount: string;
  txHash?: string;
}

export interface CollateralizeRequest {
  wexelId: string;
}

export interface RepayLoanRequest {
  wexelId: string;
  amount: string;
}

export interface UpdatePriceRequest {
  tokenMint: string;
  priceUsd: string;
  source: string;
}

export interface CalculateBoostRequest {
  tokenMint: string;
  amount: string;
}

export interface ApiResponse<T = any> {
  data?: T;
  message?: string;
  error?: string;
}

export interface PaginatedResponse<T = any> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface Stats {
  totalPools: number;
  totalLiquidity: string;
  totalWexels: string;
  totalUsers?: number;
  totalVolume?: string;
}

export interface UserStats {
  totalWexels: number;
  totalDeposits: string;
  totalClaims: string;
}

export interface RewardsCalculation {
  wexelId: string;
  principal: string;
  apyBase: number;
  apyBoost: number;
  totalApy: number;
  dailyReward: string;
  daysElapsed: number;
  totalDays: number;
  totalRewards: string;
  claimedRewards: string;
  pendingRewards: string;
  isMatured: boolean;
}
