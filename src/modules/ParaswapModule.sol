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

    /// @notice Sells a fixed amount of `sellToken` against `buyToken`, which are then sent to `receiver`.
    /// @dev Sells the minimum of `sellAmount` and the balance of this contract.
    /// @dev Slippage is checked with `minBuyAmount`. `minBuyAmount` is adjusted if `sellAmount` is adjusted.
    /// @dev Remember to add 4 to the `augustusCalldata` offset to account for the function signature.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param augustusCalldata Swap data to call `augustus` with. Contains routing information.
    /// @param sellToken Token to sell.
    /// @param buyToken Token to buy.
    /// @param sellAmount Amount of `sellToken` to sell. Can be adjusted.
    /// @param minBuyAmount If the trade yields less than `minBuyAmount`, the trade reverts. Can be adjusted.
    /// @param sellAmountOffset Byte offset of `augustusCalldata` at which to overwrite `sellAmount`, if `sellAmount` is
    /// adjusted.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `sellToken`.
    function sell(
        address augustus,
        bytes memory augustusCalldata,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 minBuyAmount,
        uint256 sellAmountOffset,
        address receiver
    ) external bundlerOnly inAugustusRegistry(augustus) {
        uint256 buyBalanceBefore = ERC20(buyToken).balanceOf(address(this));
        uint256 sellBalanceBefore = ERC20(sellToken).balanceOf(address(this));

        if (sellBalanceBefore < sellAmount) {
            updateInPlace(augustusCalldata, sellAmountOffset, sellBalanceBefore);
            minBuyAmount = minBuyAmount.mulDivUp(sellBalanceBefore, sellAmount);
        }

        trade(augustus, augustusCalldata, sellToken);

        uint256 boughtAmount = ERC20(buyToken).balanceOf(address(this)) - buyBalanceBefore;
        require(boughtAmount >= minBuyAmount, ErrorsLib.SLIPPAGE_EXCEEDED);

        skim(sellToken, receiver);
        skim(buyToken, receiver);
    }

    /// @notice Buys a fixed amount of `buyToken` for `receiver` by selling `sellToken`.
    /// @dev Using the `marketParams` parameter, it is possible to adjust `buyAmount` from a fixed amount to the entire
    /// initiator's debt in a Morpho market.
    /// @dev Remember to add 4 to the `augustusCalldata` offset to account for the function signature.
    /// @dev Slippage is checked with `maxSellAmount`. `maxSellAmount` is adjusted if `buyAmount` is adjusted.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param augustusCalldata Swap data to call `augustus` with. Contains routing information.
    /// @param sellToken Token to sell.
    /// @param buyToken Token to buy.
    /// @param maxSellAmount If the trade costs more than `maxSellAmount`, the trade reverts. Can be adjusted.
    /// @param buyAmount Amount of `buyToken` to buy. Can be adjusted.
    /// @param buyAmountOffset Byte offset of `augustusCalldata` at which to overwrite `buyAmount`, if `buyAmount` is
    /// adjusted.
    /// @param marketParams If `marketParams.loanToken` is nonzero, adjusts `buyAmount` to the initiator's debt in this
    /// market.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `sellToken`.
    function buy(
        address augustus,
        bytes memory augustusCalldata,
        address sellToken,
        address buyToken,
        uint256 maxSellAmount,
        uint256 buyAmount,
        uint256 buyAmountOffset,
        MarketParams memory marketParams,
        address receiver
    ) public bundlerOnly inAugustusRegistry(augustus) {
        uint256 sellBalanceBefore = ERC20(sellToken).balanceOf(address(this));

        if (marketParams.loanToken != address(0)) {
            require(marketParams.loanToken == buyToken, ErrorsLib.INCORRECT_LOAN_TOKEN);
            uint256 borrowAssets = MORPHO.expectedBorrowAssets(marketParams, initiator());
            updateInPlace(augustusCalldata, buyAmountOffset, borrowAssets);
            maxSellAmount = maxSellAmount * borrowAssets / buyAmount;
        }

        trade(augustus, augustusCalldata, sellToken);
        uint256 skimmed = skim(sellToken, receiver);

        uint256 soldAmount = sellBalanceBefore - skimmed;
        require(soldAmount <= maxSellAmount, ErrorsLib.SLIPPAGE_EXCEEDED);

        skim(buyToken, receiver);
    }

    /* INTERNAL FUNCTIONS */

    /// @notice Execute the trade specified by `augustusCalldata` with `augustus`.
    function trade(address augustus, bytes memory augustusCalldata, address sellToken) internal {
        ERC20(sellToken).safeApprove(augustus, type(uint256).max);
        (bool success, bytes memory returnData) = address(augustus).call(augustusCalldata);
        if (!success) _revert(returnData);
        ERC20(sellToken).safeApprove(augustus, 0);
    }

    /// @notice Update memory bytes `data` by replacing the 32 bytes starting at `offset` with `newValue`.
    function updateInPlace(bytes memory data, uint256 offset, uint256 newValue) internal pure {
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
