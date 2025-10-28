import { IsNotEmpty, IsNumber, IsString, IsPositive } from 'class-validator';

export class CreateDepositDto {
  @IsNumber()
  @IsPositive()
  @IsNotEmpty()
  poolId: number;

  @IsString()
  @IsNotEmpty()
  userAddress: string;

  @IsString()
  @IsNotEmpty()
  amountUsd: string; // String to handle BigInt
}
