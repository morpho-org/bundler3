// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {IAugustusRegistry} from "./interfaces/IAugustusRegistry.sol";
import {IMorpho, MarketParams} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {BaseBundler} from "./BaseBundler.sol";
import {SafeTransferLib, ERC20} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {MorphoBalancesLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {BytesLib} from "./libraries/BytesLib.sol";
import "./interfaces/IParaswapBundler.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title ParaswapBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler for trading with Paraswap.
contract ParaswapBundler is BaseBundler, IParaswapBundler {
    using Math for uint256;
    using SafeTransferLib for ERC20;
    using MorphoBalancesLib for IMorpho;
    using BytesLib for bytes;

    /* IMMUTABLES */

    IAugustusRegistry public immutable AUGUSTUS_REGISTRY;
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    constructor(address hub, address morpho, address augustusRegistry) BaseBundler(hub) {
        AUGUSTUS_REGISTRY = IAugustusRegistry(augustusRegistry);
        MORPHO = IMorpho(morpho);
    }

    /* MODIFIERS */

    modifier inAugustusRegistry(address augustus) {
        require(AUGUSTUS_REGISTRY.isValidAugustus(augustus), ErrorsLib.AUGUSTUS_NOT_IN_REGISTRY);
        _;
    }

    /* SWAP ACTIONS */

    /// @inheritdoc IParaswapBundler
    function sell(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        bool sellEntireBalance,
        Offsets calldata offsets,
        address receiver
    ) external hubOnly inAugustusRegistry(augustus) {
        if (sellEntireBalance) {
            uint256 newSrcAmount = ERC20(srcToken).balanceOf(address(this));
            updateAmounts(callData, offsets, newSrcAmount, Math.Rounding.Ceil);
        }

        swapAndSkim(
            augustus,
            callData,
            srcToken,
            destToken,
            callData.get(offsets.exactAmount),
            callData.get(offsets.limitAmount),
            receiver
        );
    }

    /// @inheritdoc IParaswapBundler
    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        MarketParams calldata marketParams,
        Offsets calldata offsets,
        address receiver
    ) external hubOnly inAugustusRegistry(augustus) {
        if (marketParams.loanToken != address(0)) {
            require(marketParams.loanToken == destToken, ErrorsLib.INCORRECT_LOAN_TOKEN);
            uint256 newDestAmount = MORPHO.expectedBorrowAssets(marketParams, initiator());
            updateAmounts(callData, offsets, newDestAmount, Math.Rounding.Floor);
        }

        swapAndSkim(
            augustus,
            callData,
            srcToken,
            destToken,
            callData.get(offsets.limitAmount),
            callData.get(offsets.exactAmount),
            receiver
        );
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Execute the swap specified by `augustusCalldata` with `augustus`.
    function swapAndSkim(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 minDestAmount,
        address receiver
    ) internal {
        uint256 srcInitial = ERC20(srcToken).balanceOf(address(this));
        uint256 destInitial = ERC20(destToken).balanceOf(address(this));

        ERC20(srcToken).safeApprove(augustus, type(uint256).max);
        (bool success, bytes memory returnData) = address(augustus).call(callData);
        if (!success) _revert(returnData);
        ERC20(srcToken).safeApprove(augustus, 0);

        uint256 srcFinal = ERC20(srcToken).balanceOf(address(this));
        uint256 destFinal = ERC20(destToken).balanceOf(address(this));

        uint256 srcAmount = srcInitial - srcFinal;
        uint256 destAmount = destFinal - destInitial;

        require(srcAmount <= maxSrcAmount, ErrorsLib.SELL_AMOUNT_TOO_HIGH);
        require(destAmount >= minDestAmount, ErrorsLib.BUY_AMOUNT_TOO_LOW);

        emit EventsLib.MorphoBundlerParaswapBundlerSwap(srcToken, destToken, receiver, srcAmount, destAmount);

        if (srcFinal > 0) ERC20(srcToken).safeTransfer(receiver, srcFinal);
        if (destFinal > 0) ERC20(destToken).safeTransfer(receiver, destFinal);
    }

    /// @notice Set exact amount in `callData` to `exactAmount`.
    /// @notice Proportionally scale limit amount in `callData`.
    /// @notice If `offsets.quotedAmount` is not zero, proportionally scale quoted amount in `callData`.
    function updateAmounts(bytes memory callData, Offsets calldata offsets, uint256 exactAmount, Math.Rounding rounding)
        internal
        pure
    {
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
