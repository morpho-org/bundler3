// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {BaseModule, Math} from "./BaseModule.sol";

import {IMorphoModule} from "./interfaces/IMorphoModule.sol";
import {IPublicAllocator, Withdrawal} from "./interfaces/IPublicAllocator.sol";
import {MarketParams, Signature, Authorization, IMorpho} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {IAllowanceTransfer} from "../lib/permit2/src/interfaces/IAllowanceTransfer.sol";

import {Call} from "./interfaces/Call.sol";
import {IBundler} from "./interfaces/IBundler.sol";
import {ModuleLib} from "./libraries/ModuleLib.sol";
import {SafeCast160} from "../lib/permit2/src/libraries/SafeCast160.sol";
import {IUniversalRewardsDistributor} from
    "../lib/universal-rewards-distributor/src/interfaces/IUniversalRewardsDistributor.sol";
import {IERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Permit2Lib} from "../lib/permit2/src/libraries/Permit2Lib.sol";
import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20Wrapper} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {IParaswapModule, Offsets} from "./interfaces/IParaswapModule.sol";
import {MorphoBalancesLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @title GenericModule1
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Chain agnostic module contract n°1.
contract GenericModule1 is BaseModule {
    using SafeCast160 for uint256;
    using SafeTransferLib for ERC20;
    using MorphoBalancesLib for IMorpho;

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

    /// @notice Deposits underlying tokens and mints the corresponding amount of wrapped tokens.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The account receiving the wrapped tokens.
    /// @param amount The amount of underlying tokens to deposit. Capped at the module's balance.
    function erc20WrapperDepositFor(address wrapper, address receiver, uint256 amount) external bundlerOnly {
        ERC20 underlying = ERC20(address(ERC20Wrapper(wrapper).underlying()));

        amount = Math.min(amount, underlying.balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(address(underlying), wrapper);

        require(ERC20Wrapper(wrapper).depositFor(receiver, amount), ErrorsLib.DepositFailed());
    }

    /// @notice Burns wrapped tokens and withdraws the corresponding amount of underlying tokens.
    /// @dev Wrapped tokens must have been previously sent to the module.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Capped at the module's balance.
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external bundlerOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        amount = Math.min(amount, ERC20(wrapper).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }

    /* ERC4626 ACTIONS */

    /// @notice Mints the given amount of `shares` on the given ERC4626 `vault`, on behalf of `receiver`.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param shares The amount of shares to mint.
    /// @param maxAssets The maximum amount of assets to deposit in exchange for `shares`.
    /// @param receiver The address to which shares will be minted.
    function erc4626Mint(address vault, uint256 shares, uint256 maxAssets, address receiver) external bundlerOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(shares != 0, ErrorsLib.ZeroShares());

        ModuleLib.approveMaxToIfAllowanceZero(IERC4626(vault).asset(), vault);

        uint256 assets = IERC4626(vault).mint(shares, receiver);
        require(assets <= maxAssets, ErrorsLib.SlippageExceeded());
    }

    /// @notice Deposits the given amount of `assets` on the given ERC4626 `vault`, on behalf of `receiver`.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param assets The amount of assets to deposit. Capped at the module's assets.
    /// @param minShares The minimum amount of shares to mint in exchange for `assets`. This parameter is proportionally
    /// scaled down in case there are fewer assets than `assets` on the module.
    /// @param receiver The address to which shares will be minted.
    function erc4626Deposit(address vault, uint256 assets, uint256 minShares, address receiver) external bundlerOnly {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        uint256 initialAssets = assets;
        address underlyingToken = IERC4626(vault).asset();
        assets = Math.min(assets, ERC20(underlyingToken).balanceOf(address(this)));

        require(assets != 0, ErrorsLib.ZeroAmount());

        ModuleLib.approveMaxToIfAllowanceZero(underlyingToken, vault);

        uint256 shares = IERC4626(vault).deposit(assets, receiver);
        require(shares * initialAssets >= minShares * assets, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws the given amount of `assets` from the given ERC4626 `vault` to `receiver`.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the module to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the module.
    /// @param vault The address of the vault.
    /// @param assets The amount of assets to withdraw.
    /// @param maxShares The maximum amount of shares to redeem in exchange for `assets`.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the assets are withdrawn. Can only be the module or the initiator.
    function erc4626Withdraw(address vault, uint256 assets, uint256 maxShares, address receiver, address owner)
        external
        bundlerOnly
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == initiator(), ErrorsLib.UnexpectedOwner(owner));
        require(assets != 0, ErrorsLib.ZeroAmount());

        uint256 shares = IERC4626(vault).withdraw(assets, receiver, owner);
        require(shares <= maxShares, ErrorsLib.SlippageExceeded());
    }

    /// @notice Redeems the given amount of `shares` from the given ERC4626 `vault` to `receiver`.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the module to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the module.
    /// @param vault The address of the vault.
    /// @param shares The amount of shares to redeem. Capped at the owner's shares.
    /// @param minAssets The minimum amount of assets to withdraw in exchange for `shares`. This parameter is
    /// proportionally scaled down in case the owner holds fewer shares than `shares`.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the shares are redeemed. Can only be the module or the initiator.
    function erc4626Redeem(address vault, uint256 shares, uint256 minAssets, address receiver, address owner)
        external
        bundlerOnly
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == initiator(), ErrorsLib.UnexpectedOwner(owner));

        uint256 initialShares = shares;
        shares = Math.min(shares, IERC4626(vault).balanceOf(owner));

        require(shares != 0, ErrorsLib.ZeroShares());

        uint256 assets = IERC4626(vault).redeem(shares, receiver, owner);
        require(assets * initialShares >= minAssets * shares, ErrorsLib.SlippageExceeded());
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

    /// @notice Approves `authorization.authorized` to manage `authorization.authorizer`'s position via EIP712
    /// `signature`.
    /// @param authorization The `Authorization` struct.
    /// @param signature The signature.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function morphoSetAuthorizationWithSig(
        Authorization calldata authorization,
        Signature calldata signature,
        bool skipRevert
    ) external bundlerOnly {
        try MORPHO.setAuthorizationWithSig(authorization, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /// @notice Supplies `assets` of the loan asset on behalf of `onBehalf`.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// module is guaranteed to have `assets` tokens pulled from its balance, but the possibility to mint a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param marketParams The Morpho market to supply assets to.
    /// @param assets The amount of assets to supply. Pass `type(uint256).max` to supply the module's loan asset
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
    ) external bundlerOnly {
        // Do not check `onBehalf` against the zero address as it's done in Morpho.
        require(onBehalf != address(this), ErrorsLib.ModuleAddress());

        // Don't always cap the assets to the module's balance because the liquidity can be transferred later
        // (via the `onMorphoSupply` callback).
        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        ModuleLib.approveMaxToIfAllowanceZero(marketParams.loanToken, address(MORPHO));

        (uint256 suppliedAssets, uint256 suppliedShares) = MORPHO.supply(marketParams, assets, shares, onBehalf, data);

        if (assets > 0) require(suppliedShares >= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(suppliedAssets <= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Supplies `assets` of collateral on behalf of `onBehalf`.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param marketParams The Morpho market to supply collateral to.
    /// @param assets The amount of collateral to supply. Pass `type(uint256).max` to supply the module's collateral
    /// balance.
    /// @param onBehalf The address that will own the increased collateral position.
    /// @param data Arbitrary data to pass to the `onMorphoSupplyCollateral` callback. Pass empty data if not needed.
    function morphoSupplyCollateral(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external bundlerOnly {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.ModuleAddress());

        // Don't always cap the assets to the module's balance because the liquidity can be transferred later
        // (via the `onMorphoSupplyCollateral` callback).
        if (assets == type(uint256).max) assets = ERC20(marketParams.collateralToken).balanceOf(address(this));

        ModuleLib.approveMaxToIfAllowanceZero(marketParams.collateralToken, address(MORPHO));

        MORPHO.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    /// @notice Borrows `assets` of the loan asset on behalf of the initiator.
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
    ) external bundlerOnly {
        (uint256 borrowedAssets, uint256 borrowedShares) =
            MORPHO.borrow(marketParams, assets, shares, initiator(), receiver);

        if (assets > 0) require(borrowedShares <= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(borrowedAssets >= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Repays `assets` of the loan asset on behalf of `onBehalf`.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// module is guaranteed to have `assets` tokens pulled from its balance, but the possibility to burn a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Underlying tokens must have been previously sent to the module.
    /// @param marketParams The Morpho market to repay assets to.
    /// @param assets The amount of assets to repay. Pass `type(uint256).max` to repay the module's loan asset balance.
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
    ) external bundlerOnly {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.ModuleAddress());

        // Don't always cap the assets to the module's balance because the liquidity can be transferred later
        // (via the `onMorphoRepay` callback).
        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        ModuleLib.approveMaxToIfAllowanceZero(marketParams.loanToken, address(MORPHO));

        (uint256 repaidAssets, uint256 repaidShares) = MORPHO.repay(marketParams, assets, shares, onBehalf, data);

        if (assets > 0) require(repaidShares >= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(repaidAssets <= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws `assets` of the loan asset on behalf of the initiator.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to withdraw `assets` tokens, but the possibility to burn a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the module to act on their behalf on Morpho.
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
    ) external bundlerOnly {
        (uint256 withdrawnAssets, uint256 withdrawnShares) =
            MORPHO.withdraw(marketParams, assets, shares, initiator(), receiver);

        if (assets > 0) require(withdrawnShares <= slippageAmount, ErrorsLib.SlippageExceeded());
        else require(withdrawnAssets >= slippageAmount, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws `assets` of the collateral asset on behalf of the initiator.
    /// @dev Initiator must have previously authorized the module to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to withdraw collateral from.
    /// @param assets The amount of collateral to withdraw.
    /// @param receiver The address that will receive the collateral assets.
    function morphoWithdrawCollateral(MarketParams calldata marketParams, uint256 assets, address receiver)
        external
        bundlerOnly
    {
        MORPHO.withdrawCollateral(marketParams, assets, initiator(), receiver);
    }

    /// @notice Triggers a flash loan on Morpho.
    /// @param token The address of the token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onMorphoFlashLoan` callback.
    function morphoFlashLoan(address token, uint256 assets, bytes calldata data) external bundlerOnly {
        ModuleLib.approveMaxToIfAllowanceZero(token, address(MORPHO));

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
    ) external payable bundlerOnly {
        IPublicAllocator(publicAllocator).reallocateTo{value: value}(vault, withdrawals, supplyMarketParams);
    }

    /* PERMIT2 ACTIONS */

    /// @notice Approves the given `permitSingle.details.amount` of `permitSingle.details.token` from the initiator to
    /// be spent by `permitSingle.spender` via
    /// Permit2 with the given `permitSingle.sigDeadline` & EIP-712 `signature`.
    /// @param permitSingle The `PermitSingle` struct.
    /// @param signature The signature, serialized.
    /// @param skipRevert Whether to avoid reverting the call in case the signature is frontrunned.
    function approve2(IAllowanceTransfer.PermitSingle calldata permitSingle, bytes calldata signature, bool skipRevert)
        external
        bundlerOnly
    {
        try Permit2Lib.PERMIT2.permit(initiator(), permitSingle, signature) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /// @notice Transfers the given `amount` of `token` from the initiator to the module via Permit2.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer from the initiator. Capped at the initiator's balance.
    function transferFrom2(address token, address receiver, uint256 amount) external bundlerOnly {
        address _initiator = initiator();
        amount = Math.min(amount, ERC20(token).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZeroAmount());

        Permit2Lib.PERMIT2.transferFrom(_initiator, receiver, amount.toUint160(), token);
    }

    /* PERMIT ACTIONS */

    /// @notice Permits the given `amount` of `token` from sender to be spent by the module via EIP-2612 Permit with
    /// the given `deadline` & EIP-712 signature's `v`, `r` & `s`.
    /// @param token The address of the token to be permitted.
    /// @param spender The address allowed to spend the tokens.
    /// @param amount The amount of `token` to be permitted.
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
    ) external bundlerOnly {
        try IERC20Permit(token).permit(initiator(), spender, amount, deadline, v, r, s) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /* TRANSFER ACTIONS */

    /// @notice Transfers the given `amount` of `token` from sender to this contract via ERC20 transferFrom.
    /// @notice Initiator must have given sufficient allowance to the Module to spend their tokens.
    /// @notice The amount must be strictly positive.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of `token` to transfer from the initiator. Capped at the initiator's balance.
    function erc20TransferFrom(address token, address receiver, uint256 amount) external bundlerOnly {
        address _initiator = initiator();
        amount = Math.min(amount, ERC20(token).balanceOf(_initiator));

        require(amount != 0, ErrorsLib.ZeroAmount());

        ERC20(token).safeTransferFrom(_initiator, receiver, amount);
    }

    /* WRAPPED NATIVE TOKEN ACTIONS */

    /// @notice Wraps the given `amount` of the native token to wNative.
    /// @dev Native tokens must have been previously sent to the module.
    /// @param amount The amount of native token to wrap. Capped at the module's native token balance.
    /// @param receiver The account receiving the wrapped native tokens.
    function wrapNative(uint256 amount, address receiver) external payable bundlerOnly {
        amount = Math.min(amount, address(this).balance);

        require(amount != 0, ErrorsLib.ZeroAmount());

        WRAPPED_NATIVE.deposit{value: amount}();
        if (receiver != address(this)) ERC20(address(WRAPPED_NATIVE)).safeTransfer(receiver, amount);
    }

    /// @notice Unwraps the given `amount` of wNative to the native token.
    /// @dev Wrapped native tokens must have been previously sent to the module.
    /// @param amount The amount of wrapped native token to unwrap. Capped at the module's wNative balance.
    /// @param receiver The account receiving the native tokens.
    function unwrapNative(uint256 amount, address receiver) external bundlerOnly {
        amount = Math.min(amount, WRAPPED_NATIVE.balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZeroAmount());

        WRAPPED_NATIVE.withdraw(amount);
        if (receiver != address(this)) SafeTransferLib.safeTransferETH(receiver, amount);
    }

    /* UNIVERSAL REWARDS DISTRIBUTOR ACTIONS */

    /// @notice Claims available `reward` tokens on behalf of `account` on the given rewards distributor, using `proof`.
    /// @dev Assumes the given distributor implements IUniversalRewardsDistributor.
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
    ) external bundlerOnly {
        require(account != address(0), ErrorsLib.ZeroAddress());
        require(account != address(this), ErrorsLib.ModuleAddress());

        try IUniversalRewardsDistributor(distributor).claim(account, reward, claimable, proof) {}
        catch (bytes memory returnData) {
            if (!skipRevert) ModuleLib.lowLevelRevert(returnData);
        }
    }

    /* SWAP ACTIONS */

    function paraswapBuyMorphoDebt(
        address paraswapModule,
        address augustus,
        bytes memory callData,
        address srcToken,
        MarketParams calldata marketParams,
        Offsets calldata offsets,
        address receiver
    ) external bundlerOnly {
        uint256 newDestAmount = MORPHO.expectedBorrowAssets(marketParams, initiator());
        IParaswapModule(paraswapModule).buy(
            augustus, callData, srcToken, marketParams.loanToken, newDestAmount, offsets, receiver
        );
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Triggers `_multicall` logic during a callback.
    function _morphoCallback(bytes calldata data) internal {
        require(msg.sender == address(MORPHO), ErrorsLib.UnauthorizedSender(msg.sender));
        // No need to approve Morpho to pull tokens because it should already be approved max.

        multicallBundler(data);
    }
}
