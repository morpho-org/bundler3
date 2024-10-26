import { BigNumberish, BytesLike, Signature } from "ethers";

import {
  BaseBundler__factory,
  TransferBundler__factory,
  PermitBundler__factory,
  Permit2Bundler__factory,
  ERC4626Bundler__factory,
  MorphoBundler__factory,
  UrdBundler__factory,
  WNativeBundler__factory,
  StEthBundler__factory,
  EthereumPermitBundler__factory,
  IAllowanceTransfer,
  ERC20WrapperBundler__factory,
} from "../types";
import { AuthorizationStruct, MarketParamsStruct, WithdrawalStruct } from "../types/src/MorphoBundler";
import type { CallStruct} from "../types/src/Hub";
export type BundlerCall = CallStruct;

export type BundlerCalldata = string;
// export { CallStruct as BundlerCall } from "../types/src/Hub";

const BASE_BUNDLER_IFC = BaseBundler__factory.createInterface();
const TRANSFER_BUNDLER_IFC = TransferBundler__factory.createInterface();
const PERMIT_BUNDLER_IFC = PermitBundler__factory.createInterface();
const PERMIT2_BUNDLER_IFC = Permit2Bundler__factory.createInterface();
const ERC20_WRAPPER_BUNDLER_IFC = ERC20WrapperBundler__factory.createInterface();
const ERC4626_BUNDLER_IFC = ERC4626Bundler__factory.createInterface();
const MORPHO_BUNDLER_IFC = MorphoBundler__factory.createInterface();
const URD_BUNDLER_IFC = UrdBundler__factory.createInterface();
const WNATIVE_BUNDLER_IFC = WNativeBundler__factory.createInterface();
const ST_ETH_BUNDLER_IFC = StEthBundler__factory.createInterface();
const ETHEREUM_PERMIT_BUNDLER_IFC = EthereumPermitBundler__factory.createInterface();

/**
 * Class to easily encode calls to the Bundler contract, using ethers.
 */
export class BundlerAction {
  private genericBundler1Address: string;
  private ethereumBundler1Address: string;


  constructor(genericBundler1Address: string, ethereumBundler1Address: string) {
    this.genericBundler1Address = genericBundler1Address;
    this.ethereumBundler1Address = ethereumBundler1Address;
  }

  /* BaseBundler */

  /**
   * Encodes a call to a bundler to transfer native tokens (ETH on ethereum, MATIC on polygon, etc). Sends the transfer amount of native tokens from hub to the bundler as part of the hub to bundler call.
   * @param recipient The address to send native tokens to.
   * @param amount The amount of native tokens to send (in wei).
   * @param bundlerAddress The address of the bundler sending the native tokens.
   */
  nativeTransfer(recipient: string, amount: BigNumberish, bundlerAddress: string): BundlerCall {
    return {to: bundlerAddress, value: amount, data: BASE_BUNDLER_IFC.encodeFunctionData("nativeTransfer", [recipient, amount])};
  }

  /**
   * Encodes a call to the Bundler to transfer ERC20 tokens.
   * @param asset The address of the ERC20 token to transfer.
   * @param recipient The address to send tokens to.
   * @param amount The amount of tokens to send.
   */
  erc20Transfer(asset: string, recipient: string, amount: BigNumberish, bundlerAddress: string): BundlerCall {
    return {to: bundlerAddress, value: 0, data: BASE_BUNDLER_IFC.encodeFunctionData("erc20Transfer", [asset, recipient, amount])};
  }

