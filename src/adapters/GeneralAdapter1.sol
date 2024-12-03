// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IWNative} from "../interfaces/IWNative.sol";
import {IAllowanceTransfer} from "../../lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {MarketParams, Signature, Authorization, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {CoreAdapter} from "./CoreAdapter.sol";

import {UtilsLib} from "../libraries/UtilsLib.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MathRayLib} from "../libraries/MathRayLib.sol";
import {SafeCast160} from "../../lib/permit2/src/libraries/SafeCast160.sol";
import {Permit2Lib} from "../../lib/permit2/src/libraries/Permit2Lib.sol";
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {ERC20Wrapper} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MarketParamsLib} from "../../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MorphoLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";

/// @custom:contact security@morpho.org
/// @notice Chain agnostic adapter contract n°1.
contract GeneralAdapter1 is CoreAdapter {
    using SafeCast160 for uint256;
    using MarketParamsLib for MarketParams;
    using MathRayLib for uint256;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable MORPHO;

    /// @dev The address of the wrapped native token contract.
    IWNative public immutable WRAPPED_NATIVE;

    /* CONSTRUCTOR */

    constructor(address bundler, address morpho, address wNative) CoreAdapter(bundler) {
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
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The account receiving the wrapped tokens.
    /// @param amount The amount of underlying tokens to deposit. Pass `type(uint).max` to deposit the adapter's
    /// underlying balance.
    function erc20WrapperDepositFor(address wrapper, address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address underlying = address(ERC20Wrapper(wrapper).underlying());
        if (amount == type(uint256).max) amount = ERC20(underlying).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        UtilsLib.approveMaxToIfAllowanceZero(underlying, wrapper);

        require(ERC20Wrapper(wrapper).depositFor(receiver, amount), ErrorsLib.DepositFailed());
    }

    /// @notice Unwraps wrapped token to underlying token.
    /// @dev Wrapped tokens must have been previously sent to the adapter.
    /// @dev Assumes that `wrapper` implements the `ERC20Wrapper` interface.
    /// @param wrapper The address of the ERC20 wrapper contract.
    /// @param receiver The address receiving the underlying tokens.
    /// @param amount The amount of wrapped tokens to burn. Pass `type(uint).max` to burn the adapter's wrapped token
    /// balance.
    function erc20WrapperWithdrawTo(address wrapper, address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        if (amount == type(uint256).max) amount = ERC20(wrapper).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        require(ERC20Wrapper(wrapper).withdrawTo(receiver, amount), ErrorsLib.WithdrawFailed());
    }

    /* ERC4626 ACTIONS */

    /// @notice Mints shares of an ERC4626 vault.
    /// @dev Underlying tokens must have been previously sent to the adapter.
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

        UtilsLib.approveMaxToIfAllowanceZero(IERC4626(vault).asset(), vault);

        uint256 assets = IERC4626(vault).mint(shares, receiver);
        require(assets.rDivUp(shares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Deposits underlying token in an ERC4626 vault.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes the given vault implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param assets The amount of underlying token to deposit. Pass `type(uint).max` to deposit the adapter's balance.
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

        UtilsLib.approveMaxToIfAllowanceZero(underlyingToken, vault);

        uint256 shares = IERC4626(vault).deposit(assets, receiver);
        require(assets.rDivUp(shares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws underlying token from an ERC4626 vault.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the adapter to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the adapter.
    /// @param vault The address of the vault.
    /// @param assets The amount of underlying token to withdraw.
    /// @param minSharePriceE27 The minimum number of assets to receive per share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the assets are withdrawn. Can only be the adapter or the initiator.
    function erc4626Withdraw(address vault, uint256 assets, uint256 minSharePriceE27, address receiver, address owner)
        external
        onlyBundler
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == _initiator(), ErrorsLib.UnexpectedOwner());
        require(assets != 0, ErrorsLib.ZeroAmount());

        uint256 shares = IERC4626(vault).withdraw(assets, receiver, owner);
        require(assets.rDivDown(shares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Redeems shares of an ERC4626 vault.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the adapter to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the adapter.
    /// @param vault The address of the vault.
    /// @param shares The amount of vault shares to redeem. Pass `type(uint).max` to redeem the owner's shares.
    /// @param minSharePriceE27 The minimum number of assets to receive per share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the shares are redeemed. Can only be the adapter or the initiator.
    function erc4626Redeem(address vault, uint256 shares, uint256 minSharePriceE27, address receiver, address owner)
        external
        onlyBundler
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == _initiator(), ErrorsLib.UnexpectedOwner());

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

    /// @notice Supplies loan asset on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// adapter is guaranteed to have `assets` tokens pulled from its balance, but the possibility to mint a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param marketParams The Morpho market to supply assets to.
    /// @param assets The amount of assets to supply. Pass `type(uint).max` to supply the adapter's loan asset balance.
    /// @param shares The amount of shares to mint.
    /// @param maxSharePriceE27 The maximum amount of assets supplied per minted share, scaled by 1e27.
    /// @param onBehalf The address that will own the increased supply position.
    /// @param data Arbitrary data to pass to the `onMorphoSupply` callback. Pass empty data if not needed.
    function morphoSupply(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 maxSharePriceE27,
        address onBehalf,
        bytes calldata data
    ) external onlyBundler {
        // Do not check `onBehalf` against the zero address as it's done in Morpho.
        require(onBehalf != address(this), ErrorsLib.AdapterAddress());

        if (assets == type(uint256).max) {
            assets = ERC20(marketParams.loanToken).balanceOf(address(this));
            require(assets != 0, ErrorsLib.ZeroAmount());
        }

        UtilsLib.approveMaxToIfAllowanceZero(marketParams.loanToken, address(MORPHO));

        (uint256 suppliedAssets, uint256 suppliedShares) = MORPHO.supply(marketParams, assets, shares, onBehalf, data);

        require(suppliedAssets.rDivUp(suppliedShares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Supplies collateral on Morpho.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param marketParams The Morpho market to supply collateral to.
    /// @param assets The amount of collateral to supply. Pass `type(uint).max` to supply the adapter's collateral
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
        require(onBehalf != address(this), ErrorsLib.AdapterAddress());

        if (assets == type(uint256).max) assets = ERC20(marketParams.collateralToken).balanceOf(address(this));

        require(assets != 0, ErrorsLib.ZeroAmount());

        UtilsLib.approveMaxToIfAllowanceZero(marketParams.collateralToken, address(MORPHO));

        MORPHO.supplyCollateral(marketParams, assets, onBehalf, data);
    }

    /// @notice Borrows assets on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to borrow `assets` tokens, but the possibility to mint a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the adapter to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to borrow assets from.
    /// @param assets The amount of assets to borrow.
    /// @param shares The amount of shares to mint.
    /// @param minSharePriceE27 The minimum amount of assets borrowed per borrow share minted, scaled by 1e27.
    /// @param receiver The address that will receive the borrowed assets.
    function morphoBorrow(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 minSharePriceE27,
        address receiver
    ) external onlyBundler {
        (uint256 borrowedAssets, uint256 borrowedShares) =
            MORPHO.borrow(marketParams, assets, shares, _initiator(), receiver);

        require(borrowedAssets.rDivDown(borrowedShares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Repays assets on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// adapter is guaranteed to have `assets` tokens pulled from its balance, but the possibility to burn a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param marketParams The Morpho market to repay assets to.
    /// @param assets The amount of assets to repay. Pass `type(uint).max` to repay the adapter's loan asset balance.
    /// @param shares The amount of shares to burn. Pass `type(uint).max` to repay the initiator's entire debt.
    /// @param maxSharePriceE27 The maximum amount of assets repaid per borrow share burned, scaled by 1e27.
    /// @param onBehalf The address of the owner of the debt position.
    /// @param data Arbitrary data to pass to the `onMorphoRepay` callback. Pass empty data if not needed.
    function morphoRepay(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 maxSharePriceE27,
        address onBehalf,
        bytes calldata data
    ) external onlyBundler {
        // Do not check `onBehalf` against the zero address as it's done at Morpho's level.
        require(onBehalf != address(this), ErrorsLib.AdapterAddress());

        if (assets == type(uint256).max) {
            assets = ERC20(marketParams.loanToken).balanceOf(address(this));
            require(assets != 0, ErrorsLib.ZeroAmount());
        }

        if (shares == type(uint256).max) {
            shares = MorphoLib.borrowShares(MORPHO, marketParams.id(), _initiator());
            require(shares != 0, ErrorsLib.ZeroAmount());
        }

        UtilsLib.approveMaxToIfAllowanceZero(marketParams.loanToken, address(MORPHO));

        (uint256 repaidAssets, uint256 repaidShares) = MORPHO.repay(marketParams, assets, shares, onBehalf, data);

        require(repaidAssets.rDivUp(repaidShares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws assets on Morpho.
    /// @dev Either `assets` or `shares` should be zero. Most usecases should rely on `assets` as an input so the
    /// initiator is guaranteed to withdraw `assets` tokens, but the possibility to burn a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev Initiator must have previously authorized the maodule to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to withdraw assets from.
    /// @param assets The amount of assets to withdraw.
    /// @param shares The amount of shares to burn. Pass `type(uint).max` to burn all the initiator's supply shares.
    /// @param minSharePriceE27 The minimum amount of assets withdraw per burn share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    function morphoWithdraw(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 minSharePriceE27,
        address receiver
    ) external onlyBundler {
        if (shares == type(uint256).max) {
            shares = MorphoLib.supplyShares(MORPHO, marketParams.id(), _initiator());
            require(shares != 0, ErrorsLib.ZeroAmount());
        }

        (uint256 withdrawnAssets, uint256 withdrawnShares) =
            MORPHO.withdraw(marketParams, assets, shares, _initiator(), receiver);

        require(withdrawnAssets.rDivDown(withdrawnShares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws collateral from Morpho.
    /// @dev Initiator must have previously authorized the adapter to act on their behalf on Morpho.
    /// @param marketParams The Morpho market to withdraw collateral from.
    /// @param assets The amount of collateral to withdraw. Pass `type(uint).max` to withdraw the initiator's collateral
    /// balance.
    /// @param receiver The address that will receive the collateral assets.
    function morphoWithdrawCollateral(MarketParams calldata marketParams, uint256 assets, address receiver)
        external
        onlyBundler
    {
        if (assets == type(uint256).max) assets = MorphoLib.collateral(MORPHO, marketParams.id(), _initiator());
        require(assets != 0, ErrorsLib.ZeroAmount());

        MORPHO.withdrawCollateral(marketParams, assets, _initiator(), receiver);
    }

    /// @notice Triggers a flash loan on Morpho.
    /// @param token The address of the token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onMorphoFlashLoan` callback.
    function morphoFlashLoan(address token, uint256 assets, bytes calldata data) external onlyBundler {
        require(assets != 0, ErrorsLib.ZeroAmount());
        UtilsLib.approveMaxToIfAllowanceZero(token, address(MORPHO));

        MORPHO.flashLoan(token, assets, data);
    }

    /* PERMIT2 ACTIONS */

    /// @notice Transfers with Permit2.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function transferFrom2(address token, address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address _initiator = _initiator();
        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(_initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        Permit2Lib.PERMIT2.transferFrom(_initiator, receiver, amount.toUint160(), token);
    }

    /* TRANSFER ACTIONS */

    /// @notice Transfers ERC20 tokens from the initiator.
    /// @notice Initiator must have given sufficient allowance to the Adapter to spend their tokens.
    /// @notice The amount must be strictly positive.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function erc20TransferFrom(address token, address receiver, uint256 amount) external onlyBundler {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address _initiator = _initiator();
        if (amount == type(uint256).max) amount = ERC20(token).balanceOf(_initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        SafeTransferLib.safeTransferFrom(ERC20(token), _initiator, receiver, amount);
    }

    /* WRAPPED NATIVE TOKEN ACTIONS */

    /// @notice Wraps native tokens to wNative.
    /// @dev Native tokens must have been previously sent to the adapter.
    /// @param amount The amount of native token to wrap. Pass `type(uint).max` to wrap the adapter's balance.
    /// @param receiver The account receiving the wrapped native tokens.
    function wrapNative(uint256 amount, address receiver) external onlyBundler {
        if (amount == type(uint256).max) amount = address(this).balance;

        require(amount != 0, ErrorsLib.ZeroAmount());

        WRAPPED_NATIVE.deposit{value: amount}();
        if (receiver != address(this)) SafeTransferLib.safeTransfer(ERC20(address(WRAPPED_NATIVE)), receiver, amount);
    }

    /// @notice Unwraps wNative tokens to the native token.
    /// @dev Wrapped native tokens must have been previously sent to the adapter.
    /// @param amount The amount of wrapped native token to unwrap. Pass `type(uint).max` to unwrap the adapter's
    /// balance.
    /// @param receiver The account receiving the native tokens.
    function unwrapNative(uint256 amount, address receiver) external onlyBundler {
        if (amount == type(uint256).max) amount = WRAPPED_NATIVE.balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        WRAPPED_NATIVE.withdraw(amount);
        if (receiver != address(this)) SafeTransferLib.safeTransferETH(receiver, amount);
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Triggers `_multicall` logic during a callback.
    function _morphoCallback(bytes calldata data) internal {
        require(msg.sender == address(MORPHO), ErrorsLib.UnauthorizedSender());
        // No need to approve Morpho to pull tokens because it should already be approved max.

        _reenterBundler(data);
    }
}
