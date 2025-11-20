// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";



struct BebopAggregateOrder {
    uint256 expiry;
    address taker_address;
    address[] maker_addresses;
    uint256[] maker_nonces;
    address[][] taker_tokens;
    address[][] maker_tokens;
    uint256[][] taker_amounts;
    uint256[][] maker_amounts;
    address receiver;
    bytes commands;
    uint256 flags;
}


struct BebopMakerSignature {
    bytes signatureBytes;
    uint256 flags;
}

/// @custom:security-contact security@morpho.org
/// @notice Interface of Bebop Adapter.
interface IBebopAdapter {
     function sell(
        bytes memory callData,
        address srcToken,
        address destToken,
        bool sellEntireBalance,
        address receiver
    ) external;

    function buy(
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        address receiver
    ) external;

    function buyMorphoDebt(
        bytes memory callData,
        address srcToken,
        MarketParams calldata marketParams,
        address onBehalf,
        address receiver
    ) external;
}
