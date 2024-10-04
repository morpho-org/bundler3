// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title IParaswapModule
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of Paraswap Module
interface IParaswapModule {
    function sell(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 minDestAmount,
        bool sellEntireBalance,
        uint256 srcAmountOffset,
        address receiver
    ) external;

    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        MarketParams memory marketParams,
        uint256 destAmountOffset,
        address receiver
    ) external;
}
