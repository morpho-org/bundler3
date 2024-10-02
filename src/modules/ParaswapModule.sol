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

    /// @notice Sell an exact amount. Reverts unless at least `minBuyAmount` tokens are received.
    /// @dev If the exact sell amount is adjusted, then `minBuyAmount` is adjusted but the slippage check parameters
    /// inside `augustusCalldata` are not adjusted.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param augustusCalldata Swap data to call `augustus` with. Contains routing information.
    /// @param sellToken Token to sell.
    /// @param buyToken Token to buy.
    /// @param minBuyAmount If the swap yields strictly less than `minBuyAmount`, the swap reverts. Can change if
    /// `sellEntireBalance` is true.
    /// @param sellEntireBalance If true, adjusts sell amount to the current balance of this contract.
    /// @param sellAmountOffset Byte offset of `augustusCalldata` where the exact sell amount is stored.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `sellToken`.
    function sell(
        address augustus,
        bytes memory augustusCalldata,
        address sellToken,
        address buyToken,
        uint256 minBuyAmount,
        bool sellEntireBalance,
        uint256 sellAmountOffset,
        address receiver
    ) external bundlerOnly inAugustusRegistry(augustus) {
        uint256 buyBalanceBefore = ERC20(buyToken).balanceOf(address(this));

        if (sellEntireBalance) {
            uint256 sellAmount = readBytesAtOffset(augustusCalldata, sellAmountOffset);
            uint256 sellBalanceBefore = ERC20(sellToken).balanceOf(address(this));

            writeBytesAtOffset(augustusCalldata, sellAmountOffset, sellBalanceBefore);
            minBuyAmount = minBuyAmount.mulDivUp(sellBalanceBefore, sellAmount);
        }

        swap(augustus, augustusCalldata, sellToken);

        uint256 boughtAmount = ERC20(buyToken).balanceOf(address(this)) - buyBalanceBefore;
        require(boughtAmount >= minBuyAmount, ErrorsLib.SLIPPAGE_EXCEEDED);

        skim(buyToken, receiver);
        skim(sellToken, receiver);
    }

    /// @notice Buy an exact amount. Reverts unless at most `maxSellAmount` tokens are sold.
    /// @dev If the exact buy amount is adjusted, then `maxSellAmount` is adjusted. But when called, the `augustus`
    /// contract may still try to transfer the max sell amount value encoded in `augustusCalldata` no matter the new
    /// `maxSellAmount` value.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param augustusCalldata Swap data to call `augustus` with. Contains routing information.
    /// @param sellToken Token to sell.
    /// @param buyToken Token to buy.
    /// @param maxSellAmount If the swap costs strctly more than `maxSellAmount`, the swap reverts. Can change if
    /// `marketParams.loanToken` is not zero.
    /// @param marketParams If `marketParams.loanToken` is not zero and equal to `buyToken`, adjusts buy amount to the
    /// initiator's debt in this market.
    /// @param buyAmountOffset Byte offset of `augustusCalldata` where the exact buy amount is stored.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `sellToken`.
    function buy(
        address augustus,
        bytes memory augustusCalldata,
        address sellToken,
        address buyToken,
        uint256 maxSellAmount,
        MarketParams memory marketParams,
        uint256 buyAmountOffset,
        address receiver
    ) public bundlerOnly inAugustusRegistry(augustus) {
        uint256 sellBalanceBefore = ERC20(sellToken).balanceOf(address(this));

        if (marketParams.loanToken != address(0)) {
            uint256 buyAmount = readBytesAtOffset(augustusCalldata, buyAmountOffset);
            require(marketParams.loanToken == buyToken, ErrorsLib.INCORRECT_LOAN_TOKEN);
            uint256 borrowAssets = MORPHO.expectedBorrowAssets(marketParams, initiator());
            writeBytesAtOffset(augustusCalldata, buyAmountOffset, borrowAssets);
            maxSellAmount = maxSellAmount.mulDivDown(borrowAssets, buyAmount);
        }

        swap(augustus, augustusCalldata, sellToken);

        skim(buyToken, receiver);
        uint256 sellBalanceSkimmed = skim(sellToken, receiver);

        uint256 soldAmount = sellBalanceBefore - sellBalanceSkimmed;
        require(soldAmount <= maxSellAmount, ErrorsLib.SLIPPAGE_EXCEEDED);
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Execute the swap specified by `augustusCalldata` with `augustus`.
    function swap(address augustus, bytes memory augustusCalldata, address sellToken) internal {
        ERC20(sellToken).safeApprove(augustus, type(uint256).max);
        (bool success, bytes memory returnData) = address(augustus).call(augustusCalldata);
        if (!success) _revert(returnData);
        ERC20(sellToken).safeApprove(augustus, 0);
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
