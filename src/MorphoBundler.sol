// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorphoBundler} from "./interfaces/IMorphoBundler.sol";
import {IPublicAllocator, Withdrawal} from "./interfaces/IPublicAllocator.sol";
import {MarketParams, Signature, Authorization, IMorpho} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {MorphoBalancesLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @title MorphoBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing interactions with Morpho.
abstract contract MorphoBundler is BaseBundler, IMorphoBundler {
    using SafeTransferLib for ERC20;
    using MorphoBalancesLib for IMorpho;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZERO_ADDRESS);

        MORPHO = IMorpho(morpho);
    }

    /* CALLBACKS */

    function onMorphoSupply(uint256, bytes calldata data) external {
        // Don't need to approve Morpho to pull tokens because it should already be approved max.
        _callback(data);
    }

    function onMorphoSupplyCollateral(uint256, bytes calldata data) external {
        // Don't need to approve Morpho to pull tokens because it should already be approved max.
        _callback(data);
    }

    function onMorphoRepay(uint256, bytes calldata data) external {
        // Don't need to approve Morpho to pull tokens because it should already be approved max.
        _callback(data);
    }

    function onMorphoFlashLoan(uint256, bytes calldata data) external {
        // Don't need to approve Morpho to pull tokens because it should already be approved max.
        _callback(data);
    }

    /* ACTIONS */

    /// @notice Approves `authorization.authorized` to manage `authorization.authorizer`'s position via EIP712
    /// `signature`.
    /// @param authorization The `Authorization` struct.
    /// @param signature The signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function morphoSetAuthorizationWithSig(
        Authorization calldata authorization,
        Signature calldata signature,
        bool skipRevert
    ) external payable protected {
        try MORPHO.setAuthorizationWithSig(authorization, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) _revert(returnData);
        }
    }

    /// @notice Supplies `assets` of the loan asset on behalf of `onBehalf`.
    /// @notice The supplied assets cannot be used as collateral but is eligible to earn interest.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// bundler is guaranteed to have `assets` tokens pulled from its balance, but the possibility to mint a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Initiator must have previously transferred their assets to the bundler.
    /// @param marketParams The Morpho market to supply assets to.
    /// @param assets The amount of assets to supply. Pass `type(uint256).max` to supply the bundler's loan asset
    /// balance.
    /// @param shares The amount of shares to mint.
    /// @param slippageAmount The minimum amount of supply shares to mint in exchange for `assets` when it is used.
    /// The maximum amount of assets to deposit in exchange for `shares` otherwise.
    /// @param onBehalf The address that will own the increased supply position.
    /// @param data Arbitrary data to pass to the `onMorphoSupply` callback. Pass empty data if not needed.
    function morphoSupply(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf,
        bytes calldata data
    ) external payable protected {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        // Don't always cap the assets to the bundler's balance because the liquidity can be transferred later
        // (via the `onMorphoSupply` callback).
        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        _approveMaxTo(marketParams.loanToken, address(MORPHO));

        (uint256 suppliedAssets, uint256 suppliedShares) = MORPHO.supply(marketParams, assets, shares, onBehalf, data);

        if (assets > 0) require(suppliedShares >= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
        else require(suppliedAssets <= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Supplies `assets` of collateral on behalf of `onBehalf`.
    /// @dev Initiator must have previously transferred their assets to the bundler.
    /// @param marketParams The Morpho market to supply collateral to.
    /// @param assets The amount of collateral to supply. Pass `type(uint256).max` to supply the bundler's loan asset
    /// balance.
    /// @param onBehalf The address that will own the increased collateral position.
    /// @param data Arbitrary data to pass to the `onMorphoSupplyCollateral` callback. Pass empty data if not needed.
    function morphoSupplyCollateral(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external payable protected {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        // Don't always cap the assets to the bundler's balance because the liquidity can be transferred later
        // (via the `onMorphoSupplyCollateral` callback).
        if (assets == type(uint256).max) assets = ERC20(marketParams.collateralToken).balanceOf(address(this));

        _approveMaxTo(marketParams.collateralToken, address(MORPHO));

        MORPHO.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    /// @notice Borrows `assets` of the loan asset on behalf of the initiator.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to borrow `assets` tokens, but the possibility to mint a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the bundler to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to borrow assets from.
    /// @param assets The amount of assets to borrow.
    /// @param shares The amount of shares to mint.
    /// @param slippageAmount The maximum amount of borrow shares to mint in exchange for `assets` when it is used.
    /// The minimum amount of assets to borrow in exchange for `shares` otherwise.
    /// @param receiver The address that will receive the borrowed assets.
    function morphoBorrow(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) external payable protected {
        (uint256 borrowedAssets, uint256 borrowedShares) =
            MORPHO.borrow(marketParams, assets, shares, initiator(), receiver);

        if (assets > 0) require(borrowedShares <= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
        else require(borrowedAssets >= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Repays `assets` of the loan asset on behalf of `onBehalf`.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// bundler is guaranteed to have `assets` tokens pulled from its balance, but the possibility to burn a specific
    /// amount of shares is given for full compatibility and precision.
    /// @param marketParams The Morpho market to repay assets to.
    /// @param assets The amount of assets to repay. Pass `type(uint256).max` to repay the bundler's loan asset balance.
    /// @param shares The amount of shares to burn.
    /// @param slippageAmount The minimum amount of borrow shares to burn in exchange for `assets` when it is used.
    /// The maximum amount of assets to deposit in exchange for `shares` otherwise.
    /// @param onBehalf The address of the owner of the debt position.
    /// @param data Arbitrary data to pass to the `onMorphoRepay` callback. Pass empty data if not needed.
    function morphoRepay(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address onBehalf,
        bytes calldata data
    ) external payable protected {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        // Don't always cap the assets to the bundler's balance because the liquidity can be transferred later
        // (via the `onMorphoRepay` callback).
        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        _approveMaxTo(marketParams.loanToken, address(MORPHO));

        (uint256 repaidAssets, uint256 repaidShares) = MORPHO.repay(marketParams, assets, shares, onBehalf, data);

        if (assets > 0) require(repaidShares >= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
        else require(repaidAssets <= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Withdraws `assets` of the loan asset on behalf of the initiator.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to withdraw `assets` tokens, but the possibility to burn a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the bundler to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to withdraw assets from.
    /// @param assets The amount of assets to withdraw.
    /// @param shares The amount of shares to burn.
    /// @param slippageAmount The maximum amount of supply shares to burn in exchange for `assets` when it is used.
    /// The minimum amount of assets to withdraw in exchange for `shares` otherwise.
    /// @param receiver The address that will receive the withdrawn assets.
    function morphoWithdraw(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) external payable protected {
        (uint256 withdrawnAssets, uint256 withdrawnShares) =
            MORPHO.withdraw(marketParams, assets, shares, initiator(), receiver);

        if (assets > 0) require(withdrawnShares <= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
        else require(withdrawnAssets >= slippageAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Withdraws `assets` of the collateral asset on behalf of the initiator.
    /// @dev Initiator must have previously authorized the bundler to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to withdraw collateral from.
    /// @param assets The amount of collateral to withdraw.
    /// @param receiver The address that will receive the collateral assets.
    function morphoWithdrawCollateral(MarketParams calldata marketParams, uint256 assets, address receiver)
        external
        payable
        protected
    {
        MORPHO.withdrawCollateral(marketParams, assets, initiator(), receiver);
    }

    /// @notice Triggers a flash loan on Morpho.
    /// @param token The address of the token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onMorphoFlashLoan` callback.
    function morphoFlashLoan(address token, uint256 assets, bytes calldata data) external payable protected {
        _approveMaxTo(token, address(MORPHO));

        MORPHO.flashLoan(token, assets, data);
    }

    /// @notice Reallocates funds from markets of a vault to another market of that same vault.
    /// @param publicAllocator The address of the public allocator.
    /// @param vault The address of the vault.
    /// @param value The value in ETH to pay for the reallocate fee.
    /// @param withdrawals The list of markets and corresponding amounts to withdraw.
    /// @param supplyMarketParams The market receiving the funds.
    function reallocateTo(
        address publicAllocator,
        address vault,
        uint256 value,
        Withdrawal[] calldata withdrawals,
        MarketParams calldata supplyMarketParams
    ) external payable protected {
        IPublicAllocator(publicAllocator).reallocateTo{value: value}(vault, withdrawals, supplyMarketParams);
    }

    /* INTERNAL */

    /// @dev Triggers `_multicall` logic during a callback.
    function _callback(bytes calldata data) internal {
        require(msg.sender == address(MORPHO), ErrorsLib.UNAUTHORIZED_SENDER);

        _multicall(abi.decode(data, (bytes[])));
    }

    /// @inheritdoc BaseBundler
    function _isSenderAuthorized() internal view virtual override returns (bool) {
        return super._isSenderAuthorized() || msg.sender == address(MORPHO);
    }
}
