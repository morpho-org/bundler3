// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";
import {BundlerLib} from "./libraries/BundlerLib.sol";

/// @title ERC4626Bundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract managing interactions with ERC4626 compliant tokens.
abstract contract ERC4626Bundler is BaseBundler {
    /* ACTIONS */

    /// @notice Mints the given amount of `shares` on the given ERC4626 `vault`, on behalf of `receiver`.
    /// @dev Initiator must have previously transferred their assets to the bundler.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param shares The amount of shares to mint.
    /// @param maxAssets The maximum amount of assets to deposit in exchange for `shares`.
    /// @param receiver The address to which shares will be minted.
    function erc4626Mint(address vault, uint256 shares, uint256 maxAssets, address receiver) external hubOnly {
        /// Do not check `receiver != address(this)` to allow the bundler to receive the vault's shares.
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        require(shares != 0, ErrorsLib.ZERO_SHARES);

        BundlerLib.approveMaxTo(IERC4626(vault).asset(), vault);

        uint256 assets = IERC4626(vault).mint(shares, receiver);
        require(assets <= maxAssets, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Deposits the given amount of `assets` on the given ERC4626 `vault`, on behalf of `receiver`.
    /// @dev Initiator must have previously transferred their assets to the bundler.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param assets The amount of assets to deposit. Capped at the bundler's assets.
    /// @param minShares The minimum amount of shares to mint in exchange for `assets`. This parameter is proportionally
    /// scaled down in case there are fewer assets than `assets` on the bundler.
    /// @param receiver The address to which shares will be minted.
    function erc4626Deposit(address vault, uint256 assets, uint256 minShares, address receiver) external hubOnly {
        /// Do not check `receiver != address(this)` to allow the bundler to receive the vault's shares.
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

        uint256 initialAssets = assets;
        address asset = IERC4626(vault).asset();
        assets = Math.min(assets, ERC20(asset).balanceOf(address(this)));

        require(assets != 0, ErrorsLib.ZERO_AMOUNT);

        BundlerLib.approveMaxTo(asset, vault);

        uint256 shares = IERC4626(vault).deposit(assets, receiver);
        require(shares * initialAssets >= minShares * assets, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Withdraws the given amount of `assets` from the given ERC4626 `vault`, transferring assets to
    /// `receiver`.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param assets The amount of assets to withdraw.
    /// @param maxShares The maximum amount of shares to redeem in exchange for `assets`.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the assets are withdrawn. Can only be the bundler or the initiator.
    /// If `owner` is the initiator, they must have previously approved the bundler to spend their vault shares.
    /// Otherwise, they must have previously transferred their vault shares to the bundler.
    function erc4626Withdraw(address vault, uint256 assets, uint256 maxShares, address receiver, address owner)
        external
        hubOnly
    {
        /// Do not check `receiver != address(this)` to allow the bundler to receive the underlying asset.
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        require(owner == address(this) || owner == initiator(), ErrorsLib.UNEXPECTED_OWNER);
        require(assets != 0, ErrorsLib.ZERO_AMOUNT);

        uint256 shares = IERC4626(vault).withdraw(assets, receiver, owner);
        require(shares <= maxShares, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Redeems the given amount of `shares` from the given ERC4626 `vault`, transferring assets to `receiver`.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param shares The amount of shares to redeem. Capped at the owner's shares.
    /// @param minAssets The minimum amount of assets to withdraw in exchange for `shares`. This parameter is
    /// proportionally scaled down in case the owner holds fewer shares than `shares`.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the shares are redeemed. Can only be the bundler or the initiator.
    /// If `owner` is the initiator, they must have previously approved the bundler to spend their vault shares.
    /// Otherwise, they must have previously transferred their vault shares to the bundler.
    function erc4626Redeem(address vault, uint256 shares, uint256 minAssets, address receiver, address owner)
        external
        hubOnly
    {
        /// Do not check `receiver != address(this)` to allow the bundler to receive the underlying asset.
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        require(owner == address(this) || owner == initiator(), ErrorsLib.UNEXPECTED_OWNER);

        uint256 initialShares = shares;
        shares = Math.min(shares, IERC4626(vault).balanceOf(owner));

        require(shares != 0, ErrorsLib.ZERO_SHARES);

        uint256 assets = IERC4626(vault).redeem(shares, receiver, owner);
        require(assets * initialShares >= minAssets * shares, ErrorsLib.SLIPPAGE_EXCEEDED);
    }
}