  /**
   * Encodes a call to the Bundler to transfer ERC20 tokens from the sender to the Bundler.
   * @param asset The address of the ERC20 token to transfer.
   * @param receiver The address that will receive the assets.
   * @param amount The amount of tokens to send.
   */
  erc20TransferFrom(asset: string, receiver: string, amount: BigNumberish): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: TRANSFER_BUNDLER_IFC.encodeFunctionData("erc20TransferFrom", [asset, receiver, amount])};
  }

  /* Permit */

  /**
   * Encodes a call to the Bundler to permit an ERC20 token.
   * @param asset The address of the ERC20 token to permit.
   * @param spender The address allowed to spend the tokens.
   * @param amount The amount of tokens to permit.
   * @param deadline The timestamp until which the signature is valid.
   * @param signature The Ethers signature to permit the tokens.
   * @param skipRevert Whether to allow the permit to revert without making the whole multicall revert.
   */
  permit(
    asset: string,
    spender: string,
    amount: BigNumberish,
    deadline: BigNumberish,
    signature: Signature,
    skipRevert: boolean,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: PERMIT_BUNDLER_IFC.encodeFunctionData("permit", [
      asset,
      spender,
      amount,
      deadline,
      signature.v,
      signature.r,
      signature.s,
      skipRevert,
    ])};
  }

  /**
   * Encodes a call to the Bundler to permit DAI.
   * @param spender The address allowed to spend the Dai.
   * @param nonce The permit nonce used.
   * @param expiry The timestamp until which the signature is valid.
   * @param allowed The amount of DAI to permit.
   * @param signature The Ethers signature to permit the tokens.
   * @param skipRevert Whether to allow the permit to revert without making the whole multicall revert.
   */
  permitDai(
    spender: string,
    nonce: BigNumberish,
    expiry: BigNumberish,
    allowed: boolean,
    signature: Signature,
    skipRevert: boolean,
  ): BundlerCall {
    return {to: this.ethereumBundler1Address, value: 0, data: ETHEREUM_PERMIT_BUNDLER_IFC.encodeFunctionData("permitDai", [
      spender,
      nonce,
      expiry,
      allowed,
      signature.v,
      signature.r,
      signature.s,
      skipRevert,
    ])};
  }

  /* Permit2 */

  /**
   * Encodes a call to the Bundler to permit ERC20 tokens via Permit2.
   * @param permitSingle The permit details to submit to Permit2.
   * @param signature The Ethers signature to permit the tokens.
   * @param skipRevert Whether to allow the permit to revert without making the whole multicall revert.
   */
  approve2(
    permitSingle: IAllowanceTransfer.PermitSingleStruct,
    signature: Signature,
    skipRevert: boolean,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: PERMIT2_BUNDLER_IFC.encodeFunctionData("approve2", [permitSingle, signature.serialized, skipRevert])};
  }

  /**
   * Encodes a call to the Bundler to transfer ERC20 tokens via Permit2 from the sender to the Bundler.
   * @param asset The address of the ERC20 token to transfer.
   * @param receiver The address that will receive the assets.
   * @param amount The amount of tokens to send.
   */
  transferFrom2(asset: string, receiver: string, amount: BigNumberish): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: PERMIT2_BUNDLER_IFC.encodeFunctionData("transferFrom2", [asset, receiver, amount])};
  }

  /* ERC20 Wrapper */

  /**
   * Encodes a call to the Bundler to wrap ERC20 tokens via the provided ERC20Wrapper.
   * @param wrapper The address of the ERC20 wrapper token.
   * @param receiver The address that will receive the assets.
   * @param amount The amount of tokens to send.
   */
  erc20WrapperDepositFor(wrapper: string, receiver: string, amount: BigNumberish): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: ERC20_WRAPPER_BUNDLER_IFC.encodeFunctionData("erc20WrapperDepositFor", [wrapper, receiver, amount])};
  }

  /**
   * Encodes a call to the Bundler to unwrap ERC20 tokens from the provided ERC20Wrapper.
   * @param wrapper The address of the ERC20 wrapper token.
   * @param receiver The address to send the underlying ERC20 tokens.
   * @param amount The amount of tokens to send.
   */
  erc20WrapperWithdrawTo(wrapper: string, receiver: string, amount: BigNumberish): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: ERC20_WRAPPER_BUNDLER_IFC.encodeFunctionData("erc20WrapperWithdrawTo", [wrapper, receiver, amount])};
  }

  /* ERC4626 */

  /**
   * Encodes a call to the Bundler to mint shares of the provided ERC4626 vault.
   * @param erc4626 The address of the ERC4626 vault.
   * @param shares The amount of shares to mint.
   * @param maxAssets The maximum amount of assets to deposit (protects the sender from unexpected slippage).
   * @param receiver The address to send the shares to.
   */
  erc4626Mint(
    erc4626: string,
    shares: BigNumberish,
    maxAssets: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: ERC4626_BUNDLER_IFC.encodeFunctionData("erc4626Mint", [erc4626, shares, maxAssets, receiver])};
  }

  /**
   * Encodes a call to the Bundler to deposit assets into the provided ERC4626 vault.
   * @param erc4626 The address of the ERC4626 vault.
   * @param assets The amount of assets to deposit.
   * @param minShares The minimum amount of shares to mint (protects the sender from unexpected slippage).
   * @param receiver The address to send the shares to.
   */
  erc4626Deposit(
    erc4626: string,
    assets: BigNumberish,
    minShares: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: ERC4626_BUNDLER_IFC.encodeFunctionData("erc4626Deposit", [erc4626, assets, minShares, receiver])};
  }

  /**
   * Encodes a call to the Bundler to withdraw assets from the provided ERC4626 vault.
   * @param erc4626 The address of the ERC4626 vault.
   * @param assets The amount of assets to withdraw.
   * @param maxShares The maximum amount of shares to redeem (protects the sender from unexpected slippage).
   * @param receiver The address to send the assets to.
   */
  erc4626Withdraw(
    erc4626: string,
    assets: BigNumberish,
    maxShares: BigNumberish,
    receiver: string,
    owner: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: ERC4626_BUNDLER_IFC.encodeFunctionData("erc4626Withdraw", [erc4626, assets, maxShares, receiver, owner])};
  }

  /**
   * Encodes a call to the Bundler to redeem shares from the provided ERC4626 vault.
   * @param erc4626 The address of the ERC4626 vault.
   * @param shares The amount of shares to redeem.
   * @param minAssets The minimum amount of assets to withdraw (protects the sender from unexpected slippage).
   * @param receiver The address to send the assets to.
   */
  erc4626Redeem(
    erc4626: string,
    shares: BigNumberish,
    minAssets: BigNumberish,
    receiver: string,
    owner: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: ERC4626_BUNDLER_IFC.encodeFunctionData("erc4626Redeem", [erc4626, shares, minAssets, receiver, owner])};
  }

  /* Morpho */

  /**
   * Encodes a call to the Bundler to authorize an account on Morpho Blue.
   * @param authorization The authorization details to submit to Morpho Blue.
   * @param signature The Ethers signature to authorize the account.
   * @param skipRevert Whether to allow the authorization call to revert without making the whole multicall revert.
   */
  morphoSetAuthorizationWithSig(
    authorization: AuthorizationStruct,
    signature: Signature,
    skipRevert: boolean,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSetAuthorizationWithSig", [
      authorization,
      { v: signature.v, r: signature.r, s: signature.s },
      skipRevert,
    ])};
  }

  /**
   * Encodes a call to the Bundler to supply to a Morpho Blue market.
   * @param market The market params to supply to.
   * @param assets The amount of assets to supply.
   * @param shares The amount of supply shares to mint.
   * @param slippageAmount The maximum (resp. minimum) amount of assets (resp. supply shares) to supply (resp. mint) (protects the sender from unexpected slippage).
   * @param onBehalf The address to supply on behalf of.
   * @param callbackCalls The array of calls to execute inside Morpho Blue's `onMorphoSupply` callback.
   */
  morphoSupply(
    market: MarketParamsStruct,
    assets: BigNumberish,
    shares: BigNumberish,
    slippageAmount: BigNumberish,
    onBehalf: string,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSupply", [
      market,
      assets,
      shares,
      slippageAmount,
      onBehalf,
      MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ])};
  }

  /**
   * Encodes a call to the Bundler to supply collateral to a Morpho Blue market.
   * @param market The market params to supply to.
   * @param assets The amount of assets to supply.
   * @param onBehalf The address to supply on behalf of.
   * @param callbackCalls The array of calls to execute inside Morpho Blue's `onMorphoSupplyCollateral` callback.
   */
  morphoSupplyCollateral(
    market: MarketParamsStruct,
    assets: BigNumberish,
    onBehalf: string,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSupplyCollateral", [
      market,
      assets,
      onBehalf,
      MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ])};
  }

  /**
   * Encodes a call to the Bundler to borrow from a Morpho Blue market.
   * @param market The market params to borrow from.
   * @param assets The amount of assets to borrow.
   * @param shares The amount of borrow shares to mint.
   * @param slippageAmount The minimum (resp. maximum) amount of assets (resp. borrow shares) to borrow (resp. mint) (protects the sender from unexpected slippage).
   * @param receiver The address to send borrowed tokens to.
   */
  morphoBorrow(
    market: MarketParamsStruct,
    assets: BigNumberish,
    shares: BigNumberish,
    slippageAmount: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoBorrow", [market, assets, shares, slippageAmount, receiver])};
  }

  /**
   * Encodes a call to the Bundler to repay to a Morpho Blue market.
   * @param market The market params to repay to.
   * @param assets The amount of assets to repay.
   * @param shares The amount of borrow shares to redeem.
   * @param slippageAmount The maximum (resp. minimum) amount of assets (resp. borrow shares) to repay (resp. redeem) (protects the sender from unexpected slippage).
   * @param onBehalf The address to repay on behalf of.
   * @param callbackCalls The array of calls to execute inside Morpho Blue's `onMorphoSupply` callback.
   */
  morphoRepay(
    market: MarketParamsStruct,
    assets: BigNumberish,
    shares: BigNumberish,
    slippageAmount: BigNumberish,
    onBehalf: string,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoRepay", [
      market,
      assets,
      shares,
      slippageAmount,
      onBehalf,
      MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ])};
  }

  /**
   * Encodes a call to the Bundler to withdraw from a Morpho Blue market.
   * @param market The market params to withdraw from.
   * @param assets The amount of assets to withdraw.
   * @param shares The amount of supply shares to redeem.
   * @param slippageAmount The minimum (resp. maximum) amount of assets (resp. supply shares) to withdraw (resp. redeem) (protects the sender from unexpected slippage).
   * @param receiver The address to send withdrawn tokens to.
   */
  morphoWithdraw(
    market: MarketParamsStruct,
    assets: BigNumberish,
    shares: BigNumberish,
    slippageAmount: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoWithdraw", [market, assets, shares, slippageAmount, receiver])};
  }

  /**
   * Encodes a call to the Bundler to withdraw collateral from a Morpho Blue market.
   * @param market The market params to withdraw from.
   * @param assets The amount of assets to withdraw.
   * @param receiver The address to send withdrawn tokens to.
   */
  morphoWithdrawCollateral(
    market: MarketParamsStruct,
    assets: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoWithdrawCollateral", [market, assets, receiver])};
  }

  /**
   * Encodes a call to the Bundler to flash loan from Morpho Blue.
   * @param asset The address of the ERC20 token to flash loan.
   * @param amount The amount of tokens to flash loan.
   * @param callbackCalls The array of calls to execute inside Morpho Blue's `onMorphoFlashLoan` callback.
   */
  morphoFlashLoan(asset: string, amount: BigNumberish, callbackCalls: BundlerCall[]): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("morphoFlashLoan", [
      asset,
      amount,
      MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ])};
  }

  /**
   * Encodes a call to the Bundler to trigger a public reallocation on the PublicAllocator.
   * @param publicAllocator The address of the PublicAllocator to use.
   * @param vault The vault to reallocate.
   * @param value The value of the call. Can be used to pay the vault reallocation fees.
   * @param withdrawals The array of withdrawals to perform, before supplying everything to the supply market.
   * @param supplyMarketParams The market params to reallocate to.
   */
  metaMorphoReallocateTo(
    publicAllocator: string,
    vault: string,
    value: BigNumberish,
    withdrawals: WithdrawalStruct[],
    supplyMarketParams: MarketParamsStruct,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: MORPHO_BUNDLER_IFC.encodeFunctionData("reallocateTo", [
      publicAllocator,
      vault,
      value,
      withdrawals,
      supplyMarketParams,
    ])};
  }

  /* Universal Rewards Distributor */

  /**
   * Encodes a call to the Bundler to claim rewards from the Universal Rewards Distributor.
   * @param distributor The address of the distributor to claim rewards from.
   * @param account The address to claim rewards for.
   * @param reward The address of the reward token to claim.
   * @param amount The amount of rewards to claim.
   * @param proof The Merkle proof to claim the rewards.
   * @param skipRevert Whether to allow the claim to revert without making the whole multicall revert.
   */
  urdClaim(
    distributor: string,
    account: string,
    reward: string,
    amount: BigNumberish,
    proof: BytesLike[],
    skipRevert: boolean,
  ): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: URD_BUNDLER_IFC.encodeFunctionData("urdClaim", [distributor, account, reward, amount, proof, skipRevert])};
  }

  /* Wrapped Native */

  /**
   * Encodes a call to the Bundler to wrap native tokens (ETH to WETH on ethereum, MATIC to WMATIC on polygon, etc).
   * @param amount The amount of native tokens to wrap (in wei).
   * @param receiver The address that will receive the assets.
   */
  wrapNative(amount: BigNumberish, receiver: string): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: WNATIVE_BUNDLER_IFC.encodeFunctionData("wrapNative", [amount, receiver])};
  }

  /**
   * Encodes a call to the Bundler to unwrap native tokens (WETH to ETH on ethereum, WMATIC to MATIC on polygon, etc).
   * @param amount The amount of native tokens to unwrap (in wei).
   * @param receiver The address that will receive the assets.
   */
  unwrapNative(amount: BigNumberish, receiver: string): BundlerCall {
    return {to: this.genericBundler1Address, value: 0, data: WNATIVE_BUNDLER_IFC.encodeFunctionData("unwrapNative", [amount, receiver])};
  }

  /* stETH */

  /**
   * Encodes a call to the Bundler to stake native tokens using Lido (ETH to stETH on ethereum).
   * @param amount The amount of native tokens to stake (in wei). This amount will be sent from the hub to the bundler.
   * @param minShares The minimum amount of shares to mint (protects the sender from unexpected slippage).
   * @param referral The referral address to use.
   * @param receiver The address that will receive the assets.
   */
  stakeEth(amount: BigNumberish, minShares: BigNumberish, referral: string, receiver: string): BundlerCall {
    return {to: this.ethereumBundler1Address, value: amount, data: ST_ETH_BUNDLER_IFC.encodeFunctionData("stakeEth", [amount, minShares, referral, receiver])};
  }

  /* Wrapped stETH */

  /**
   * Encodes a call to the Bundler to wrap stETH (stETH to wstETH on ethereum).
   * @param amount The amount of stETH to wrap (in wei).
   * @param receiver The address that will receive the assets.
   */
  wrapStEth(amount: BigNumberish, receiver: string): BundlerCall {
    return {to: this.ethereumBundler1Address, value: 0, data: ST_ETH_BUNDLER_IFC.encodeFunctionData("wrapStEth", [amount, receiver])};
  }

  /**
   * Encodes a call to the Bundler to unwrap wstETH (wstETH to stETH on ethereum).
   * @param amount The amount of wstETH to unwrap (in wei).
   * @param receiver The address that will receive the assets.
   */
  unwrapStEth(amount: BigNumberish, receiver: string): BundlerCall {
    return {to: this.ethereumBundler1Address, value: 0, data: ST_ETH_BUNDLER_IFC.encodeFunctionData("unwrapStEth", [amount, receiver])};
  }
}

export default BundlerAction;
