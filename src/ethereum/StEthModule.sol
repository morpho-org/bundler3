// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IWstEth} from "../interfaces/IWstEth.sol";
import {IStEth} from "../interfaces/IStEth.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

import {BaseModule, SafeTransferLib} from "../BaseModule.sol";
import {ModuleLib} from "../libraries/ModuleLib.sol";
import {WAD} from "../../lib/morpho-blue/src/libraries/MathLib.sol";

/// @title StEthModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Contract allowing to bundle multiple interactions with stETH together.
abstract contract StEthModule is BaseModule {
    /* IMMUTABLES */

    /// @dev The address of the stETH contract.
    address public immutable ST_ETH;

    /// @dev The address of the wstETH contract.
    address public immutable WST_ETH;

    /* CONSTRUCTOR */

    /// @param wstEth The address of the wstEth contract.
    constructor(address wstEth) {
        require(wstEth != address(0), ErrorsLib.ZeroAddress());

        ST_ETH = IWstEth(wstEth).stETH();
        WST_ETH = wstEth;

        ModuleLib.approveMaxToIfAllowanceZero(ST_ETH, WST_ETH);
    }

    /* ACTIONS */

    /// @notice Stakes ETH via Lido.
    /// @dev ETH must have been previously sent to the module.
    /// @param amount The amount of ETH to stake. Pass `type(uint).max` to repay the module's ETH balance.
    /// @param maxSharePriceE18 The maximum amount of wei to pay for minting 1 share, scaled by 1e18.
    /// @param referral The address of the referral regarding the Lido Rewards-Share Program.
    /// @param receiver The account receiving the stETH tokens.
    function stakeEth(uint256 amount, uint256 maxSharePriceE18, address referral, address receiver)
        external
        payable
        bundlerOnly
    {
        if (amount == type(uint256).max) amount = address(this).balance;

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 sharesReceived = IStEth(ST_ETH).submit{value: amount}(referral);
        require(amount * WAD >= maxSharePriceE18 * sharesReceived, ErrorsLib.SlippageExceeded());

        SafeTransferLib.safeTransfer(ERC20(ST_ETH), receiver, amount);
    }

    /// @notice Wraps stETH to wstETH.
    /// @dev stETH must have been previously sent to the module.
    /// @param amount The amount of stEth to wrap. Pass `type(uint).max` to wrap the module's balance.
    /// @param receiver The account receiving the wstETH tokens.
    function wrapStEth(uint256 amount, address receiver) external bundlerOnly {
        if (amount == type(uint256).max) amount = ERC20(ST_ETH).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = IWstEth(WST_ETH).wrap(amount);
        if (receiver != address(this) && received > 0) SafeTransferLib.safeTransfer(ERC20(WST_ETH), receiver, received);
    }

    /// @notice Unwraps wstETH to stETH.
    /// @dev wstETH must have been previously sent to the module.
    /// @param amount The amount of wstEth to unwrap. Pass `type(uint).max` to unwrap the module's balance.
    /// @param receiver The account receiving the stETH tokens.
    function unwrapStEth(uint256 amount, address receiver) external bundlerOnly {
        if (amount == type(uint256).max) amount = ERC20(WST_ETH).balanceOf(address(this));

        require(amount != 0, ErrorsLib.ZeroAmount());

        uint256 received = IWstEth(WST_ETH).unwrap(amount);
        if (receiver != address(this) && received > 0) SafeTransferLib.safeTransfer(ERC20(ST_ETH), receiver, received);
    }
}
