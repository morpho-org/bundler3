// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {BaseModule, ErrorsLib, ERC20, SafeTransferLib, ModuleLib} from "./BaseModule.sol";
import {IAugustusRegistry} from "./interfaces/IAugustusRegistry.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {BytesLib} from "./libraries/BytesLib.sol";
import "./interfaces/IParaswapModule.sol";
import {IMorpho, MorphoBalancesLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @custom:contact security@morpho.org
/// @notice Module for trading with Paraswap.
contract ParaswapModule is BaseModule, IParaswapModule {
    using Math for uint256;
    using BytesLib for bytes;

    /* IMMUTABLES */

    IAugustusRegistry public immutable AUGUSTUS_REGISTRY;
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    constructor(address bundler, address morpho, address augustusRegistry) BaseModule(bundler) {
        AUGUSTUS_REGISTRY = IAugustusRegistry(augustusRegistry);
        MORPHO = IMorpho(morpho);
    }

    /* SWAP ACTIONS */

    /// @notice Sell an exact amount. Can check for a minimum purchased amount.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param sellEntireBalance If true, adjusts amounts to sell the current balance of this contract.
    /// @param offsets Offsets in callData of the exact sell amount (`exactAmount`), minimum buy amount (`limitAmount`)
    /// and quoted buy amount (`quotedAmount`).
    /// @dev The quoted buy amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
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
            uint256 newSrcAmount = ERC20(srcToken).balanceOf(address(this));
            _updateAmounts(callData, offsets, newSrcAmount, Math.Rounding.Ceil);
        }

        _swapAndSkim(
            augustus,
            callData,
            srcToken,
            destToken,
            callData.get(offsets.exactAmount),
            callData.get(offsets.limitAmount),
            receiver
        );
    }

    /// @notice Buy an exact amount. Can check for a maximum sold amount.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @dev `callData` can change if `marketParams.loanToken == destToken`.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param newDestAmount Adjusted amount to buy. Will be used to update callData before before sent to Augustus
    /// contract.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @dev The quoted sell amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
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
            _updateAmounts(callData, offsets, newDestAmount, Math.Rounding.Floor);
        }

        _swapAndSkim(
            augustus,
            callData,
            srcToken,
            destToken,
            callData.get(offsets.limitAmount),
            callData.get(offsets.exactAmount),
            receiver
        );
    }

    /// @notice Buy the amount of the initiator's Morpho debt.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param marketParams Market parameters of the initiator's Morpho debt.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
    function buyMorphoDebt(
        address augustus,
        bytes memory callData,
        address srcToken,
        MarketParams calldata marketParams,
        Offsets calldata offsets,
        address receiver
    ) external {
        uint256 newDestAmount = MorphoBalancesLib.expectedBorrowAssets(MORPHO, marketParams, _initiator());
        buy(augustus, callData, srcToken, marketParams.loanToken, newDestAmount, offsets, receiver);
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Execute the swap specified by `augustusCalldata` with `augustus`.
    function _swapAndSkim(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 minDestAmount,
        address receiver
    ) internal {
        require(AUGUSTUS_REGISTRY.isValidAugustus(augustus), ErrorsLib.AugustusNotInRegistry());

        uint256 srcInitial = ERC20(srcToken).balanceOf(address(this));
        uint256 destInitial = ERC20(destToken).balanceOf(address(this));

        if (ERC20(srcToken).allowance(address(this), augustus) == 0) {
            SafeTransferLib.safeApprove(ERC20(srcToken), augustus, type(uint256).max);
        }

        (bool success, bytes memory returnData) = address(augustus).call(callData);
        if (!success) ModuleLib.lowLevelRevert(returnData);

        uint256 srcFinal = ERC20(srcToken).balanceOf(address(this));
        uint256 destFinal = ERC20(destToken).balanceOf(address(this));

        uint256 srcAmount = srcInitial - srcFinal;
        uint256 destAmount = destFinal - destInitial;

        require(srcAmount <= maxSrcAmount, ErrorsLib.SellAmountTooHigh());
        require(destAmount >= minDestAmount, ErrorsLib.BuyAmountTooLow());

        if (srcFinal > 0) SafeTransferLib.safeTransfer(ERC20(srcToken), receiver, srcFinal);
        if (destFinal > 0) SafeTransferLib.safeTransfer(ERC20(destToken), receiver, destFinal);
    }

    /// @notice Set exact amount in `callData` to `exactAmount`.
    /// @notice Proportionally scale limit amount in `callData`.
    /// @notice If `offsets.quotedAmount` is not zero, proportionally scale quoted amount in `callData`.
    function _updateAmounts(
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
