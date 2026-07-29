// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @notice A single reallocation hop, moving liquidity from one Morpho market to another through the public allocator.
struct Reallocation {
    address deallocateAdapter;
    MarketParams deallocateMarketParams;
    address allocateAdapter;
    MarketParams allocateMarketParams;
    uint128 assets;
}

/// @custom:security-contact security@morpho.org
/// @notice Minimal interface of the vault-v2 Blue public allocator.
interface IBluePublicAllocator {
    function allocateFromIdle(address vault, address adapter, MarketParams calldata marketParams, uint128 assets)
        external
        payable;
    function reallocate(
        address vault,
        address deallocateAdapter,
        MarketParams calldata deallocateMarketParams,
        address allocateAdapter,
        MarketParams calldata allocateMarketParams,
        uint128 assets
    ) external payable;
    function vaultData(address vault)
        external
        view
        returns (bool canAllocateFromIdle, uint120 nativePenalty, uint120 accruedNativePenalty);
}
