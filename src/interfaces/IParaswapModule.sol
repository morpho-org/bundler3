// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @notice The offsets are:
///  - exactAmount, the offset in augustus calldata of the exact amount to sell / buy.
///  - limitAmount, the offset in augustus calldata of the minimum amount to buy / maximum amount to sell
///  - quotedAmount, the offset in augustus calldata of the initially quoted buy amount / initially quoted sell amount.
/// Set to 0 if the quoted amount is not present in augustus calldata so that it is not used.
struct Offsets {
    uint256 exactAmount;
    uint256 limitAmount;
    uint256 quotedAmount;
}

/// @title IParaswapModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Paraswap Module
interface IParaswapModule {
    /// @notice Sell an exact amount. Reverts unless at least `minDestAmount` tokens are received.
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
    ) external;

    /// @notice Buy an exact amount. Reverts unless at most `maxSrcAmount` tokens are sold.
    /// @param augustus Address of the swapping contract. Must be in Paraswap's Augustus registry.
    /// @param callData Swap data to call `augustus` with. Contains routing information.
    /// @dev `callData` can change if `marketParams.loanToken == destToken`.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param marketParams If `marketParams.loanToken == destToken`, adjusts amounts to sell the current balance of
    /// this contract.
    /// @dev Revert if `marketParams.loanToken != destToken` and is nonzero.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @dev The quoted sell amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent, as well as any leftover `srcToken`.
    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        MarketParams calldata marketParams,
        Offsets calldata offsets,
        address receiver
    ) external;
}
