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

/// @custom:security-contact security@morpho.org
/// @notice Interface of Paraswap Adapter.
interface IParaswapAdapter {
    function sell(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        bool sellEntireBalance,
        Offsets calldata offsets,
        address receiver
    ) external;

    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        Offsets calldata offsets,
        address receiver
    ) external;

    function buyMorphoDebt(
        address augustus,
        bytes memory callData,
        address srcToken,
        MarketParams calldata marketParams,
        Offsets calldata offsets,
        address onBehalf,
        address receiver
    ) external;
}
