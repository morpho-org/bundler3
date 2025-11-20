// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IBebopAdapter, MarketParams, BebopAggregateOrder, BebopMakerSignature} from "../interfaces/IBebopAdapter.sol";
import {CoreAdapter, ErrorsLib, IERC20, SafeERC20, UtilsLib} from "./CoreAdapter.sol";
import {BytesLib} from "../libraries/BytesLib.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IMorpho, MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @custom:security-contact security@morpho.org
/// @notice Adapter for trading with zero-slippage using Bebop.
contract BebopAdapter is CoreAdapter, IBebopAdapter {
    using Math for uint256;
    using BytesLib for bytes;

    /* IMMUTABLES */

    /// @notice The address of the BebopBlendPmm contract (0xbbbbbBB520d69a9775E85b458C58c648259FAD5F)
    address public immutable BEBOP;

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    /// @param bundler3 The address of the Bundler3 contract.
    /// @param morpho The address of the Morpho protocol.
    /// @param bebop The address of the BebopBlendPmm contract.
    constructor(address bundler3, address morpho, address bebop) CoreAdapter(bundler3) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());
        require(bebop != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
        BEBOP = bebop;
    }

    /* SWAP ACTIONS */

    /// @notice Sells an exact amount with 0 slippage
    /// @notice This function should be used immediately after sending tokens to the adapter, and any tokens remaining
    /// in the adapter after a swap should be transferred out immediately.
    /// @param callData Swap data to call `bebop` with
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param sellEntireBalance If true, adjusts amounts to sell the current balance of this contract.
    /// @param receiver Address to which bought assets will be sent. Any leftover `srcToken` should be skimmed
    /// separately.
    function sell(
        bytes memory callData,
        address srcToken,
        address destToken,
        bool sellEntireBalance,
        address receiver
    ) external {
        uint256 newSrcAmount;
        uint256 newDestAmount;
        if (sellEntireBalance) {
            newSrcAmount = IERC20(srcToken).balanceOf(address(this));
            newDestAmount = updateFilledAmountForSell(srcToken, destToken, callData, newSrcAmount);
        } else {
            (newSrcAmount, newDestAmount) = getQuoteAmounts(srcToken, destToken, callData);
        }
        swap({
            callData: callData,
            srcToken: srcToken,
            destToken: destToken,
            maxSrcAmount: newSrcAmount,
            minDestAmount: newDestAmount,
            receiver: receiver
        });
    }

    /// @notice Buys an exact amount with 0 slippage.
    /// @notice This function should be used immediately after sending tokens to the adapter, and any tokens remaining
    /// in the adapter after a swap should be transferred out immediately.
    /// @param callData Swap data to call `bebop`
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param newDestAmount Adjusted amount to buy. Will be used to update callData before sent to Bebop contract.
    /// @param receiver Address to which bought assets will be sent. Any leftover `srcToken` should be skimmed
    /// separately.
    function buy(
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        address receiver
    ) public {
        uint256 newSrcAmount;
        if (newDestAmount != 0) {
            newSrcAmount = updateFilledAmountForBuy(srcToken, destToken, callData, newDestAmount);
        } else {
            (newSrcAmount, newDestAmount) = getQuoteAmounts(srcToken, destToken, callData);
        }
        swap({
            callData: callData,
            srcToken: srcToken,
            destToken: destToken,
            maxSrcAmount: newSrcAmount,
            minDestAmount: newDestAmount,
            receiver: receiver
        });
    }

    /// @notice Buys an amount corresponding to a user's Morpho debt.
    /// @notice This function should be used immediately after sending tokens to the adapter, and any tokens remaining
    /// in the adapter after a swap should be transferred out immediately.
    /// @param callData Swap data to call `bebop`
    /// @param srcToken Token to sell.
    /// @param marketParams Market parameters of the market with Morpho debt. The user must have nonzero debt.
    /// @param onBehalf The amount bought will be exactly `onBehalf`'s debt.
    /// @param receiver Address to which bought assets will be sent. Any leftover `src` tokens should be skimmed
    /// separately.
    function buyMorphoDebt(
        bytes memory callData,
        address srcToken,
        MarketParams calldata marketParams,
        address onBehalf,
        address receiver
    ) external {
        uint256 debtAmount = MorphoBalancesLib.expectedBorrowAssets(MORPHO, marketParams, onBehalf);
        require(debtAmount != 0, ErrorsLib.ZeroAmount());
        buy({
            callData: callData,
            srcToken: srcToken,
            destToken: marketParams.loanToken,
            newDestAmount: debtAmount,
            receiver: receiver
        });
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Executes the swap specified by `callData` with `bebop`.
    /// @dev Even if this adapter holds no approval, swaps are restricted to Bundler3 here as in all adapters in
    /// order to simplify the security model.
    /// @param callData Swap data to call `bebop`
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param maxSrcAmount Maximum amount of `srcToken` to sell.
    /// @param minDestAmount Minimum amount of `destToken` to buy.
    /// @param receiver Address to which bought assets will be sent. Any leftover `src` tokens should be skimmed
    /// separately.
    function swap(
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 minDestAmount,
        address receiver
    ) internal onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        uint256 srcInitial = IERC20(srcToken).balanceOf(address(this));
        uint256 destInitial = IERC20(destToken).balanceOf(address(this));

        SafeERC20.forceApprove(IERC20(srcToken), BEBOP, type(uint256).max);

        (bool success, bytes memory returnData) = BEBOP.call(callData);
        if (!success) UtilsLib.lowLevelRevert(returnData);

        SafeERC20.forceApprove(IERC20(srcToken), BEBOP, 0);

        uint256 srcFinal = IERC20(srcToken).balanceOf(address(this));
        uint256 destFinal = IERC20(destToken).balanceOf(address(this));

        uint256 srcAmount = srcInitial - srcFinal;
        uint256 destAmount = destFinal - destInitial;

        require(srcAmount <= maxSrcAmount, ErrorsLib.SellAmountTooHigh());
        require(destAmount >= minDestAmount, ErrorsLib.BuyAmountTooLow());

        if (receiver != address(this)) {
            SafeERC20.safeTransfer(IERC20(destToken), receiver, destAmount);
        }
    }

    /// @notice Sets exact sell-amount in `callData`
    /// @return New amount for dest token
    function updateFilledAmountForSell(
        address srcToken,
        address destToken,
        bytes memory callData,
        uint256 exactAmount
    ) internal pure returns (uint256) {
        (uint256 quoteFromAmount, uint256 quoteToAmount) = getQuoteAmounts(srcToken, destToken, callData);
        if (exactAmount == quoteFromAmount) {
            return quoteToAmount;
        }
        uint256 offset = getOffset(callData);

        require(exactAmount <= quoteFromAmount, ErrorsLib.SellAmountTooHigh());
        uint256 newToAmount = quoteToAmount.mulDiv(exactAmount, quoteFromAmount, Math.Rounding.Floor);

        callData.set(offset, exactAmount);
        return newToAmount;
    }

    /// @notice Sets exact buy-amount in `callData`
    /// @return New amount for src token
    function updateFilledAmountForBuy(
        address srcToken,
        address destToken,
        bytes memory callData,
        uint256 exactAmount
    ) internal pure returns (uint256) {
        (uint256 quoteFromAmount, uint256 quoteToAmount) = getQuoteAmounts(srcToken, destToken, callData);
        if (exactAmount == quoteToAmount) {
            return quoteFromAmount;
        }
        uint256 offset = getOffset(callData);

        require(exactAmount <= quoteToAmount, ErrorsLib.BuyAmountTooLow());
        uint256 newFromAmount = quoteFromAmount.mulDiv(exactAmount, quoteToAmount, Math.Rounding.Ceil);
        
        callData.set(offset, newFromAmount);
        return newFromAmount;
    }

    /// @notice Extract quote amounts from `callData`
    function getQuoteAmounts(
        address sellToken,
        address buyToken,
        bytes memory callData
    ) internal pure returns (uint256, uint256) {
        uint32 selector;
        assembly {
            selector := shr(224, mload(add(callData, 32)))
        }
        if (selector == 0x4dcebcba) {  // swapSingle
            uint256 quoteFromAmount = callData.get(196);
            uint256 quoteToAmount = callData.get(228);
            return (quoteFromAmount, quoteToAmount);
        } else if (selector == 0xa2f74893) {  // swapAggregate
            bytes memory shifted = callData;
            uint256 overwrittenWord;
            assembly {
                let len := mload(shifted)
                let newPtr := add(shifted, 4)
                overwrittenWord := mload(newPtr)
                mstore(newPtr, sub(len, 4))
                shifted := newPtr
            }
            (BebopAggregateOrder memory order,,) = abi.decode(shifted, (BebopAggregateOrder, BebopMakerSignature[], uint256));
            uint256 quoteFromAmount;
            uint256 quoteToAmount;
            for (uint i; i < order.taker_tokens.length; ++i){
                for (uint j; j < order.taker_tokens[i].length; ++j){
                    if (order.taker_tokens[i][j] == sellToken){
                        quoteFromAmount += order.taker_amounts[i][j];
                    }
                }
            }
            for (uint i; i < order.maker_tokens.length; ++i){
                for (uint j; j < order.maker_tokens[i].length; ++j){
                    if (order.maker_tokens[i][j] == buyToken){
                        quoteToAmount += order.maker_amounts[i][j];
                    }
                }
            }
            assembly {
                mstore(add(callData, 4), overwrittenWord)
            }
            return (quoteFromAmount, quoteToAmount);
        } 
        revert ErrorsLib.UnknownSelector();
    }

    /// @notice Extract offset for filledTakerAmount field in `callData`
    function getOffset(bytes memory callData) internal pure returns (uint256) {
        uint32 selector;
        assembly {
            selector := shr(224, mload(add(callData, 32)))
        }
        if (selector == 0x4dcebcba) return 388;  // swapSingle
        if (selector == 0xa2f74893) return 68;   // swapAggregate
        revert ErrorsLib.UnknownSelector();
    }

    
}
