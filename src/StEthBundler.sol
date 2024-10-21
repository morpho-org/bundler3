// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IWstEth} from "./interfaces/IWstEth.sol";
import {IStEth} from "./interfaces/IStEth.sol";

import {Math} from "../lib/morpho-utils/src/math/Math.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";

/// @title StEthBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to bundle multiple interactions with stETH together.
abstract contract StEthBundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    /// @dev The address of the stETH contract.
    address public immutable ST_ETH;

    /// @dev The address of the wstETH contract.
    address public immutable WST_ETH;

    /* CONSTRUCTOR */

    /// @dev Warning: assumes the given addresses are non-zero (they are not expected to be deployment arguments).
    /// @param wstEth The address of the wstEth contract.
    constructor(address wstEth) {
        ST_ETH = IWstEth(wstEth).stETH();
        WST_ETH = wstEth;

        _approveMaxTo(ST_ETH, WST_ETH);
    }

    /* ACTIONS */

    /// @notice Stakes the given `amount` of ETH via Lido, using the `referral` id.
    /// @notice stETH tokens are received by the bundler and should be used afterwards.
    /// @dev Initiator must have previously transferred their ETH to the bundler.
    /// @param amount The amount of ETH to stake. Capped at the bundler's ETH balance.
    /// @param minShares The minimum amount of shares to mint in exchange for `amount`. This parameter is
    /// proportionally scaled down in case there is fewer ETH than `amount` on the bundler.
    /// @param referral The address of the referral regarding the Lido Rewards-Share Program.
    function stakeEth(uint256 amount, uint256 minShares, address referral) external payable hubOnly {
        uint256 initialAmount = amount;
        amount = Math.min(amount, address(this).balance);

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        uint256 shares = IStEth(ST_ETH).submit{value: amount}(referral);
        require(shares * initialAmount >= minShares * amount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /// @notice Wraps the given `amount` of stETH to wstETH.
    /// @notice wstETH tokens are received by the bundler and should be used afterwards.
    /// @dev Initiator must have previously transferred their stETH tokens to the bundler.
    /// @param amount The amount of stEth to wrap. Capped at the bundler's stETH balance.
    function wrapStEth(uint256 amount) external hubOnly {
        amount = Math.min(amount, ERC20(ST_ETH).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        IWstEth(WST_ETH).wrap(amount);
    }

    /// @notice Unwraps the given `amount` of wstETH to stETH.
    /// @notice stETH tokens are received by the bundler and should be used afterwards.
    /// @dev Initiator must have previously transferred their wstETH tokens to the bundler.
    /// @param amount The amount of wstEth to unwrap. Capped at the bundler's wstETH balance.
    function unwrapStEth(uint256 amount) external hubOnly {
        amount = Math.min(amount, ERC20(WST_ETH).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        IWstEth(WST_ETH).unwrap(amount);
    }
}
