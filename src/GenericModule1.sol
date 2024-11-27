// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {BaseModule} from "./BaseModule.sol";

import {IPublicAllocator, Withdrawal} from "./interfaces/IPublicAllocator.sol";
import {MarketParams, Signature, Authorization, IMorpho} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IAllowanceTransfer} from "../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {ModuleLib} from "./libraries/ModuleLib.sol";
import {SafeCast160} from "../lib/permit2/src/libraries/SafeCast160.sol";
import {IUniversalRewardsDistributor} from
    "../lib/universal-rewards-distributor/src/interfaces/IUniversalRewardsDistributor.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Permit2Lib} from "../lib/permit2/src/libraries/Permit2Lib.sol";
import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20Wrapper} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {MathRayLib} from "./libraries/MathRayLib.sol";

/// @title GenericModule1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Chain agnostic module contract n°1.
contract GenericModule1 is BaseModule {
    using SafeCast160 for uint256;
    using SafeTransferLib for ERC20;
    using MathRayLib for uint256;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable MORPHO;

    /// @dev The address of the wrapped native token contract.
    IWNative public immutable WRAPPED_NATIVE;

    /* CONSTRUCTOR */

    constructor(address bundler, address morpho, address wNative) BaseModule(bundler) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());
        require(wNative != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
        WRAPPED_NATIVE = IWNative(wNative);
    }

    /* ERC20 WRAPPER ACTIONS */

    // Enables the wrapping and unwrapping of ERC20 tokens. The largest usecase is to wrap permissionless tokens to
    // their permissioned counterparts and access permissioned markets on Morpho Blue. Permissioned tokens can be built
    // using: https://github.com/morpho-org/erc20-permissioned

    /// @notice Wraps underlying tokens to wrapped token.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The account receiving the wrapped tokens.
    /// @param amount The amount of underlying tokens to deposit. Pass `type(uint).max` to deposit the module's
    /// underlying balance.
    function erc20WrapperDepositFor(address wrapper, address receiver, uint256 amount) external onlyBundler {
        ERC20 underlying = ERC20(address(ERC20Wrapper(wrapper).underlying()));

        if (amount == type(uint256).max) amount = underlying.balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(address(underlying), wrapper);

        require(ERC20Wrapper(wrapper).depositFor(receiver, amount), ErrorsLib.DepositFailed());
    }

    /// @notice Unwraps wrapped token to underlying token.
    /// @dev Wrapped tokens must have been previously sent to the module.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Pass `type(uint).max` to burn the module's wrapped token
    /// balance.
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        if (amount == type(uint256).max) amount = ERC20(wrapper).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }

    /* ERC4626 ACTIONS */

    /// @notice Mints shares of a ERC4626 vault.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes the given vault implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param shares The amount of vault shares to mint.
    /// @param maxSharePriceE27 The maximum amount of assets to pay to get 1 share, scaled by 1e27.
    /// @param receiver The address to which shares will be minted.
    function erc4626Mint(address vault, uint256 shares, uint256 maxSharePriceE27, address receiver)
        external
        onlyBundler
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(shares != 0, ErrorsLib.ZeroShares());

        ModuleLib.approveMaxToIfAllowanceZero(IERC4626(vault).asset(), vault);

        uint256 assets = IERC4626(vault).mint(shares, receiver);
        require(assets.rDivUp(shares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Deposits underlying token in a ERC4626 vault.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes the given vault implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param assets The amount of underlying token to deposit. Pass `type(uint).max` to deposit the module's balance.
    /// @param maxSharePriceE27 The maximum amount of assets to pay to get 1 share, scaled by 1e27.
    /// @param receiver The address to which shares will be minted.
    function erc4626Deposit(address vault, uint256 assets, uint256 maxSharePriceE27, address receiver)
        external
        onlyBundler
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address underlyingToken = IERC4626(vault).asset();
        if (assets == type(uint256).max) assets = ERC20(underlyingToken).balanceOf(address(this));

        require(assets != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(underlyingToken, vault);

        uint256 shares = IERC4626(vault).deposit(assets, receiver);
        require(assets.rDivUp(shares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws underlying token from a ERC4626 vault.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the module to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the module.
    /// @param vault The address of the vault.
    /// @param assets The amount of underlying token to withdraw.
    /// @param minSharePriceE27 the minimum number of assets to receive per share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the assets are withdrawn. Can only be the module or the initiator.
    function erc4626Withdraw(address vault, uint256 assets, uint256 minSharePriceE27, address receiver, address owner)
        external
        onlyBundler
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == initiator(), ErrorsLib.UnexpectedOwner(owner));
        require(assets != 0, ErrorsLib.ZeroAmount());

        uint256 shares = IERC4626(vault).withdraw(assets, receiver, owner);
        require(assets.rDivDown(shares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Redeems shares of a ERC4626 vault.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the module to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the module.
    /// @param vault The address of the vault.
    /// @param shares The amount of vault shares to redeem. Pass `type(uint).max` to redeem the owner's shares.
    /// @param minSharePriceE27 the minimum number of assets to receive per share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the shares are redeemed. Can only be the module or the initiator.
    function erc4626Redeem(address vault, uint256 shares, uint256 minSharePriceE27, address receiver, address owner)
        external
        onlyBundler
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == initiator(), ErrorsLib.UnexpectedOwner(owner));

        if (shares == type(uint256).max) shares = IERC4626(vault).balanceOf(owner);

        require(shares != 0, ErrorsLib.ZeroShares());

        uint256 assets = IERC4626(vault).redeem(shares, receiver, owner);
        require(assets.rDivDown(shares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /* MORPHO CALLBACKS */

    function onMorphoSupply(uint256, bytes calldata data) external {
        _morphoCallback(data);
    }

    function onMorphoSupplyCollateral(uint256, bytes calldata data) external {
        _morphoCallback(data);
    }

    function onMorphoRepay(uint256, bytes calldata data) external {
        _morphoCallback(data);
    }

    function onMorphoFlashLoan(uint256, bytes calldata data) external {
        _morphoCallback(data);
    }

    /* MORPHO ACTIONS */

    /// @notice Approves with signature on Morpho.
    /// @param authorization The `Authorization` struct.
    /// @param signature The signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function morphoSetAuthorizationWithSig(
        Authorization calldata authorization,
        Signature calldata signature,
        bool skipRevert
    ) external onlyBundler {
        try MORPHO.setAuthorizationWithSig(authorization, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /// @notice Supplies loan asset on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// module is guaranteed to have `assets` tokens pulled from its balance, but the possibility to mint a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param marketParams The Morpho market to supply assets to.
    /// @param assets The amount of assets to supply. Pass `type(uint).max` to supply the module's loan asset balance.
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
    ) external onlyBundler {
        // Do not check `onBehalf` against the zero address as it's done in Morpho.
        require(onBehalf != address(this), ErrorsLib.ModuleAddress());

        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        ModuleLib.approveMaxToIfAllowanceZero(marketParams.loanToken, address(MORPHO));

        (uint256 suppliedAssets, uint256 suppliedShares) = MORPHO.supply(marketParams, assets, shares, onBehalf, data);

        if (assets > 0) require(suppliedShares >= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(suppliedAssets <= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Supplies collateral on Morpho.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param marketParams The Morpho market to supply collateral to.
    /// @param assets The amount of collateral to supply. Pass `type(uint).max` to supply the module's collateral
    /// balance.
    /// @param onBehalf The address that will own the increased collateral position.
    /// @param data Arbitrary data to pass to the `onMorphoSupplyCollateral` callback. Pass empty data if not needed.
    function morphoSupplyCollateral(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external onlyBundler {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.ModuleAddress());

        if (assets == type(uint256).max) assets = ERC20(marketParams.collateralToken).balanceOf(address(this));

        ModuleLib.approveMaxToIfAllowanceZero(marketParams.collateralToken, address(MORPHO));

        MORPHO.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    /// @notice Borrows assets on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to borrow `assets` tokens, but the possibility to mint a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the module to act on their behalf on Morpho.
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
    ) external onlyBundler {
        (uint256 borrowedAssets, uint256 borrowedShares) =
            MORPHO.borrow(marketParams, assets, shares, initiator(), receiver);

        if (assets > 0) require(borrowedShares <= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(borrowedAssets >= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Repays assets on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// module is guaranteed to have `assets` tokens pulled from its balance, but the possibility to burn a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param marketParams The Morpho market to repay assets to.
    /// @param assets The amount of assets to repay. Pass `type(uint).max` to repay the module's loan asset balance.
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
    ) external onlyBundler {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.ModuleAddress());

        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        ModuleLib.approveMaxToIfAllowanceZero(marketParams.loanToken, address(MORPHO));

        (uint256 repaidAssets, uint256 repaidShares) = MORPHO.repay(marketParams, assets, shares, onBehalf, data);

        if (assets > 0) require(repaidShares >= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(repaidAssets <= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws assets on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to withdraw `assets` tokens, but the possibility to burn a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the maodule to act on their behalf on Morpho.
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
    ) external onlyBundler {
        (uint256 withdrawnAssets, uint256 withdrawnShares) =
            MORPHO.withdraw(marketParams, assets, shares, initiator(), receiver);

        if (assets > 0) require(withdrawnShares <= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(withdrawnAssets >= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws collateral from Morpho.
    /// @dev Initiator must have previously authorized the module to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to withdraw collateral from.
    /// @param assets The amount of collateral to withdraw.
    /// @param receiver The address that will receive the collateral assets.
    function morphoWithdrawCollateral(MarketParams calldata marketParams, uint256 assets, address receiver)
        external
        onlyBundler
    {
        MORPHO.withdrawCollateral(marketParams, assets, initiator(), receiver);
    }

    /// @notice Triggers a flash loan on Morpho.
    /// @param token The address of the token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onMorphoFlashLoan` callback.
    function morphoFlashLoan(address token, uint256 assets, bytes calldata data) external onlyBundler {
        ModuleLib.approveMaxToIfAllowanceZero(token, address(MORPHO));

        MORPHO.flashLoan(token, assets, data);
    }

    /// @notice Reallocates funds using the public allocator.
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
    ) external payable onlyBundler {
        IPublicAllocator(publicAllocator).reallocateTo{value: value}(vault, withdrawals, supplyMarketParams);
    }

    /* PERMIT2 ACTIONS */

    /// @notice Approves with Permit2.
    /// @param permitSingle The `PermitSingle` struct.
    /// @param signature The signature, serialized.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function approve2(IAllowanceTransfer.PermitSingle calldata permitSingle, bytes calldata signature, bool skipRevert)
        external
        onlyBundler
    {
        try Permit2Lib.PERMIT2.permit(initiator(), permitSingle, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /// @notice Batch approves with Permit2.
    /// @param permitBatch The `PermitBatch` struct.
    /// @param signature The signature, serialized.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function approve2Batch(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature,
        bool skipRevert
    ) external onlyBundler {
        try Permit2Lib.PERMIT2.permit(initiator(), permitBatch, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /// @notice Transfers with Permit2.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function transferFrom2(address token, address receiver, uint256 amount) external onlyBundler {
        require(token != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address _initiator = initiator();
        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(_initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        Permit2Lib.PERMIT2.transferFrom(_initiator, receiver, amount.toUint160(), token);
    }

    /* PERMIT ACTIONS */

    /// @notice Permits with EIP-2612.
    /// @param token The address of the token to be permitted.
    /// @param spender The address allowed to spend the tokens.
    /// @param amount The amount of token to be permitted.
    /// @param deadline The deadline of the approval.
    /// @param v The `v` component of a signature.
    /// @param r The `r` component of a signature.
    /// @param s The `s` component of a signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function permit(
        address token,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool skipRevert
    ) external onlyBundler {
        try IERC20Permit(token).permit(initiator(), spender, amount, deadline, v, r, s) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /* TRANSFER ACTIONS */

    /// @notice Transfers ERC20 tokens from the initiator.
    /// @notice Initiator must have given sufficient allowance to the Module to spend their tokens.
    /// @notice The amount must be strictly positive.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function erc20TransferFrom(address token, address receiver, uint256 amount) external onlyBundler {
        require(token != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address _initiator = initiator();
        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(_initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        ERC20(token).safeTransferFrom(_initiator, receiver, amount);
    }

    /* WRAPPED NATIVE TOKEN ACTIONS */

    /// @notice Wraps native tokens to wNative.
    /// @dev Native tokens must have been previously sent to the module.
    /// @param amount The amount of native token to wrap. Pass `type(uint).max` to wrap the module's balance.
    /// @param receiver The account receiving the wrapped native tokens.
    function wrapNative(uint256 amount, address receiver) external payable onlyBundler {
        if (amount == type(uint256).max) amount = address(this).balance;

        require(amount != 0, ErrorsLib.ZeroAmount());

        WRAPPED_NATIVE.deposit{value: amount}();
        if (receiver != address(this)) ERC20(address(WRAPPED_NATIVE)).safeTransfer(receiver, amount);
    }

    /// @notice Unwraps wNative tokens to the native token.
    /// @dev Wrapped native tokens must have been previously sent to the module.
    /// @param amount The amount of wrapped native token to unwrap. Pass `type(uint).max` to unwrap the module's
    /// balance.
    /// @param receiver The account receiving the native tokens.
    function unwrapNative(uint256 amount, address receiver) external onlyBundler {
        if (amount == type(uint256).max) amount = WRAPPED_NATIVE.balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        WRAPPED_NATIVE.withdraw(amount);
        if (receiver != address(this)) SafeTransferLib.safeTransferETH(receiver, amount);
    }

    /* UNIVERSAL REWARDS DISTRIBUTOR ACTIONS */

    /// @notice Claims rewards on the URD.
    /// @dev Assumes the given distributor implements `IUniversalRewardsDistributor`.
    /// @param distributor The address of the reward distributor contract.
    /// @param account The address of the owner of the rewards (also the address that will receive the rewards).
    /// @param reward The address of the token reward.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The proof.
    /// @param skipRevert Whether to avoid reverting the call in case the proof is frontrunned.
    function urdClaim(
        address distributor,
        address account,
        address reward,
        uint256 claimable,
        bytes32[] calldata proof,
        bool skipRevert
    ) external onlyBundler {
        require(account != address(0), ErrorsLib.ZeroAddress());
        require(account != address(this), ErrorsLib.ModuleAddress());

        try IUniversalRewardsDistributor(distributor).claim(account, reward, claimable, proof) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Triggers `_multicall` logic during a callback.
    function _morphoCallback(bytes calldata data) internal {
        require(msg.sender == address(MORPHO), ErrorsLib.UnauthorizedSender(msg.sender));
        // No need to approve Morpho to pull tokens because it should already be approved max.

        multicallBundler(data);
    }
}
