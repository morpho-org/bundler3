// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {IAugustusRegistry} from "../interfaces/IAugustusRegistry.sol";
import {IMorpho, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {BaseMorphoBundlerModule} from "./BaseMorphoBundlerModule.sol";
import {SafeTransferLib, ERC20} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MathLib} from "../../lib/morpho-blue/src/libraries/MathLib.sol";

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
        uint256 destBalanceBefore = ERC20(destToken).balanceOf(address(this));

        if (sellEntireBalance) {
            uint256 srcAmount = readBytesAtOffset(callData, srcAmountOffset);
            uint256 sellBalanceBefore = ERC20(srcToken).balanceOf(address(this));

            writeBytesAtOffset(callData, srcAmountOffset, sellBalanceBefore);
            minDestAmount = minDestAmount.mulDivUp(sellBalanceBefore, srcAmount);
        }

        swap(augustus, callData, srcToken);

        uint256 destAmount = ERC20(destToken).balanceOf(address(this)) - destBalanceBefore;
        require(destAmount >= minDestAmount, ErrorsLib.SLIPPAGE_EXCEEDED);

        skim(destToken, receiver);
        skim(srcToken, receiver);
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
    ) public bundlerOnly inAugustusRegistry(augustus) {
        uint256 srcBalanceBefore = ERC20(srcToken).balanceOf(address(this));

        if (marketParams.loanToken != address(0)) {
            require(marketParams.loanToken == destToken, ErrorsLib.INCORRECT_LOAN_TOKEN);
            uint256 destAmount = readBytesAtOffset(callData, destAmountOffset);
            uint256 borrowAssets = MORPHO.expectedBorrowAssets(marketParams, initiator());
            writeBytesAtOffset(callData, destAmountOffset, borrowAssets);
            maxSrcAmount = maxSrcAmount.mulDivDown(borrowAssets, destAmount);
        }

        swap(augustus, callData, srcToken);

        skim(destToken, receiver);
        uint256 srcBalanceAfter = skim(srcToken, receiver);

        uint256 srcAmount = srcBalanceBefore - srcBalanceAfter;
        require(srcAmount <= maxSrcAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Execute the swap specified by `callData` with `augustus`.
    function swap(address augustus, bytes memory callData, address srcToken) internal {
        ERC20(srcToken).safeApprove(augustus, type(uint256).max);
        (bool success, bytes memory returnData) = address(augustus).call(callData);
        if (!success) _revert(returnData);
        ERC20(srcToken).safeApprove(augustus, 0);
    }

    /// @notice Read 32 bytes at offset `offset` of memory bytes `data`.
    function readBytesAtOffset(bytes memory data, uint256 offset) internal pure returns (uint256 currentValue) {
        require(offset <= data.length - 32, ErrorsLib.INVALID_OFFSET);
        assembly {
            currentValue := mload(add(32, add(data, offset)))
        }
    }

    /// @notice Write `newValue` at offset `offset` of memory bytes `data`.
    function writeBytesAtOffset(bytes memory data, uint256 offset, uint256 newValue) internal pure {
        require(offset <= data.length - 32, ErrorsLib.INVALID_OFFSET);
        assembly ("memory-safe") {
            let memoryOffset := add(32, add(data, offset))
            mstore(memoryOffset, newValue)
        }
    }

    /// @notice Send remaining balance of `token` to `dest`.
    function skim(address token, address dest) internal returns (uint256 skimmed) {
        skimmed = ERC20(token).balanceOf(address(this));
        if (skimmed > 0) ERC20(token).transfer(dest, skimmed);
    }
}
