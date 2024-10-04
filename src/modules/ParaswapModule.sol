// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {IAugustusRegistry} from "../interfaces/IAugustusRegistry.sol";
import {IMorpho, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {BaseMorphoBundlerModule} from "./BaseMorphoBundlerModule.sol";
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MathLib} from "../../lib/morpho-blue/src/libraries/MathLib.sol";
import {BytesLib} from "../libraries/BytesLib.sol";
import {EventsLib} from "../libraries/EventsLib.sol";

interface HasMorpho {
    function MORPHO() external returns (IMorpho);
}

/// @title ParaswapModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Module for trading with Paraswap.
contract ParaswapModule is BaseMorphoBundlerModule {
    using MathLib for uint256;
    using SafeTransferLib for ERC20;
    using MorphoBalancesLib for IMorpho;
    using BytesLib for bytes;

    /* IMMUTABLES */

    IAugustusRegistry public immutable AUGUSTUS_REGISTRY;
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    constructor(address morphoBundler, address augustusRegistry) BaseMorphoBundlerModule(morphoBundler) {
        AUGUSTUS_REGISTRY = IAugustusRegistry(augustusRegistry);
        MORPHO = HasMorpho(morphoBundler).MORPHO();
    }

    /* MODIFIERS */

    modifier inAugustusRegistry(address augustus) {
        require(AUGUSTUS_REGISTRY.isValidAugustus(augustus), ErrorsLib.AUGUSTUS_NOT_IN_REGISTRY);
        _;
    }

    /* SWAP ACTIONS */

    /// @notice Sell an exact amount. Reverts unless at least `minDestAmount` tokens are received.
    /// @dev If the exact sell amount is adjusted, then `minDestAmount` is adjusted but the slippage check parameters
    /// inside `callData` are not adjusted.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param minDestAmount If the swap yields strictly less than `minDestAmount`, the swap reverts. Can change if
    /// `sellEntireBalance` is true.
    /// @param sellEntireBalance If true, adjusts sell amount to the current balance of this contract.
    /// @param srcAmountOffset Byte offset of `callData` where the exact sell amount is stored.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
    function sell(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 minDestAmount,
        bool sellEntireBalance,
        uint256 srcAmountOffset,
        address receiver
    ) external bundlerOnly inAugustusRegistry(augustus) {
        if (sellEntireBalance) {
            uint256 srcAmount = callData.get(srcAmountOffset);
            uint256 newSrcAmount = ERC20(srcToken).balanceOf(address(this));
            callData.set(srcAmountOffset, newSrcAmount);
            minDestAmount = minDestAmount.mulDivUp(newSrcAmount, srcAmount);
        }

        swapAndSkim(augustus, callData, srcToken, destToken, callData.get(srcAmountOffset), minDestAmount,receiver);
    }

    /// @notice Buy an exact amount. Reverts unless at most `maxSrcAmount` tokens are sold.
    /// @dev If the exact buy amount is adjusted, then `maxSrcAmount` is adjusted. But when called, the `augustus`
    /// contract may still try to transfer the max sell amount value encoded in `callData` no matter the new
    /// `maxSrcAmount` value.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param maxSrcAmount If the swap costs strctly more than `maxSrcAmount`, the swap reverts. Can change if
    /// `marketParams.loanToken` is not zero.
    /// @param marketParams If `marketParams.loanToken` is not zero and equal to `destToken`, adjusts buy amount to the
    /// initiator's debt in this market.
    /// @param destAmountOffset Byte offset of `callData` where the exact buy amount is stored.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        MarketParams memory marketParams,
        uint256 destAmountOffset,
        address receiver
    ) external bundlerOnly inAugustusRegistry(augustus) {
        if (marketParams.loanToken != address(0)) {
            require(marketParams.loanToken == destToken, ErrorsLib.INCORRECT_LOAN_TOKEN);
            uint256 destAmount = callData.get(destAmountOffset);
            uint256 newDestAmount = MORPHO.expectedBorrowAssets(marketParams, initiator());
            callData.set(destAmountOffset, newDestAmount);
            maxSrcAmount = maxSrcAmount.mulDivDown(newDestAmount, destAmount);
        }

        swapAndSkim(augustus, callData, srcToken,destToken,maxSrcAmount,callData.get(destAmountOffset),receiver);
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Execute the swap specified by `callData` with `augustus` and check spent/bought amounts.
    function swapAndSkim(address augustus, bytes memory callData, address srcToken, address destToken, uint maxSrcAmount, uint minDestAmount, address receiver) internal {
        uint256 srcInitial = ERC20(srcToken).balanceOf(address(this));
        uint256 destInitial = ERC20(destToken).balanceOf(address(this));

        ERC20(srcToken).safeApprove(augustus, type(uint256).max);
        (bool success, bytes memory returnData) = address(augustus).call(callData);
        if (!success) _revert(returnData);
        ERC20(srcToken).safeApprove(augustus, 0);

        uint256 srcFinal = ERC20(srcToken).balanceOf(address(this));
        uint destFinal = ERC20(destToken).balanceOf(address(this));

        uint srcAmount = srcInitial - srcFinal;
        uint destAmount = destFinal - destInitial;

        require(srcAmount <= maxSrcAmount, ErrorsLib.SELL_AMOUNT_TOO_HIGH);
        require(destAmount >= minDestAmount, ErrorsLib.BUY_AMOUNT_TOO_LOW);

        emit EventsLib.MorphoBundlerParaswapModuleSwap(srcToken, destToken, receiver, srcAmount, destAmount);

        if (srcFinal > 0) ERC20(srcToken).safeTransfer(receiver, srcFinal);
        if (destFinal > 0) ERC20(destToken).safeTransfer(receiver, destFinal);

    }
}
