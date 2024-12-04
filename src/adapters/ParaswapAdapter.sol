// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IParaswapAdapter, Offsets, MarketParams} from "../interfaces/IParaswapAdapter.sol";
import {IAugustusRegistry} from "../interfaces/IAugustusRegistry.sol";
import {CoreAdapter, ErrorsLib, IERC20, SafeERC20, UtilsLib} from "./CoreAdapter.sol";
import {BytesLib} from "../libraries/BytesLib.sol";
import {Math} from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IMorpho, MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @custom:contact security@morpho.org
/// @notice Adapter for trading with Paraswap.
contract ParaswapAdapter is CoreAdapter, IParaswapAdapter {
    using Math for uint256;
    using BytesLib for bytes;

    /* IMMUTABLES */

    /// @notice The address of the Augustus registry.
    IAugustusRegistry public immutable AUGUSTUS_REGISTRY;

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    constructor(address bundler, address morpho, address augustusRegistry) CoreAdapter(bundler) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());
        require(augustusRegistry != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
        AUGUSTUS_REGISTRY = IAugustusRegistry(augustusRegistry);
    }

    /* SWAP ACTIONS */

    /// @notice Sells an exact amount. Can check for a minimum purchased amount.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param sellEntireBalance If true, adjusts amounts to sell the current balance of this contract.
    /// @param offsets Offsets in callData of the exact sell amount (`exactAmount`), minimum buy amount (`limitAmount`)
    /// and quoted buy amount (`quotedAmount`).
    /// @dev The quoted buy amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent.
    function sell(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        bool sellEntireBalance,
        Offsets calldata offsets,
        address receiver
    ) external {
        if (sellEntireBalance) {
            uint256 newSrcAmount = IERC20(srcToken).balanceOf(address(this));
            updateAmounts(callData, offsets, newSrcAmount, Math.Rounding.Ceil);
        }

        swap({
            augustus: augustus,
            callData: callData,
            srcToken: srcToken,
            destToken: destToken,
            maxSrcAmount: callData.get(offsets.exactAmount),
            minDestAmount: callData.get(offsets.limitAmount),
            receiver: receiver
        });
    }

    /// @notice Buys an exact amount. Can check for a maximum sold amount.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus`. Contains routing information.
    /// @dev `callData` can change if `marketParams.loanToken == destToken`.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param newDestAmount Adjusted amount to buy. Will be used to update callData before sent to Augustus contract.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @dev The quoted sell amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent. Any leftover `srcToken` should be skimmed
    /// separately.
    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        Offsets calldata offsets,
        address receiver
    ) public {
        if (newDestAmount != 0) {
            updateAmounts(callData, offsets, newDestAmount, Math.Rounding.Floor);
        }

        swap({
            augustus: augustus,
            callData: callData,
            srcToken: srcToken,
            destToken: destToken,
            maxSrcAmount: callData.get(offsets.limitAmount),
            minDestAmount: callData.get(offsets.exactAmount),
            receiver: receiver
        });
    }

    /// @notice Buys an amount corresponding to a user's Morpho debt.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus`. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param marketParams Market parameters of the market with Morpho debt.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @param onBehalf The amount bought will be exactly `onBehalf`'s debt.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
    function buyMorphoDebt(
        address augustus,
        bytes memory callData,
        address srcToken,
        MarketParams calldata marketParams,
        Offsets calldata offsets,
        address onBehalf,
        address receiver
    ) external {
        uint256 debtAmount = MorphoBalancesLib.expectedBorrowAssets(MORPHO, marketParams, onBehalf);
        buy({
            augustus: augustus,
            callData: callData,
            srcToken: srcToken,
            destToken: marketParams.loanToken,
            newDestAmount: debtAmount,
            offsets: offsets,
            receiver: receiver
        });
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Executes the swap specified by `callData` with `augustus`.
    function swap(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 minDestAmount,
        address receiver
    ) internal {
        require(AUGUSTUS_REGISTRY.isValidAugustus(augustus), ErrorsLib.AugustusNotInRegistry());
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        UtilsLib.forceApproveMaxTo(srcToken, augustus);

        uint256 srcInitial = IERC20(srcToken).balanceOf(address(this));
        uint256 destInitial = IERC20(destToken).balanceOf(address(this));

        (bool success, bytes memory returnData) = address(augustus).call(callData);
        if (!success) UtilsLib.lowLevelRevert(returnData);

        uint256 srcFinal = IERC20(srcToken).balanceOf(address(this));
        uint256 destFinal = IERC20(destToken).balanceOf(address(this));

        uint256 srcAmount = srcInitial - srcFinal;
        uint256 destAmount = destFinal - destInitial;

        require(srcAmount <= maxSrcAmount, ErrorsLib.SellAmountTooHigh());
        require(destAmount >= minDestAmount, ErrorsLib.BuyAmountTooLow());

        if (destFinal > 0 && receiver != address(this)) {
            SafeERC20.safeTransfer(IERC20(destToken), receiver, destAmount);
        }
    }

    /// @notice Sets exact amount in `callData` to `exactAmount`.
    /// @notice Proportionally scale limit amount in `callData`.
    /// @notice If `offsets.quotedAmount` is not zero, proportionally scale quoted amount in `callData`.
    function updateAmounts(
        bytes memory callData,
        Offsets calldata offsets,
        uint256 exactAmount,
        Math.Rounding rounding
    ) internal pure {
        uint256 oldExactAmount = callData.get(offsets.exactAmount);
        callData.set(offsets.exactAmount, exactAmount);

        uint256 limitAmount = callData.get(offsets.limitAmount).mulDiv(exactAmount, oldExactAmount, rounding);
        callData.set(offsets.limitAmount, limitAmount);

        if (offsets.quotedAmount > 0) {
            uint256 quotedAmount = callData.get(offsets.quotedAmount).mulDiv(exactAmount, oldExactAmount, rounding);
            callData.set(offsets.quotedAmount, quotedAmount);
        }
    }
}
